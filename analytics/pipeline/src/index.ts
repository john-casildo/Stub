import 'dotenv/config';
import cron from 'node-cron';
import { cloneDatabase } from './clone';
import { runEtl } from './etl';

// Guards against an overlapping cron tick starting a second runPipeline()
// while a prior one is still in flight (e.g. hung on a slow/unreachable
// connection — see clone.ts's connect_timeout comment). Without this, a
// second run could spawn a second pg_dump/psql pair on top of a first
// that's still stuck, compounding indefinitely (one stuck pair per missed
// midnight) — the same "stray processes needing docker restart" symptom
// already fixed once in clone.ts, arriving through a different door. Only
// used by the cron path below; RUN_NOW=1 only ever runs once and exits.
let running = false;

async function runPipeline(): Promise<void> {
  const sourceUrl = process.env.DATABASE_URL;
  const analyticsUrl = process.env.ANALYTICS_DATABASE_URL;
  if (!sourceUrl || !analyticsUrl) {
    throw new Error('DATABASE_URL and ANALYTICS_DATABASE_URL are required');
  }
  console.log(`[${new Date().toISOString()}] Starting nightly analytics pipeline`);
  await cloneDatabase(sourceUrl, analyticsUrl);
  await runEtl(analyticsUrl);
  console.log(`[${new Date().toISOString()}] Pipeline complete`);
}

if (process.env.RUN_NOW === '1') {
  runPipeline()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
} else {
  console.log('Pipeline scheduled for midnight (cron: 0 0 * * *)');
  cron.schedule('0 0 * * *', () => {
    if (running) {
      console.log('Skipping this run — previous run still in progress');
      return;
    }
    running = true;
    runPipeline()
      .catch((err) => console.error('Pipeline run failed:', err))
      .finally(() => { running = false; });
  });
}
