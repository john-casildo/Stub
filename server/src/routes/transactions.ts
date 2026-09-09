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
  const row = await withUserContext(req.userId!, (client) =>
    client
      .query(
        `with inserted as (
           insert into transactions (user_id, category_id, merchant, amount, source, occurred_at)
           values ($1, $2, $3, $4, $5, $6)
           returning *
         )
         select inserted.*, c.name as category_name
         from inserted join categories c on c.id = inserted.category_id`,
        [req.userId, categoryId, merchant, amount, source, occurredAt],
      )
      .then((r) => r.rows[0]),
  );
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
