import * as fs from 'fs';
import * as path from 'path';
import ExcelJS from 'exceljs';
import { Pool } from 'pg';

const OUTPUT_DIR = path.join(process.cwd(), 'department-files', 'output');

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
      nombre_empleado: String(row.getCell(6).value),
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
      nombre_empleado: record.nombre_empl,
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
    nombre_empleado: String(row.NOMBRE_EMPLEADO),
  }));
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
  `);
}

export async function runEtl(analyticsUrl: string): Promise<void> {
  const pool = new Pool({ connectionString: analyticsUrl });
  try {
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

    console.log(`ETL complete: ${accounting.length} accounting rows, ${finance.length} budget rows, ${ops.length} ops rows.`);
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
