exports.shorthands = undefined;

exports.up = (pgm) => {
  pgm.sql(`
    create extension if not exists pgcrypto;

    do $$
    begin
      if not exists (select from pg_roles where rolname = 'app_user') then
        create role app_user login password 'app_user_password';
      end if;
    end
    $$;

    create table users (
      id uuid primary key default gen_random_uuid(),
      email text unique,
      first_name text,
      last_name text,
      created_at timestamptz not null default now()
    );

    create table categories (
      id uuid primary key default gen_random_uuid(),
      user_id uuid not null references users(id) on delete cascade,
      name text not null,
      currency_code text check (currency_code in (
        'USD', 'CRC', 'EUR', 'GBP', 'JPY', 'CNY', 'INR', 'KRW', 'VND', 'ILS',
        'TRY', 'PHP', 'THB', 'UAH', 'PLN', 'RUB', 'MXN', 'BRL', 'ARS', 'CLP',
        'COP', 'CAD', 'AUD', 'NZD', 'HKD', 'SGD', 'CHF', 'SEK', 'NOK', 'DKK',
        'ZAR', 'NGN', 'EGP', 'AED', 'SAR', 'PKR', 'BDT', 'IDR', 'MYR', 'PEN'
      )),
      icon text not null default 'tag' check (icon in (
        'tag', 'cart', 'car', 'home', 'heart', 'film', 'bag', 'coffee',
        'plane', 'book', 'bolt', 'dumbbell', 'paw', 'gift', 'phone', 'wallet'
      )),
      color_index integer check (color_index >= 0 and color_index <= 5),
      created_at timestamptz not null default now(),
      unique (user_id, name)
    );

    create table budgets (
      id uuid primary key default gen_random_uuid(),
      user_id uuid not null references users(id) on delete cascade,
      category_id uuid not null references categories(id) on delete cascade,
      limit_amount numeric(12,2) not null check (limit_amount >= 0),
      period_type text not null check (period_type in ('weekly','monthly','yearly','custom')),
      period_start date not null,
      period_end date,
      created_at timestamptz not null default now(),
      unique (category_id),
      check (period_type <> 'custom' or period_end is not null)
    );

    create table transactions (
      id uuid primary key default gen_random_uuid(),
      user_id uuid not null references users(id) on delete cascade,
      category_id uuid not null references categories(id) on delete restrict,
      merchant text not null,
      amount numeric(12,2) not null check (amount > 0),
      source text not null check (source in ('receipt','payment_app','bank_screenshot','manual')),
      image_path text,
      occurred_at timestamptz not null default now(),
      created_at timestamptz not null default now()
    );

    create index idx_budgets_user_id on budgets(user_id);
    create index idx_transactions_category_id on transactions(category_id);
    create index idx_transactions_user_id on transactions(user_id);

    alter table categories enable row level security;
    alter table budgets enable row level security;
    alter table transactions enable row level security;

    create policy categories_own on categories
      using (user_id = current_setting('app.current_user_id', true)::uuid)
      with check (user_id = current_setting('app.current_user_id', true)::uuid);

    create policy budgets_own on budgets
      using (user_id = current_setting('app.current_user_id', true)::uuid)
      with check (user_id = current_setting('app.current_user_id', true)::uuid);

    create policy transactions_own on transactions
      using (user_id = current_setting('app.current_user_id', true)::uuid)
      with check (user_id = current_setting('app.current_user_id', true)::uuid);

    create view budget_progress
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
      coalesce(sum(t.amount), 0) as spent,
      c.currency_code,
      c.icon,
      c.color_index
    from budgets b
    join categories c on c.id = b.category_id
    left join transactions t
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
    group by b.id, c.name, c.currency_code, c.icon, c.color_index;

    grant usage on schema public to app_user;
    grant select, insert, update, delete on categories, budgets, transactions, users to app_user;
    grant select on budget_progress to app_user;
  `);
};

exports.down = (pgm) => {
  pgm.sql(`
    drop view if exists budget_progress;
    drop table if exists transactions;
    drop table if exists budgets;
    drop table if exists categories;
    drop table if exists users;
    drop role if exists app_user;
  `);
};
