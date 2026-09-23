import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import ExcelJS from 'exceljs';
import * as yaml from 'js-yaml';
import { Pool } from 'pg';
import { S3Client, GetObjectCommand, ListObjectsV2Command } from '@aws-sdk/client-s3';
import type { Readable } from 'stream';

// A private, writable scratch directory for files downloaded from the
// data lake — deliberately NOT the bind-mounted department-files/output
// (that mount is read-only, and files here are re-fetched from MinIO on
// every run anyway, so nothing needs to persist between runs).
const OUTPUT_DIR = path.join(os.tmpdir(), 'department-files-output');

// The "data lake" raw zone (MinIO) — every read function below still
// reads from OUTPUT_DIR on local disk, but downloadDataLakeFiles() (run
// once at the top of runEtl(), before any reader) populates that
// directory fresh from the lake first. This is the real source of truth
// for a scheduled run — the local files generate.ts happened to leave
// behind are not trusted here. Defaults to the Docker-network hostname
// since this runs inside the pipeline container in real use.
const DATALAKE_ENDPOINT = process.env.DATALAKE_ENDPOINT || 'http://analytics-datalake:9000';
const DATALAKE_BUCKET = 'department-files';

function dataLakeClient(): S3Client {
  return new S3Client({
    endpoint: DATALAKE_ENDPOINT,
    region: 'us-east-1',
    credentials: { accessKeyId: 'minioadmin', secretAccessKey: 'minioadmin123' },
    forcePathStyle: true, // required for MinIO's S3-compatible API
  });
}

async function streamToBuffer(stream: Readable): Promise<Buffer> {
  const chunks: Buffer[] = [];
  for await (const chunk of stream) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  return Buffer.concat(chunks);
}

async function downloadDataLakeFiles(): Promise<number> {
  const client = dataLakeClient();
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  const list = await client.send(new ListObjectsV2Command({ Bucket: DATALAKE_BUCKET }));
  const objects = list.Contents ?? [];
  for (const obj of objects) {
    if (!obj.Key) continue;
    const res = await client.send(new GetObjectCommand({ Bucket: DATALAKE_BUCKET, Key: obj.Key }));
    const body = await streamToBuffer(res.Body as Readable);
    fs.writeFileSync(path.join(OUTPUT_DIR, obj.Key), body);
  }
  return objects.length;
}

type AccountingRecord = {
  fecha: Date;
  tipo: string;
  categoria: string;
  monto: number;
  moneda: string;
  nombre_empleado: string;
};

type BudgetRecord = {
  departamento: string;
  presupuesto_asignado: number;
  gastado: number;
  periodo: string;
  nombre_empleado: string;
};

type OpsRecord = {
  ticket_id: string;
  fecha: string;
  tipo: string;
  estado: string;
  tiempo_resolucion_horas: number;
  descripcion: string;
  nombre_empleado: string;
};

type HrRecord = {
  nombre_empleado: string;
  departamento: string;
  puesto: string | null;
  salario: number;
  fecha_contratacion: string;
};

type MarketingRecord = {
  campana: string;
  nombre_empleado: string;
  canal: string;
  presupuesto: number | null;
  fecha_inicio: string;
};

type LegalRecord = {
  numero: string;
  tipo: string | null;
  monto: number;
  fecha_firma: string;
  nombre_empleado: string;
};

type ComprasRecord = {
  nombre_empleado: string;
  producto: string;
  cantidad: number;
  monto: number;
  fecha: string;
};

type InventarioRecord = {
  item_id: string;
  producto: string;
  cantidad: number;
  nombre_empleado: string;
  ubicacion: string | null;
};

type SoporteRecord = {
  ticket: string;
  nombre_empleado: string;
  prioridad: string;
  estado: string;
};

type AuditoriaRecord = {
  timestamp: string;
  nombre_empleado: string;
  accion: string;
  resultado: string;
};

// Shared cleanup for every source's employee-name field: every file here
// has its own dirt (extra whitespace, inconsistent casing) on top of its
// own field-naming mismatch — trim first, then title-case so "  JANE DOE  "
// and "jane doe" both normalize to the same "Jane Doe".
function cleanName(raw: string): string {
  const trimmed = raw.trim().replace(/\s+/g, ' ');
  return trimmed
    .toLowerCase()
    .split(' ')
    .map((word) => (word.length > 0 ? word[0].toUpperCase() + word.slice(1) : word))
    .join(' ');
}

