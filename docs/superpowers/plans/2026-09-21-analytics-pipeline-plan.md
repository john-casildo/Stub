# Analytics Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the school assignment's four deliverables for Stub: synthetic department files with inconsistent schemas, a nightly production→analytics database clone, a custom ETL that normalizes and loads the department files, and local Terraform (Docker provider) managing the new pieces.

**Architecture:** A single new `analytics/` npm package (separate from `server/`) holds a Faker-based file generator, a Node/TS pipeline (clone + ETL, scheduled via `node-cron`), and Terraform config using the `kreuzwerker/docker` provider. The pipeline container joins `server/docker-compose.yml`'s existing default network (`server_default`) to reach production Postgres by its Compose service name; the Analytics DB is a second, independent Postgres 16 container.

**Tech Stack:** Node 20 + TypeScript (matches `server/`'s conventions) + `exceljs` (xlsx) + `pg` + `node-cron` + `dotenv`; Terraform `~> 3.0` with the `kreuzwerker/docker` provider.

**Spec:** `docs/superpowers/specs/2026-09-21-analytics-pipeline-design.md`

## Global Constraints

- One consolidated `analytics/` npm package (single `package.json`/`tsconfig.json` at `analytics/` root) — not two separate node projects — so `department-files/generate.ts` and `pipeline/src/etl.ts` share `exceljs`/etc. without duplicated dependency declarations. This is an implementation refinement of the spec's file tree, not a scope change.
- No changes to `server/docker-compose.yml`, `server/src/**`, `server/migrations/**`, or any existing `server/` file.
- Analytics DB: Postgres 16, host port `5433` (production stays on `5432`), database name `analytics`.
- The pipeline container and Terraform both reference the existing `server_default` Docker network by name/lookup — neither creates nor destroys it.
- Employee-name field normalization: `emp_nom` (Excel) / `nombre_empl` (CSV) / `NOMBRE_EMPLEADO` (JSON) all map to one `nombre_empleado` column in every ETL target table.
- No Jest coverage for this tooling (per spec) — verification is running it and checking real output, matching `server/seed/`'s precedent.
- Real npm-resolved dependency versions only — never hand-type a version into `package.json`.

---

## File Structure

```
analytics/
  package.json
  tsconfig.json
  .gitignore
  .dockerignore
  department-files/
    generate.ts
    output/                    # gitignored; generated on demand
  pipeline/
    Dockerfile
    src/
      clone.ts
      etl.ts
      index.ts
  terraform/
    main.tf
    variables.tf
```

---

### Task 1: Scaffold the `analytics/` package

**Files:**
- Create: `analytics/package.json`
- Create: `analytics/tsconfig.json`
- Create: `analytics/.gitignore`
- Create: `analytics/.dockerignore`

**Interfaces:**
- Produces: an installable npm package with `dotenv`, `exceljs`, `node-cron`, `pg` as dependencies and `@faker-js/faker`, `typescript`, `ts-node`, `@types/node`, `@types/pg`, `@types/node-cron` as devDependencies — later tasks' `import` statements rely on these being present.

- [ ] **Step 1: Create the directory and initialize package.json**

Run: `mkdir -p /Users/johncasildo/Documents/Stub/analytics && cd /Users/johncasildo/Documents/Stub/analytics && npm init -y`

- [ ] **Step 2: Install real dependencies**

Run:
```bash
cd /Users/johncasildo/Documents/Stub/analytics
npm install dotenv exceljs node-cron pg
npm install --save-dev @faker-js/faker typescript ts-node @types/node @types/pg @types/node-cron
```

Expected: `package.json`'s `dependencies`/`devDependencies` are populated with real npm-resolved versions (don't hand-edit them).

- [ ] **Step 3: Set package.json's scripts and metadata**

Edit `analytics/package.json` — add/adjust these fields (keep the dependency blocks npm just wrote):

```json
{
  "name": "stub-analytics",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "generate-files": "ts-node --transpile-only department-files/generate.ts",
    "build": "tsc",
    "pipeline:start": "ts-node --transpile-only pipeline/src/index.ts",
    "pipeline:run-now": "RUN_NOW=1 ts-node --transpile-only pipeline/src/index.ts"
  }
}
```

- [ ] **Step 4: Write tsconfig.json**

Create `analytics/tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "dist",
    "rootDir": ".",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true
  },
  "include": ["department-files/**/*.ts", "pipeline/src/**/*.ts"]
}
```

