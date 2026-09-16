import 'dotenv/config';
import { Pool } from 'pg';
import { faker } from '@faker-js/faker';
import jwt from 'jsonwebtoken';
import * as fs from 'fs';
import * as path from 'path';

const DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL) {
  throw new Error('DATABASE_URL environment variable is required');
}

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  throw new Error('JWT_SECRET environment variable is required');
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

const CATEGORY_ICONS = [
  'tag', 'cart', 'car', 'home', 'heart', 'film', 'bag', 'coffee',
  'plane', 'book', 'bolt', 'dumbbell', 'paw', 'gift', 'phone', 'wallet',
];

const CURRENCY_CODES = [
  'USD', 'CRC', 'EUR', 'GBP', 'JPY', 'CNY', 'INR', 'KRW', 'VND', 'ILS',
  'TRY', 'PHP', 'THB', 'UAH', 'PLN', 'RUB', 'MXN', 'BRL', 'ARS', 'CLP',
  'COP', 'CAD', 'AUD', 'NZD', 'HKD', 'SGD', 'CHF', 'SEK', 'NOK', 'DKK',
  'ZAR', 'NGN', 'EGP', 'AED', 'SAR', 'PKR', 'BDT', 'IDR', 'MYR', 'PEN',
];

const CATEGORY_NAMES = [
  'Groceries', 'Rent', 'Transport', 'Entertainment', 'Dining Out',
  'Utilities', 'Health', 'Travel', 'Shopping', 'Subscriptions',
  'Insurance', 'Education', 'Gifts', 'Savings', 'Pets', 'Personal Care',
];

const PERIOD_TYPES = ['weekly', 'monthly', 'yearly', 'custom'] as const;

function chunk<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) {
    out.push(items.slice(i, i + size));
  }
  return out;
}

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

export type SeededCategory = { id: string; userId: string };

async function seedCategoriesAndBudgets(userIds: string[]): Promise<SeededCategory[]> {
  console.log('Seeding categories...');

  type PendingCategory = {
    userId: string;
    name: string;
    currencyCode: string | null;
    icon: string;
    colorIndex: number;
  };
  const pending: PendingCategory[] = [];
  for (const userId of userIds) {
    const count = faker.number.int({ min: 4, max: 8 });
    const names = faker.helpers.arrayElements(CATEGORY_NAMES, count);
    for (const name of names) {
      pending.push({
        userId,
        name,
        // ~10% of categories override the app's global default currency.
        currencyCode: faker.number.int({ min: 1, max: 10 }) === 1
          ? faker.helpers.arrayElement(CURRENCY_CODES)
          : null,
        icon: faker.helpers.arrayElement(CATEGORY_ICONS),
        colorIndex: faker.number.int({ min: 0, max: 5 }),
      });
    }
  }

  const categories: SeededCategory[] = [];
  for (const batch of chunk(pending, 2000)) {
    const values: string[] = [];
    const params: unknown[] = [];
    batch.forEach((c, i) => {
      const base = i * 5;
      values.push(`($${base + 1}, $${base + 2}, $${base + 3}, $${base + 4}, $${base + 5})`);
      params.push(c.userId, c.name, c.currencyCode, c.icon, c.colorIndex);
    });
    const result = await pool.query<{ id: string; user_id: string }>(
      `insert into categories (user_id, name, currency_code, icon, color_index)
       values ${values.join(', ')} returning id, user_id`,
      params,
    );
    for (const row of result.rows) {
      categories.push({ id: row.id, userId: row.user_id });
    }
  }
  console.log(`Inserted ${categories.length} categories.`);

  console.log('Seeding budgets...');
  let budgetCount = 0;
  for (const batch of chunk(categories, 2000)) {
    const values: string[] = [];
    const params: unknown[] = [];
    batch.forEach((c, i) => {
      const periodType = faker.helpers.weightedArrayElement([
        { weight: 4, value: 'monthly' },
        { weight: 3, value: 'weekly' },
        { weight: 2, value: 'yearly' },
        { weight: 1, value: 'custom' },
      ]);
      const periodStart = faker.date.past({ years: 1 });
      const periodEnd = periodType === 'custom'
        ? faker.date.soon({ days: faker.number.int({ min: 30, max: 120 }), refDate: periodStart })
        : null;
      const limitAmount = Number(faker.finance.amount({ min: 50, max: 5000, dec: 2 }));
      const base = i * 6;
      values.push(
        `($${base + 1}, $${base + 2}, $${base + 3}, $${base + 4}, $${base + 5}, $${base + 6})`,
      );
      params.push(c.userId, c.id, limitAmount, periodType, periodStart, periodEnd);
    });
    const result = await pool.query(
      `insert into budgets (user_id, category_id, limit_amount, period_type, period_start, period_end)
       values ${values.join(', ')}`,
      params,
    );
    budgetCount += result.rowCount ?? 0;
  }
  console.log(`Inserted ${budgetCount} budgets.`);

  return categories;
}