// recursos_humanos.txt mixes DD/MM/YYYY and YYYY-MM-DD in the same column
// (dirty on purpose) — normalize both to YYYY-MM-DD for the date column.
function normalizeDate(raw: string): string {
  const isoMatch = raw.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (isoMatch) return raw;
  const dmyMatch = raw.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
  if (dmyMatch) {
    const [, d, m, y] = dmyMatch;
    return `${y}-${m.padStart(2, '0')}-${d.padStart(2, '0')}`;
  }
  return raw;
}

// Reads by fixed column position, matching generate.ts's exact write
// order (1=fecha, 2=tipo, 3=categoria, 4=monto, 5=moneda, 6=emp_nom) —
// this is the emp_nom -> nombre_empleado normalization for this source.
async function readAccountingExcel(): Promise<AccountingRecord[]> {
  const workbook = new ExcelJS.Workbook();
  await workbook.xlsx.readFile(path.join(OUTPUT_DIR, 'contabilidad.xlsx'));
  const sheet = workbook.worksheets[0];
  const records: AccountingRecord[] = [];
  sheet.eachRow((row, rowNumber) => {
    if (rowNumber === 1) return; // header
    records.push({
      fecha: row.getCell(1).value as Date,
      tipo: String(row.getCell(2).value),
      categoria: String(row.getCell(3).value),
      monto: Number(row.getCell(4).value),
      moneda: String(row.getCell(5).value),
      nombre_empleado: cleanName(String(row.getCell(6).value)),
    });
  });
  return records;
}

function parseCsvLine(line: string): string[] {
  // generate.ts's own writer never emits commas/quotes inside a field,
  // so a plain split is a safe, dependency-free reader for this file.
  return line.split(',');
}

// header-name lookup here (unlike the Excel reader) is fine since the
// CSV is small and this is the nombre_empl -> nombre_empleado mapping.
async function readFinanceCsv(): Promise<BudgetRecord[]> {
  const content = fs.readFileSync(path.join(OUTPUT_DIR, 'finanzas.csv'), 'utf-8');
  const lines = content.trim().split('\n');
  const headers = parseCsvLine(lines[0]);
  return lines.slice(1).map((line) => {
    const values = parseCsvLine(line);
    const record: Record<string, string> = {};
    headers.forEach((h, i) => { record[h] = values[i]; });
    return {
      departamento: record.departamento,
      presupuesto_asignado: Number(record.presupuesto_asignado),
      gastado: Number(record.gastado),
      periodo: record.periodo,
      nombre_empleado: cleanName(record.nombre_empl),
    };
  });
}

// This is the NOMBRE_EMPLEADO -> nombre_empleado mapping (case-normalized).
async function readOpsJson(): Promise<OpsRecord[]> {
  const content = fs.readFileSync(path.join(OUTPUT_DIR, 'operaciones.json'), 'utf-8');
  const rows = JSON.parse(content) as Record<string, unknown>[];
  return rows.map((row) => ({
    ticket_id: String(row.ticket_id),
    fecha: String(row.fecha),
    tipo: String(row.tipo),
    estado: String(row.estado),
    tiempo_resolucion_horas: Number(row.tiempo_resolucion_horas),
    descripcion: String(row.descripcion),
    nombre_empleado: cleanName(String(row.NOMBRE_EMPLEADO)),
  }));
}

// Pipe-delimited plain text (an old HR export). This is the
// empleado_nombre -> nombre_empleado mapping; also cleans the mixed
// DD/MM/YYYY vs YYYY-MM-DD dates and normalizes a blank puesto to null.
async function readHrTxt(): Promise<HrRecord[]> {
  const content = fs.readFileSync(path.join(OUTPUT_DIR, 'recursos_humanos.txt'), 'utf-8');
  const lines = content.trim().split('\n');
  return lines.slice(1).map((line) => {
    const [nombre, departamento, puesto, salario, fecha] = line.split('|');
    return {
      nombre_empleado: cleanName(nombre),
      departamento: departamento.trim(),
      puesto: puesto.trim().length > 0 ? puesto.trim() : null,
      salario: Number(salario),
      fecha_contratacion: normalizeDate(fecha.trim()),
    };
  });
}

// YAML (a marketing tool's export). This is the responsable ->
// nombre_empleado mapping; also normalizes canal casing/whitespace and
// leaves a null presupuesto as null rather than coercing it to 0 (a
// missing budget is a real "we don't know," not a real zero).
async function readMarketingYaml(): Promise<MarketingRecord[]> {
  const content = fs.readFileSync(path.join(OUTPUT_DIR, 'marketing.yaml'), 'utf-8');
  const parsed = yaml.load(content) as { campanas: Record<string, unknown>[] };
  return parsed.campanas.map((row) => ({
    campana: String(row.campana),
    nombre_empleado: cleanName(String(row.responsable)),
    canal: String(row.canal).trim().toLowerCase(),
    presupuesto: row.presupuesto === null ? null : Number(row.presupuesto),
    fecha_inicio: String(row.fecha_inicio),
  }));
}

