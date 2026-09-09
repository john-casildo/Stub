import { Pool } from 'pg';
import { withUserContext } from '../src/db';

const adminPool = new Pool({ connectionString: process.env.DATABASE_URL });

async function insertUser(): Promise<string> {
  const res = await adminPool.query('insert into users default values returning id');
  return res.rows[0].id as string;
}

beforeEach(async () => {
  await adminPool.query('delete from transactions');
  await adminPool.query('delete from budgets');
  await adminPool.query('delete from categories');
  await adminPool.query('delete from users');
});

afterAll(async () => {
  await adminPool.end();
});

describe('withUserContext', () => {
  it('lets a user see only their own categories', async () => {
    const userA = await insertUser();
    const userB = await insertUser();

    await withUserContext(userA, (client) =>
      client.query('insert into categories (user_id, name) values ($1, $2)', [userA, 'Groceries']),
    );

    const rowsForB = await withUserContext(userB, (client) =>
      client.query('select * from categories').then((r) => r.rows),
    );
    expect(rowsForB).toHaveLength(0);

    const rowsForA = await withUserContext(userA, (client) =>
      client.query('select * from categories').then((r) => r.rows),
    );
    expect(rowsForA).toHaveLength(1);
    expect(rowsForA[0].name).toBe('Groceries');
  });
});
