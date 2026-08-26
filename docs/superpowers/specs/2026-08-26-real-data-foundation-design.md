# Real Data Foundation — Design Spec

**Goal:** Replace Stub's hardcoded sample data with a real Supabase-backed
data layer, so every screen (Ledger, Scan, Edit Entry, Manual Entry,
Budgets) reads and writes real transactions, categories, and budgets.

**Context:** Stub currently ships 6 fully-built screens (see CLAUDE.md)
wired to static sample lists in `RootShell`. Supabase (`jlygdlftvvgmekjcawgr`)
is provisioned and `supabase_flutter` is already initialized in `main.dart`,
but no schema exists and no screen talks to it. This is Phase 1 of two —
Phase 2 (optional account-linking UI: Apple/Google/Email/Phone, surfaced
once on first launch and always reachable later from the Profile tab) is
explicitly out of scope here and tracked as a follow-up.

## Decisions carried in from brainstorming (with rationale)

- **No email-based identity.** Anonymous Supabase auth for this phase —
  the app creates a session silently on first launch, no sign-in screen.
  Real portable identity (Apple/Google/Email/Phone) is Phase 2, optional,
  never a gate on using the app — this matches the zero-friction pattern
  observed in comparable apps.
- **Categories are user-managed**, not a fixed list — matches the
  already-built (but unwired) "+ Add a category" button on Budgets.
- **Budget periods are configurable per category**: weekly, monthly,
  yearly, or a fully custom date range. This needs new UI (a period
  picker) that doesn't exist in any mockup.
- **Recurring periods are calendar-aligned**, not anchored to an arbitrary
  creation date — "monthly" always means the actual current calendar
  month, "weekly" the actual current calendar week, etc. This avoids
  real recurrence-math complexity (leap years, month-length differences)
  for a benefit nobody asked for. `custom` periods use an explicit,
  user-chosen start/end date instead.
- **Period history is kept.** "Spent so far" is never stored as a column —
  it's computed from real transaction dates against whichever period
  window is being asked about. This gives "how much did I spend last
  month" for free later without a schema change.
- **Transactions are expenses only** for this phase — no income/refund
  support. Every current screen assumes a single positive amount against
  a category; adding income means designing new UI that doesn't exist
  yet, which is separable, future work.
- **Deleting a category with existing transactions is blocked**
  (`ON DELETE RESTRICT`), not cascaded or silently orphaned. The app
  surfaces this as "can't delete a category with existing transactions."
