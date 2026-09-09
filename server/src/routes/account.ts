import { Router } from 'express';
import { pool } from '../db';
import { requireAuth, AuthedRequest } from '../auth';

export const accountRouter = Router();

accountRouter.get('/', requireAuth, async (req: AuthedRequest, res) => {
  const result = await pool.query(
    'select email, first_name, last_name, created_at from users where id = $1',
    [req.userId],
  );
  if (result.rows.length === 0) {
    // The JWT is well-formed but its `sub` has no matching row (orphaned or
    // manually deleted user). Without this guard `row.email` throws and the
    // generic 500 handler swallows it into an undiagnosable failure.
    return res.status(404).json({ error: { code: 'user_not_found', message: 'User not found' } });
  }
  const row = result.rows[0];
  res.json({
    isAnonymous: row.email === null,
    linkedEmail: row.email,
    firstName: row.first_name,
    lastName: row.last_name,
    memberSince: row.created_at,
  });
});

accountRouter.patch('/name', requireAuth, async (req: AuthedRequest, res) => {
  const { firstName, lastName } = req.body as { firstName?: string; lastName?: string };
  if (!firstName || !lastName) {
    return res.status(400).json({ error: { code: 'bad_request', message: 'firstName and lastName are required' } });
  }
  await pool.query('update users set first_name = $1, last_name = $2 where id = $3', [
    firstName,
    lastName,
    req.userId,
  ]);
  res.status(204).send();
});
