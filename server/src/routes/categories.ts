import { Router } from 'express';
import { withUserContext } from '../db';
import { requireAuth, AuthedRequest } from '../auth';

export const categoriesRouter = Router();

categoriesRouter.get('/', requireAuth, async (req: AuthedRequest, res) => {
  const rows = await withUserContext(req.userId!, (client) =>
    client.query('select * from categories order by created_at').then((r) => r.rows),
  );
  res.json(rows);
});

categoriesRouter.post('/', requireAuth, async (req: AuthedRequest, res) => {
  const { name, currencyCode, icon, colorIndex } = req.body as {
    name: string;
    currencyCode?: string | null;
    icon?: string;
    colorIndex?: number | null;
  };
  try {
    const row = await withUserContext(req.userId!, (client) =>
      client
        .query(
          `insert into categories (user_id, name, currency_code, icon, color_index)
           values ($1, $2, $3, $4, $5) returning *`,
          [req.userId, name, currencyCode ?? null, icon ?? 'tag', colorIndex ?? null],
        )
        .then((r) => r.rows[0]),
    );
    res.status(201).json(row);
  } catch (err: any) {
    // `unique (user_id, name)` — matches the Supabase path's `23505` handling
    // in `root_shell.dart`'s `_friendlyMessage`, so the same everyday mistake
    // reads the same on both backends.
    if (err.code === '23505') {
      return res.status(409).json({
        error: { code: 'duplicate_name', message: 'A category with that name already exists' },
      });
    }
    throw err;
  }
});

categoriesRouter.delete('/:id', requireAuth, async (req: AuthedRequest, res) => {
  try {
    await withUserContext(req.userId!, (client) =>
      client.query('delete from categories where id = $1', [req.params.id]),
    );
    res.status(204).send();
  } catch (err: any) {
    if (err.code === '23503') {
      return res.status(409).json({
        error: { code: 'foreign_key_violation', message: 'Category still has transactions' },
      });
    }
    throw err;
  }
});