- **An `image_path` column is added now**, even though nothing populates
  it yet (camera/OCR capture isn't wired) — avoids a follow-up migration
  when that work starts.

## Schema

Three tables, all under Postgres RLS scoped to `auth.uid()`. All three
also get anonymous users' rows correctly, since Supabase anonymous
sessions carry a real, unique `auth.uid()` and the `authenticated`
Postgres role — the `to authenticated` + `user_id = auth.uid()` policy
pattern below covers anonymous and upgraded users identically, with
nothing to change when Phase 2 upgrades an anonymous session to a real
identity.

```sql
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  unique (user_id, name)
);

create table public.budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  limit_amount numeric(12,2) not null check (limit_amount >= 0),
  period_type text not null check (period_type in ('weekly','monthly','yearly','custom')),
  period_start date not null,
  period_end date,
  created_at timestamptz not null default now(),
  unique (category_id),
  check (period_type <> 'custom' or period_end is not null)
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete restrict,
  merchant text not null,
  amount numeric(12,2) not null check (amount > 0),
  source text not null check (source in ('receipt','payment_app','bank_screenshot','manual')),
  image_path text,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.categories enable row level security;
alter table public.budgets enable row level security;
alter table public.transactions enable row level security;

-- Same owner-scoped pattern on all three tables (categories/budgets shown
-- once; transactions repeats it identically):
create policy "categories_select_own" on public.categories for select to authenticated using (user_id = auth.uid());
create policy "categories_insert_own" on public.categories for insert to authenticated with check (user_id = auth.uid());
create policy "categories_update_own" on public.categories for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "categories_delete_own" on public.categories for delete to authenticated using (user_id = auth.uid());
```

Notes:
- `budgets.category_id` cascades on category delete (a budget with no
  category is meaningless); `transactions.category_id` restricts (this is
  what enforces the "can't delete a category with transactions" rule).
- `transactions.occurred_at` is the real transaction date — the current
  Dart model's `dateLabel` (e.g. "Today", "Mon") becomes a client-side
  computed display string from this, not a stored column.

## Budget progress (computed, not stored)

A `security_invoker` view computes each category's current-period spend
by summing `transactions.amount` within that budget's live period window
(calendar-aligned for recurring types, explicit for `custom`):

```sql
create or replace view public.budget_progress
with (security_invoker = true) as
select
  b.id as budget_id,
  b.user_id,
  b.category_id,
  c.name as category_name,
  b.limit_amount,
  b.period_type,
  coalesce(sum(t.amount), 0) as spent
from public.budgets b
join public.categories c on c.id = b.category_id
left join public.transactions t
  on t.category_id = b.category_id
 and t.user_id = b.user_id
 and t.occurred_at >= case b.period_type
       when 'weekly'  then date_trunc('week', now())
       when 'monthly' then date_trunc('month', now())
       when 'yearly'  then date_trunc('year', now())
       else b.period_start::timestamptz
     end
 and t.occurred_at < case b.period_type
       when 'weekly'  then date_trunc('week', now()) + interval '7 days'
       when 'monthly' then date_trunc('month', now()) + interval '1 month'
       when 'yearly'  then date_trunc('year', now()) + interval '1 year'
       else (b.period_end + interval '1 day')::timestamptz
     end
group by b.id, c.name;
```

`security_invoker = true` is required (per the Supabase security
checklist) — without it the view runs as its creator and silently
bypasses RLS. The repeated `case` logic here is a spec-level sketch of
the *behavior*; the implementation plan may factor it into a SQL helper
function to avoid duplication.

Historical periods (e.g. "last month") are a direct `transactions` query
filtered by an explicit date range the caller supplies — no special
schema needed; the view above only ever answers "the current period."

## Data flow / Flutter integration

- **Startup**: before `RootShell` is shown (inside `main.dart`'s existing
  lock-gate flow), ensure a Supabase session exists — call
  `signInAnonymously()` if there is none yet.
- **New `lib/data/` layer**: repository classes
  (`CategoryRepository`, `BudgetRepository`, `TransactionRepository`, or
  one `StubRepository` facade — decided during planning) wrap Supabase
  queries and map rows to the existing `Transaction`/`CategorySpend`/
  `BudgetLimit` Dart models, so screens change minimally.
- **RootShell**: sample lists (`_sampleCategories`, `_sampleRecent`,
  `_sampleBudgets`) are replaced with repository-backed async loads.
- **Manual Entry**: gets a real UI trigger for the first time — a
  floating "+" action button on the Ledger screen (bottom-right, above
  the bottom nav, matching the paper-ledger aesthetic rather than a
  stock Material FAB) that pushes `ManualEntryScreen` — closing the
  long-standing gap where nothing opens it. `onSave` inserts a real row.
- **Edit Entry**: `onSave`/`onDelete` become real update/delete calls.
- **Budgets' "+ Add a category"**: becomes a real flow — name, limit
  amount, and the new period-picker UI (weekly/monthly/yearly/custom with
  a date-range picker) — inserting into `categories` + `budgets`.

## Error handling & loading states

Every data-driven screen currently assumes instant, always-successful
static data. Ledger and Budgets need a loading state (styled to the
paper-ledger aesthetic, not a generic spinner) and a retry-able error
state for query failures. Manual Entry / Edit Entry / Add Category need
inline save-failure feedback (e.g. a snackbar) instead of assuming writes
always succeed.

## Testing

Existing tests are all widget tests with no real network calls — that
continues. The repository layer gets unit tests against fake/mocked
Supabase responses (not the real project); screen widget tests get a
fake repository injected, matching how the screens are already pure,
callback-driven presentational widgets.

## Out of scope (Phase 2 / later, explicitly not this spec)

- Sign in with Apple / Google / Email / Phone, the optional first-launch
  prompt, and the Profile tab's account-linking UI.
- Income/refund tracking.
- Camera/OCR capture actually populating `image_path` or inserting
  transactions from a scan.
- Multi-currency support.