const TRANSACTION_SOURCES = ['receipt', 'payment_app', 'bank_screenshot', 'manual'] as const;

function buildWeightedCategoryPool(categories: SeededCategory[]): SeededCategory[] {
  const pool_: SeededCategory[] = [];
  for (const category of categories) {
    // A random per-category weight (1-10 copies in the pool) gives a
    // Pareto-ish spend distribution — some categories busier than others —
    // without weighted-random sampling overhead per transaction.
    const weight = faker.number.int({ min: 1, max: 10 });
    for (let w = 0; w < weight; w++) pool_.push(category);
  }
  return pool_;
}

function randomSource(): (typeof TRANSACTION_SOURCES)[number] {
  return faker.helpers.arrayElement(TRANSACTION_SOURCES);
}

function randomMerchant(source: string): string {
  return source === 'payment_app' ? faker.person.fullName() : faker.company.name();
}

function randomAmount(): number {
  // ~5% of transactions are large (rent/big purchases), the rest everyday spend.
  const isLarge = faker.number.int({ min: 1, max: 100 }) <= 5;
  return isLarge
    ? Number(faker.finance.amount({ min: 500, max: 3000, dec: 2 }))
    : Number(faker.finance.amount({ min: 2, max: 400, dec: 2 }));
}

async function seedTransactions(categories: SeededCategory[]): Promise<void> {
  console.log(`Seeding ${TARGET_TRANSACTIONS} transactions...`);
  const pool_ = buildWeightedCategoryPool(categories);
  const oneYearAgo = faker.date.past({ years: 1 });
  const now = new Date();

  let inserted = 0;
  while (inserted < TARGET_TRANSACTIONS) {
    const batchSize = Math.min(TRANSACTION_BATCH_SIZE, TARGET_TRANSACTIONS - inserted);
    const userIds: string[] = new Array(batchSize);
    const categoryIds: string[] = new Array(batchSize);
    const merchants: string[] = new Array(batchSize);
    const amounts: number[] = new Array(batchSize);
    const sources: string[] = new Array(batchSize);
    const occurredAts: string[] = new Array(batchSize);

    for (let i = 0; i < batchSize; i++) {
      const category = pool_[Math.floor(Math.random() * pool_.length)];
      const source = randomSource();
      userIds[i] = category.userId;
      categoryIds[i] = category.id;
      merchants[i] = randomMerchant(source);
      amounts[i] = randomAmount();
      sources[i] = source;
      occurredAts[i] = faker.date.between({ from: oneYearAgo, to: now }).toISOString();
    }

    await pool.query(
      `insert into transactions (user_id, category_id, merchant, amount, source, occurred_at)
       select * from unnest($1::uuid[], $2::uuid[], $3::text[], $4::numeric[], $5::text[], $6::timestamptz[])`,
      [userIds, categoryIds, merchants, amounts, sources, occurredAts],
    );

    inserted += batchSize;
    console.log(`  ${inserted.toLocaleString()} / ${TARGET_TRANSACTIONS.toLocaleString()} transactions`);
  }
}

function exportUserTokens(userIds: string[], categories: SeededCategory[]): void {
  console.log('Exporting user tokens for the load test...');
  const categoryIdsByUser = new Map<string, string[]>();
  for (const category of categories) {
    const list = categoryIdsByUser.get(category.userId) ?? [];
    list.push(category.id);
    categoryIdsByUser.set(category.userId, list);
  }

  const entries = userIds
    // Only export users that ended up with at least one category — the
    // load test's POST /transactions calls need a valid categoryId.
    .filter((userId) => (categoryIdsByUser.get(userId)?.length ?? 0) > 0)
    .map((userId) => ({
      userId,
      token: jwt.sign({ sub: userId }, JWT_SECRET, { expiresIn: '365d' }),
      categoryIds: categoryIdsByUser.get(userId)!,
    }));

  const outDir = path.join(__dirname, 'output');
  fs.mkdirSync(outDir, { recursive: true });
  const outFile = path.join(outDir, 'users.json');
  fs.writeFileSync(outFile, JSON.stringify(entries));
  console.log(`Wrote ${entries.length} user tokens to ${outFile}`);
}

async function main() {
  await resetTables();
  const userIds = await seedUsers();
  const categories = await seedCategoriesAndBudgets(userIds);
  await seedTransactions(categories);
  exportUserTokens(userIds, categories);
  console.log('Seeding complete.');
  await pool.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
