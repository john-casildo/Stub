import { Pool, PoolClient } from 'pg';

export const pool = new Pool({
  connectionString: process.env.APP_DATABASE_URL,
  // node-postgres defaults `max` to 10, which caps concurrent DB work at
  // 10 in-flight queries regardless of how many HTTP requests arrive
  // concurrently — the confirmed root cause of the k6 load test's first
  // real-run shortfall (see CLAUDE.md's school-assignment load-testing
  // tooling paragraph). 80 leaves headroom under Postgres's default
  // `max_connections` of 100 for psql/migration connections on the
  // separate `postgres` superuser role, which shares the same
  // server-wide limit. (Clustering the API across worker processes was
  // also tried and reverted — it made real-run throughput worse, not
  // better. `EXPLAIN ANALYZE` on the real hot-path query showed ~20ms
  // per execution even under RLS, ruling out query cost as the cause —
  // the real ceiling is aggregate CPU/concurrency capacity on this local
  // Docker VM under the sheer volume of simultaneous connections, not
  // any single slow query or a fixable app-layer setting. See CLAUDE.md.)
  max: 80,
});

// Without this, an unhandled 'error' event on a pooled client (e.g. a
// connection reset under heavy load) is fatal to the whole Node process
// by default — this was a real, reproduced crash during the load test
// (see CLAUDE.md's Open items). Logging and swallowing it here lets the
// pool recover by opening a replacement connection instead of taking the
// worker down.
pool.on('error', (err) => {
  console.error('Unexpected error on idle Postgres client', err);
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
