import { Router } from 'express';
import { withUserContext } from '../db';
import { requireAuth, AuthedRequest } from '../auth';

export const budgetsRouter = Router();

budgetsRouter.get('/', requireAuth, async (req: AuthedRequest, res) => {
  const rows = await withUserContext(req.userId!, (client) =>
    client.query('select * from budget_progress order by category_name').then((r) => r.rows),
  );
  res.json(rows);
});

budgetsRouter.post('/', requireAuth, async (req: AuthedRequest, res) => {
  const { categoryId, limitAmount, periodType, periodStart, periodEnd } = req.body as {
    categoryId: string;
    limitAmount: number;
    periodType: string;
    periodStart: string;
    periodEnd?: string | null;
  };
  // `select ... from categories` (rather than `values`) is an application-level
  // ownership check — see the same pattern in `transactions.ts`'s POST: the
  // FK constraint alone bypasses RLS, so without this a user could squat
  // another user's category (`unique (category_id)` then blocks the owner
  // from ever budgeting it).
  const row = await withUserContext(req.userId!, (client) =>
    client
      .query(
        `insert into budgets (user_id, category_id, limit_amount, period_type, period_start, period_end)
         select $1, c.id, $3, $4, $5, $6
         from categories c
         where c.id = $2
         returning id`,
        [req.userId, categoryId, limitAmount, periodType, periodStart, periodEnd ?? null],
      )
      .then((r) => r.rows[0]),
  );
  if (!row) {
    return res.status(404).json({ error: { code: 'category_not_found', message: 'Category not found' } });
  }
  res.status(201).send();
});
