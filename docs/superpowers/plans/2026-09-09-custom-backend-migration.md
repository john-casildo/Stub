# Custom Node/Postgres Backend Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a self-hosted Dockerized Postgres + Node/TypeScript API server as a working alternative backend for the Stub app, wired in as sibling implementations of the existing repository interfaces — without touching or deleting any Supabase code.

**Architecture:** A new `server/` project (Express + `pg`, JWT auth, raw parameterized SQL, Postgres RLS as defense-in-depth) runs in Docker Compose alongside a `postgres:16` container. The schema is a near-verbatim port of the existing Supabase migrations, plus a `users` table replacing `auth.users`. On the Flutter side, new `Http*` classes implement `CategoryRepository`/`TransactionRepository`/`BudgetRepository`/`AccountLinkService` — the same interfaces `Supabase*Repository` already implements — so `main.dart` picks one set or the other via a single `BackendConfig.mode` switch.

**Tech Stack:** Node.js + TypeScript, Express, `pg` (node-postgres), `jsonwebtoken`, `node-pg-migrate`, Jest + Supertest, Docker Compose. Flutter side: `http` package (add via `flutter pub add http` if not already present), `shared_preferences` (already a dependency).

**Spec:** `docs/superpowers/specs/2026-09-09-custom-backend-migration-design.md`

## Global Constraints

- Never delete, modify, or deprecate any existing `Supabase*` class, `app/supabase/` migrations, or `app/supabase/config.toml` — they must keep working if `BackendConfig.mode` is switched back to `supabase`.
- Never hand-edit a version number into `app/pubspec.yaml` — use `flutter pub add <package>` and let it resolve the real current version.
- Keep Postgres RLS policies as defense-in-depth (per spec section 2) — every route also explicitly scopes queries by the authenticated `userId` in application code, never relying on RLS alone.
- JSON keys returned by the server match the raw Postgres column names (snake_case) wherever an existing `fromRow`/`toInsertRow` parser already expects that shape (`Category.fromRow`, `Transaction.fromRow`, `BudgetLimit.fromRow`) — this lets the new `Http*Repository` classes reuse those parsers unchanged.
- No automated Flutter test is required for the new `Http*Repository`/`HttpAccountLinkService` classes beyond `flutter analyze` passing — matching the existing project convention that `Supabase*Repository` classes have no dedicated test file either (verified only by the existing 210 fake-backed tests continuing to pass unchanged).
- Server-side: every route's authorization is verified by an integration test that proves user A cannot read/write user B's rows (RLS isolation), per spec section 8.

---

## Task 1: Server project scaffold + Docker Compose + health check

**Files:**
- Create: `server/package.json`
- Create: `server/tsconfig.json`
- Create: `server/.env.example`
- Create: `server/.gitignore`
- Create: `server/src/app.ts`
- Create: `server/src/index.ts`
- Create: `server/docker-compose.yml`
- Create: `server/Dockerfile`
- Create: `server/jest.config.js`
- Test: `server/test/health.test.ts`

**Interfaces:**
- Produces: `createApp(): express.Express` (exported from `server/src/app.ts`) — every later route task imports and extends this. A bare `GET /health` route returning `{ status: 'ok' }` is the only route registered in this task.

- [ ] **Step 1: Create the server folder and `package.json`**

```bash
mkdir -p /Users/johncasildo/Documents/Stub/server/src/routes /Users/johncasildo/Documents/Stub/server/test /Users/johncasildo/Documents/Stub/server/migrations
```

```json
{
  "name": "stub-server",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "ts-node-dev --respawn src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "migrate": "node-pg-migrate",
    "test": "jest --runInBand"
  }
}
```

- [ ] **Step 2: Install dependencies**

```bash
cd /Users/johncasildo/Documents/Stub/server
npm install express pg jsonwebtoken dotenv
npm install --save-dev typescript ts-node-dev node-pg-migrate jest ts-jest @types/jest supertest @types/supertest @types/express @types/node @types/pg @types/jsonwebtoken
```

- [ ] **Step 3: Write `tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true
  },
  "include": ["src"]
}
```

- [ ] **Step 4: Write `jest.config.js`**

```js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/test/**/*.test.ts'],
  testTimeout: 15000,
  setupFiles: ['dotenv/config'],
};
```

**Why `setupFiles: ['dotenv/config']` matters:** every test task from Task 2 onward runs `npx jest test/<file>.test.ts` directly, with no explicit env-var export in that command. Without this line, `DATABASE_URL`/`APP_DATABASE_URL`/`JWT_SECRET` would be unset inside the Jest process even after `.env` exists on disk (Task 2 Step 2 creates it), because nothing else loads it before `src/db.ts`/`src/auth.ts` read `process.env.*` at module import time. This line makes Jest load `.env` the same way `src/index.ts`'s `import 'dotenv/config'` does for the real server process.

- [ ] **Step 5: Write `.env.example` and `.gitignore`**

`.env.example`:
```
DATABASE_URL=postgres://postgres:postgres@localhost:5432/stub
APP_DATABASE_URL=postgres://app_user:app_user_password@localhost:5432/stub
JWT_SECRET=dev-secret-change-me
PORT=3000
```

`.gitignore`:
```
node_modules/
dist/
.env
```

- [ ] **Step 6: Write the failing test for the health route**

`server/test/health.test.ts`:
```ts
import request from 'supertest';
import { createApp } from '../src/app';

describe('GET /health', () => {
  it('returns ok', async () => {
    const app = createApp();
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok' });
  });
});
```

- [ ] **Step 7: Run the test and confirm it fails**

Run: `cd /Users/johncasildo/Documents/Stub/server && npx jest test/health.test.ts`
Expected: FAIL — `Cannot find module '../src/app'`

- [ ] **Step 8: Write `src/app.ts` and `src/index.ts`**

`server/src/app.ts`:
```ts
import express from 'express';

export function createApp() {
  const app = express();
  app.use(express.json());

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });

  return app;
}
```

`server/src/index.ts`:
```ts
import 'dotenv/config';
import { createApp } from './app';

const port = Number(process.env.PORT ?? 3000);
createApp().listen(port, () => {
  console.log(`Stub backend listening on port ${port}`);
});
```

- [ ] **Step 9: Run the test and confirm it passes**

Run: `cd /Users/johncasildo/Documents/Stub/server && npx jest test/health.test.ts`
Expected: PASS

- [ ] **Step 10: Write the Dockerfile and docker-compose.yml**

`server/Dockerfile`:
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build
CMD ["sh", "-c", "npm run migrate && node dist/index.js"]
```

`server/docker-compose.yml`:
```yaml
services:
  postgres:
    image: postgres:16
    restart: unless-stopped
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: stub
    ports:
      - "5432:5432"
    volumes:
      - stub_postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  api:
    build: .
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgres://postgres:postgres@postgres:5432/stub
      APP_DATABASE_URL: postgres://app_user:app_user_password@postgres:5432/stub
      JWT_SECRET: dev-secret-change-me
      PORT: 3000

