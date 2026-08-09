-- Kharcha v0.2.1 fix: server categories table was never seeded, so any budget
-- /recurring push referencing a builtin category id (1-14) failed the FK
-- "budgets_category_id_fkey" (23503). App assumes shared builtin categories
-- have identical ids on every device (seeded in the same order locally) — seed
-- the server side with the same 14 rows, explicit ids, idempotent.

begin;

insert into public.categories (id, name, emoji, color, is_custom, sort_order, is_income)
overriding system value
select v.id, v.name, v.emoji, v.color, false, v.sort_order, v.is_income
from (values
  (1,  'Food',           '🍔', '#E86A17', 0, false),
  (2,  'Travel',         '🚗', '#2E86AB', 1, false),
  (3,  'Shopping',       '🛍️', '#9B5DE5', 2, false),
  (4,  'Bills',          '⚡', '#F4B942', 3, false),
  (5,  'Recharge',       '📱', '#06D6A0', 4, false),
  (6,  'Rent',           '🏠', '#EF476F', 5, false),
  (7,  'Grocery',        '🛒', '#4CAF50', 6, false),
  (8,  'Medical',        '💊', '#E63946', 7, false),
  (9,  'Entertainment',  '🎬', '#FF9F1C', 8, false),
  (10, 'Other',          '📦', '#8D99AE', 9, false),
  (11, 'Salary',         '💼', '#2E9E6B', 10, true),
  (12, 'Bonus',          '🎁', '#F4B942', 11, true),
  (13, 'Gift',           '🎉', '#9B5DE5', 12, true),
  (14, 'Other income',   '💰', '#06D6A0', 13, true)
) as v(id, name, emoji, color, sort_order, is_income)
on conflict (id) do nothing;

commit;
