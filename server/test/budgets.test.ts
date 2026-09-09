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

async function setup() {
  const signUp = await request(app).post('/auth/anonymous');
  const token = signUp.body.token as string;
  const category = await request(app)
    .post('/categories')
    .set('Authorization', `Bearer ${token}`)
    .send({ name: 'Groceries' });
  return { token, categoryId: category.body.id as string };
}

describe('budgets', () => {
  it('creates a budget and lists it via budget_progress with spent computed', async () => {
    const { token, categoryId } = await setup();

    const createRes = await request(app)
      .post('/budgets')
      .set('Authorization', `Bearer ${token}`)
      .send({ categoryId, limitAmount: 500, periodType: 'monthly', periodStart: '2026-09-01' });
    expect(createRes.status).toBe(201);

    const listBefore = await request(app).get('/budgets').set('Authorization', `Bearer ${token}`);
    expect(listBefore.body).toHaveLength(1);
    expect(Number(listBefore.body[0].spent)).toBe(0);
    expect(Number(listBefore.body[0].limit_amount)).toBe(500);

    await request(app)
      .post('/transactions')
      .set('Authorization', `Bearer ${token}`)
      .send({
        categoryId,
        merchant: 'Store',
        amount: 40,
        source: 'manual',
        occurredAt: new Date().toISOString(),
      });

    const listAfter = await request(app).get('/budgets').set('Authorization', `Bearer ${token}`);
    expect(Number(listAfter.body[0].spent)).toBe(40);
  });
});
