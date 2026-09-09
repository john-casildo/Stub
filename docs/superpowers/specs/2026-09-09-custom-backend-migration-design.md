# Custom Node/Postgres Backend Migration — Design Spec

**Goal:** Replace Supabase (hosted Postgres + Auth + REST) as the app's
live backend with a self-hosted, Dockerized Postgres + a custom Node/
TypeScript API server, **without deleting or breaking the existing
Supabase code path** — the user wants to be able to switch back to
Supabase in the future.

**Context:** Prompted by wanting full control over the backend (own
Postgres, own server) instead of depending on the hosted Supabase
project, whose CLI auth token was already blocking migration pushes (see
CLAUDE.md's Open Items — the not-yet-pushed `currency_code`/`icon`/
`color_index` migrations). This move also unblocks those, since there's
no more `supabase login` token needed once Postgres is self-hosted.

## Decisions from brainstorming (with rationale)

- **Plain Postgres, no Supabase services at all** — not a self-hosted
  Supabase stack (`supabase start`). The user explicitly wants a real,
  from-scratch backend, not just repointing `supabase_flutter` at a local
  Docker instance.
- **Custom backend (Node + TypeScript), not PostgREST.** PostgREST would
  have meant near-zero new code (auto-generated REST from schema + RLS),
  but the user chose the custom-server path deliberately, favoring full
  control over business logic and no dependency on a niche auto-REST tool
  over the lower-effort option.
- **Keep the existing `Supabase*Repository`/`SupabaseAccountLinkService`
  classes untouched in the tree.** They already sit behind abstract
  interfaces (`CategoryRepository`, `TransactionRepository`,
  `BudgetRepository`, `AccountLinkService`) — the new `Http*` classes
  become sibling implementations of the same interfaces, not
  replacements. Switching backends is a one-line change in `main.dart`'s
  wiring, not a rewrite.
- **Replicate anonymous-sign-in + later email-linking**, matching
  today's onboarding exactly (drop straight into the app, no login
  screen), rather than switching to a simple single-user password login.
  Chosen to preserve the app's current no-friction first-run experience.
- **Keep Postgres RLS as defense-in-depth**, with the Node server setting
  a per-request session variable (mirroring how Supabase's own stack
  uses PostgREST + RLS under the hood) — not app-code-only
  authorization. The existing RLS policies from
  `20260826222620_real_data_foundation.sql` are plain Postgres features
  and port over unchanged.
- **Raw parameterized SQL via `pg` (node-postgres), not an ORM.** The
  schema is small (3 tables + 1 view) and every query is already known
  from the `Supabase*Repository` implementations — an ORM adds
  indirection without saving meaningful effort here.
- **Local machine only for now** (Docker Compose on the user's Mac,
  reached via LAN IP from a physical phone during dev) — no production
  hosting decision (TLS, domain, always-on server) needed yet.

## Out of scope

- Deleting, deprecating, or modifying any existing `Supabase*` class,
  the Supabase schema migrations, or `app/supabase/config.toml`. All of
  it stays exactly as-is for a future switch back.
- PostgREST or any other auto-REST tool.
- Production deployment (VPS/home server, TLS, domain, restart
  policies) — this spec covers local Docker Compose only.
- Apple/Google/Phone identity providers for the new backend — only
  anonymous + email, matching what's actually implemented in
  `StubAccountLinkPanel` today (the other three are still visibly
  disabled placeholders).
- Storage/image upload (the `image_path` column already exists but is
  unused — no upload path is wired to it in Supabase either).
- Cloud-vision OCR fallback — unrelated to this migration.
- Migrating existing production data — there's no real user data at
  stake yet (anonymous accounts, pre-launch).

## New files/interfaces

- **`server/`** (new top-level folder, sibling to `app/`) — the Node +
  TypeScript API project (`package.json`, `tsconfig.json`, `src/`).
- **`server/docker-compose.yml`** — two services: `postgres` (image
  `postgres:16`, port `5432`, a named volume for persistence) and `api`
  (the Node server, port `3000`, depends on `postgres`).
- **`server/migrations/`** — raw `.sql` files run via `node-pg-migrate`;
  ports the three existing Supabase migrations (real-data-foundation,
  category-currency, category-icon-color) near-verbatim, since they're
  plain Postgres DDL with no Supabase-specific syntax beyond
  `security_invoker` on the view (a real Postgres 15+ feature, works
  fine standalone).
- **`server/src/db.ts`** — a `pg.Pool`, plus a helper that runs a query
  on a client with `SET LOCAL request.jwt.claim.sub = '<user_id>'` set
  first, so RLS policies keyed on that claim keep working unchanged.
- **`server/src/auth.ts`** — JWT sign/verify (`jsonwebtoken`), an Express
  middleware that verifies `Authorization: Bearer <jwt>` on every route
  except `/auth/anonymous` and `/auth/link-email`'s initial call,
  attaching the resolved `userId` to the request.