// XML (a legal/contracts export). This is the responsable_legal ->
// nombre_empleado mapping; a bare-bones regex-based reader is enough
// here since the writer's structure is fixed and simple — a full XML
// parser would be overkill for one flat repeating element.
async function readLegalXml(): Promise<LegalRecord[]> {
  const content = fs.readFileSync(path.join(OUTPUT_DIR, 'legal.xml'), 'utf-8');
  const records: LegalRecord[] = [];
  const contractBlocks = content.match(/<contrato>[\s\S]*?<\/contrato>/g) ?? [];
  for (const block of contractBlocks) {
    const field = (tag: string) => block.match(new RegExp(`<${tag}>([\\s\\S]*?)</${tag}>`))?.[1] ?? '';
    const hasEmptyTipo = /<tipo\/>/.test(block);
    records.push({
      numero: field('numero'),
      tipo: hasEmptyTipo ? null : field('tipo'),
      monto: Number(field('monto')),
      fecha_firma: field('fecha_firma'),
      nombre_empleado: cleanName(field('responsable_legal')),
    });
  }
  return records;
}

// Fixed-width plain text (a mainframe-style purchasing report) — every
// column occupies an exact character width, no delimiter. Widths must
// match generate.ts's COMPRAS_WIDTHS exactly.
const COMPRAS_WIDTHS = { empleado: 20, producto: 25, cantidad: 10, monto: 11, fecha: 10 };
async function readComprasTxt(): Promise<ComprasRecord[]> {
  const content = fs.readFileSync(path.join(OUTPUT_DIR, 'compras.txt'), 'utf-8');
  const lines = content.split('\n').filter((l) => l.trim().length > 0);
  const w = COMPRAS_WIDTHS;
  return lines.slice(1).map((line) => {
    let pos = 0;
    const empleado = line.slice(pos, pos += w.empleado).trim();
    const producto = line.slice(pos, pos += w.producto).trim();
    const cantidad = line.slice(pos, pos += w.cantidad).trim();
    const monto = line.slice(pos, pos += w.monto).trim();
    const fecha = line.slice(pos, pos += w.fecha).trim();
    return {
      nombre_empleado: cleanName(empleado),
      producto,
      cantidad: Number(cantidad),
      monto: Number(monto),
      fecha,
    };
  });
}

