import { Router } from 'express';
import { pool } from '../db';
import { signToken, requireAuth, AuthedRequest } from '../auth';

export const authRouter = Router();

authRouter.post('/anonymous', async (_req, res) => {
  const result = await pool.query('insert into users default values returning id');
  const userId = result.rows[0].id as string;
  res.status(201).json({ token: signToken(userId), userId });
});

authRouter.post('/link-email', requireAuth, async (req: AuthedRequest, res) => {
  const { email } = req.body as { email?: string };
  if (!email) {
    return res.status(400).json({ error: { code: 'bad_request', message: 'email is required' } });
  }
  try {
    await pool.query('update users set email = $1 where id = $2', [email, req.userId]);
  } catch (err: any) {
    if (err.code === '23505') {
      return res.status(409).json({
        error: { code: 'email_taken', message: 'That email is already linked to an account' },
      });
    }
    throw err;
  }
  res.status(200).json({ email });
});
