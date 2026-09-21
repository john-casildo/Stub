# Analytics pipeline: shadow-IT files, nightly clone, custom ETL, Terraform

## Context

School assignment ("tarea de esta semana"), four numbered requirements
against the Stub project:

1. Generate finance/operations/department-adjacent files that reflect what
   the company (Stub) actually does.
2. A script that periodically (nightly, ~midnight) creates/updates a clone
   of the production database — the "analytics database."
3. A custom ETL that fetches files and formats them for storage in the
   analytics database.
4. Use Terraform locally to manage the infrastructure described above.

The instructor's reference diagram (provided mid-brainstorm) confirms the
intended shape: a production DB feeds an Analytics DB (Postgres) both
directly (a clone/replication arrow) and via an ETL that also ingests three
external "shadow IT" department files — an Accounting Excel, a Finance
Access-style export, and an Operations Notion-style export — each using a
differently-named/cased employee-name field (`emp_nom` /
`nombre_empl` / `NOMBRE_EMPLEADO`), which the ETL must normalize to one
canonical `nombre_empleado`. The Analytics DB then feeds a BI/analysis
layer (out of scope here — PowerBI/Tableau/Metabase and business-analyst
reporting are not part of this assignment's deliverable).

## Goals

- Three synthetic department files (Excel, CSV, JSON) with realistic-looking
  Stub-adjacent data and deliberately inconsistent schemas (especially the
  employee-name field), generated via a Faker-based script.
- A nightly (default: midnight) automated job that clones the real
  production Postgres database (`server/`'s `postgres` service) into a
  separate Analytics Postgres database.
- A separate, custom ETL step (same nightly job, run after the clone) that
  reads the three department files, normalizes their schemas, and loads
  them into their own tables in the Analytics DB.
- Terraform (using the Docker provider) manages the new infrastructure this
  assignment adds: the Analytics DB container and the pipeline container
  that runs the clone + ETL on a schedule.

## Non-goals

- No changes to `server/`'s existing `docker-compose.yml`, schema, or app
  code — the existing production stack is a black box this assignment
  reads from, not modifies.
- No BI/dashboard layer (PowerBI/Tableau/Metabase, Sheets reporting) — the
  diagram's upper half is instructor context, not part of this deliverable.
- No real MS Access file — "Access de Finanzas" is simulated as a CSV
  (matching the brainstormed formats: `.xlsx` for Accounting, `.csv` for
  Finance, `.json` for Operations), since MS Access itself isn't practical
  to produce or read outside Windows.
- No cloud Terraform — this is `kreuzwerker/docker`-provider Terraform
  running entirely against the local Docker daemon, matching "usar
  Terraform localmente."

## Architecture

```
analytics/
  department-files/
    generate.ts              # Faker-based generator for the 3 synthetic files
    output/                   # gitignored; regenerated on demand
      contabilidad.xlsx        # Accounting: revenue + expenses, field "emp_nom"
      finanzas.csv              # Finance: department budgets, field "nombre_empl"
      operaciones.json          # Operations: tickets/incidents/uptime, field "NOMBRE_EMPLEADO"
  pipeline/
    Dockerfile
    package.json
    src/
      clone.ts                 # pg_dump production | psql restore into Analytics DB
      etl.ts                   # reads the 3 files, normalizes, loads into Analytics DB
      index.ts                 # node-cron entrypoint: midnight -> clone() -> etl()
  terraform/
    main.tf                    # docker provider: analytics-db + pipeline containers
    variables.tf
```

### Department files (`analytics/department-files/generate.ts`)

A single Node/TS script (`@faker-js/faker`, same convention as
`server/seed/seed.ts`) that writes all three files to `output/`, each with
~50-150 rows of plausible fake data:

- **`contabilidad.xlsx`** (Accounting, via `exceljs`) — one row per
  transaction: `fecha`, `tipo` (`ingreso`/`gasto`), `categoria`
  (`suscripciones`, `hosting`, `nomina`, `marketing`, `soporte`), `monto`,
  `moneda`, **`emp_nom`** (employee responsible).
- **`finanzas.csv`** (Finance) — one row per department per month:
  `departamento`, `presupuesto_asignado`, `gastado`, `periodo`
  (`YYYY-MM`), **`nombre_empl`**.
- **`operaciones.json`** (Operations) — an array of ticket/incident/uptime
  records: `ticket_id`, `fecha`, `tipo`
  (`ticket_soporte`/`incidente`/`chequeo_uptime`), `estado`,
  `tiempo_resolucion_horas`, `descripcion`, **`NOMBRE_EMPLEADO`**.

The deliberately different casing/naming of the employee field
(`emp_nom` / `nombre_empl` / `NOMBRE_EMPLEADO`) is the point — the ETL's
job is to normalize all three to one `nombre_empleado` column downstream.

### Nightly pipeline (`analytics/pipeline/`)

One long-running Node/TS container, scheduled via `node-cron`
(`0 0 * * *`, midnight), running two steps in sequence — each also
independently invocable via a CLI flag for manual testing
(`RUN_NOW=1 node dist/index.js` runs both steps once immediately and
exits, instead of staying resident on the cron schedule):

1. **`clone.ts`** — shells out to `pg_dump` against the production
   `DATABASE_URL` (`--clean --if-exists --no-owner --no-privileges`,
   full schema+data dump) and pipes its stdout directly into `psql`
   against `ANALYTICS_DATABASE_URL`. This is a full destructive
   replace-in-place clone each run — simplest correct implementation of
   "clone the database," not an incremental sync.
2. **`etl.ts`** — reads the three files under `department-files/output/`
   (`exceljs` for the `.xlsx`, `csv-parse` for the `.csv`, native
   `JSON.parse` for the `.json`), maps each source's employee-name field to
   one canonical `nombre_empleado` column, and loads the normalized rows
   into three new tables in the Analytics DB (created via an idempotent
   `create table if not exists` at the top of `etl.ts` — this is a small,
   self-contained script, not wired into `server/`'s `node-pg-migrate`
   migration system): `accounting_records`, `department_budgets`,
   `ops_metrics`. Each run truncates and reloads these three tables from
   the current file contents (matching the "automatic periodic
   creation/update" requirement — an idempotent nightly refresh, not an
   append-only log).

The pipeline container joins the same Docker network the existing
`server/docker-compose.yml` stack creates by default
(`server_default` — Compose's default project-scoped network name,
confirmed via `docker network ls` against this repo's compose project
name `server`), so it can reach the production `postgres` service by its
Compose service name (`postgres:5432`) without any change to
`server/docker-compose.yml`.

### Analytics DB

A second, independent Postgres 16 container (not the same as
production's), its own named Docker volume, exposed on host port `5433`
(production stays on `5432`) so both can run simultaneously without
conflict, database name `analytics`.

### Terraform (`analytics/terraform/`)

Uses the `kreuzwerker/docker` provider (`~> 3.0`) against the local Docker
daemon (`unix:///var/run/docker.sock` default). Manages exactly two
resources this assignment adds:

- `docker_container.analytics_db` (+ its image/volume) — the Analytics
  Postgres, on the shared `server_default` external network (referenced via
  a `data "docker_network"` lookup, not created by Terraform — it's owned
  by `server/docker-compose.yml`).
- `docker_image.pipeline` (built from `analytics/pipeline/Dockerfile` via
  a `build {}` block) + `docker_container.pipeline` — the nightly
  clone+ETL job, `restart: unless-stopped`, environment wired to both
  `DATABASE_URL` (production, reachable via the shared network) and
  `ANALYTICS_DATABASE_URL` (this container's own DB), with
  `department-files/output/` bind-mounted read-only so `etl.ts` can read
  the generated files.

`terraform apply` is how a grader/user stands up the Analytics DB +
pipeline; `terraform destroy` tears both down. `server/docker-compose.yml`
and its own `docker compose up/down` lifecycle are completely untouched —
Terraform only ever looks up that network, never creates or destroys it.

## Data flow summary

```
server/'s postgres (production, docker-compose)
        │ pg_dump | psql (clone.ts, nightly)
        ▼
analytics_db (Postgres, Terraform-managed)  ◄── etl.ts (nightly)
                                                    ▲
                                    contabilidad.xlsx / finanzas.csv / operaciones.json
                                          (department-files/generate.ts, one-time/on-demand)
```

## Testing / verification

This is infra/ops tooling, matching the precedent already set by
`server/seed/` and `server/loadtest/` in this repo — no Jest coverage.
Verification is:

1. `generate.ts` run and the three output files spot-checked for shape
   (row counts, the three differently-named employee fields present).
2. `terraform apply` brings up `analytics_db` and `pipeline` healthy;
   `terraform destroy` cleanly tears them down.
3. `RUN_NOW=1` manual invocation of the pipeline: confirm the Analytics DB
   ends up with the production tables' row counts matching production
   (clone worked) and the three new ETL tables populated with normalized
   `nombre_empleado` values from all three source formats.
4. Let the container run un-terminated for a schedule tick (or briefly
   override the cron expression during manual testing to something like
   "every 2 minutes") to confirm the `node-cron` wiring itself fires
   correctly, not just the `RUN_NOW=1` path.

## Out of scope / open items

- No incremental/differential clone — every run is a full destructive
  replace. Fine at this data volume (the seeded demo data, not the 1.2M+
  load-test dataset — cloning that nightly would be slow; if the load-test
  seed is present when this runs, `clone.ts` clones whatever is there,
  including it).
- No secrets management — `DATABASE_URL`/`ANALYTICS_DATABASE_URL` are
  plain environment variables in Terraform's container definitions, same
  dev-only-placeholder posture as `server/`'s existing
  `dev-secret-change-me` JWT secret and hardcoded DB passwords.
- The BI/reporting layer from the instructor's diagram (PowerBI/Tableau/
  Metabase, Business Analysts in Sheets) is explicitly out of scope for
  this deliverable — the Analytics DB is the end of this pipeline.
