import express from 'express';
import { authRouter } from './routes/auth';
import { accountRouter } from './routes/account';
import { categoriesRouter } from './routes/categories';

export function createApp() {
  const app = express();
  app.use(express.json());

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });

  app.use('/auth', authRouter);
  app.use('/account', accountRouter);
  app.use('/categories', categoriesRouter);

  return app;
}