- **`server/src/routes/auth.ts`** — `POST /auth/anonymous` (creates a
  `users` row, returns a JWT), `POST /auth/link-email` (attaches
  email+password to the caller's existing user row, matching
  `SupabaseAccountLinkService.linkEmail`'s semantics).
- **`server/src/routes/categories.ts`**, **`transactions.ts`**,
  **`budgets.ts`**, **`account.ts`** — one file per resource, each a thin
  Express router calling parameterized SQL directly (no service-layer
  indirection beyond what's needed to share the RLS-session-variable
  helper).
- **`app/lib/data/http_category_repository.dart`**,
  **`http_transaction_repository.dart`**, **`http_budget_repository.dart`**
  (new) — real implementations of the existing `CategoryRepository`/
  `TransactionRepository`/`BudgetRepository` interfaces, using `http` or
  `dio` (whichever the project prefers — `http` is simpler and this
  project has no other justification yet for `dio`'s extra features) to
  call the new server.
- **`app/lib/data/http_account_link_service.dart`** (new) — real
  implementation of `AccountLinkService` calling `/auth/link-email` and
  `/account`.
- **`app/lib/data/local_auth_token_store.dart`** (new) — thin wrapper
  around `SharedPreferences` (or `flutter_secure_storage` — decide at
  implementation time) persisting the device's JWT, the same role
  Supabase's own session persistence plays today.
- **`app/lib/config/backend_config.dart`** (new) — a `BackendMode` enum
  (`supabase` / `customServer`) and the base URL for the custom server;
  `main.dart` branches on this one value to construct either the
  `Supabase*` set or the `Http*` set of repositories/services. Default
  value TBD by the user at implementation time (likely `customServer`
  once this ships, flippable back to `supabase` for the future).

## Data flow

1. **Cold start, no stored JWT**: `main.dart` calls
   `HttpAccountLinkService`'s underlying flow — really, a small
   `_ensureSession()` equivalent — which calls `POST /auth/anonymous`,
   stores the returned JWT via `LocalAuthTokenStore`, and proceeds.
2. **Every repository call** attaches `Authorization: Bearer <jwt>`;
   the server's auth middleware resolves `userId`, and each route
   handler runs its SQL through the `SET LOCAL request.jwt.claim.sub`
   helper before the actual query, so RLS enforces `user_id = <that
   claim>` exactly as it does today under Supabase.
3. **Email linking**: `StubAccountLinkPanel`'s existing UI (unchanged)
   calls `AccountLinkService.linkEmail`, now routed to
   `HttpAccountLinkService`, which calls `POST /auth/link-email` —
   same one-time "claim this anonymous account" semantics as
   `SupabaseAccountLinkService.linkEmail` today.
4. **Budget progress**: `GET /budgets` returns the same shape
   `budget_progress` produces today (joined category name/icon/color,
   period-scoped `spent`) — computed by keeping that view in the new
   schema, not reimplementing the period-window logic in Node.
5. **Category deletion with existing transactions**: the FK's `ON
   DELETE RESTRICT` still fires in Postgres; the route catches Postgres
   error code `23503` and responds `409`, which `RootShell`'s existing
   error handling (currently keyed off the raw Postgrest error code)
   needs a small adjustment to key off HTTP status instead — the only
   spot in the existing Flutter code that needs to change behavior
   based on which backend is active, since everything else is hidden
   behind the repository interfaces.

## Error handling

- Consistent JSON error body from every route: `{ error: { code,
  message } }`. `code` mirrors the Postgres error where relevant (e.g.
  `foreign_key_violation`) so Flutter-side handling stays legible.
- Auth middleware rejects a missing/invalid/expired JWT with `401`; the
  Flutter side treats this the same way it already treats "no session"
  today — the anonymous-sign-in flow just reruns.
- Any unhandled server error returns `500` with a generic message body
  — no stack traces or SQL text leaked to the client.
- The 1000-row pagination behavior `RootShell._deleteAllData` already
  loops around (a Postgrest-specific `max_rows` cap) doesn't exist on a
  custom server by default — the new `GET /transactions` endpoint
  should default to a sane page size and support `?offset=`/`?limit=`
  so that calling code's existing "loop until empty" logic keeps
  working unchanged.

## Testing

- **Node backend**: integration tests (Jest or Node's built-in test
  runner) run against a real test-Postgres container in Docker,
  covering each route's happy path, RLS isolation (user A can't read
  user B's rows), and the FK-restrict-on-delete error path. This is
  new coverage the project didn't have for Supabase (its Testing
  approach notes call out zero integration coverage against the real
  Supabase project).
- **Flutter**: the new `Http*Repository`/`HttpAccountLinkService`
  classes get no new widget/unit tests beyond compiling correctly and
  matching their interfaces — the existing 210 tests all run against
  `Fake*` doubles regardless of which real implementation backs
  production, so no existing test needs to change.
- **Not automatable**: real end-to-end verification (a physical
  phone/simulator talking to the Dockerized server over LAN) needs
  manual testing, same story as every other "real backend" integration
  point already called out in CLAUDE.md's Open Items.

## Open items this spec would add to CLAUDE.md once implemented

- Production deployment target (always-on host, TLS, domain) is
  undecided — local Docker Compose only for now.
- `BackendMode` default value and how a user/dev actually flips it
  needs deciding at implementation time.
- The `LocalAuthTokenStore` storage mechanism (`SharedPreferences` vs
  `flutter_secure_storage`) needs deciding at implementation time — a
  JWT is more sensitive than the UI-only prefs `LocalPrefs` currently
  stores.
- Email-link mechanism (password vs magic-link) for `/auth/link-email`
  needs deciding at implementation time.
- No production data migration path exists yet if this is ever needed
  for real (non-anonymous, non-pre-launch) user data.
