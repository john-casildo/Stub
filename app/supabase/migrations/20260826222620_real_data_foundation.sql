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

create index idx_budgets_user_id on public.budgets(user_id);
create index idx_transactions_category_id on public.transactions(category_id);
create index idx_transactions_user_id on public.transactions(user_id);

alter table public.categories enable row level security;
alter table public.budgets enable row level security;
alter table public.transactions enable row level security;

create policy "categories_select_own" on public.categories for select to authenticated using (user_id = (select auth.uid()));
create policy "categories_insert_own" on public.categories for insert to authenticated with check (user_id = (select auth.uid()));
create policy "categories_update_own" on public.categories for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "categories_delete_own" on public.categories for delete to authenticated using (user_id = (select auth.uid()));

create policy "budgets_select_own" on public.budgets for select to authenticated using (user_id = (select auth.uid()));
create policy "budgets_insert_own" on public.budgets for insert to authenticated with check (user_id = (select auth.uid()));
create policy "budgets_update_own" on public.budgets for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "budgets_delete_own" on public.budgets for delete to authenticated using (user_id = (select auth.uid()));

create policy "transactions_select_own" on public.transactions for select to authenticated using (user_id = (select auth.uid()));
create policy "transactions_insert_own" on public.transactions for insert to authenticated with check (user_id = (select auth.uid()));
create policy "transactions_update_own" on public.transactions for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "transactions_delete_own" on public.transactions for delete to authenticated using (user_id = (select auth.uid()));

create or replace view public.budget_progress
with (security_invoker = true) as
select
  b.id as budget_id,
  b.user_id,
  b.category_id,
  c.name as category_name,
  b.limit_amount,
  b.period_type,
  b.period_start,
  b.period_end,
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
