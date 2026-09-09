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
