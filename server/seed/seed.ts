import 'dotenv/config';
import { Pool } from 'pg';

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

async function main() {
  await resetTables();
  console.log('Reset complete.');
  await pool.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