- [ ] **Step 5: Write .gitignore and .dockerignore**

Create `analytics/.gitignore`:

```
node_modules/
dist/
department-files/output/
.env
```

Create `analytics/.dockerignore`:

```
node_modules
dist
department-files/output
.git
```

- [ ] **Step 6: Verify**

Run: `cd /Users/johncasildo/Documents/Stub/analytics && ls node_modules/.bin/tsc node_modules/.bin/ts-node`

Expected: both binaries exist (confirms install succeeded). `npm run build` isn't runnable yet (no `.ts` files exist), so skip that check for this task.

- [ ] **Step 7: Commit**

```bash
cd /Users/johncasildo/Documents/Stub
git add analytics/package.json analytics/package-lock.json analytics/tsconfig.json analytics/.gitignore analytics/.dockerignore
git commit -m "$(cat <<'EOF'
feat: scaffold the analytics/ npm package

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01HJYg4eqjGXL56CDmkwSKKJ
EOF
)"
```

---

### Task 2: Department-files generator

**Files:**
- Create: `analytics/department-files/generate.ts`

**Interfaces:**
- Consumes: `@faker-js/faker`, `exceljs`, Node's `fs`/`path` (from Task 1's installed deps).
- Produces: `analytics/department-files/output/contabilidad.xlsx`, `analytics/department-files/output/finanzas.csv`, `analytics/department-files/output/operaciones.json` — Task 4's `etl.ts` reads these three files by exact name and exact column order (documented below), so keep both in sync if either changes.

- [ ] **Step 1: Write the generator**

Create `analytics/department-files/generate.ts`:

```typescript
import { faker } from '@faker-js/faker';
import ExcelJS from 'exceljs';
import * as fs from 'fs';
import * as path from 'path';

const OUTPUT_DIR = path.join(__dirname, 'output');

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
```

- [ ] **Step 2: Run and verify**

Run: `cd /Users/johncasildo/Documents/Stub/analytics && npm run generate-files`

Expected: three console lines confirming row counts, and all three files exist:

```bash
ls -la department-files/output/
node -e "console.log(require('./department-files/output/operaciones.json').length)"
```

Expected: `contabilidad.xlsx`, `finanzas.csv`, `operaciones.json` all present; the JSON count prints `80`. Spot-check `finanzas.csv`'s header line (`cat department-files/output/finanzas.csv | head -1`) reads exactly `departamento,presupuesto_asignado,gastado,periodo,nombre_empl`.

- [ ] **Step 3: Commit**

```bash
cd /Users/johncasildo/Documents/Stub
git add analytics/department-files/generate.ts
git commit -m "$(cat <<'EOF'
feat: generate synthetic department files with mismatched employee-name fields

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01HJYg4eqjGXL56CDmkwSKKJ
EOF
)"
```

---

### Task 3: Database clone script

**Files:**
- Create: `analytics/pipeline/src/clone.ts`

**Interfaces:**
- Produces: `export async function cloneDatabase(sourceUrl: string, targetUrl: string): Promise<void>` — Task 5's `index.ts` imports and calls this.

- [ ] **Step 1: Write clone.ts**

Create `analytics/pipeline/src/clone.ts`:

```typescript
import { spawn } from 'child_process';

export async function cloneDatabase(sourceUrl: string, targetUrl: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const dump = spawn('pg_dump', ['--clean', '--if-exists', '--no-owner', '--no-privileges', sourceUrl]);
    const restore = spawn('psql', [targetUrl]);

    dump.stdout.pipe(restore.stdin);

    let dumpStderr = '';
    let restoreStderr = '';
    dump.stderr.on('data', (chunk) => { dumpStderr += chunk.toString(); });
    restore.stderr.on('data', (chunk) => { restoreStderr += chunk.toString(); });

    dump.on('error', reject);
    restore.on('error', reject);

    restore.on('close', (code) => {
      if (code === 0) {
        console.log('Clone complete.');
        resolve();
      } else {
        reject(new Error(
          `psql restore exited with code ${code}.\npg_dump stderr: ${dumpStderr}\npsql stderr: ${restoreStderr}`,
        ));
      }
    });
  });
}

if (require.main === module) {
  const sourceUrl = process.env.DATABASE_URL;
  const targetUrl = process.env.ANALYTICS_DATABASE_URL;
  if (!sourceUrl || !targetUrl) {
    throw new Error('DATABASE_URL and ANALYTICS_DATABASE_URL are required');
  }
  cloneDatabase(sourceUrl, targetUrl).catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
```

