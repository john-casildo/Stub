import { faker } from '@faker-js/faker';
import ExcelJS from 'exceljs';
import * as fs from 'fs';
import * as path from 'path';
import { S3Client, PutObjectCommand, CreateBucketCommand, HeadBucketCommand } from '@aws-sdk/client-s3';

// Use process.cwd() which is always the analytics directory when run via npm
const OUTPUT_DIR = path.join(process.cwd(), 'department-files', 'output');

// The "data lake" raw zone (MinIO, S3-compatible) — this script is the
// producer side: every file it writes locally also gets uploaded here,
// simulating each department dropping its own export into shared
// storage. `etl.ts` is the consumer side — it downloads from this same
// bucket before parsing, never reading generate.ts's local output
// directly in a real run (the local copy is a convenience for
// inspecting what was generated, not the pipeline's actual source).
// Defaults to localhost:9000 since this script normally runs on the
// host (`npm run generate-files`), reaching MinIO via its published
// port — not the Docker-network hostname etl.ts uses from inside a
// container.
const DATALAKE_ENDPOINT = process.env.DATALAKE_ENDPOINT || 'http://localhost:9000';
const DATALAKE_BUCKET = 'department-files';

function dataLakeClient(): S3Client {
  return new S3Client({
    endpoint: DATALAKE_ENDPOINT,
    region: 'us-east-1',
    credentials: { accessKeyId: 'minioadmin', secretAccessKey: 'minioadmin123' },
    forcePathStyle: true, // required for MinIO's S3-compatible API
  });
}

async function ensureBucket(client: S3Client): Promise<void> {
  try {
    await client.send(new HeadBucketCommand({ Bucket: DATALAKE_BUCKET }));
  } catch {
    await client.send(new CreateBucketCommand({ Bucket: DATALAKE_BUCKET }));
  }
}

async function uploadAllToDataLake(): Promise<void> {
  const client = dataLakeClient();
  await ensureBucket(client);
  const files = fs.readdirSync(OUTPUT_DIR);
  for (const file of files) {
    const body = fs.readFileSync(path.join(OUTPUT_DIR, file));
    await client.send(new PutObjectCommand({ Bucket: DATALAKE_BUCKET, Key: file, Body: body }));
  }
  console.log(`Uploaded ${files.length} files to data lake (bucket: ${DATALAKE_BUCKET}, endpoint: ${DATALAKE_ENDPOINT})`);
}

// A fixed pool of employees, reused across all three files/rows instead of
// generating a fresh random name per row — without this, "spend by
// employee"-style dashboards are meaningless (almost every row gets a
// unique name, so there's nothing to group). Real companies have a real,
// bounded headcount; this simulates that.
const EMPLOYEES = Array.from({ length: 20 }, () => faker.person.fullName());
function randomEmployee(): string {
  return faker.helpers.arrayElement(EMPLOYEES);
}

// Column order here is load-bearing: pipeline/src/etl.ts reads this sheet
// by fixed column position (1=fecha, 2=tipo, 3=categoria, 4=monto,
// 5=moneda, 6=emp_nom), not by header lookup. Keep both in sync.
const ACCOUNTING_ROWS = 300;
async function generateAccountingExcel(): Promise<void> {
  const workbook = new ExcelJS.Workbook();
  const sheet = workbook.addWorksheet('Contabilidad');
  sheet.addRow(['fecha', 'tipo', 'categoria', 'monto', 'moneda', 'emp_nom']);

  const gastoCategorias = [
    'hosting', 'nomina', 'marketing', 'soporte', 'seguros', 'legal',
    'viajes', 'equipo', 'capacitacion', 'oficina',
  ];
  const monedas = ['USD', 'CRC'];
  for (let i = 0; i < ACCOUNTING_ROWS; i++) {
    const tipo = faker.helpers.arrayElement(['ingreso', 'gasto']);
    const categoria = tipo === 'ingreso' ? 'suscripciones' : faker.helpers.arrayElement(gastoCategorias);
    const moneda = faker.helpers.arrayElement(monedas);
    // CRC amounts are ~500x USD in nominal terms (~500 CRC per USD) — vary
    // the range per currency so the numbers still look plausible in context.
    const [min, max] = moneda === 'CRC' ? [25000, 2500000] : [50, 5000];
    sheet.addRow([
      faker.date.past({ years: 2 }),
      tipo,
      categoria,
      Number(faker.finance.amount({ min, max, dec: 2 })),
      moneda,
      randomEmployee(),
    ]);
  }

  await workbook.xlsx.writeFile(path.join(OUTPUT_DIR, 'contabilidad.xlsx'));
  console.log(`Wrote contabilidad.xlsx (${ACCOUNTING_ROWS} rows)`);
}