volumes:
  stub_postgres_data:
```

- [ ] **Step 11: Verify Docker Compose brings up Postgres and the API**

Run: `cd /Users/johncasildo/Documents/Stub/server && docker compose up -d postgres && docker compose ps`
Expected: `postgres` service shows as `healthy`.

Run: `curl http://localhost:5432` — expected to fail with a connection-reset/protocol error (proves Postgres is listening; it isn't an HTTP server, so this is just confirming the port is open).

Leave `api` service stopped for now (it has nothing to migrate yet — Task 2 adds the migration it needs).

- [ ] **Step 12: Commit**

```bash
cd /Users/johncasildo/Documents/Stub
git add server/package.json server/package-lock.json server/tsconfig.json server/.env.example server/.gitignore server/src/app.ts server/src/index.ts server/docker-compose.yml server/Dockerfile server/jest.config.js server/test/health.test.ts
git commit -m "feat(server): scaffold Node/TypeScript backend with Docker Compose"
```

---

## Task 2: Database schema migration + connection helpers

**Files:**
- Create: `server/migrations/1757000000000_init.js`
- Create: `server/src/db.ts`
- Test: `server/test/db.test.ts`

**Interfaces:**
- Consumes: `server/docker-compose.yml`'s `postgres` service (Task 1), reachable at `localhost:5432` with `DATABASE_URL`/`APP_DATABASE_URL` from `.env`.
- Produces: `pool: Pool` (a `pg.Pool` connected via `APP_DATABASE_URL`) and `withUserContext<T>(userId: string, fn: (client: PoolClient) => Promise<T>): Promise<T>` from `server/src/db.ts` — every later route task uses `withUserContext` to run RLS-scoped queries.

**Why a separate `app_user` role:** Postgres RLS is bypassed entirely for superusers and for a table's owner (unless `FORCE ROW LEVEL SECURITY` is set, which still doesn't affect superusers). The migration runs as the `postgres` superuser (via `DATABASE_URL`) to create tables/extensions/roles, but the running API connects as a separate, non-superuser `app_user` role (via `APP_DATABASE_URL`) so the RLS policies actually take effect — otherwise every query would silently see every user's rows regardless of the session variable.

- [ ] **Step 1: Write the migration**

`server/migrations/1757000000000_init.js`:
```js
exports.shorthands = undefined;

exports.up = (pgm) => {
  pgm.sql(`
    create extension if not exists pgcrypto;

    do $$
    begin
      if not exists (select from pg_roles where rolname = 'app_user') then
        create role app_user login password 'app_user_password';
      end if;
    end
    $$;

    create table users (
      id uuid primary key default gen_random_uuid(),
      email text unique,
      first_name text,
      last_name text,
      created_at timestamptz not null default now()
    );

    create table categories (
      id uuid primary key default gen_random_uuid(),
      user_id uuid not null references users(id) on delete cascade,
      name text not null,
      currency_code text check (currency_code in (
        'USD', 'CRC', 'EUR', 'GBP', 'JPY', 'CNY', 'INR', 'KRW', 'VND', 'ILS',
        'TRY', 'PHP', 'THB', 'UAH', 'PLN', 'RUB', 'MXN', 'BRL', 'ARS', 'CLP',
        'COP', 'CAD', 'AUD', 'NZD', 'HKD', 'SGD', 'CHF', 'SEK', 'NOK', 'DKK',
        'ZAR', 'NGN', 'EGP', 'AED', 'SAR', 'PKR', 'BDT', 'IDR', 'MYR', 'PEN'
      )),
      icon text not null default 'tag' check (icon in (
        'tag', 'cart', 'car', 'home', 'heart', 'film', 'bag', 'coffee',
        'plane', 'book', 'bolt', 'dumbbell', 'paw', 'gift', 'phone', 'wallet'
      )),
      color_index integer check (color_index >= 0 and color_index <= 5),
      created_at timestamptz not null default now(),
      unique (user_id, name)
    );

    create table budgets (
      id uuid primary key default gen_random_uuid(),
      user_id uuid not null references users(id) on delete cascade,
      category_id uuid not null references categories(id) on delete cascade,
      limit_amount numeric(12,2) not null check (limit_amount >= 0),
      period_type text not null check (period_type in ('weekly','monthly','yearly','custom')),
      period_start date not null,
      period_end date,
      created_at timestamptz not null default now(),
      unique (category_id),
      check (period_type <> 'custom' or period_end is not null)
    );

    create table transactions (
      id uuid primary key default gen_random_uuid(),
      user_id uuid not null references users(id) on delete cascade,
      category_id uuid not null references categories(id) on delete restrict,
      merchant text not null,
      amount numeric(12,2) not null check (amount > 0),
      source text not null check (source in ('receipt','payment_app','bank_screenshot','manual')),
      image_path text,
      occurred_at timestamptz not null default now(),
      created_at timestamptz not null default now()
    );

    create index idx_budgets_user_id on budgets(user_id);
    create index idx_transactions_category_id on transactions(category_id);
    create index idx_transactions_user_id on transactions(user_id);

    alter table categories enable row level security;
    alter table budgets enable row level security;
    alter table transactions enable row level security;

    create policy categories_own on categories
      using (user_id = current_setting('app.current_user_id', true)::uuid)
      with check (user_id = current_setting('app.current_user_id', true)::uuid);

    create policy budgets_own on budgets
      using (user_id = current_setting('app.current_user_id', true)::uuid)
      with check (user_id = current_setting('app.current_user_id', true)::uuid);

    create policy transactions_own on transactions
      using (user_id = current_setting('app.current_user_id', true)::uuid)
      with check (user_id = current_setting('app.current_user_id', true)::uuid);

    create view budget_progress
    with (security_invoker = true) as
    select
      b.id as budget_id,
      b.user_id,
      b.category_id,
      c.name as category_name,
      b.limit_amount,
      b.period_type,
      b.period_start,
      b.period_end,
      coalesce(sum(t.amount), 0) as spent,
      c.currency_code,
      c.icon,
      c.color_index
    from budgets b
    join categories c on c.id = b.category_id
    left join transactions t
      on t.category_id = b.category_id
     and t.user_id = b.user_id
     and t.occurred_at >= case b.period_type
           when 'weekly'  then date_trunc('week', now())
           when 'monthly' then date_trunc('month', now())
           when 'yearly'  then date_trunc('year', now())
           else b.period_start::timestamptz
         end
     and t.occurred_at < case b.period_type
           when 'weekly'  then date_trunc('week', now()) + interval '7 days'
           when 'monthly' then date_trunc('month', now()) + interval '1 month'
           when 'yearly'  then date_trunc('year', now()) + interval '1 year'
           else (b.period_end + interval '1 day')::timestamptz
         end
    group by b.id, c.name, c.currency_code, c.icon, c.color_index;

    grant usage on schema public to app_user;
    grant select, insert, update, delete on categories, budgets, transactions, users to app_user;
    grant select on budget_progress to app_user;
  `);
};

exports.down = (pgm) => {
  pgm.sql(`
    drop view if exists budget_progress;
    drop table if exists transactions;
    drop table if exists budgets;
    drop table if exists categories;
    drop table if exists users;
    drop role if exists app_user;
  `);
};
```