// INI/properties format — one [section] per inventory item. This is the
// responsable_inventario -> nombre_empleado mapping; a missing ubicacion
// key (dirty on purpose) is treated as null rather than an empty string.
async function readInventarioIni(): Promise<InventarioRecord[]> {
  const content = fs.readFileSync(path.join(OUTPUT_DIR, 'inventario.ini'), 'utf-8');
  const sections = content.split(/\n(?=\[)/).map((s) => s.trim()).filter((s) => s.length > 0);
  return sections.map((section) => {
    const idMatch = section.match(/^\[(.+?)\]/);
    const kv: Record<string, string> = {};
    for (const line of section.split('\n').slice(1)) {
      const eq = line.indexOf('=');
      if (eq === -1) continue;
      kv[line.slice(0, eq).trim()] = line.slice(eq + 1).trim();
    }
    return {
      item_id: idMatch?.[1] ?? '',
      producto: kv.producto,
      cantidad: Number(kv.cantidad),
      nombre_empleado: cleanName(kv.responsable_inventario),
      ubicacion: kv.ubicacion ?? null,
    };
  });
}

// Markdown table — this is the "Empleado Asignado" -> nombre_empleado
// mapping. Splits each row on "|" and trims every cell (dirty on purpose:
// inconsistent whitespace around the employee name).
async function readSoporteMd(): Promise<SoporteRecord[]> {
  const content = fs.readFileSync(path.join(OUTPUT_DIR, 'soporte.md'), 'utf-8');
  const lines = content.trim().split('\n').slice(2); // skip header + separator row
  return lines.map((line) => {
    const cells = line.split('|').map((c) => c.trim()).filter((c) => c.length > 0);
    const [ticket, empleado, prioridad, estado] = cells;
    return {
      ticket,
      nombre_empleado: cleanName(empleado),
      prioridad,
      estado,
    };
  });
}

// Custom "key=value" log lines — this is the AUDITOR= -> nombre_empleado
// mapping (AUDITOR's casing varies row to row on purpose).
async function readAuditoriaLog(): Promise<AuditoriaRecord[]> {
  const content = fs.readFileSync(path.join(OUTPUT_DIR, 'auditoria.log'), 'utf-8');
  const lines = content.trim().split('\n');
  return lines.map((line) => {
    const parts = line.split('|').map((p) => p.trim());
    const timestamp = parts[0];
    const field = (key: string) => parts.find((p) => p.startsWith(`${key}=`))?.slice(key.length + 1) ?? '';
    return {
      timestamp,
      nombre_empleado: cleanName(field('AUDITOR')),
      accion: field('ACCION'),
      resultado: field('RESULTADO'),
    };
  });
}

async function ensureTables(pool: Pool): Promise<void> {
  await pool.query(`
    create table if not exists accounting_records (
      id serial primary key,
      fecha date not null,
      tipo text not null,
      categoria text not null,
      monto numeric(12,2) not null,
      moneda text not null,
      nombre_empleado text not null,
      source_file text not null,
      loaded_at timestamptz not null default now()
    );
    create table if not exists department_budgets (
      id serial primary key,
      departamento text not null,
      presupuesto_asignado numeric(12,2) not null,
      gastado numeric(12,2) not null,
      periodo text not null,
      nombre_empleado text not null,
      source_file text not null,
      loaded_at timestamptz not null default now()
    );
    create table if not exists ops_metrics (
      id serial primary key,
      ticket_id text not null,
      fecha date not null,
      tipo text not null,
      estado text not null,
      tiempo_resolucion_horas numeric(6,2) not null,
      descripcion text not null,
      nombre_empleado text not null,
      source_file text not null,
      loaded_at timestamptz not null default now()
    );
    create table if not exists hr_records (
      id serial primary key,
      nombre_empleado text not null,
      departamento text not null,
      puesto text,
      salario numeric(12,2) not null,
      fecha_contratacion date not null,
      source_file text not null,
      loaded_at timestamptz not null default now()
    );
    create table if not exists marketing_campaigns (
      id serial primary key,
      campana text not null,
      nombre_empleado text not null,
      canal text not null,
      presupuesto numeric(12,2),
      fecha_inicio date not null,
      source_file text not null,
      loaded_at timestamptz not null default now()
    );
    create table if not exists legal_contracts (
      id serial primary key,
      numero text not null,
      tipo text,
      monto numeric(12,2) not null,
      fecha_firma date not null,
      nombre_empleado text not null,
      source_file text not null,
      loaded_at timestamptz not null default now()
    );
    create table if not exists purchase_records (
      id serial primary key,
      nombre_empleado text not null,
      producto text not null,
      cantidad integer not null,
      monto numeric(12,2) not null,
      fecha date not null,
      source_file text not null,
      loaded_at timestamptz not null default now()
    );
    create table if not exists inventory_items (
      id serial primary key,
      item_id text not null,
      producto text not null,
      cantidad integer not null,
      nombre_empleado text not null,
      ubicacion text,
      source_file text not null,
      loaded_at timestamptz not null default now()
    );
    create table if not exists support_tickets (
      id serial primary key,
      ticket text not null,
      nombre_empleado text not null,
      prioridad text not null,
      estado text not null,
      source_file text not null,
      loaded_at timestamptz not null default now()
    );
    create table if not exists audit_log (
      id serial primary key,
      event_timestamp timestamptz not null,
      nombre_empleado text not null,
      accion text not null,
      resultado text not null,
      source_file text not null,
      loaded_at timestamptz not null default now()
    );
  `);
}

export async function runEtl(analyticsUrl: string): Promise<void> {
  const pool = new Pool({ connectionString: analyticsUrl });
  try {
    const fetched = await downloadDataLakeFiles();
    console.log(`Fetched ${fetched} files from the data lake (bucket: ${DATALAKE_BUCKET}, endpoint: ${DATALAKE_ENDPOINT})`);

    await ensureTables(pool);

    const accounting = await readAccountingExcel();
    await pool.query('truncate accounting_records restart identity');
    for (const r of accounting) {
      await pool.query(
        `insert into accounting_records (fecha, tipo, categoria, monto, moneda, nombre_empleado, source_file)
         values ($1,$2,$3,$4,$5,$6,$7)`,
        [r.fecha, r.tipo, r.categoria, r.monto, r.moneda, r.nombre_empleado, 'contabilidad.xlsx'],
      );
    }

    const finance = await readFinanceCsv();
    await pool.query('truncate department_budgets restart identity');
    for (const r of finance) {
      await pool.query(
        `insert into department_budgets (departamento, presupuesto_asignado, gastado, periodo, nombre_empleado, source_file)
         values ($1,$2,$3,$4,$5,$6)`,
        [r.departamento, r.presupuesto_asignado, r.gastado, r.periodo, r.nombre_empleado, 'finanzas.csv'],
      );
    }

    const ops = await readOpsJson();
    await pool.query('truncate ops_metrics restart identity');
    for (const r of ops) {
      await pool.query(
        `insert into ops_metrics (ticket_id, fecha, tipo, estado, tiempo_resolucion_horas, descripcion, nombre_empleado, source_file)
         values ($1,$2,$3,$4,$5,$6,$7,$8)`,
        [r.ticket_id, r.fecha, r.tipo, r.estado, r.tiempo_resolucion_horas, r.descripcion, r.nombre_empleado, 'operaciones.json'],
      );
    }

    const hr = await readHrTxt();
    await pool.query('truncate hr_records restart identity');
    for (const r of hr) {
      await pool.query(
        `insert into hr_records (nombre_empleado, departamento, puesto, salario, fecha_contratacion, source_file)
         values ($1,$2,$3,$4,$5,$6)`,
        [r.nombre_empleado, r.departamento, r.puesto, r.salario, r.fecha_contratacion, 'recursos_humanos.txt'],
      );
    }

    const marketing = await readMarketingYaml();
    await pool.query('truncate marketing_campaigns restart identity');
    for (const r of marketing) {
      await pool.query(
        `insert into marketing_campaigns (campana, nombre_empleado, canal, presupuesto, fecha_inicio, source_file)
         values ($1,$2,$3,$4,$5,$6)`,
        [r.campana, r.nombre_empleado, r.canal, r.presupuesto, r.fecha_inicio, 'marketing.yaml'],
      );
    }

    const legal = await readLegalXml();
    await pool.query('truncate legal_contracts restart identity');
    for (const r of legal) {
      await pool.query(
        `insert into legal_contracts (numero, tipo, monto, fecha_firma, nombre_empleado, source_file)
         values ($1,$2,$3,$4,$5,$6)`,
        [r.numero, r.tipo, r.monto, r.fecha_firma, r.nombre_empleado, 'legal.xml'],
      );
    }

    const compras = await readComprasTxt();
    await pool.query('truncate purchase_records restart identity');
    for (const r of compras) {
      await pool.query(
        `insert into purchase_records (nombre_empleado, producto, cantidad, monto, fecha, source_file)
         values ($1,$2,$3,$4,$5,$6)`,
        [r.nombre_empleado, r.producto, r.cantidad, r.monto, r.fecha, 'compras.txt'],
      );
    }

    const inventario = await readInventarioIni();
    await pool.query('truncate inventory_items restart identity');
    for (const r of inventario) {
      await pool.query(
        `insert into inventory_items (item_id, producto, cantidad, nombre_empleado, ubicacion, source_file)
         values ($1,$2,$3,$4,$5,$6)`,
        [r.item_id, r.producto, r.cantidad, r.nombre_empleado, r.ubicacion, 'inventario.ini'],
      );
    }

    const soporte = await readSoporteMd();
    await pool.query('truncate support_tickets restart identity');
    for (const r of soporte) {
      await pool.query(
        `insert into support_tickets (ticket, nombre_empleado, prioridad, estado, source_file)
         values ($1,$2,$3,$4,$5)`,
        [r.ticket, r.nombre_empleado, r.prioridad, r.estado, 'soporte.md'],
      );
    }

    const auditoria = await readAuditoriaLog();
    await pool.query('truncate audit_log restart identity');
    for (const r of auditoria) {
      await pool.query(
        `insert into audit_log (event_timestamp, nombre_empleado, accion, resultado, source_file)
         values ($1,$2,$3,$4,$5)`,
        [r.timestamp, r.nombre_empleado, r.accion, r.resultado, 'auditoria.log'],
      );
    }

    console.log(
      `ETL complete: ${accounting.length} accounting, ${finance.length} budget, ${ops.length} ops, `
      + `${hr.length} hr, ${marketing.length} marketing, ${legal.length} legal, ${compras.length} compras, `
      + `${inventario.length} inventario, ${soporte.length} soporte, ${auditoria.length} auditoria rows.`,
    );
  } finally {
    await pool.end();
  }
}

if (require.main === module) {
  const analyticsUrl = process.env.ANALYTICS_DATABASE_URL;
  if (!analyticsUrl) {
    throw new Error('ANALYTICS_DATABASE_URL is required');
  }
  runEtl(analyticsUrl).catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
