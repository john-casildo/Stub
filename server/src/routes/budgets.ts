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
  await withUserContext(req.userId!, (client) =>
    client.query(
      `insert into budgets (user_id, category_id, limit_amount, period_type, period_start, period_end)
       values ($1, $2, $3, $4, $5, $6)`,
      [req.userId, categoryId, limitAmount, periodType, periodStart, periodEnd ?? null],
    ),
  );
  res.status(201).send();
});