- [ ] **Step 2: Run the migration against the local Postgres**

Run:
```bash
cd /Users/johncasildo/Documents/Stub/server
cp .env.example .env
export $(cat .env | xargs)
npm run migrate up
```
Expected: output ends with `### MIGRATION 1757000000000_init (UP) ###` and no errors.

- [ ] **Step 3: Write the failing test proving RLS is actually enforced (not just declared)**

`server/test/db.test.ts`:
```ts
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
```

- [ ] **Step 4: Run the test and confirm it fails**

Run: `cd /Users/johncasildo/Documents/Stub/server && npx jest test/db.test.ts`
Expected: FAIL — `Cannot find module '../src/db'`

- [ ] **Step 5: Write `src/db.ts`**

```ts
import { Pool, PoolClient } from 'pg';

export const pool = new Pool({
  connectionString: process.env.APP_DATABASE_URL,
});

export async function withUserContext<T>(
  userId: string,
  fn: (client: PoolClient) => Promise<T>,
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query("select set_config('app.current_user_id', $1, true)", [userId]);
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}
```

- [ ] **Step 6: Run the test and confirm it passes**

Run: `cd /Users/johncasildo/Documents/Stub/server && npx jest test/db.test.ts`
Expected: PASS. If it fails with a permission error instead, the `app_user` grants from Step 1 didn't apply — re-run `npm run migrate up` (or `npm run migrate redo` after fixing the migration file) before re-testing.

- [ ] **Step 7: Commit**

```bash
cd /Users/johncasildo/Documents/Stub
git add server/migrations server/src/db.ts server/test/db.test.ts
git commit -m "feat(server): add Postgres schema migration with RLS + connection helper"
```

---

## Task 3: Anonymous sign-in + JWT auth middleware

**Files:**
- Create: `server/src/auth.ts`
- Create: `server/src/routes/auth.ts`
- Modify: `server/src/app.ts`
- Test: `server/test/auth.test.ts`

**Interfaces:**
- Consumes: `pool` from `server/src/db.ts` (Task 2).
- Produces: `signToken(userId: string): string`, `requireAuth(req, res, next)` Express middleware, and `AuthedRequest` (an `express.Request` with an added `userId?: string` field) from `server/src/auth.ts` — every later route task uses `requireAuth` and `AuthedRequest`. `authRouter` (mounted at `/auth`) from `server/src/routes/auth.ts`, exposing `POST /auth/anonymous` and `POST /auth/link-email`.

- [ ] **Step 1: Write the failing test**

`server/test/auth.test.ts`:
```ts
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
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `cd /Users/johncasildo/Documents/Stub/server && npx jest test/auth.test.ts`
Expected: FAIL — `/auth/anonymous` returns 404 (route doesn't exist yet).

- [ ] **Step 3: Write `src/auth.ts`**

```ts
import jwt from 'jsonwebtoken';
import { Request, Response, NextFunction } from 'express';

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  throw new Error('JWT_SECRET environment variable is required');
}

export interface AuthedRequest extends Request {
  userId?: string;
}

export function signToken(userId: string): string {
  return jwt.sign({ sub: userId }, JWT_SECRET, { expiresIn: '365d' });
}

export function requireAuth(req: AuthedRequest, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ error: { code: 'unauthorized', message: 'Missing bearer token' } });
  }
  const token = header.slice('Bearer '.length);
  try {
    const payload = jwt.verify(token, JWT_SECRET) as { sub: string };
    req.userId = payload.sub;
    next();
  } catch {
    return res.status(401).json({ error: { code: 'unauthorized', message: 'Invalid or expired token' } });
  }
}
```

- [ ] **Step 4: Write `src/routes/auth.ts`**

```ts
import { Router } from 'express';
import { pool } from '../db';
import { signToken, requireAuth, AuthedRequest } from '../auth';

export const authRouter = Router();

authRouter.post('/anonymous', async (_req, res) => {
  const result = await pool.query('insert into users default values returning id');
  const userId = result.rows[0].id as string;
  res.status(201).json({ token: signToken(userId), userId });
});

authRouter.post('/link-email', requireAuth, async (req: AuthedRequest, res) => {
  const { email } = req.body as { email?: string };
  if (!email) {
    return res.status(400).json({ error: { code: 'bad_request', message: 'email is required' } });
  }
  try {
    await pool.query('update users set email = $1 where id = $2', [email, req.userId]);
  } catch (err: any) {
    if (err.code === '23505') {
      return res.status(409).json({
        error: { code: 'email_taken', message: 'That email is already linked to an account' },
      });
    }
    throw err;
  }
  res.status(200).json({ email });
});
```

- [ ] **Step 5: Wire the router into `src/app.ts`**

```ts
import express from 'express';
import { authRouter } from './routes/auth';

export function createApp() {
  const app = express();
  app.use(express.json());

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });

  app.use('/auth', authRouter);

  return app;
}
```

- [ ] **Step 6: Run the test and confirm it passes**

Run: `cd /Users/johncasildo/Documents/Stub/server && npx jest test/auth.test.ts`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
cd /Users/johncasildo/Documents/Stub
git add server/src/auth.ts server/src/routes/auth.ts server/src/app.ts server/test/auth.test.ts
git commit -m "feat(server): add anonymous sign-in and email-linking auth routes"
```

---

## Task 4: Account routes

**Files:**
- Create: `server/src/routes/account.ts`
- Modify: `server/src/app.ts`
- Test: `server/test/account.test.ts`

**Interfaces:**
- Consumes: `pool`, `requireAuth`, `AuthedRequest` (Tasks 2-3).
- Produces: `accountRouter` (mounted at `/account`), exposing `GET /account` (returns `{ isAnonymous, linkedEmail, firstName, lastName, memberSince }`) and `PATCH /account/name` (body `{ firstName, lastName }`).

- [ ] **Step 1: Write the failing test**

`server/test/account.test.ts`:
```ts
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
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `cd /Users/johncasildo/Documents/Stub/server && npx jest test/account.test.ts`
Expected: FAIL — `GET /account` returns 404.

- [ ] **Step 3: Write `src/routes/account.ts`**

```ts
import { Router } from 'express';
import { pool } from '../db';
import { requireAuth, AuthedRequest } from '../auth';

export const accountRouter = Router();

