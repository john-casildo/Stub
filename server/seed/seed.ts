import 'dotenv/config';
import { Pool } from 'pg';
import { faker } from '@faker-js/faker';

const DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL) {
  throw new Error('DATABASE_URL environment variable is required');
}

// This script unconditionally truncates every app table — refuse to run
// unless the target clearly looks like a local/dev database.
const dbUrl = new URL(DATABASE_URL);
const LOCAL_HOSTS = new Set(['localhost', '127.0.0.1', 'postgres']);
if (!LOCAL_HOSTS.has(dbUrl.hostname)) {
  throw new Error(
    `Refusing to seed: DATABASE_URL host "${dbUrl.hostname}" doesn't look local ` +
      `(expected one of ${[...LOCAL_HOSTS].join(', ')}).`,
  );
}

export const pool = new Pool({ connectionString: DATABASE_URL });

export const TARGET_USERS = 3000;
export const TARGET_TRANSACTIONS = 1_200_000;
export const TRANSACTION_BATCH_SIZE = 20_000;

async function resetTables(): Promise<void> {
  console.log('Truncating users, categories, budgets, transactions...');
  await pool.query('TRUNCATE users, categories, budgets, transactions CASCADE');
}

async function seedUsers(): Promise<string[]> {
  console.log(`Seeding ${TARGET_USERS} users...`);
  const values: string[] = [];
  const params: unknown[] = [];
  for (let i = 0; i < TARGET_USERS; i++) {
    const firstName = faker.person.firstName();
    const lastName = faker.person.lastName();
    // Roughly half the fake users are "linked" (have an email), mirroring
    // real anonymous-vs-linked usage. Appending the loop index guarantees
    // uniqueness against the `users.email` unique constraint even though
    // faker.internet.email() alone isn't guaranteed collision-free.
    const hasEmail = i % 2 === 0;
    const email = hasEmail
      ? faker.internet.email({ firstName, lastName }).toLowerCase().replace('@', `+${i}@`)
      : null;
    const base = i * 3;
    values.push(`($${base + 1}, $${base + 2}, $${base + 3})`);
    params.push(email, firstName, lastName);
  }
  const result = await pool.query<{ id: string }>(
    `insert into users (email, first_name, last_name) values ${values.join(', ')} returning id`,
    params,
  );
  console.log(`Inserted ${result.rows.length} users.`);
  return result.rows.map((r) => r.id);
}

async function main() {
  await resetTables();
  const userIds = await seedUsers();
  console.log(`Reset + users complete. ${userIds.length} users.`);
  await pool.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