// Our own generator controls every value here — none contain a literal
// comma — so a plain join is a safe, dependency-free CSV writer. Column
// order here is load-bearing the same way: etl.ts reads by header name
// after splitting on comma, so header text and order must stay exact.
function toCsvRow(fields: (string | number)[]): string {
  return fields.join(',');
}

const FINANCE_MONTHS = 24;
function generateFinanceCsv(): void {
  const departamentos = [
    'Nomina', 'Marketing', 'Infraestructura', 'Legal', 'Ventas', 'Soporte',
  ];
  const lines = [toCsvRow(['departamento', 'presupuesto_asignado', 'gastado', 'periodo', 'nombre_empl'])];

  const now = new Date();
  for (let monthsAgo = 0; monthsAgo < FINANCE_MONTHS; monthsAgo++) {
    const d = new Date(now.getFullYear(), now.getMonth() - monthsAgo, 1);
    const periodo = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    for (const departamento of departamentos) {
      const presupuesto = Number(faker.finance.amount({ min: 2000, max: 20000, dec: 2 }));
      // Occasionally go over budget (up to 130%) so "presupuesto vs.
      // gastado" dashboards actually show some departments in the red.
      const gastado = Number((presupuesto * faker.number.float({ min: 0.4, max: 1.3 })).toFixed(2));
      lines.push(toCsvRow([departamento, presupuesto, gastado, periodo, randomEmployee()]));
    }
  }

  fs.writeFileSync(path.join(OUTPUT_DIR, 'finanzas.csv'), lines.join('\n'));
  console.log(`Wrote finanzas.csv (${departamentos.length * FINANCE_MONTHS} rows)`);
}

const OPS_ROWS = 200;
function generateOpsJson(): void {
  const tipos = ['ticket_soporte', 'incidente', 'chequeo_uptime', 'mantenimiento', 'solicitud_acceso'];
  const estados = ['abierto', 'en_progreso', 'cerrado', 'escalado', 'pendiente_cliente'];
  const descripciones = [
    'Usuario reporta lentitud en el sistema',
    'Error al procesar transaccion',
    'Solicitud de acceso a nuevo modulo',
    'Falla en notificaciones push',
    'Revision programada de servidores',
    'Reporte de datos inconsistentes',
    'Consulta sobre facturacion',
    'Actualizacion de certificado SSL',
  ];
  const records = [];
  for (let i = 0; i < OPS_ROWS; i++) {
    records.push({
      ticket_id: `OPS-${1000 + i}`,
      fecha: faker.date.past({ years: 2 }).toISOString().slice(0, 10),
      tipo: faker.helpers.arrayElement(tipos),
      estado: faker.helpers.arrayElement(estados),
      tiempo_resolucion_horas: Number(faker.number.float({ min: 0.5, max: 120, fractionDigits: 1 })),
      descripcion: faker.helpers.arrayElement(descripciones),
      NOMBRE_EMPLEADO: randomEmployee(),
    });
  }
  fs.writeFileSync(path.join(OUTPUT_DIR, 'operaciones.json'), JSON.stringify(records, null, 2));
  console.log(`Wrote operaciones.json (${records.length} rows)`);
}

// Pipe-delimited plain text, as an old HR system might export — dirty on
// purpose: inconsistent whitespace/casing on names, a nullable puesto,
// and two different date formats mixed in the same column.
const HR_ROWS = 50;
function generateHrTxt(): void {
  const puestos = ['Analista', 'Gerente', 'Coordinador', 'Especialista', null, null];
  const departamentos = ['Recursos Humanos', 'TI', 'Ventas', 'Operaciones', 'Finanzas'];
  const lines = ['empleado_nombre|departamento|puesto|salario|fecha_contratacion'];
  for (let i = 0; i < HR_ROWS; i++) {
    const nombre = randomEmployee();
    const nombreSucio = faker.datatype.boolean() ? `  ${nombre.toUpperCase()}  ` : ` ${nombre} `;
    const departamento = faker.helpers.arrayElement(departamentos);
    const puesto = faker.helpers.arrayElement(puestos);
    const salario = faker.finance.amount({ min: 300000, max: 2000000, dec: 0 });
    const fecha = faker.date.past({ years: 3 });
    const fechaSucia = faker.datatype.boolean()
      ? `${fecha.getDate()}/${fecha.getMonth() + 1}/${fecha.getFullYear()}`
      : fecha.toISOString().slice(0, 10);
    lines.push(`${nombreSucio}|${departamento}|${puesto ?? ''}|${salario}|${fechaSucia}`);
  }
  fs.writeFileSync(path.join(OUTPUT_DIR, 'recursos_humanos.txt'), lines.join('\n'));
  console.log(`Wrote recursos_humanos.txt (${HR_ROWS} rows, intentionally dirty)`);
}