accountRouter.get('/', requireAuth, async (req: AuthedRequest, res) => {
  const result = await pool.query(
    'select email, first_name, last_name, created_at from users where id = $1',
    [req.userId],
  );
  const row = result.rows[0];
  res.json({
    isAnonymous: row.email === null,
    linkedEmail: row.email,
    firstName: row.first_name,
    lastName: row.last_name,
    memberSince: row.created_at,
  });
});

accountRouter.patch('/name', requireAuth, async (req: AuthedRequest, res) => {
  const { firstName, lastName } = req.body as { firstName?: string; lastName?: string };
  if (!firstName || !lastName) {
    return res.status(400).json({ error: { code: 'bad_request', message: 'firstName and lastName are required' } });
  }
  await pool.query('update users set first_name = $1, last_name = $2 where id = $3', [
    firstName,
    lastName,
    req.userId,
  ]);
  res.status(204).send();
});
```

- [ ] **Step 4: Wire the router into `src/app.ts`**

```ts
import { accountRouter } from './routes/account';
// ...
app.use('/account', accountRouter);
```

- [ ] **Step 5: Run the test and confirm it passes**

Run: `cd /Users/johncasildo/Documents/Stub/server && npx jest test/account.test.ts`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
cd /Users/johncasildo/Documents/Stub
git add server/src/routes/account.ts server/src/app.ts server/test/account.test.ts
git commit -m "feat(server): add account routes for profile name and link status"
```

---

## Task 5: Categories routes

**Files:**
- Create: `server/src/routes/categories.ts`
- Modify: `server/src/app.ts`
- Test: `server/test/categories.test.ts`

**Interfaces:**
- Consumes: `withUserContext` (Task 2), `requireAuth`, `AuthedRequest` (Task 3).
- Produces: `categoriesRouter` (mounted at `/categories`): `GET /categories`, `POST /categories` (body `{ name, currencyCode?, icon?, colorIndex? }`), `DELETE /categories/:id` (409 with `error.code: 'foreign_key_violation'` if the category still has transactions).

- [ ] **Step 1: Write the failing test**

`server/test/categories.test.ts`:
```ts
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
});
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `cd /Users/johncasildo/Documents/Stub/server && npx jest test/categories.test.ts`
Expected: FAIL — `POST /categories` returns 404 (and the third test also needs `POST /transactions`, added in Task 6 — expect that one to still fail after Task 6 lands too, until then it errors on the missing categories route first).

- [ ] **Step 3: Write `src/routes/categories.ts`**

```ts
import { Router } from 'express';
import { withUserContext } from '../db';
import { requireAuth, AuthedRequest } from '../auth';

export const categoriesRouter = Router();

categoriesRouter.get('/', requireAuth, async (req: AuthedRequest, res) => {
  const rows = await withUserContext(req.userId!, (client) =>
    client.query('select * from categories order by created_at').then((r) => r.rows),
  );
  res.json(rows);
});

categoriesRouter.post('/', requireAuth, async (req: AuthedRequest, res) => {
  const { name, currencyCode, icon, colorIndex } = req.body as {
    name: string;
    currencyCode?: string | null;
    icon?: string;
    colorIndex?: number | null;
  };
  const row = await withUserContext(req.userId!, (client) =>
    client
      .query(
        `insert into categories (user_id, name, currency_code, icon, color_index)
         values ($1, $2, $3, $4, $5) returning *`,
        [req.userId, name, currencyCode ?? null, icon ?? 'tag', colorIndex ?? null],
      )
      .then((r) => r.rows[0]),
  );
  res.status(201).json(row);
});

categoriesRouter.delete('/:id', requireAuth, async (req: AuthedRequest, res) => {
  try {
    await withUserContext(req.userId!, (client) =>
      client.query('delete from categories where id = $1', [req.params.id]),
    );
    res.status(204).send();
  } catch (err: any) {
    if (err.code === '23503') {
      return res.status(409).json({
        error: { code: 'foreign_key_violation', message: 'Category still has transactions' },
      });
    }
    throw err;
  }
});
```

- [ ] **Step 4: Wire the router into `src/app.ts`**

```ts
import { categoriesRouter } from './routes/categories';
// ...
app.use('/categories', categoriesRouter);
```

- [ ] **Step 5: Run the first two tests and confirm they pass** (the third depends on Task 6)

Run: `cd /Users/johncasildo/Documents/Stub/server && npx jest test/categories.test.ts -t "creates and lists|does not show"`
Expected: PASS for both.

- [ ] **Step 6: Commit**

```bash
cd /Users/johncasildo/Documents/Stub
git add server/src/routes/categories.ts server/src/app.ts server/test/categories.test.ts
git commit -m "feat(server): add categories routes"
```

---

## Task 6: Transactions routes

**Files:**
- Create: `server/src/routes/transactions.ts`
- Modify: `server/src/app.ts`
- Test: `server/test/transactions.test.ts`

**Interfaces:**
- Consumes: `withUserContext`, `requireAuth`, `AuthedRequest`.
- Produces: `transactionsRouter` (mounted at `/transactions`): `GET /transactions?offset=&limit=` (each row includes `category_name`, joined from `categories`; defaults to `limit=1000`), `POST /transactions` (body `{ categoryId, merchant, amount, source, occurredAt }`), `PATCH /transactions/:id` (same body shape), `DELETE /transactions/:id`.

- [ ] **Step 1: Write the failing test**

`server/test/transactions.test.ts`:
```ts
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
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `cd /Users/johncasildo/Documents/Stub/server && npx jest test/transactions.test.ts`
Expected: FAIL — `POST /transactions` returns 404.

- [ ] **Step 3: Write `src/routes/transactions.ts`**

```ts
import { Router } from 'express';
import { withUserContext } from '../db';
import { requireAuth, AuthedRequest } from '../auth';

export const transactionsRouter = Router();
const DEFAULT_LIMIT = 1000;

transactionsRouter.get('/', requireAuth, async (req: AuthedRequest, res) => {
  const offset = Number(req.query.offset ?? 0);
  const limit = Number(req.query.limit ?? DEFAULT_LIMIT);
  const rows = await withUserContext(req.userId!, (client) =>
    client
      .query(
        `select t.*, c.name as category_name
         from transactions t
         join categories c on c.id = t.category_id
         order by t.occurred_at desc
         limit $1 offset $2`,
        [limit, offset],
      )
      .then((r) => r.rows),
  );
  res.json(rows);
});

transactionsRouter.post('/', requireAuth, async (req: AuthedRequest, res) => {
  const { categoryId, merchant, amount, source, occurredAt } = req.body as {
    categoryId: string;
    merchant: string;
    amount: number;
    source: string;
    occurredAt: string;
  };
  const row = await withUserContext(req.userId!, (client) =>
    client
      .query(
        `with inserted as (
           insert into transactions (user_id, category_id, merchant, amount, source, occurred_at)
           values ($1, $2, $3, $4, $5, $6)
           returning *
         )
         select inserted.*, c.name as category_name
         from inserted join categories c on c.id = inserted.category_id`,
        [req.userId, categoryId, merchant, amount, source, occurredAt],
      )
      .then((r) => r.rows[0]),
  );
  res.status(201).json(row);
});

transactionsRouter.patch('/:id', requireAuth, async (req: AuthedRequest, res) => {
  const { categoryId, merchant, amount, source, occurredAt } = req.body as {
    categoryId: string;
    merchant: string;
    amount: number;
    source: string;
    occurredAt: string;
  };
  await withUserContext(req.userId!, (client) =>
    client.query(
      `update transactions
       set category_id = $1, merchant = $2, amount = $3, source = $4, occurred_at = $5
       where id = $6`,
      [categoryId, merchant, amount, source, occurredAt, req.params.id],
    ),
  );
  res.status(204).send();
});

transactionsRouter.delete('/:id', requireAuth, async (req: AuthedRequest, res) => {
  await withUserContext(req.userId!, (client) =>
    client.query('delete from transactions where id = $1', [req.params.id]),
  );
  res.status(204).send();
});
```

