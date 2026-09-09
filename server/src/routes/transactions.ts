import { Router } from 'express';
import { withUserContext } from '../db';
import { requireAuth, AuthedRequest } from '../auth';

export const transactionsRouter = Router();
const DEFAULT_LIMIT = 1000;

transactionsRouter.get('/', requireAuth, async (req: AuthedRequest, res) => {
  const offset = Number(req.query.offset ?? 0);
  const limit = Number(req.query.limit ?? DEFAULT_LIMIT);
  const rows = await withUserContext(req.userId!, (client) =>
    client
      .query(
        `select t.*, c.name as category_name
         from transactions t
         join categories c on c.id = t.category_id
         order by t.occurred_at desc
         limit $1 offset $2`,
        [limit, offset],
      )
      .then((r) => r.rows),
  );
  res.json(rows);
});

transactionsRouter.post('/', requireAuth, async (req: AuthedRequest, res) => {
  const { categoryId, merchant, amount, source, occurredAt } = req.body as {
    categoryId: string;
    merchant: string;
    amount: number;
    source: string;
    occurredAt: string;
  };
  // `select ... from categories` (rather than `values`) is an application-level
  // ownership check: under RLS the subselect returns zero rows for another
  // user's category, so the insert becomes a no-op. Postgres's own FK check
  // runs with elevated privileges and bypasses RLS, so it would otherwise
  // happily accept a category the caller can't even see.
  const row = await withUserContext(req.userId!, (client) =>
    client
      .query(
        `with inserted as (
           insert into transactions (user_id, category_id, merchant, amount, source, occurred_at)
           select $1, c.id, $3, $4, $5, $6
           from categories c
           where c.id = $2
           returning *
         )
         select inserted.*, c.name as category_name
         from inserted join categories c on c.id = inserted.category_id`,
        [req.userId, categoryId, merchant, amount, source, occurredAt],
      )
      .then((r) => r.rows[0]),
  );
  if (!row) {
    return res.status(404).json({ error: { code: 'category_not_found', message: 'Category not found' } });
  }
  res.status(201).json(row);
});

transactionsRouter.patch('/:id', requireAuth, async (req: AuthedRequest, res) => {
  const { categoryId, merchant, amount, source, occurredAt } = req.body as {
    categoryId: string;
    merchant: string;
    amount: number;
    source: string;
    occurredAt: string;
  };
  await withUserContext(req.userId!, (client) =>
    client.query(
      `update transactions
       set category_id = $1, merchant = $2, amount = $3, source = $4, occurred_at = $5
       where id = $6`,
      [categoryId, merchant, amount, source, occurredAt, req.params.id],
    ),
  );
  res.status(204).send();
});

transactionsRouter.delete('/:id', requireAuth, async (req: AuthedRequest, res) => {
  await withUserContext(req.userId!, (client) =>
    client.query('delete from transactions where id = $1', [req.params.id]),
  );
  res.status(204).send();
});
