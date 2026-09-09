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

describe('categories', () => {
  it('creates and lists a category for the authenticated user', async () => {
    const token = await anonymousToken();

    const createRes = await request(app)
      .post('/categories')
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Groceries', icon: 'cart', colorIndex: 2 });
    expect(createRes.status).toBe(201);
    expect(createRes.body.name).toBe('Groceries');
    expect(createRes.body.icon).toBe('cart');

    const listRes = await request(app).get('/categories').set('Authorization', `Bearer ${token}`);
    expect(listRes.status).toBe(200);
    expect(listRes.body).toHaveLength(1);
    expect(listRes.body[0].name).toBe('Groceries');
  });

  it("does not show one user's categories to another user", async () => {
    const tokenA = await anonymousToken();
    const tokenB = await anonymousToken();

    await request(app).post('/categories').set('Authorization', `Bearer ${tokenA}`).send({ name: 'Groceries' });

    const listRes = await request(app).get('/categories').set('Authorization', `Bearer ${tokenB}`);
    expect(listRes.status).toBe(200);
    expect(listRes.body).toHaveLength(0);
  });

  it('returns 409 when deleting a category that still has transactions', async () => {
    const token = await anonymousToken();
    const category = await request(app)
      .post('/categories')
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Groceries' });

    await request(app)
      .post('/transactions')
      .set('Authorization', `Bearer ${token}`)
      .send({
        categoryId: category.body.id,
        merchant: 'Store',
        amount: 10,
        source: 'manual',
        occurredAt: new Date().toISOString(),
      });

    const deleteRes = await request(app)
      .delete(`/categories/${category.body.id}`)
      .set('Authorization', `Bearer ${token}`);
    expect(deleteRes.status).toBe(409);
    expect(deleteRes.body.error.code).toBe('foreign_key_violation');
  });

  it('returns 409 when creating a second category with the same name', async () => {
    const token = await anonymousToken();
    await request(app).post('/categories').set('Authorization', `Bearer ${token}`).send({ name: 'Groceries' });

    const res = await request(app)
      .post('/categories')
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Groceries' });
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('duplicate_name');
  });
});