- [ ] **Step 4: Wire the router into `src/app.ts`**

```ts
import { transactionsRouter } from './routes/transactions';
// ...
app.use('/transactions', transactionsRouter);
```

- [ ] **Step 5: Run the test and confirm it passes**

Run: `cd /Users/johncasildo/Documents/Stub/server && npx jest test/transactions.test.ts`
Expected: PASS

- [ ] **Step 6: Re-run Task 5's third test (category-delete-with-transactions), now unblocked**

Run: `cd /Users/johncasildo/Documents/Stub/server && npx jest test/categories.test.ts`
Expected: PASS (all three tests).

- [ ] **Step 7: Commit**

```bash
cd /Users/johncasildo/Documents/Stub
git add server/src/routes/transactions.ts server/src/app.ts server/test/transactions.test.ts
git commit -m "feat(server): add transactions routes"
```

---

## Task 7: Budgets routes

**Files:**
- Create: `server/src/routes/budgets.ts`
- Modify: `server/src/app.ts`
- Test: `server/test/budgets.test.ts`

**Interfaces:**
- Consumes: `withUserContext`, `requireAuth`, `AuthedRequest`.
- Produces: `budgetsRouter` (mounted at `/budgets`): `GET /budgets` (rows from the `budget_progress` view), `POST /budgets` (body `{ categoryId, limitAmount, periodType, periodStart, periodEnd? }`).

- [ ] **Step 1: Write the failing test**

`server/test/budgets.test.ts`:
```ts
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
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `cd /Users/johncasildo/Documents/Stub/server && npx jest test/budgets.test.ts`
Expected: FAIL — `POST /budgets` returns 404.

- [ ] **Step 3: Write `src/routes/budgets.ts`**

```ts
import { Router } from 'express';
import { withUserContext } from '../db';
import { requireAuth, AuthedRequest } from '../auth';

export const budgetsRouter = Router();

budgetsRouter.get('/', requireAuth, async (req: AuthedRequest, res) => {
  const rows = await withUserContext(req.userId!, (client) =>
    client.query('select * from budget_progress order by category_name').then((r) => r.rows),
  );
  res.json(rows);
});

budgetsRouter.post('/', requireAuth, async (req: AuthedRequest, res) => {
  const { categoryId, limitAmount, periodType, periodStart, periodEnd } = req.body as {
    categoryId: string;
    limitAmount: number;
    periodType: string;
    periodStart: string;
    periodEnd?: string | null;
  };
  await withUserContext(req.userId!, (client) =>
    client.query(
      `insert into budgets (user_id, category_id, limit_amount, period_type, period_start, period_end)
       values ($1, $2, $3, $4, $5, $6)`,
      [req.userId, categoryId, limitAmount, periodType, periodStart, periodEnd ?? null],
    ),
  );
  res.status(201).send();
});
```

- [ ] **Step 4: Wire the router into `src/app.ts`**

```ts
import { budgetsRouter } from './routes/budgets';
// ...
app.use('/budgets', budgetsRouter);
```

Also add the shared 500-error handler now that all routers are registered — append at the very end of `createApp()`, after every `app.use(...)` call:

```ts
app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(err);
  res.status(500).json({ error: { code: 'internal_error', message: 'Something went wrong' } });
});
```

- [ ] **Step 5: Run the test and confirm it passes**

Run: `cd /Users/johncasildo/Documents/Stub/server && npx jest test/budgets.test.ts`
Expected: PASS

- [ ] **Step 6: Run the full server test suite**

Run: `cd /Users/johncasildo/Documents/Stub/server && npm test`
Expected: all suites pass (health, db, auth, account, categories, transactions, budgets).

- [ ] **Step 7: Commit**

```bash
cd /Users/johncasildo/Documents/Stub
git add server/src/routes/budgets.ts server/src/app.ts server/test/budgets.test.ts
git commit -m "feat(server): add budgets routes and shared error handler"
```

---

## Task 8: Flutter `ApiClient` + `LocalAuthTokenStore`

**Files:**
- Create: `app/lib/data/local_auth_token_store.dart`
- Create: `app/lib/data/api_client.dart`

**Interfaces:**
- Consumes: `SharedPreferences` (already a dependency), the `http` package (add in Step 1 if not already present).
- Produces: `LocalAuthTokenStore` (`readToken()`, `writeToken(String token)`) and `ApiClient` (`ApiClient({required baseUrl, required tokenStore})`, with `getList(path)`, `getMap(path)`, `post(path, body)`, `patch(path, body)`, `delete(path)`) and `ApiException` (`statusCode`, `code`, `message`) — every `Http*Repository`/`HttpAccountLinkService` task depends on these two classes.

- [ ] **Step 1: Add the `http` package**

Run: `cd /Users/johncasildo/Documents/Stub/app && flutter pub add http`
Expected: `pubspec.yaml` gains an `http:` entry with a real resolved version (never hand-typed).

- [ ] **Step 2: Write `local_auth_token_store.dart`**

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the device's JWT for the custom Node backend — the equivalent
/// role Supabase's own session persistence plays for `SupabaseAccountLinkService`.
class LocalAuthTokenStore {
  static const _key = 'custom_backend_jwt';

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> writeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }
}
```

- [ ] **Step 3: Write `api_client.dart`**

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'local_auth_token_store.dart';

/// Thrown for any non-2xx response from the custom backend. `code` mirrors
/// the server's `error.code` field (see `server/src/app.ts`'s error shape),
/// letting callers branch the same way they already do on
/// `PostgrestException.code` for the Supabase backend.
class ApiException implements Exception {
  ApiException(this.statusCode, this.code, this.message);
  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'ApiException($statusCode, $code, $message)';
}

