import { faker } from '@faker-js/faker';
import ExcelJS from 'exceljs';
import * as fs from 'fs';
import * as path from 'path';

// Use process.cwd() which is always the analytics directory when run via npm
const OUTPUT_DIR = path.join(process.cwd(), 'department-files', 'output');

// Column order here is load-bearing: pipeline/src/etl.ts reads this sheet
// by fixed column position (1=fecha, 2=tipo, 3=categoria, 4=monto,
// 5=moneda, 6=emp_nom), not by header lookup. Keep both in sync.
async function generateAccountingExcel(): Promise<void> {
  const workbook = new ExcelJS.Workbook();
  const sheet = workbook.addWorksheet('Contabilidad');
  sheet.addRow(['fecha', 'tipo', 'categoria', 'monto', 'moneda', 'emp_nom']);

  const gastoCategorias = ['hosting', 'nomina', 'marketing', 'soporte'];
  for (let i = 0; i < 120; i++) {
    const tipo = faker.helpers.arrayElement(['ingreso', 'gasto']);
    const categoria = tipo === 'ingreso' ? 'suscripciones' : faker.helpers.arrayElement(gastoCategorias);
    sheet.addRow([
      faker.date.past({ years: 1 }),
      tipo,
      categoria,
      Number(faker.finance.amount({ min: 50, max: 5000, dec: 2 })),
      'USD',
      faker.person.fullName(),
    ]);
  }

  await workbook.xlsx.writeFile(path.join(OUTPUT_DIR, 'contabilidad.xlsx'));
  console.log('Wrote contabilidad.xlsx (120 rows)');
}

// Our own generator controls every value here — none contain a literal
// comma — so a plain join is a safe, dependency-free CSV writer. Column
// order here is load-bearing the same way: etl.ts reads by header name
// after splitting on comma, so header text and order must stay exact.
function toCsvRow(fields: (string | number)[]): string {
  return fields.join(',');
}

function generateFinanceCsv(): void {
  const departamentos = ['Nomina', 'Marketing', 'Infraestructura'];
  const lines = [toCsvRow(['departamento', 'presupuesto_asignado', 'gastado', 'periodo', 'nombre_empl'])];

  const now = new Date();
  for (let monthsAgo = 0; monthsAgo < 12; monthsAgo++) {
    const d = new Date(now.getFullYear(), now.getMonth() - monthsAgo, 1);
    const periodo = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    for (const departamento of departamentos) {
      const presupuesto = Number(faker.finance.amount({ min: 2000, max: 20000, dec: 2 }));
      const gastado = Number((presupuesto * faker.number.float({ min: 0.5, max: 1.1 })).toFixed(2));
      lines.push(toCsvRow([departamento, presupuesto, gastado, periodo, faker.person.fullName()]));
    }
  }

  fs.writeFileSync(path.join(OUTPUT_DIR, 'finanzas.csv'), lines.join('\n'));
  console.log(`Wrote finanzas.csv (${departamentos.length * 12} rows)`);
}

function generateOpsJson(): void {
  const tipos = ['ticket_soporte', 'incidente', 'chequeo_uptime'];
  const estados = ['abierto', 'en_progreso', 'cerrado'];
  const records = [];
  for (let i = 0; i < 80; i++) {
    records.push({
      ticket_id: `OPS-${1000 + i}`,
      fecha: faker.date.past({ years: 1 }).toISOString().slice(0, 10),
      tipo: faker.helpers.arrayElement(tipos),
      estado: faker.helpers.arrayElement(estados),
      tiempo_resolucion_horas: Number(faker.number.float({ min: 0.5, max: 72, fractionDigits: 1 })),
      descripcion: faker.lorem.sentence(),
      NOMBRE_EMPLEADO: faker.person.fullName(),
    });
  }
  fs.writeFileSync(path.join(OUTPUT_DIR, 'operaciones.json'), JSON.stringify(records, null, 2));
  console.log(`Wrote operaciones.json (${records.length} rows)`);
}

async function main() {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  await generateAccountingExcel();
  generateFinanceCsv();
  generateOpsJson();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
