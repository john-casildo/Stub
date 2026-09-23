# Product analytics: core-funnel event tracking

## Context

Every Metabase dashboard built for Stub so far (see
`2026-09-21-analytics-pipeline-design.md` and `analytics/README.md`) is
built from data that already exists: the production clone
(`users`/`categories`/`budgets`/`transactions`) and the school-assignment
"shadow IT" ETL tables (unrelated to Stub's actual business). Neither
tells you anything about product health — activation, engagement,
adoption of the account-linking flow — because Stub has never recorded a
single product event. This spec adds the minimum event tracking needed
to answer that, scoped to a first slice of 5 events, on the currently-
active `customServer` backend only (`app/lib/config/backend_config.dart`
— Supabase support can be added later if `BackendMode.mode` is ever
flipped back).

## Goals

- Record 5 events server-side, at the point each action already happens:
  `app_opened`, `account_linked`, `category_created`,
  `transaction_created` (with its `source`), `budget_created`.
- Event logging must never be able to break the real action it's attached
  to — a failed event write is swallowed and logged, never surfaced to
  the user or the caller.
- New rows flow into the existing analytics pipeline for free (the
  nightly `pg_dump | psql` clone) — no ETL changes needed.

## Non-goals

- No client-side/screen-view event tracking, no new `POST /events`
  generic endpoint for arbitrary client-fired events — only the 5 events
  above, all fired server-side.
- No Supabase-path implementation (Supabase stays untouched, per
  CLAUDE.md's "two backends, one switch" rule — dormant until the switch
  is flipped back).
- No subscription/paywall/revenue events — there is no real subscription
  system built yet; adding event types for a feature that doesn't exist
  would be speculative.
- No new Metabase dashboards/questions in this pass — that's a fast
  follow-up once real event data exists to build charts from.
- No user-facing opt-out/consent UI — Stub already collects this data
  server-side for its own operation (transactions, categories); this is
  additional operational telemetry about actions already logged, not a
  new category of user data collection. Revisit if this ever needs a
  privacy-policy-level answer.

## Schema

New migration (`server/migrations/`, next timestamp after
`1758100000000_transactions_occurred_at_index.js`):

```sql
create table events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  event_type text not null,
  properties jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create index events_type_created_at_idx on events (event_type, created_at);
create index events_user_id_idx on events (user_id);

alter table events enable row level security;

create policy events_insert_own on events
  for insert
  with check (user_id = current_setting('app.current_user_id')::uuid);
```

No `select`/`update`/`delete` policy — nothing in the app-facing API ever
reads events back; only the analytics clone (which runs as the Postgres
superuser via `pg_dump`, bypassing RLS entirely, same as every other
table) touches this data downstream. This matches the "insert only,
no read path" shape that's already correct for a write-only log table.

`event_type` is a free-text column, not a Postgres enum — adding a 6th
event type later is a code change only, no migration. Valid values for
this slice: `'app_opened'`, `'account_linked'`, `'category_created'`,
`'transaction_created'`, `'budget_created'`.

## Recording mechanism

New `server/src/events.ts`. Deliberately **not** run inside the calling
request's own `withUserContext` transaction, so a rollback of the real
action can never also roll back (or be rolled back by) the event write —
it opens its own short-lived connection and sets
`app.current_user_id` itself, since that's what the RLS policy above
checks and it's only set inside a `withUserContext` block:

```typescript
export async function recordEvent(
  userId: string,
  eventType: string,
  properties: Record<string, unknown> = {},
): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query("select set_config('app.current_user_id', $1, true)", [userId]);
    await client.query(
      'insert into events (user_id, event_type, properties) values ($1, $2, $3)',
      [userId, eventType, properties],
    );
    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    console.error(`Failed to record event ${eventType} for user ${userId}`, err);
  } finally {
    client.release();
  }
}
```

Called as a fire-and-forget statement (`void recordEvent(...)`, or
`await`ed after the real response-relevant work is already done/committed
— either way, its own try/catch means a failure here can never propagate
and fail the caller's request) from:

| Route | File | Event | Properties |
|---|---|---|---|
| `POST /auth/anonymous` (new user only) | `src/routes/auth.ts` | `app_opened` | `{}` |
| `POST /auth/link-email` | `src/routes/auth.ts` | `account_linked` | `{}` |
| `POST /categories` | `src/routes/categories.ts` | `category_created` | `{}` |
| `POST /transactions` | `src/routes/transactions.ts` | `transaction_created` | `{source: transaction.source}` |
| `POST /budgets` | `src/routes/budgets.ts` | `budget_created` | `{periodType: budget.periodType}` |

`POST /auth/anonymous` only fires `app_opened` on the branch that
actually creates a new `users` row (a brand-new install's first launch) —
not on every anonymous sign-in call, since an existing anonymous user
re-authenticating isn't an "app opened" signal by itself; that's what the
new ping below is for.

## New endpoint: warm-start ping

`POST /events/app-opened` (new `src/routes/events.ts`, `requireAuth`,
204 no body) — the app already has a stored token on every launch after
the first, so `/auth/anonymous` never fires again; this is the only way
to capture `app_opened` for every subsequent launch.

```typescript
eventsRouter.post('/app-opened', requireAuth, async (req: AuthedRequest, res) => {
  await recordEvent(req.userId, 'app_opened', {});
  res.status(204).send();
});
```

Registered in `src/app.ts` alongside the other routers:
`app.use('/events', eventsRouter);`

## App-side trigger

One addition to `main.dart`'s `_startup()`, matching the existing
"best-effort, never blocks startup" pattern already used for
`_initWeeklySummary` and the deep-link listener setup:

```dart
// Fire-and-forget: an app-open ping for product analytics. Never blocks
// startup and never surfaces a failure to the user — matches
// _initWeeklySummary's established pattern in this same method.
if (BackendConfig.mode == BackendMode.customServer) {
  unawaited(apiClient.post('/events/app-opened', {}).catchError((_) {}));
}
```

Only fires under `BackendMode.customServer` (per the Supabase non-goal
above) — a no-op if the app is ever flipped back to
`BackendMode.supabase`.

## Pipeline / Metabase

No changes needed to `clone.ts` or `etl.ts` — `pg_dump | psql` clones
every table in the production schema, `events` included, automatically
on the next nightly run (or `RUN_NOW=1`). Building the actual funnel
charts (events-by-type-over-time, days-to-first-transaction, DAU
approximated from daily-distinct `app_opened` users) is a follow-up once
real event data has accumulated — out of scope for this implementation
pass.

## Testing

New `server/test/events.test.ts`, matching the existing per-route Jest
pattern (`server/test/*.test.ts`, real Postgres, `beforeEach` truncates):

- `POST /events/app-opened` inserts one `events` row with the right
  `user_id`/`event_type`, returns 204.
- `POST /auth/anonymous` on a brand-new sign-in inserts an `app_opened`
  event; a second sign-in with an existing token does not insert a
  second one.
- `POST /auth/link-email`, `POST /categories`, `POST /transactions`, and
  `POST /budgets` each insert the correct event row with the correct
  `properties` shape (verified directly against the `events` table, not
  through a read endpoint — there isn't one).
- A forced `recordEvent` failure (e.g. temporarily revoking insert
  privilege, or mocking `pool.connect` to throw) does not fail the
  wrapping request — the real transaction/category/budget/link action
  still succeeds and returns its normal response.

No Dart-side test needed beyond confirming the existing `ApiClient` call
shape works (it's a thin `apiClient.post` call, same as every other
mutating call already covered by `ApiClient`'s own tests) — the ping's
own success/failure is invisible to the UI by design.
