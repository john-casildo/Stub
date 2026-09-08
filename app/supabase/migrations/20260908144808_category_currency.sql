-- Optional per-category currency override. Null means "use the app's
-- global default currency" (a client-side preference, not stored here).
-- Restricted to the currencies the app actually formats
-- (see lib/util/currency.dart's supportedCurrencies) — add more codes here
-- alongside a matching client-side symbol before allowing them.
alter table public.categories
  add column currency_code text check (currency_code in (
    'USD', 'CRC', 'EUR', 'GBP', 'JPY', 'CNY', 'INR', 'KRW', 'VND', 'ILS',
    'TRY', 'PHP', 'THB', 'UAH', 'PLN', 'RUB', 'MXN', 'BRL', 'ARS', 'CLP',
    'COP', 'CAD', 'AUD', 'NZD', 'HKD', 'SGD', 'CHF', 'SEK', 'NOK', 'DKK',
    'ZAR', 'NGN', 'EGP', 'AED', 'SAR', 'PKR', 'BDT', 'IDR', 'MYR', 'PEN'
  ));

-- budget_progress already joins categories for the name; also expose the
-- per-category currency override so the client can format each budget's
-- spent/limit in the right currency without a second round trip.
create or replace view public.budget_progress
with (security_invoker = true) as
select
  b.id as budget_id,
  b.user_id,
  b.category_id,
  c.name as category_name,
  c.currency_code,
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
group by b.id, c.name, c.currency_code;