// YAML, as a marketing tool's export might look — dirty on purpose:
// inconsistent channel-name casing, a nullable presupuesto, and stray
// whitespace around the responsible employee's name.
const MARKETING_ROWS = 50;
function generateMarketingYaml(): void {
  const canales = ['Redes Sociales', 'redes sociales', 'REDES SOCIALES', 'Email', 'email', 'Google Ads', 'Prensa'];
  let yaml = 'campanas:\n';
  for (let i = 0; i < MARKETING_ROWS; i++) {
    const campana = faker.company.catchPhrase().replace(/"/g, '');
    const nombre = randomEmployee();
    const responsable = faker.datatype.boolean() ? `  ${nombre}  ` : nombre;
    const canal = faker.helpers.arrayElement(canales);
    const presupuesto = faker.datatype.boolean() ? Number(faker.finance.amount({ min: 500, max: 15000, dec: 2 })) : null;
    const fecha = faker.date.past({ years: 2 }).toISOString().slice(0, 10);
    yaml += `  - campana: "${campana}"\n`;
    yaml += `    responsable: "${responsable}"\n`;
    yaml += `    canal: "${canal}"\n`;
    yaml += `    presupuesto: ${presupuesto === null ? 'null' : presupuesto}\n`;
    yaml += `    fecha_inicio: "${fecha}"\n`;
  }
  fs.writeFileSync(path.join(OUTPUT_DIR, 'marketing.yaml'), yaml);
  console.log(`Wrote marketing.yaml (${MARKETING_ROWS} rows, intentionally dirty)`);
}

// XML, as a legal/contracts system might export — dirty on purpose: stray
// whitespace around the responsible employee's name, and an occasional
// empty <tipo/> element.
const LEGAL_ROWS = 50;
function generateLegalXml(): void {
  const tipos = ['Servicio', 'Arrendamiento', 'Confidencialidad', 'Laboral', ''];
  let xml = '<?xml version="1.0" encoding="UTF-8"?>\n<contratos>\n';
  for (let i = 0; i < LEGAL_ROWS; i++) {
    const numero = `C-${2000 + i}`;
    const tipo = faker.helpers.arrayElement(tipos);
    const monto = Number(faker.finance.amount({ min: 1000, max: 50000, dec: 2 }));
    const fecha = faker.date.past({ years: 3 }).toISOString().slice(0, 10);
    const nombre = randomEmployee();
    const responsable = faker.datatype.boolean() ? `  ${nombre}  ` : nombre;
    xml += '  <contrato>\n';
    xml += `    <numero>${numero}</numero>\n`;
    xml += tipo ? `    <tipo>${tipo}</tipo>\n` : '    <tipo/>\n';
    xml += `    <monto>${monto}</monto>\n`;
    xml += `    <fecha_firma>${fecha}</fecha_firma>\n`;
    xml += `    <responsable_legal>${responsable}</responsable_legal>\n`;
    xml += '  </contrato>\n';
  }
  xml += '</contratos>\n';
  fs.writeFileSync(path.join(OUTPUT_DIR, 'legal.xml'), xml);
  console.log(`Wrote legal.xml (${LEGAL_ROWS} rows, intentionally dirty)`);
}

// Fixed-width plain text, mainframe-report style — every column occupies
// an exact character width, no delimiter at all. Genuinely different
// parsing challenge from every other format here.
const COMPRAS_ROWS = 50;
const COMPRAS_WIDTHS = { empleado: 20, producto: 25, cantidad: 10, monto: 11, fecha: 10 };
function padField(value: string, width: number): string {
  return value.length >= width ? value.slice(0, width) : value.padEnd(width, ' ');
}
function generateComprasTxt(): void {
  const productos = [
    'Laptop Dell', 'Monitor LG 27"', 'Silla ergonomica', 'Teclado mecanico',
    'Impresora HP', 'Router Cisco', 'Licencia Office', 'Camara web',
  ];
  const header = padField('EMPLEADO', COMPRAS_WIDTHS.empleado)
    + padField('PRODUCTO', COMPRAS_WIDTHS.producto)
    + padField('CANTIDAD', COMPRAS_WIDTHS.cantidad)
    + padField('MONTO', COMPRAS_WIDTHS.monto)
    + padField('FECHA', COMPRAS_WIDTHS.fecha);
  const lines = [header];
  for (let i = 0; i < COMPRAS_ROWS; i++) {
    const nombre = randomEmployee().toUpperCase();
    const producto = faker.helpers.arrayElement(productos);
    const cantidad = faker.number.int({ min: 1, max: 10 });
    const monto = faker.finance.amount({ min: 15000, max: 900000, dec: 2 });
    const fecha = faker.date.past({ years: 2 }).toISOString().slice(0, 10);
    lines.push(
      padField(nombre, COMPRAS_WIDTHS.empleado)
      + padField(producto, COMPRAS_WIDTHS.producto)
      + padField(String(cantidad), COMPRAS_WIDTHS.cantidad)
      + padField(monto, COMPRAS_WIDTHS.monto)
      + padField(fecha, COMPRAS_WIDTHS.fecha),
    );
  }
  fs.writeFileSync(path.join(OUTPUT_DIR, 'compras.txt'), lines.join('\n'));
  console.log(`Wrote compras.txt (${COMPRAS_ROWS} rows, fixed-width)`);
}

// INI/properties format, one section per inventory item — as an old
// inventory tool might export. Dirty on purpose: some sections missing
// the ubicacion key entirely.
const INVENTARIO_ROWS = 50;
function generateInventarioIni(): void {
  const productos = ['Monitor LG', 'Laptop Dell', 'Silla ergonomica', 'Proyector Epson', 'Router TP-Link'];
  const ubicaciones = ['Bodega Central', 'Piso 2', 'Piso 3', 'Sucursal Norte'];
  let ini = '';
  for (let i = 0; i < INVENTARIO_ROWS; i++) {
    const id = `item_${String(i + 1).padStart(3, '0')}`;
    ini += `[${id}]\n`;
    ini += `producto = ${faker.helpers.arrayElement(productos)}\n`;
    ini += `cantidad = ${faker.number.int({ min: 1, max: 50 })}\n`;
    ini += `responsable_inventario = ${randomEmployee()}\n`;
    if (faker.datatype.boolean()) {
      ini += `ubicacion = ${faker.helpers.arrayElement(ubicaciones)}\n`;
    }
    ini += '\n';
  }
  fs.writeFileSync(path.join(OUTPUT_DIR, 'inventario.ini'), ini);
  console.log(`Wrote inventario.ini (${INVENTARIO_ROWS} rows, intentionally dirty)`);
}

// Markdown table, as an IT support tool's export might look. Dirty on
// purpose: cell values with inconsistent leading/trailing whitespace.
const SOPORTE_ROWS = 50;
function generateSoporteMd(): void {
  const prioridades = ['Alta', 'Media', 'Baja'];
  const estados = ['Resuelto', 'Pendiente', 'En progreso'];
  let md = '| Ticket | Empleado Asignado | Prioridad | Estado |\n';
  md += '|---|---|---|---|\n';
  for (let i = 0; i < SOPORTE_ROWS; i++) {
    const ticket = `SUP-${String(i + 1).padStart(3, '0')}`;
    const empleado = faker.datatype.boolean() ? ` ${randomEmployee()} ` : randomEmployee();
    const prioridad = faker.helpers.arrayElement(prioridades);
    const estado = faker.helpers.arrayElement(estados);
    md += `| ${ticket} | ${empleado} | ${prioridad} | ${estado} |\n`;
  }
  fs.writeFileSync(path.join(OUTPUT_DIR, 'soporte.md'), md);
  console.log(`Wrote soporte.md (${SOPORTE_ROWS} rows, intentionally dirty)`);
}

// A custom pipe-and-key=value log format, as an audit/compliance system
// might emit. Dirty on purpose: AUDITOR casing varies row to row.
const AUDITORIA_ROWS = 50;
function generateAuditoriaLog(): void {
  const acciones = ['revision_cuenta', 'aprobacion_gasto', 'cambio_permiso', 'revision_contrato'];
  const resultados = ['aprobado', 'rechazado', 'pendiente'];
  const lines: string[] = [];
  for (let i = 0; i < AUDITORIA_ROWS; i++) {
    const ts = faker.date.past({ years: 1 }).toISOString();
    const nombre = randomEmployee();
    const auditor = faker.datatype.boolean() ? nombre.toUpperCase() : nombre;
    const accion = faker.helpers.arrayElement(acciones);
    const resultado = faker.helpers.arrayElement(resultados);
    lines.push(`${ts} | INFO | AUDITOR=${auditor} | ACCION=${accion} | RESULTADO=${resultado}`);
  }
  fs.writeFileSync(path.join(OUTPUT_DIR, 'auditoria.log'), lines.join('\n'));
  console.log(`Wrote auditoria.log (${AUDITORIA_ROWS} rows, intentionally dirty)`);
}

async function main() {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  console.log(`Employee pool: ${EMPLOYEES.length} employees`);
  await generateAccountingExcel();
  generateFinanceCsv();
  generateOpsJson();
  generateHrTxt();
  generateMarketingYaml();
  generateLegalXml();
  generateComprasTxt();
  generateInventarioIni();
  generateSoporteMd();
  generateAuditoriaLog();
  await uploadAllToDataLake();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
