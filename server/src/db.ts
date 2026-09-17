import { Pool, PoolClient } from 'pg';

export const pool = new Pool({
  connectionString: process.env.APP_DATABASE_URL,
  // node-postgres defaults `max` to 10, which caps concurrent DB work at
  // 10 in-flight queries regardless of how many HTTP requests arrive
  // concurrently. Confirmed root cause of the k6 load test's real-run
  // shortfall (see CLAUDE.md's school-assignment load-testing tooling
  // paragraph): under real concurrency this caused requests to queue for
  // a pool slot, ballooning http_req_duration into the seconds and
  // eventually causing pooled connections to be dropped/reset under the
  // resulting load — which crashed the whole process (see the
  // `withUserContext`/`client.release()` flow below has no `pool.on(
  // 'error', ...)` handler, so an unhandled 'error' event on a pooled
  // client is fatal to the Node process by default). Approved,
  // narrowly-scoped exception to this task's "no server/src/** changes"
  // rule — resource tuning only, no route/business-logic changes.
  // Postgres itself is configured for max_connections=100 (see
  // docker-compose.yml); 80 leaves headroom for psql/migration
  // connections (which use the separate `postgres` superuser role but
  // share the same server-wide connection limit) while giving the app
  // far more concurrency than the previous default of 10.
  max: 80,
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