- [ ] **Step 2: Confirm `pg_dump`/`psql` are available on the host**

Run: `pg_dump --version && psql --version`

Expected: both print a version (Postgres client tools ship with `postgres.app`/`brew install postgresql` on macOS — if missing, `brew install postgresql@16` installs them). This step only verifies the host has these tools for local testing; the Docker image gets them explicitly in Task 6.

- [ ] **Step 3: Stand up a real source and a throwaway target, then verify**

```bash
cd /Users/johncasildo/Documents/Stub/server && docker compose up -d postgres
docker run --rm -d --name analytics-db-test -p 5433:5432 -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=analytics postgres:16
sleep 3
cd /Users/johncasildo/Documents/Stub/analytics
DATABASE_URL="postgres://postgres:postgres@localhost:5432/stub" \
ANALYTICS_DATABASE_URL="postgres://postgres:postgres@localhost:5433/analytics" \
npx ts-node --transpile-only pipeline/src/clone.ts
```

Expected: prints `Clone complete.` and exits 0. Verify the clone actually copied data:

```bash
docker exec analytics-db-test psql -U postgres -d analytics -c "select count(*) from users;"
docker exec server-postgres-1 psql -U postgres -d stub -c "select count(*) from users;"
```

Expected: both counts match (whatever's currently seeded in `stub`, even if `0`, as long as both sides agree).

Clean up the throwaway target:

```bash
docker stop analytics-db-test
```

- [ ] **Step 4: Commit**

```bash
cd /Users/johncasildo/Documents/Stub
git add analytics/pipeline/src/clone.ts
git commit -m "$(cat <<'EOF'
feat: clone the production database via pg_dump | psql

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01HJYg4eqjGXL56CDmkwSKKJ
EOF
)"
```

---

### Task 4: ETL script

**Files:**
- Create: `analytics/pipeline/src/etl.ts`

**Interfaces:**
- Consumes: Task 2's three generated files (by exact name/column order), the `pg` package.
- Produces: `export async function runEtl(analyticsUrl: string): Promise<void>` — Task 5's `index.ts` imports and calls this. Creates (if not already present) and reloads three tables in the Analytics DB: `accounting_records`, `department_budgets`, `ops_metrics`, each with a `nombre_empleado` column.

- [ ] **Step 1: Write etl.ts**

Create `analytics/pipeline/src/etl.ts`:

```typescript
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
```

- [ ] **Step 2: Run and verify against a throwaway analytics target**

```bash
docker run --rm -d --name analytics-db-test -p 5433:5432 -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=analytics postgres:16
sleep 3
cd /Users/johncasildo/Documents/Stub/analytics
ANALYTICS_DATABASE_URL="postgres://postgres:postgres@localhost:5433/analytics" \
npx ts-node --transpile-only pipeline/src/etl.ts
```

Expected: prints `ETL complete: 120 accounting rows, 36 budget rows, 80 ops rows.`

Verify the normalization actually happened (every table has a real, non-null `nombre_empleado`, not the original mismatched field names):

```bash
docker exec analytics-db-test psql -U postgres -d analytics -c \
  "select count(*) from accounting_records where nombre_empleado is not null and nombre_empleado <> '';
   select count(*) from department_budgets where nombre_empleado is not null and nombre_empleado <> '';
   select count(*) from ops_metrics where nombre_empleado is not null and nombre_empleado <> '';"
```

Expected: `120`, `36`, `80` — every row in every table has a populated `nombre_empleado`.

Clean up:

```bash
docker stop analytics-db-test
```

- [ ] **Step 3: Commit**

```bash
cd /Users/johncasildo/Documents/Stub
git add analytics/pipeline/src/etl.ts
git commit -m "$(cat <<'EOF'
feat: ETL the three department files into normalized analytics tables

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01HJYg4eqjGXL56CDmkwSKKJ
EOF
)"
```

---

### Task 5: Pipeline entrypoint (cron scheduling + manual run)

**Files:**
- Create: `analytics/pipeline/src/index.ts`

**Interfaces:**
- Consumes: `cloneDatabase` from Task 3's `clone.ts`, `runEtl` from Task 4's `etl.ts`, `node-cron`, `dotenv`.
- Produces: the pipeline's actual entrypoint — Task 6's Dockerfile `CMD`s this file (compiled).

- [ ] **Step 1: Write index.ts**

Create `analytics/pipeline/src/index.ts`:

```typescript
import 'dotenv/config';
import cron from 'node-cron';
import { cloneDatabase } from './clone';
import { runEtl } from './etl';

async function runPipeline(): Promise<void> {
  const sourceUrl = process.env.DATABASE_URL;
  const analyticsUrl = process.env.ANALYTICS_DATABASE_URL;
  if (!sourceUrl || !analyticsUrl) {
    throw new Error('DATABASE_URL and ANALYTICS_DATABASE_URL are required');
  }
  console.log(`[${new Date().toISOString()}] Starting nightly analytics pipeline`);
  await cloneDatabase(sourceUrl, analyticsUrl);
  await runEtl(analyticsUrl);
  console.log(`[${new Date().toISOString()}] Pipeline complete`);
}

if (process.env.RUN_NOW === '1') {
  runPipeline()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
} else {
  console.log('Pipeline scheduled for midnight (cron: 0 0 * * *)');
  cron.schedule('0 0 * * *', () => {
    runPipeline().catch((err) => console.error('Pipeline run failed:', err));
  });
}
```

- [ ] **Step 2: Verify the RUN_NOW path end to end**

```bash
cd /Users/johncasildo/Documents/Stub/server && docker compose up -d postgres
docker run --rm -d --name analytics-db-test -p 5433:5432 -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=analytics postgres:16
sleep 3
cd /Users/johncasildo/Documents/Stub/analytics
DATABASE_URL="postgres://postgres:postgres@localhost:5432/stub" \
ANALYTICS_DATABASE_URL="postgres://postgres:postgres@localhost:5433/analytics" \
npm run pipeline:run-now
```

Expected: logs show both the clone completing and the ETL's row-count summary, in that order, then the process exits 0 (confirm with `echo $?`).

- [ ] **Step 3: Verify the scheduled (non-RUN_NOW) path starts without error**

```bash
cd /Users/johncasildo/Documents/Stub/analytics
DATABASE_URL="postgres://postgres:postgres@localhost:5432/stub" \
ANALYTICS_DATABASE_URL="postgres://postgres:postgres@localhost:5433/analytics" \
timeout 5 npm run pipeline:start; echo "exit code: $?"
```

Expected: prints `Pipeline scheduled for midnight (cron: 0 0 * * *)` and stays running (the `timeout 5` kills it after 5s — exit code `124` from `timeout` is expected and fine, it just confirms the process didn't crash on startup).

Clean up:

```bash
docker stop analytics-db-test
```

- [ ] **Step 4: Commit**

```bash
cd /Users/johncasildo/Documents/Stub
git add analytics/pipeline/src/index.ts
git commit -m "$(cat <<'EOF'
feat: wire the clone+ETL pipeline to a midnight cron schedule

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01HJYg4eqjGXL56CDmkwSKKJ
EOF
)"
```

---

### Task 6: Dockerize the pipeline

**Files:**
- Create: `analytics/pipeline/Dockerfile`

**Interfaces:**
- Produces: a buildable Docker image (`stub-analytics-pipeline`) — Task 7's Terraform config builds this image via a `docker_image` resource with `build { context = "<analytics/>", dockerfile = "pipeline/Dockerfile" }`.

- [ ] **Step 1: Write the Dockerfile**

Create `analytics/pipeline/Dockerfile`:

```dockerfile
FROM node:20-slim

RUN apt-get update && apt-get install -y --no-install-recommends postgresql-client \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

CMD ["node", "dist/pipeline/src/index.js"]
```

Note: this Dockerfile's build context is `analytics/` (the package root, one level up from where the Dockerfile itself lives), not `analytics/pipeline/` — it needs `package.json`, `tsconfig.json`, and `department-files/` alongside `pipeline/` to build. Task 7's Terraform `build` block sets `context`/`dockerfile` accordingly; for a manual build (this task's verification), pass the context explicitly.

- [ ] **Step 2: Build and verify**

```bash
cd /Users/johncasildo/Documents/Stub/analytics
docker build -f pipeline/Dockerfile -t stub-analytics-pipeline:latest .
```

Expected: builds successfully (no errors), ending with the image tagged.

Verify the image actually runs and can reach a real database (using the same server + throwaway-analytics setup as prior tasks, this time via `--network host` for the simplest possible manual check — Task 7's Terraform run is what verifies the real Docker-network wiring):

```bash
cd /Users/johncasildo/Documents/Stub/server && docker compose up -d postgres
docker run --rm -d --name analytics-db-test -p 5433:5432 -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=analytics postgres:16
sleep 3
docker run --rm --network host \
  -e DATABASE_URL="postgres://postgres:postgres@localhost:5432/stub" \
  -e ANALYTICS_DATABASE_URL="postgres://postgres:postgres@localhost:5433/analytics" \
  -e RUN_NOW=1 \
  -v "/Users/johncasildo/Documents/Stub/analytics/department-files/output:/app/department-files/output:ro" \
  stub-analytics-pipeline:latest
echo "exit code: $?"
```

Expected: same clone+ETL log output as Task 5's verification, exit code `0`.

Clean up:

```bash
docker stop analytics-db-test
```

- [ ] **Step 3: Commit**

```bash
cd /Users/johncasildo/Documents/Stub
git add analytics/pipeline/Dockerfile
git commit -m "$(cat <<'EOF'
feat: dockerize the analytics pipeline

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01HJYg4eqjGXL56CDmkwSKKJ
EOF
)"
```

---

### Task 7: Terraform

**Files:**
- Create: `analytics/terraform/main.tf`
- Create: `analytics/terraform/variables.tf`

**Interfaces:**
- Consumes: Task 6's `analytics/pipeline/Dockerfile` (built via Terraform's own `build` block, not the manual `docker build` from Task 6 — Terraform manages this image from here on).
- Produces: two running containers, `analytics-db` (host port `5433`) and `analytics-pipeline`, both on the `server_default` Docker network.

- [ ] **Step 1: Write variables.tf**

Create `analytics/terraform/variables.tf`:

```hcl
variable "production_database_url" {
  description = "Connection string for the production Stub Postgres (server/'s postgres service, reachable by its Compose service name on the shared network)"
  type        = string
  default     = "postgres://postgres:postgres@postgres:5432/stub"
}
```

- [ ] **Step 2: Write main.tf**

Create `analytics/terraform/main.tf`:

```hcl
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

# Owned by server/docker-compose.yml (Compose's default project-scoped
# network name for that project, "server") — looked up, never created or
# destroyed here.
data "docker_network" "server_default" {
  name = "server_default"
}

resource "docker_volume" "analytics_postgres_data" {
  name = "analytics_postgres_data"
}

resource "docker_image" "analytics_postgres" {
  name = "postgres:16"
}

resource "docker_container" "analytics_db" {
  name  = "analytics-db"
  image = docker_image.analytics_postgres.image_id

  env = [
    "POSTGRES_USER=postgres",
    "POSTGRES_PASSWORD=postgres",
    "POSTGRES_DB=analytics",
  ]

  ports {
    internal = 5432
    external = 5433
  }

  networks_advanced {
    name = data.docker_network.server_default.name
  }

  volumes {
    volume_name    = docker_volume.analytics_postgres_data.name
    container_path = "/var/lib/postgresql/data"
  }

  restart = "unless-stopped"
}

resource "docker_image" "pipeline" {
  name = "stub-analytics-pipeline:latest"
  build {
    context    = "${path.module}/.."
    dockerfile = "pipeline/Dockerfile"
  }
}

resource "docker_container" "pipeline" {
  name  = "analytics-pipeline"
  image = docker_image.pipeline.image_id

  env = [
    "DATABASE_URL=${var.production_database_url}",
    "ANALYTICS_DATABASE_URL=postgres://postgres:postgres@analytics-db:5432/analytics",
  ]

  networks_advanced {
    name = data.docker_network.server_default.name
  }

  volumes {
    host_path      = "${path.module}/../department-files/output"
    container_path = "/app/department-files/output"
    read_only      = true
  }

  restart = "unless-stopped"

  depends_on = [docker_container.analytics_db]
}
```

- [ ] **Step 3: Prerequisites — make sure the shared network and department files exist**

```bash
cd /Users/johncasildo/Documents/Stub/server && docker compose up -d
docker network ls | grep server_default
cd /Users/johncasildo/Documents/Stub/analytics && npm run generate-files
ls department-files/output/
```

Expected: `server_default` network listed; the three department files present (regenerating here is fine even if Task 2 already created them — this proves the full prerequisite chain works from a clean state).

- [ ] **Step 4: terraform init, apply, and verify**

```bash
cd /Users/johncasildo/Documents/Stub/analytics/terraform
terraform init
terraform apply -auto-approve
```

Expected: both resources created successfully. Verify both containers are actually running and correctly wired:

```bash
docker ps --filter name=analytics-db --filter name=analytics-pipeline
docker logs analytics-pipeline --tail 20
```

Expected: `docker ps` lists both containers as `Up`. `docker logs` shows the pipeline started (either the RUN_NOW summary if it happened to fire, or — since the container's default mode is the cron-scheduled one, not `RUN_NOW=1` — the `Pipeline scheduled for midnight` log line, confirming it started cleanly rather than crash-looping).

Trigger one real run manually to confirm the network wiring actually works end to end (the pipeline container reaching both `postgres` and `analytics-db` by their Compose/Terraform names):

```bash
docker exec -e RUN_NOW=1 -e DATABASE_URL="postgres://postgres:postgres@postgres:5432/stub" -e ANALYTICS_DATABASE_URL="postgres://postgres:postgres@analytics-db:5432/analytics" analytics-pipeline node dist/pipeline/src/index.js
```

Expected: same clone+ETL success log as prior tasks, this time running from inside the container over the real Docker network rather than `localhost` port mappings.

- [ ] **Step 5: terraform destroy and verify clean teardown**

```bash
terraform destroy -auto-approve
docker ps --filter name=analytics-db --filter name=analytics-pipeline
```

Expected: destroy completes without error; the `docker ps` filter returns nothing (both containers gone). Confirm the volume also still exists if you want data to survive a re-apply (`docker volume ls | grep analytics_postgres_data`) — Terraform's `docker_volume` resource is destroyed too by `terraform destroy`, so a re-`apply` after this starts the Analytics DB fresh, which is expected for this exercise.

Re-apply once more to leave the stack up for Task 8's integration check:

```bash
terraform apply -auto-approve
```

- [ ] **Step 6: Add Terraform working-directory artifacts to .gitignore**

`.terraform/` and `terraform.tfstate*` are local working-directory artifacts that should NOT be committed — append these lines to `analytics/.gitignore` (don't replace Task 1's existing entries):

```
.terraform/
terraform.tfstate
terraform.tfstate.backup
```

`analytics/terraform/.terraform.lock.hcl` (the provider version lock file, created by `terraform init` in Step 4) SHOULD be committed — it's the Terraform equivalent of a lockfile, matching this project's own convention of committing `package-lock.json`.

- [ ] **Step 7: Commit**

```bash
cd /Users/johncasildo/Documents/Stub
git add analytics/terraform/main.tf analytics/terraform/variables.tf analytics/terraform/.terraform.lock.hcl analytics/.gitignore
git commit -m "$(cat <<'EOF'
feat: add Terraform (docker provider) for the Analytics DB + pipeline

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01HJYg4eqjGXL56CDmkwSKKJ
EOF
)"
```

---

### Task 8: Full integration verification + CLAUDE.md sync

**Files:**
- Modify: `/Users/johncasildo/Documents/Stub/CLAUDE.md`

**Interfaces:**
- Consumes: everything from Tasks 1-7.
- Produces: nothing new in code — this task is the real end-to-end proof plus the project's required documentation sync (per this repo's established convention of updating CLAUDE.md's file map/Status after finishing work).

- [ ] **Step 1: Full clean-slate integration run**

```bash
cd /Users/johncasildo/Documents/Stub/analytics/terraform
terraform destroy -auto-approve

cd /Users/johncasildo/Documents/Stub/server
docker compose down -v
docker compose up -d --build
cd /Users/johncasildo/Documents/Stub/server && npm run seed   # if the load-test seeder from the earlier session is present; otherwise skip — any real data in `stub` is fine for this check

cd /Users/johncasildo/Documents/Stub/analytics
npm run generate-files

cd terraform
terraform init
terraform apply -auto-approve
```

- [ ] **Step 2: Trigger a real pipeline run and verify the Analytics DB end to end**

```bash
docker exec -e RUN_NOW=1 -e DATABASE_URL="postgres://postgres:postgres@postgres:5432/stub" -e ANALYTICS_DATABASE_URL="postgres://postgres:postgres@analytics-db:5432/analytics" analytics-pipeline node dist/pipeline/src/index.js
```

Verify the clone actually mirrored production:

```bash
docker exec server-postgres-1 psql -U postgres -d stub -c "select count(*) from users; select count(*) from categories; select count(*) from transactions;"
docker exec analytics-db psql -U postgres -d analytics -c "select count(*) from users; select count(*) from categories; select count(*) from transactions;"
```

Expected: every count matches between the two.

Verify the ETL tables:

```bash
docker exec analytics-db psql -U postgres -d analytics -c \
  "select count(*) from accounting_records;
   select count(*) from department_budgets;
   select count(*) from ops_metrics;
   select nombre_empleado from accounting_records limit 3;"
```

Expected: `120`, `36`, `80`, and three real-looking employee names (not `null`, not the raw `emp_nom`/`nombre_empl`/`NOMBRE_EMPLEADO` field names themselves).

- [ ] **Step 3: Update CLAUDE.md's file map**

Add these rows to CLAUDE.md's file-map table, in a sensible spot near the other `server/*`/analytics-adjacent rows (e.g. right after the school-assignment load-testing tooling rows):

```markdown
| `analytics/department-files/generate.ts` | School-assignment Faker generator for three synthetic "shadow IT" department files with deliberately mismatched employee-name fields (`emp_nom` in the Excel, `nombre_empl` in the CSV, `NOMBRE_EMPLEADO` in the JSON) — `contabilidad.xlsx` (120 rows, revenue/expenses), `finanzas.csv` (36 rows, monthly department budgets), `operaciones.json` (80 rows, support tickets/incidents/uptime checks). Output is gitignored (`department-files/output/`), regenerated via `cd analytics && npm run generate-files` |
| `analytics/pipeline/` | School-assignment nightly analytics pipeline (`clone.ts` + `etl.ts` + `index.ts`, Dockerized) — clones the real `server/` production Postgres into a separate Analytics DB via `pg_dump \| psql` (`clone.ts`), then reads the three department files and normalizes each one's mismatched employee-name field into one `nombre_empleado` column across three new tables (`accounting_records`/`department_budgets`/`ops_metrics`, `etl.ts`). `index.ts` runs both via `node-cron` at midnight by default, or once immediately via `RUN_NOW=1`. Managed by `analytics/terraform/` (below), not `server/docker-compose.yml` |
| `analytics/terraform/` | Local Terraform (`kreuzwerker/docker` provider) managing exactly the two containers this assignment adds — `analytics-db` (a second, independent Postgres 16 on host port 5433) and `analytics-pipeline` (built from `analytics/pipeline/Dockerfile`) — both joined to `server/docker-compose.yml`'s existing `server_default` network via a `data "docker_network"` lookup, never creating or destroying it. `terraform apply`/`terraform destroy` from this directory; `server/`'s own stack and lifecycle are untouched |
```

- [ ] **Step 4: Add a short new CLAUDE.md section**

Add this section after the "## Backend/database: two backends, one switch" section's content (before "## Backend/database: Supabase"):

```markdown
## Analytics pipeline (school assignment)

`analytics/` (repo root, sibling to `server/`) is a second school
assignment, separate from the API/seeder/load-test one: it adds a
nightly-scheduled clone of the production Postgres database into a
second, independent Analytics Postgres database, plus a custom ETL that
ingests three synthetic "shadow IT" department files (an Accounting
Excel, a Finance CSV, an Operations JSON) — each with a differently
named/cased employee field (`emp_nom`/`nombre_empl`/`NOMBRE_EMPLEADO`) —
normalizing all three into one `nombre_empleado` column across three new
Analytics DB tables. Local Terraform (`kreuzwerker/docker` provider)
manages exactly the two containers this adds (`analytics-db`,
`analytics-pipeline`); `server/docker-compose.yml` and its containers are
untouched. See `analytics/department-files/generate.ts`,
`analytics/pipeline/`, and `analytics/terraform/`'s file-map entries
above for what each piece does and how to run it. No Jest coverage (not
app logic, same convention as `server/seed/`/`server/loadtest/`) —
verified by running the full clone+ETL and checking real row counts and
normalized values in the Analytics DB.
```

- [ ] **Step 5: Commit**

```bash
cd /Users/johncasildo/Documents/Stub
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
docs: record the analytics pipeline in CLAUDE.md

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01HJYg4eqjGXL56CDmkwSKKJ
EOF
)"
```
