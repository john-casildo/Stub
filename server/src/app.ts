import express from 'express';
import { authRouter } from './routes/auth';
import { accountRouter } from './routes/account';
import { categoriesRouter } from './routes/categories';
import { transactionsRouter } from './routes/transactions';
import { budgetsRouter } from './routes/budgets';

export function createApp() {
  const app = express();
  app.use(express.json());

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });

  app.use('/auth', authRouter);
  app.use('/account', accountRouter);
  app.use('/categories', categoriesRouter);
  app.use('/transactions', transactionsRouter);
  app.use('/budgets', budgetsRouter);

  app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
    console.error(err);
    res.status(500).json({ error: { code: 'internal_error', message: 'Something went wrong' } });
  });

  return app;
}
