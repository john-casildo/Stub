# API Project (school assignment): seeder + Grafana k6 load test

## Context

School assignment, two phases:

- **Phase 1**: an API covering the main functionality of the chosen app
  (here: Stub, a budget app), excluding login/auth-flow endpoints
  (`/login`, `/recover-password`, `/new-token`, etc.).
- **Phase 2**: (1) a Faker-based script populating the database with data
  that imitates real production usage, at least 1,000,000 rows in the main
  table and hundreds/thousands in supporting tables; (2) a Grafana k6 load
  test simulating at least 500,000 total requests over 7 minutes, peaking
  at 145,000 requests in some one-minute window during the run.

This spec covers what's net-new for Phase 2 (a seeder and a load test) and
confirms Phase 1 is already satisfied by existing code, so no application
code changes are required for this project.

## Goals

- Seed the existing `server/` Postgres database with realistic-shaped data:
  1,200,000+ rows in `transactions` (the main table, analogous to the
  assignment's `tickets` example), ~18,000 rows each in `categories` and
  `budgets` (analogous to `eventos` — hundreds/thousands, not a million),
  spread across ~3,000 fake users.
- Run a k6 load test against the real API (not a mock) that totals ~500,000
  requests across 7 minutes and reaches at least 145,000 requests within
  one of those minutes, with the rest of the profile shaped as a plausible
  ramp-up/ramp-down around that peak.
- Visualize live requests-per-minute during the run in a real Grafana
  dashboard fed by Prometheus, matching the shape of the assignment's
  reference screenshots.

## Non-goals

- No changes to `server/`'s route code, schema, or auth model — Phase 1 is
  satisfied by the code already in the repo (see "Phase 1" below).
- No production deployment of the load-test/Grafana stack — this is local
  Docker Compose, for the demo only.
- No attempt to make the seeded data reachable from the real Stub Flutter
  app's UI — this data lives only in the `server` Postgres database for
  grading/demo purposes and is meant to be wiped/reset afterward.

## Phase 1: API (no new work)

`server/` (Express 5 + raw parameterized `pg`, Postgres 16) already
implements full CRUD for the app's three real resources, all ownership-
scoped via Postgres RLS keyed on a per-request `app.current_user_id`:

- `GET/POST /categories`, `DELETE /categories/:id`
- `GET/POST /budgets`
- `GET/POST/PATCH/DELETE /transactions`
- `GET /account`, `PATCH /account/name`

`POST /auth/anonymous` mints a bearer JWT with no password, login form, or
credential exchange — it is infrastructure for getting a token, not a
login/auth *flow* in the sense the assignment excludes (no
`/login`/`/recover-password`/`/new-token`). It stays as-is; the load test
uses pre-signed tokens (see below) rather than calling it repeatedly.

The existing `Stub API.postman_collection.json` at the repo root is the
Phase 1 deliverable artifact; it should be reviewed for completeness
against the routes above but does not need new endpoints added.

## Phase 2, part 1: Seeder (`server/seed/`)

### Why not go through the HTTP API

1.2M+ POST requests through Express/JWT/RLS would take far longer than a
direct bulk load and isn't what "populate the database" is asking for —
the assignment's own example (Faker + direct DB fill) implies bypassing
the API for seeding, reserving the API traffic for the k6 phase.

### Connection

The seeder connects using `DATABASE_URL` (the `postgres` superuser role,
already defined in `server/docker-compose.yml` and `.env.example`), not
`APP_DATABASE_URL` (`app_user`, RLS-scoped). Table owners bypass RLS by
default, and per-row `SET app.current_user_id` for 1.2M rows would be far
too slow — bulk inserts need a single unscoped connection.

### Steps (`server/seed/seed.ts`, run via `npm run seed`)

1. **Reset**: `TRUNCATE users, categories, budgets, transactions CASCADE;`
   — safe for local/dev use only; the script refuses to run unless
   `DATABASE_URL` points at `localhost`/`postgres` (a container host), as a
   guard against accidentally truncating a non-local database.
2. **Users**: bulk-insert ~3,000 rows via Faker (`faker.person.firstName`/
   `lastName`, `faker.internet.email` for roughly half — the rest left
   anonymous/`email: null`, mirroring real anonymous-vs-linked usage) in
   one batched multi-row `INSERT ... RETURNING id`.
3. **Categories**: for each user, 4-8 categories (random within that
   range) drawn from the same fixed `icon`/`currency_code`/`color_index`
   value sets the schema's `check` constraints allow, with Faker-generated
   names weighted toward realistic budget categories (Groceries, Rent,
   Transport, Entertainment, etc., with some fully-random Faker
   `commerce.department`-style names mixed in for variety) — batched
   multi-row inserts, ~18,000 rows total, `RETURNING id` captured per user.
4. **Budgets**: exactly one per category (satisfies `unique(category_id)`),
   `limit_amount` a Faker-random plausible amount, `period_type` randomly
   one of `weekly`/`monthly`/`yearly`/`custom` (custom rows also get a
   `period_end`, per the schema's check constraint) — batched inserts,
   ~18,000 rows.
5. **Transactions**: 1,200,000+ rows distributed across categories
   (weighted so no category is empty, but not perfectly uniform — a
   Pareto-ish distribution via Faker so some categories are busier than
   others, closer to real usage), `merchant` via
   `faker.company.name`/`faker.person.fullName`-style values depending on
   a randomly chosen `source`, `amount` a realistic Faker-random positive
   decimal, `occurred_at` spread uniformly over the trailing 12 months.
   Inserted in batches of 10,000 via
   `insert into transactions (...) select * from unnest($1::uuid[], $2::uuid[], ...)`
   — the standard fast bulk-insert pattern for `pg`, no new dependency
   needed.
6. **Token export**: for every seeded user, sign a JWT with the same
   `signToken` logic `src/auth.ts` uses (same `JWT_SECRET`, 365d expiry),
   and write `server/seed/output/users.json`:
   ```json
   [{ "userId": "...", "token": "...", "categoryIds": ["...", "..."] }]
   ```
   This lets the k6 script hit the API as 3,000 distinct real, already-
   "logged in" users without ever calling `/auth/anonymous` during the
   timed load test (that would conflate auth overhead with the app's real
   read/write endpoints, and add 3,000 setup requests that don't belong in
   the 500k budget).

### Expected runtime

Bulk `unnest`-based inserts at 10k rows/batch typically run at very high
throughput on local Postgres; 1.2M rows should complete in low single-digit
minutes. The script prints progress every batch (rows inserted / target)
so a stall is visible rather than silent.

## Phase 2, part 2: Load test (`server/loadtest/`)

### Executor choice

k6's `ramping-arrival-rate` executor is used instead of a VU-count-based
executor, because the assignment's requirement is stated directly in
requests/time ("145,000 requests per minute", "500,000 requests total") —
`ramping-arrival-rate` lets the script declare target request rates
directly and k6 manages however many VUs are needed to sustain them (up to
`maxVUs`), rather than the test author having to reverse-engineer a VU
count from a rate.

### Stage profile (`server/loadtest/scenario.js`)

Seven 60-second stages, ramping up to a plateau minute at the required
peak, then back down — a symmetric shape ("acomoden el resto de barras
como deseen" leaves this open, this is one reasonable demo shape):

| Stage | Window | Rate (req/s) | Requests in that minute |
|---|---|---|---|
| 1 | 0:00–1:00 | 0 → 500 (ramp) | 15,000 |
| 2 | 1:00–2:00 | 500 → 1,200 (ramp) | 51,000 |
| 3 | 2:00–3:00 | 1,200 → 2,417 (ramp) | 108,000 |
| 4 | 3:00–4:00 | 2,417 (constant) | **145,020** (peak) |
| 5 | 4:00–5:00 | 2,417 → 1,200 (ramp) | 108,000 |
| 6 | 5:00–6:00 | 1,200 → 500 (ramp) | 51,000 |
| 7 | 6:00–7:00 | 500 → 0 (ramp) | 15,000 |

Total ≈ 493,020 requests. This is within ~1.4% of the 500,000 target and
comfortably clears the 145,000-in-one-minute requirement; a real dry run
against the seeded database will confirm actual completed-request counts
(the arrival-rate executor targets *iteration start* rate, not guaranteed
completions, so real numbers depend on API latency under load) — if the
dry run comes in meaningfully short, stage rates are nudged up rather than
changing the shape.

`preAllocatedVUs: 300`, `maxVUs: 1000` — sized to comfortably sustain
~2,417 iterations/sec assuming sub-150ms typical response times under
load; k6 auto-scales within that ceiling.

### What each iteration does

Each iteration:
1. Picks one random entry from `users.json` (loaded once via k6's
   `SharedArray` so all VUs share one copy instead of each VU loading its
   own).
2. Sends one authenticated request, weighted by a simple random roll:
   - 45% `GET /transactions` (with a random `offset`/`limit` in a
     realistic range) — the single most common real-usage read.
   - 25% `GET /budgets` — the dashboard/budgets-tab read.
   - 15% `GET /categories`.
   - 10% `POST /transactions` — a new Faker-generated transaction against
     one of that user's own `categoryIds` (so writes are ownership-valid,
     exercising the real insert + RLS path, not just reads).
   - 5% `GET /account`.
3. Uses k6's `check()` to assert a 2xx status, so failures show up in the
   summary/Grafana without stopping the run.

This mix is read-heavy (85/15 read/write), matching how a budgeting app is
actually used — checking balances/categories far more often than logging
new transactions.

### Grafana + Prometheus (docker-compose additions)

`server/docker-compose.yml` gains three services, used only for this
demo:
- `prometheus` — scrapes nothing external; instead receives k6's push via
  the remote-write endpoint.
- `grafana` — provisioned with a Prometheus datasource pointed at that
  `prometheus` service, and k6's official community dashboard (imported by
  ID at provisioning time via a datasource/dashboard-provisioning config
  file, not manually re-clicked every run).
- k6 itself is run from the host (not containerized) via
  `k6 run --out experimental-prometheus-rw server/loadtest/scenario.js`,
  pointed at the Dockerized Prometheus's exposed port — simplest to invoke
  interactively during the actual demo, and avoids fighting k6's container
  networking to reach `localhost:3000` (the API) from inside Compose's
  network vs. from the host.

The dashboard's requests-per-minute panel is what gets screenshotted for
the deliverable, matching the assignment's reference images.

## File layout (new)

```
server/
  seed/
    seed.ts              # the Phase 2.1 seeder, run via `npm run seed`
    output/
      users.json          # generated by seed.ts, gitignored (regenerated each run)
  loadtest/
    scenario.js           # the k6 script
    grafana/
      provisioning/
        datasources/prometheus.yml
        dashboards/k6-dashboard.yml
  docker-compose.yml       # + prometheus, grafana services
  package.json             # + "seed" script, + @faker-js/faker devDependency
  .gitignore               # + seed/output/
```

## Testing / verification

This is demo/ops tooling, not application logic, so no Jest coverage is
added. Verification is:
1. Run the seeder against the Dockerized `postgres` service; confirm row
   counts via `select count(*) from transactions;` (expect ≥1,200,000) and
   spot-check a few generated rows for shape (valid `category_id`
   references, `occurred_at` within the last year, positive `amount`).
2. Run the k6 script against the running `api` service; confirm the
   terminal summary's total iteration/request count is close to 500,000
   and that the Grafana requests-per-minute panel shows a visible peak
   minute at/above 145,000 during the run.
3. Confirm existing `server/test/*.test.ts` Jest suite still passes
   unmodified (the seeder/load-test additions don't touch route code).

## Out of scope / open items

- Exact final request counts depend on real hardware/latency during the
  actual demo run — the stage table above is a starting point, tunable
  after one real dry run.
- No cleanup/reset automation beyond the seeder's own `TRUNCATE` step is
  built for "undo the 1.2M seeded rows" — re-running the seeder is itself
  the reset.
- `server/seed/output/users.json` contains real signed JWTs for fake
  users; it's gitignored and treated as disposable, regenerated by each
  seed run, never committed.
