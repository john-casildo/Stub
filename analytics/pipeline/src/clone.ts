import { spawn } from 'child_process';

export async function cloneDatabase(sourceUrl: string, targetUrl: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const dump = spawn('pg_dump', ['--clean', '--if-exists', '--no-owner', '--no-privileges', sourceUrl]);
    const restore = spawn('psql', [targetUrl]);

    dump.stdout.pipe(restore.stdin);

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
    restore.on('close', (code) => { restoreCode = code; restoreClosed = true; finish(); });
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
