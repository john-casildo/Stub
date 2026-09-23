# Analytics Pipeline

Proyecto de la tarea semanal (Data Engineering): un pipeline de analítica
para **Stub**, la app de presupuestos personales. Cubre los 4 requisitos:

1. Archivos synthetic de finanzas/operaciones/departamentos.
2. Clonado automático periódico de la base de producción a una Analytics DB.
3. ETL custom que extrae, normaliza y carga esos archivos.
4. Terraform local (provider Docker) gestionando toda la infraestructura nueva.

## Arquitectura

```
                                                    ┌─────────────────┐
generate.ts (host)  ──10 archivos──►  MinIO         │  server/postgres │
  (Excel/CSV/JSON/                    (data lake,   │  (producción,    │
   TXT/YAML/XML/INI/                  puerto 9000)  │   ya existente)  │
   MD/log)                                │         └────────┬─────────┘
                                          │                    │
                                    descarga            pg_dump | psql
                                          │                    │
                                          ▼                    ▼
                              ┌─────────────────────────────────────┐
                              │      analytics-pipeline (cron)       │
                              │  clone.ts  ──►  etl.ts               │
                              └───────────────────┬───────────────────┘
                                                   │
                                                   ▼
                                        ┌─────────────────────┐
                                        │    analytics-db      │
                                        │  (Postgres, :5433)    │
                                        │  - tablas clonadas    │
                                        │  - 10 tablas ETL      │
                                        └──────────┬────────────┘
                                                   │
                                                   ▼
                                            Metabase (:3002)
                                          dashboards/gráficos
```

Todo se gestiona con **Terraform** (`terraform/`), usando el provider
`kreuzwerker/docker` contra el Docker local — nada de esto toca
`server/docker-compose.yml` ni la infraestructura de producción existente,
solo se conecta a su red Docker (`server_default`) para poder alcanzarla.

## Los 10 archivos synthetic (Requisito 1)

Generados por `department-files/generate.ts`, uno por "departamento",
cada uno en un **formato distinto** — simulando el problema real de
"shadow IT" (cada departamento usa su propia herramienta, con su propio
formato y su propio nombre de campo para el empleado):

| # | Archivo | Formato | Filas | Campo de empleado |
|---|---|---|---|---|
| 1 | `contabilidad.xlsx` | Excel | 300 | `emp_nom` |
| 2 | `finanzas.csv` | CSV | 144 | `nombre_empl` |
| 3 | `operaciones.json` | JSON | 200 | `NOMBRE_EMPLEADO` |
| 4 | `recursos_humanos.txt` | Texto (pipe `\|`) | 50 | `empleado_nombre` |
| 5 | `marketing.yaml` | YAML | 50 | `responsable` |
| 6 | `legal.xml` | XML | 50 | `responsable_legal` |
| 7 | `compras.txt` | Texto (ancho fijo) | 50 | `EMPLEADO` |
| 8 | `inventario.ini` | INI/properties | 50 | `responsable_inventario` |
| 9 | `soporte.md` | Markdown (tabla) | 50 | `Empleado Asignado` |
| 10 | `auditoria.log` | Log custom (`key=value`) | 50 | `AUDITOR` |

**Todos usan un mismo pool fijo de 20 empleados** (no nombres al azar por
fila) — así las agrupaciones por empleado en los dashboards tienen
sentido real (varias filas por persona, no una por fila).

**Datos "sucios" a propósito**, para que el ETL tenga algo real que
limpiar:
- Espacios extra y mayúsculas/minúsculas inconsistentes en los nombres
  (`"  JANE DOE  "` vs `"jane doe"`).
- Fechas en dos formatos mezclados en la misma columna (`13/10/2025` vs
  `2025-10-13`).
- Valores nulos reales (`presupuesto: null` en YAML, `<tipo/>` vacío en
  XML, `ubicacion` faltante en ~46% de las secciones del INI).

Generar/regenerar: `npm run generate-files` (desde `analytics/`). Esto
también **sube los 10 archivos al data lake** (ver abajo) automáticamente.

## El data lake (MinIO)

Los archivos synthetic no se leen directo del disco por el ETL — primero
se suben a un **data lake real** (MinIO, compatible con S3), simulando la
capa de "Data Warehouse/Data Lake" del diagrama de referencia de la
tarea. `etl.ts` descarga los 10 archivos desde ahí en cada corrida, no
del disco local (verificado: borrar la carpeta local y correr el
pipeline igual funciona, porque todo viene de MinIO).

- Consola web: **http://localhost:9001** (usuario/clave: `minioadmin` / `minioadmin123`)
- Bucket: `department-files`

## Clonado de producción (Requisito 2)

`pipeline/src/clone.ts` clona la base de producción (`server/`'s
postgres) a la Analytics DB vía `pg_dump | psql`. Corre cada noche a
medianoche vía `node-cron` (`pipeline/src/index.ts`), o de inmediato con
`RUN_NOW=1`.

**Historia real de bugs encontrados y arreglados durante la
verificación** (documentado en detalle en `CLAUDE.md`):
1. El clonado era un **no-op silencioso** — el cliente de Postgres
   instalado (v15) no era compatible con los servidores (v16), pero solo
   se revisaba el código de salida de `psql`, no el de `pg_dump`, así que
   "Clone complete." se imprimía sin haber copiado nada. Arreglado:
   cliente fijado a v16, ambos códigos de salida verificados.
