import request from 'supertest';
import { Pool } from 'pg';
import { createApp } from '../src/app';

const app = createApp();
const adminPool = new Pool({ connectionString: process.env.DATABASE_URL });

beforeEach(async () => {
  await adminPool.query('delete from transactions');
  await adminPool.query('delete from budgets');
  await adminPool.query('delete from categories');
  await adminPool.query('delete from users');
});

afterAll(async () => {
  await adminPool.end();
});

describe('shared 500 error handler', () => {
  it('returns the standard error body for an unhandled failure', async () => {
    const token = (await request(app).post('/auth/anonymous')).body.token as string;

    // A non-UUID `:id` makes Postgres throw `22P02` (invalid input syntax for
    // type uuid). No route special-cases that code — `categories.ts`'s DELETE
    // only catches `23503` and re-throws everything else — so it falls
    // through to `app.ts`'s generic handler.
    const res = await request(app)
      .delete('/categories/not-a-valid-uuid')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(500);
    expect(res.body).toEqual({
      error: { code: 'internal_error', message: expect.any(String) },
    });
  });
});
