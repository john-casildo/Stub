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

describe('POST /auth/anonymous', () => {
  it('creates a new user and returns a usable token', async () => {
    const res = await request(app).post('/auth/anonymous');
    expect(res.status).toBe(201);
    expect(res.body.token).toEqual(expect.any(String));
    expect(res.body.userId).toEqual(expect.any(String));
  });
});

describe('POST /auth/link-email', () => {
  it('rejects a request with no token', async () => {
    const res = await request(app).post('/auth/link-email').send({ email: 'a@example.com' });
    expect(res.status).toBe(401);
  });

  it('attaches an email to the authenticated user', async () => {
    const signUp = await request(app).post('/auth/anonymous');
    const token = signUp.body.token as string;

    const res = await request(app)
      .post('/auth/link-email')
      .set('Authorization', `Bearer ${token}`)
      .send({ email: 'a@example.com' });
    expect(res.status).toBe(200);
    expect(res.body.email).toBe('a@example.com');
  });

  it('returns 409 when the email is already linked to another account', async () => {
    const userA = await request(app).post('/auth/anonymous');
    await request(app)
      .post('/auth/link-email')
      .set('Authorization', `Bearer ${userA.body.token}`)
      .send({ email: 'dup@example.com' });

    const userB = await request(app).post('/auth/anonymous');
    const res = await request(app)
      .post('/auth/link-email')
      .set('Authorization', `Bearer ${userB.body.token}`)
      .send({ email: 'dup@example.com' });
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('email_taken');
  });
});