2. `psql` corría sin `-v ON_ERROR_STOP=1` — una restauración parcial
   podía reportar éxito. Arreglado.
3. El primer arreglo para un crash de EPIPE introdujo un **deadlock**
   real (procesos `pg_dump` colgados permanentemente si `psql` moría
   antes de tiempo). Arreglado matando `pg_dump` cuando `psql` cierra
   primero — verificado en vivo contra un target inalcanzable.
4. Timeouts de conexión y una guardia contra corridas de cron
   superpuestas, agregados en la revisión final de toda la rama.

## El ETL (Requisito 3)

`pipeline/src/etl.ts` — un lector por formato, cada uno normalizando su
propio campo de empleado a una columna común `nombre_empleado`, y
limpiando la suciedad específica de esa fuente (fechas, mayúsculas,
nulos). Carga a 10 tablas nuevas en la Analytics DB (`accounting_records`,
`department_budgets`, `ops_metrics`, `hr_records`,
`marketing_campaigns`, `legal_contracts`, `purchase_records`,
`inventory_items`, `support_tickets`, `audit_log`).

Cada corrida trunca y recarga las 10 tablas — un refresco completo, no un
log incremental.

## Terraform (Requisito 4)

`terraform/main.tf` gestiona, contra el Docker local:

| Recurso | Qué es |
|---|---|
| `docker_container.analytics_db` | Postgres 16 separado, puerto 5433 |
| `docker_container.minio` | Data lake S3-compatible, puertos 9000/9001 |
| `docker_container.pipeline` | El clone+ETL, imagen reconstruida automáticamente cuando cambia el código fuente |
| `docker_container.metabase` | Dashboard de BI, puerto 3002 |

```bash
cd terraform
terraform init      # primera vez
terraform apply     # levanta/actualiza todo
terraform destroy   # lo baja todo
```

Todo se conecta a la red `server_default` (creada por
`server/docker-compose.yml`) vía un `data "docker_network"` — nunca la
crea ni la destruye.

## Cómo correr todo desde cero

```bash
# 1. Levanta el backend de producción (Stub)
cd server && docker compose up -d --build

# 2. Instala dependencias de analytics/ y genera + sube los 10 archivos
cd ../analytics && npm install && npm run generate-files

# 3. Levanta la infraestructura de analytics (Analytics DB, data lake, pipeline, Metabase)
cd terraform && terraform init && terraform apply

# 4. Corre el pipeline una vez, manualmente (sin esperar a medianoche)
docker exec -e RUN_NOW=1 \
  -e DATABASE_URL="postgres://postgres:postgres@postgres:5432/stub" \
  -e ANALYTICS_DATABASE_URL="postgres://postgres:postgres@analytics-db:5432/analytics" \
  analytics-pipeline node dist/pipeline/src/index.js
```

Luego:
- **Metabase** (dashboards): http://localhost:3002
- **MinIO** (data lake): http://localhost:9001
- **Consultas SQL directas**: `docker exec analytics-db psql -U postgres -d analytics`

## Dashboard en Metabase

Ya construido (2026-09-23, vía la API de Metabase, no a mano) — tres
dashboards en tres collections separadas, con las 25 preguntas (SQL
nativo) que los respaldan:

**App Usage & Financial Health** (datos de producción clonados: `users`,
`categories`, `budgets`, `transactions`) — KPIs (usuarios, transacciones,
volumen total, monto promedio), transacciones por semana, gasto por
categoría, top merchants, y adherencia a presupuesto (`budget_progress`).
Hoy está disperso a propósito: la producción real solo tiene 1 usuario y
0 transacciones (no hay datos del seeder de carga dejados ahí a propósito
— ver el punto sobre `npm run seed`/`npm test` en `CLAUDE.md`), así que
estos gráficos se llenarán con el uso real de la app, no son un bug.

**Department Spend (Shadow IT)** (las 10 tablas ETL) — gasto total por
empleado cruzando accounting/purchases/marketing/legal (union manual en
SQL, ya que Metabase no puede unir tablas distintas desde su query
builder), presupuesto vs. gastado por departamento, gasto de accounting
por tipo, headcount de HR, presupuesto de marketing por canal, inventario
por ubicación, valor de contratos legales en el tiempo, tickets de
soporte por estado/prioridad, tiempo de resolución de ops por tipo, y
acciones del audit log por resultado. Este dashboard sí está completamente
poblado.

**Data Quality & Pipeline Health** — conteo de filas por tabla ETL,
chequeo de `nombre_empleado` nulo/vacío por tabla (siempre debe dar cero
en las 10), frescura del clonado de producción, y frescura de carga
(`loaded_at`) por tabla ETL — para detectar de un vistazo si el pipeline
nocturno se quedó atascado o si el clonado se volvió un no-op silencioso
otra vez.

Acceso: http://localhost:3002 — la cuenta de admin es local a esta
instancia de Metabase (guardada en el volumen `metabase_data`, no en este
repo); si nadie recuerda la contraseña, la forma más simple de recuperar
acceso es resetear el contenedor (`terraform destroy
-target=docker_container.metabase -target=docker_volume.metabase_data`
seguido de `terraform apply`) y volver a correr el setup — en ese caso
los 3 dashboards y las 25 preguntas hay que reconstruirlos (no hay export
automático de Metabase a este repo todavía).
