import request from 'supertest';
import jwt from 'jsonwebtoken';
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

async function anonymousToken(): Promise<string> {
  const res = await request(app).post('/auth/anonymous');
  return res.body.token as string;
}

describe('GET /account', () => {
  it('starts anonymous with no name', async () => {
    const token = await anonymousToken();
    const res = await request(app).get('/account').set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.isAnonymous).toBe(true);
    expect(res.body.linkedEmail).toBeNull();
    expect(res.body.firstName).toBeNull();
  });

  it('returns 404 when the token references a user row that does not exist', async () => {
    // Same shape/secret as `src/auth.ts`'s signToken, but for a userId with
    // no matching row — an orphaned or manually-deleted user.
    const token = jwt.sign({ sub: '00000000-0000-0000-0000-000000000000' }, process.env.JWT_SECRET!);
    const res = await request(app).get('/account').set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('user_not_found');
  });
});

describe('PATCH /account/name', () => {
  it('sets and then reflects the name', async () => {
    const token = await anonymousToken();
    const patchRes = await request(app)
      .patch('/account/name')
      .set('Authorization', `Bearer ${token}`)
      .send({ firstName: 'Ada', lastName: 'Lovelace' });
    expect(patchRes.status).toBe(204);

    const getRes = await request(app).get('/account').set('Authorization', `Bearer ${token}`);
    expect(getRes.body.firstName).toBe('Ada');
    expect(getRes.body.lastName).toBe('Lovelace');
  });
});
