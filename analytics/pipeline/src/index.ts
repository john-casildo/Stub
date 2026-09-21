import 'dotenv/config';
import cron from 'node-cron';
import { cloneDatabase } from './clone';
import { runEtl } from './etl';

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
    runPipeline().catch((err) => console.error('Pipeline run failed:', err));
  });
}
