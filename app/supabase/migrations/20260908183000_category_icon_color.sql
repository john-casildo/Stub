-- Per-category icon + color, chosen at creation in AddCategoryScreen.
-- `icon` is a key into lib/theme/category_icons.dart's curated set (kept
-- in sync with this check constraint by hand, same pattern as
-- currency_code above). `color_index` indexes into the fixed 6-slot
-- light/dark swatch palette in lib/theme/category_colors.dart; null means
-- "no explicit pick" (only possible for rows created before this
-- migration) and the client falls back to a deterministic per-category
-- index in that case.
alter table public.categories
  add column icon text not null default 'tag' check (icon in (
    'tag', 'cart', 'car', 'home', 'heart', 'film', 'bag', 'coffee',
    'plane', 'book', 'bolt', 'dumbbell', 'paw', 'gift', 'phone', 'wallet'
  )),
  add column color_index integer check (color_index >= 0 and color_index <= 5);

-- budget_progress already joins categories for the name/currency; also
-- expose the per-category icon/color so the client can render a budget
-- row's icon without a second round trip.
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
  coalesce(sum(t.amount), 0) as spent,
  c.currency_code,
  c.icon,
  c.color_index
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
group by b.id, c.name, c.currency_code, c.icon, c.color_index;
