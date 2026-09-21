import { spawn } from 'child_process';

// Neither pg_dump nor psql are given a connect timeout by default, so if a
// host is unreachable-but-routable (packets silently dropped rather than
// actively refused — unlike the "Connection refused" case already handled
// below), the TCP connect attempt itself can hang indefinitely. That means
// the process never exits, so 'close' never fires, so finish() never runs,
// so the returned promise never settles — the mirror case of the
// dump.kill() deadlock documented below (that one was "psql dies early,
// pg_dump hangs on write"; this one is "pg_dump/psql itself hangs on
// connect"). Fail fast instead by appending a connect_timeout query param
// to the connection URL before spawning either process.
export function withConnectTimeout(url: string, seconds: number): string {
  const parsed = new URL(url);
  parsed.searchParams.set('connect_timeout', String(seconds));
  return parsed.toString();
}

const CONNECT_TIMEOUT_SECONDS = 10;

export async function cloneDatabase(sourceUrl: string, targetUrl: string): Promise<void> {
  const sourceUrlWithTimeout = withConnectTimeout(sourceUrl, CONNECT_TIMEOUT_SECONDS);
  const targetUrlWithTimeout = withConnectTimeout(targetUrl, CONNECT_TIMEOUT_SECONDS);
  return new Promise((resolve, reject) => {
    const dump = spawn('pg_dump', ['--clean', '--if-exists', '--no-owner', '--no-privileges', sourceUrlWithTimeout]);
    // -v ON_ERROR_STOP=1: without it, psql keeps going and still exits 0
    // after a failed statement inside the restore (e.g. a broken COPY
    // block) — with pg_dump also exiting 0, the clone would report success
    // with partial/corrupt data. A real, confirmed gap in the same family
    // as the pg_dump-exit-code bug above, found in review.
    const restore = spawn('psql', ['-v', 'ON_ERROR_STOP=1', targetUrlWithTimeout]);

    dump.stdout.pipe(restore.stdin);

    // If psql dies early (e.g. can't reach the target database), the pipe
    // from dump.stdout tries to write to restore.stdin after it's already
    // closed, which raises an unhandled 'error' event on the stream and
    // crashes the process with a raw EPIPE stack trace before the real
    // exit-code check below gets a chance to build a useful message. A
    // real, confirmed bug found in review, reproduced against an invalid
    // target. Swallow it here — the exit-code check still reports the
    // actual failure.
    restore.stdin.on('error', () => {});

    let dumpStderr = '';
    let restoreStderr = '';
    dump.stderr.on('data', (chunk) => { dumpStderr += chunk.toString(); });
    restore.stderr.on('data', (chunk) => { restoreStderr += chunk.toString(); });

    dump.on('error', reject);
    restore.on('error', reject);

    // Both processes' exit codes matter: pg_dump piping into psql can have
    // pg_dump fail immediately (e.g. a client/server version mismatch) while
    // psql still exits 0 having simply received an empty/incomplete stream
    // and done nothing — a real, confirmed silent-failure mode found during
    // Task 8's clean-slate verification. Wait for both processes to close
    // and reject if either exited non-zero.
    let dumpCode: number | null = null;
    let restoreCode: number | null = null;
    let dumpClosed = false;
    let restoreClosed = false;

    const finish = () => {
      if (!dumpClosed || !restoreClosed) return;
      if (dumpCode === 0 && restoreCode === 0) {
        console.log('Clone complete.');
        resolve();
      } else {
        reject(new Error(
          `Clone failed (pg_dump exited ${dumpCode}, psql restore exited ${restoreCode}).\n`
          + `pg_dump stderr: ${dumpStderr}\npsql stderr: ${restoreStderr}`,
        ));
      }
    };

    dump.on('close', (code) => { dumpCode = code; dumpClosed = true; finish(); });
    restore.on('close', (code) => {
      restoreCode = code;
      restoreClosed = true;
      // If psql exits early (e.g. it couldn't connect) while pg_dump is
      // still running, swallowing the stdin write error above (so it
      // doesn't crash) isn't enough on its own — nothing is draining
      // dump.stdout any more, so once its OS pipe buffer fills, pg_dump
      // blocks forever on its own write() and the whole clone hangs
      // indefinitely instead of failing. A real, confirmed deadlock found
      // while verifying the stdin-error fix above against an actual
      // invalid target (three real hung `pg_dump` processes were left
      // running in the container until this was added). Kill pg_dump so
      // it can't hang once its output has nowhere left to go.
      if (!dumpClosed) {
        dump.kill();
      }
      finish();
    });
  });
}

if (require.main === module) {
  const sourceUrl = process.env.DATABASE_URL;
  const targetUrl = process.env.ANALYTICS_DATABASE_URL;
  if (!sourceUrl || !targetUrl) {
    throw new Error('DATABASE_URL and ANALYTICS_DATABASE_URL are required');
  }
  cloneDatabase(sourceUrl, targetUrl).catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