/// Thin HTTP client shared by every `Http*Repository`/`HttpAccountLinkService`.
/// Ensures a device has an anonymous session before the first authenticated
/// call, matching `main.dart`'s `_ensureSession()` behavior for Supabase.
class ApiClient {
  ApiClient({required this.baseUrl, required this.tokenStore, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final LocalAuthTokenStore tokenStore;
  final http.Client _http;

  Future<String> _ensureToken() async {
    final existing = await tokenStore.readToken();
    if (existing != null) return existing;
    final response = await _http.post(Uri.parse('$baseUrl/auth/anonymous'));
    if (response.statusCode != 201) {
      throw ApiException(response.statusCode, 'anonymous_sign_in_failed', 'Could not start a session');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final token = body['token'] as String;
    await tokenStore.writeToken(token);
    return token;
  }

  Future<dynamic> _send(String method, String path, {Map<String, dynamic>? body}) async {
    final token = await _ensureToken();
    final uri = Uri.parse('$baseUrl$path');
    final headers = {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
    final encoded = body == null ? null : jsonEncode(body);
    final http.Response response;
    switch (method) {
      case 'GET':
        response = await _http.get(uri, headers: headers);
      case 'POST':
        response = await _http.post(uri, headers: headers, body: encoded);
      case 'PATCH':
        response = await _http.patch(uri, headers: headers, body: encoded);
      case 'DELETE':
        response = await _http.delete(uri, headers: headers);
      default:
        throw ArgumentError('Unsupported method $method');
    }
    if (response.statusCode >= 400) {
      final decoded = response.body.isEmpty ? null : jsonDecode(response.body) as Map<String, dynamic>?;
      final error = decoded?['error'] as Map<String, dynamic>?;
      throw ApiException(
        response.statusCode,
        error?['code'] as String? ?? 'unknown_error',
        error?['message'] as String? ?? 'Request failed',
      );
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getList(String path) async => (await _send('GET', path)) as List<dynamic>;
  Future<Map<String, dynamic>> getMap(String path) async => (await _send('GET', path)) as Map<String, dynamic>;
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async =>
      (await _send('POST', path, body: body)) as Map<String, dynamic>;
  Future<void> patch(String path, Map<String, dynamic> body) => _send('PATCH', path, body: body);
  Future<void> delete(String path) => _send('DELETE', path);
}
```

- [ ] **Step 4: Verify it compiles**

Run: `cd /Users/johncasildo/Documents/Stub/app && flutter analyze lib/data/local_auth_token_store.dart lib/data/api_client.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
cd /Users/johncasildo/Documents/Stub
git add app/pubspec.yaml app/pubspec.lock app/lib/data/local_auth_token_store.dart app/lib/data/api_client.dart
git commit -m "feat(app): add ApiClient and LocalAuthTokenStore for the custom backend"
```

---

## Task 9: `HttpCategoryRepository`

**Files:**
- Create: `app/lib/data/http_category_repository.dart`

**Interfaces:**
- Consumes: `ApiClient` (Task 8), `CategoryRepository` interface (`app/lib/data/category_repository.dart`), `Category.fromRow` (`app/lib/models/category.dart`).
- Produces: `HttpCategoryRepository implements CategoryRepository`, consumed by Task 13's `main.dart` wiring.

- [ ] **Step 1: Write the implementation**

```dart
import 'api_client.dart';
import 'category_repository.dart';
import '../models/category.dart';

class HttpCategoryRepository implements CategoryRepository {
  HttpCategoryRepository(this._client);
  final ApiClient _client;

  @override
  Future<List<Category>> list() async {
    final rows = await _client.getList('/categories');
    return rows.map((row) => Category.fromRow(row as Map<String, dynamic>)).toList();
  }

  @override
  Future<Category> create(String name, {String? currencyCode, String icon = 'tag', int? colorIndex}) async {
    final row = await _client.post('/categories', {
      'name': name,
      'currencyCode': currencyCode,
      'icon': icon,
      'colorIndex': colorIndex,
    });
    return Category.fromRow(row);
  }

  @override
  Future<void> delete(String id) => _client.delete('/categories/$id');
}
```

- [ ] **Step 2: Verify it compiles and satisfies the interface**

Run: `cd /Users/johncasildo/Documents/Stub/app && flutter analyze lib/data/http_category_repository.dart`
Expected: `No issues found!` (a mismatched method signature against `CategoryRepository` would show as an analyzer error here).

- [ ] **Step 3: Commit**

```bash
cd /Users/johncasildo/Documents/Stub
git add app/lib/data/http_category_repository.dart
git commit -m "feat(app): add HttpCategoryRepository"
```

---

## Task 10: `HttpTransactionRepository`

**Files:**
- Create: `app/lib/data/http_transaction_repository.dart`

**Interfaces:**
- Consumes: `ApiClient`, `TransactionRepository` interface, `Transaction.fromRow`/`Transaction.toInsertRow` (`app/lib/models/transaction.dart`).
- Produces: `HttpTransactionRepository implements TransactionRepository`.

- [ ] **Step 1: Write the implementation**

```dart
import 'api_client.dart';
import 'transaction_repository.dart';
import '../models/transaction.dart';

class HttpTransactionRepository implements TransactionRepository {
  HttpTransactionRepository(this._client);
  final ApiClient _client;

  static const _pageSize = 1000;

  @override
  Future<List<Transaction>> list({int offset = 0}) async {
    final rows = await _client.getList('/transactions?offset=$offset&limit=$_pageSize');
    return rows
        .map((row) => Transaction.fromRow(
              row as Map<String, dynamic>,
              categoryName: row['category_name'] as String,
            ))
        .toList();
  }

  @override
  Future<Transaction> create(Transaction transaction) async {
    final row = await _client.post('/transactions', _toWireBody(transaction));
    return Transaction.fromRow(row, categoryName: row['category_name'] as String);
  }

  @override
  Future<void> update(Transaction transaction) =>
      _client.patch('/transactions/${transaction.id}', _toWireBody(transaction));

  @override
  Future<void> delete(String id) => _client.delete('/transactions/$id');

  /// `toInsertRow` already builds exactly the fields the server route
  /// needs (see `server/src/routes/transactions.ts`); the `userId` passed
  /// here is discarded — the server derives the real owner from the JWT,
  /// never from client-supplied data.
  Map<String, dynamic> _toWireBody(Transaction transaction) {
    final row = transaction.toInsertRow(userId: 'unused');
    return {
      'categoryId': row['category_id'],
      'merchant': row['merchant'],
      'amount': row['amount'],
      'source': row['source'],
      'occurredAt': row['occurred_at'],
    };
  }
}
```

- [ ] **Step 2: Verify it compiles and satisfies the interface**

Run: `cd /Users/johncasildo/Documents/Stub/app && flutter analyze lib/data/http_transaction_repository.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd /Users/johncasildo/Documents/Stub
git add app/lib/data/http_transaction_repository.dart
git commit -m "feat(app): add HttpTransactionRepository"
```

---

## Task 11: `HttpBudgetRepository`

**Files:**
- Create: `app/lib/data/http_budget_repository.dart`

**Interfaces:**
- Consumes: `ApiClient`, `BudgetRepository` interface, `BudgetLimit.fromRow` (`app/lib/models/budget_limit.dart`), `BudgetPeriodType.wireValue`.
- Produces: `HttpBudgetRepository implements BudgetRepository`.

- [ ] **Step 1: Write the implementation**

```dart
import 'api_client.dart';
import 'budget_repository.dart';
import '../models/budget_limit.dart';

class HttpBudgetRepository implements BudgetRepository {
  HttpBudgetRepository(this._client);
  final ApiClient _client;

  @override
  Future<List<BudgetLimit>> list() async {
    final rows = await _client.getList('/budgets');
    return rows.map((row) => BudgetLimit.fromRow(row as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> create({
    required String categoryId,
    required double limitAmount,
    required BudgetPeriodType periodType,
    required DateTime periodStart,
    DateTime? periodEnd,
  }) {
    return _client.post('/budgets', {
      'categoryId': categoryId,
      'limitAmount': limitAmount,
      'periodType': periodType.wireValue,
      'periodStart': periodStart.toIso8601String().split('T').first,
      if (periodEnd != null) 'periodEnd': periodEnd.toIso8601String().split('T').first,
    });
  }
}
```

- [ ] **Step 2: Verify it compiles and satisfies the interface**

Run: `cd /Users/johncasildo/Documents/Stub/app && flutter analyze lib/data/http_budget_repository.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd /Users/johncasildo/Documents/Stub
git add app/lib/data/http_budget_repository.dart
git commit -m "feat(app): add HttpBudgetRepository"
```

---

## Task 12: `HttpAccountLinkService`

**Files:**
- Create: `app/lib/data/http_account_link_service.dart`

**Interfaces:**
- Consumes: `ApiClient`, `AccountLinkService` interface (`app/lib/data/account_link_service.dart`).
- Produces: `HttpAccountLinkService implements AccountLinkService`.

**Design note:** The server's `/auth/link-email` (Task 3) takes only `{ email }` — no password. Real cross-device login by email+password is explicitly out of scope for this migration (see the spec's "Out of scope" section); linking here attaches an email as an identity marker on the same device's existing anonymous account, matching what `linkEmail(String email)`'s single-argument interface already implies. This keeps the existing `AccountLinkService` interface — and `StubAccountLinkPanel`'s call site — completely unchanged.

- [ ] **Step 1: Write the implementation**

```dart
import 'dart:async';
import 'account_link_service.dart';
import 'api_client.dart';

class HttpAccountLinkService implements AccountLinkService {
  HttpAccountLinkService(this._client) {
    _refresh();
  }

  final ApiClient _client;
  final _statusController = StreamController<bool>.broadcast();

  bool _isAnonymous = true;
  String? _linkedEmail;
  DateTime? _memberSince;
  String? _firstName;
  String? _lastName;

  Future<void> _refresh() async {
    final row = await _client.getMap('/account');
    _isAnonymous = row['isAnonymous'] as bool;
    _linkedEmail = row['linkedEmail'] as String?;
    _memberSince = row['memberSince'] == null ? null : DateTime.parse(row['memberSince'] as String);
    _firstName = row['firstName'] as String?;
    _lastName = row['lastName'] as String?;
    _statusController.add(_isAnonymous);
  }

  @override
  bool get isAnonymous => _isAnonymous;

  @override
  String? get linkedEmail => _linkedEmail;

  @override
  DateTime? get memberSince => _memberSince;

  @override
  String? get firstName => _firstName;

  @override
  String? get lastName => _lastName;

  @override
  Future<void> linkEmail(String email) async {
    await _client.post('/auth/link-email', {'email': email});
    await _refresh();
  }

  @override
  Future<void> setName({required String firstName, required String lastName}) async {
    await _client.patch('/account/name', {'firstName': firstName, 'lastName': lastName});
    _firstName = firstName;
    _lastName = lastName;
  }

  @override
  Stream<bool> get linkStatusChanges => _statusController.stream;
}
```

- [ ] **Step 2: Verify it compiles and satisfies the interface**

Run: `cd /Users/johncasildo/Documents/Stub/app && flutter analyze lib/data/http_account_link_service.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd /Users/johncasildo/Documents/Stub
git add app/lib/data/http_account_link_service.dart
git commit -m "feat(app): add HttpAccountLinkService"
```

---

## Task 13: `BackendConfig` + `main.dart` wiring

**Files:**
- Create: `app/lib/config/backend_config.dart`
- Modify: `app/lib/main.dart`

**Interfaces:**
- Consumes: `HttpCategoryRepository`, `HttpTransactionRepository`, `HttpBudgetRepository`, `HttpAccountLinkService`, `ApiClient`, `LocalAuthTokenStore` (Tasks 8-12); existing `SupabaseCategoryRepository`, etc.
- Produces: `BackendMode` enum and `BackendConfig.mode`/`BackendConfig.baseUrl`, read by `main.dart` — this is the single switch point the whole migration hangs off of.

- [ ] **Step 1: Write `backend_config.dart`**

```dart
enum BackendMode { supabase, customServer }

/// Single switch point between the two backend implementations — see
/// `docs/superpowers/specs/2026-09-09-custom-backend-migration-design.md`.
/// Flip `mode` back to `BackendMode.supabase` to fully revert to the
/// original Supabase-backed app; nothing else needs to change.
class BackendConfig {
  /// Update this to your machine's LAN IP (not `localhost`) when testing
  /// on a physical device — the phone can't reach your Mac's `localhost`.
  /// Find it with `ipconfig getifaddr en0` (Wi-Fi) on macOS.
  static const String baseUrl = 'http://localhost:3000';

  static const BackendMode mode = BackendMode.customServer;
}
```

- [ ] **Step 2: Modify `main.dart`'s `_startup()` to skip Supabase init in custom-server mode**

In `app/lib/main.dart`, change:
```dart
Future<_StartupResult> _startup() async {
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  await _ensureSession();
```
to:
```dart
Future<_StartupResult> _startup() async {
  if (BackendConfig.mode == BackendMode.supabase) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    await _ensureSession();
  }
```

- [ ] **Step 3: Modify `_StartupGateState.build()` to construct the right repository set**

Change:
```dart
final result = snapshot.data!;
return StubApp(
  categoryRepository: SupabaseCategoryRepository(Supabase.instance.client),
  transactionRepository: SupabaseTransactionRepository(Supabase.instance.client),
  budgetRepository: SupabaseBudgetRepository(Supabase.instance.client),
  accountLinkService: SupabaseAccountLinkService(Supabase.instance.client),
  localPrefs: result.localPrefs,
```
to:
```dart
final result = snapshot.data!;
final apiClient = ApiClient(baseUrl: BackendConfig.baseUrl, tokenStore: LocalAuthTokenStore());
final useCustomServer = BackendConfig.mode == BackendMode.customServer;
return StubApp(
  categoryRepository: useCustomServer
      ? HttpCategoryRepository(apiClient)
      : SupabaseCategoryRepository(Supabase.instance.client),
  transactionRepository: useCustomServer
      ? HttpTransactionRepository(apiClient)
      : SupabaseTransactionRepository(Supabase.instance.client),
  budgetRepository: useCustomServer
      ? HttpBudgetRepository(apiClient)
      : SupabaseBudgetRepository(Supabase.instance.client),
  accountLinkService: useCustomServer
      ? HttpAccountLinkService(apiClient)
      : SupabaseAccountLinkService(Supabase.instance.client),
  localPrefs: result.localPrefs,
```

- [ ] **Step 4: Add the new imports to `main.dart`**

```dart
import 'config/backend_config.dart';
import 'data/api_client.dart';
import 'data/http_account_link_service.dart';
import 'data/http_budget_repository.dart';
import 'data/http_category_repository.dart';
import 'data/http_transaction_repository.dart';
import 'data/local_auth_token_store.dart';
```

- [ ] **Step 5: Run `flutter analyze` on the whole project**

Run: `cd /Users/johncasildo/Documents/Stub/app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Run the full existing test suite to confirm nothing broke**

Run: `cd /Users/johncasildo/Documents/Stub/app && flutter test`
Expected: all existing tests still pass — `widget_test.dart` and every other test construct `StubApp` directly with fakes, bypassing `main()`'s `_StartupGate` entirely, so this change is invisible to them.

- [ ] **Step 7: Commit**

```bash
cd /Users/johncasildo/Documents/Stub
git add app/lib/config/backend_config.dart app/lib/main.dart
git commit -m "feat(app): wire BackendConfig to switch between Supabase and the custom server"
```

---

## Task 14: `RootShell` error handling for the custom backend's `ApiException`

**Files:**
- Modify: `app/lib/screens/root_shell.dart`

**Interfaces:**
- Consumes: `ApiException` (Task 8).
- Produces: no new public interface — this task only adds error-handling branches so `RootShell`'s existing snackbar behavior (category-has-transactions, duplicate name, etc.) works the same regardless of which backend threw the error.

**Why this is the only Flutter screen that needs a change:** every other screen/widget in the app only ever sees the abstract repository interfaces and never inspects a backend-specific exception type — `RootShell` is the one place that currently catches `PostgrestException` by name to produce a friendly message (`root_shell.dart:449,512,565` — see `_friendlyMessage`).

- [ ] **Step 1: Add the import**

```dart
import '../data/api_client.dart';
```

- [ ] **Step 2: Add an `ApiException`-flavored friendly-message helper next to the existing one**

Immediately after the existing `_friendlyMessage(PostgrestException e)` method (around `root_shell.dart:525`), add:

```dart
String _friendlyMessageForApiException(ApiException e) => switch (e.code) {
      'foreign_key_violation' => "Can't delete a category with existing transactions.",
      'email_taken' => 'That email is already linked to an account.',
      _ => 'Something went wrong. Please try again.',
    };
```

- [ ] **Step 3: Add a matching `on ApiException catch (e)` clause to `_guardedWrite`**

Change:
```dart
Future<void> _guardedWrite(Future<void> Function() write, {VoidCallback? onSuccess}) async {
  try {
    await write();
    if (mounted) onSuccess?.call();
    if (mounted) _reload();
  } on PostgrestException catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyMessage(e))));
    }
  } catch (_) {
```
to:
```dart
Future<void> _guardedWrite(Future<void> Function() write, {VoidCallback? onSuccess}) async {
  try {
    await write();
    if (mounted) onSuccess?.call();
    if (mounted) _reload();
  } on PostgrestException catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyMessage(e))));
    }
  } on ApiException catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyMessageForApiException(e))));
    }
  } catch (_) {
```

- [ ] **Step 4: Add the same clause to `_deleteAllData`'s catch chain** (around `root_shell.dart:449`)

Change:
```dart
} on PostgrestException catch (e) {
  if (mounted) Navigator.of(context).pop(); // dismiss the loading dialog
  if (mounted) _reload();
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyMessage(e))));
  }
} catch (_) {
```
to:
```dart
} on PostgrestException catch (e) {
  if (mounted) Navigator.of(context).pop(); // dismiss the loading dialog
  if (mounted) _reload();
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyMessage(e))));
  }
} on ApiException catch (e) {
  if (mounted) Navigator.of(context).pop(); // dismiss the loading dialog
  if (mounted) _reload();
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyMessageForApiException(e))));
  }
} catch (_) {
```

- [ ] **Step 5: Add the same clause to `_deleteCategory`'s catch chain** (around `root_shell.dart:565`)

Change:
```dart
Future<void> _deleteCategory(String categoryId) async {
  try {
    await widget.categoryRepository.delete(categoryId);
    if (mounted) _reload();
  } on PostgrestException catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyMessage(e))));
    }
  }
```
to:
```dart
Future<void> _deleteCategory(String categoryId) async {
  try {
    await widget.categoryRepository.delete(categoryId);
    if (mounted) _reload();
  } on PostgrestException catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyMessage(e))));
    }
  } on ApiException catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyMessageForApiException(e))));
    }
  }
```

- [ ] **Step 6: Run `flutter analyze` and the full test suite**

Run: `cd /Users/johncasildo/Documents/Stub/app && flutter analyze && flutter test`
Expected: `No issues found!` and all tests pass — `FakeCategoryRepository`/etc. never throw `ApiException`, so the new catch clauses are inert for the existing fake-backed tests, matching this task's "no new public interface" scope.

- [ ] **Step 7: Commit**

```bash
cd /Users/johncasildo/Documents/Stub
git add app/lib/screens/root_shell.dart
git commit -m "feat(app): handle ApiException in RootShell alongside PostgrestException"
```

---

## Manual verification (not automatable — do this after Task 14)

1. `cd server && docker compose up -d --build` — brings up Postgres + the API together, running migrations on API startup.
2. Confirm `curl http://localhost:3000/health` returns `{"status":"ok"}`.
3. Find your Mac's LAN IP (`ipconfig getifaddr en0`) and update `BackendConfig.baseUrl` to `http://<that-ip>:3000`.
4. Run the Flutter app on a physical device/simulator on the same network, confirm: cold start creates an anonymous session, adding a category/transaction/budget round-trips through the real server, deleting a category with transactions shows the friendly snackbar, and Profile's email-link flow completes.
5. Flip `BackendConfig.mode` back to `BackendMode.supabase`, rebuild, and confirm the app still works exactly as before against the real Supabase project — proving nothing about the existing path broke.
