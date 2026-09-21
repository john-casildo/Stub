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

    restore.on('close', (code) => {
      if (code === 0) {
        console.log('Clone complete.');
        resolve();
      } else {
        reject(new Error(
          `psql restore exited with code ${code}.\npg_dump stderr: ${dumpStderr}\npsql stderr: ${restoreStderr}`,
        ));
      }
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
