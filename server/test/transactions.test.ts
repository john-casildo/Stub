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

describe('transactions', () => {
  it('creates, lists (with category_name joined), updates, and deletes a transaction', async () => {
    const { token, categoryId } = await setup();

    const createRes = await request(app)
      .post('/transactions')
      .set('Authorization', `Bearer ${token}`)
      .send({ categoryId, merchant: 'Store', amount: 12.5, source: 'manual', occurredAt: '2026-09-01T00:00:00.000Z' });
    expect(createRes.status).toBe(201);
    expect(createRes.body.category_name).toBe('Groceries');
    const id = createRes.body.id as string;

    const listRes = await request(app).get('/transactions').set('Authorization', `Bearer ${token}`);
    expect(listRes.body).toHaveLength(1);
    expect(listRes.body[0].category_name).toBe('Groceries');

    const updateRes = await request(app)
      .patch(`/transactions/${id}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ categoryId, merchant: 'Updated Store', amount: 20, source: 'manual', occurredAt: '2026-09-01T00:00:00.000Z' });
    expect(updateRes.status).toBe(204);

    const afterUpdate = await request(app).get('/transactions').set('Authorization', `Bearer ${token}`);
    expect(afterUpdate.body[0].merchant).toBe('Updated Store');

    const deleteRes = await request(app).delete(`/transactions/${id}`).set('Authorization', `Bearer ${token}`);
    expect(deleteRes.status).toBe(204);

    const afterDelete = await request(app).get('/transactions').set('Authorization', `Bearer ${token}`);
    expect(afterDelete.body).toHaveLength(0);
  });

  it("does not show one user's transactions to another user", async () => {
    const { token: tokenA, categoryId } = await setup();
    const tokenB = (await request(app).post('/auth/anonymous')).body.token as string;

    await request(app)
      .post('/transactions')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({ categoryId, merchant: 'Store', amount: 12.5, source: 'manual', occurredAt: '2026-09-01T00:00:00.000Z' });

    const listRes = await request(app).get('/transactions').set('Authorization', `Bearer ${tokenB}`);
    expect(listRes.body).toHaveLength(0);
  });
});
