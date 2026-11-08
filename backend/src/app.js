import express from 'express';
import { healthRouter } from './routes/health.js';

/** Create the Express app. Does not listen on any port. */
export function createApp(config) {
  const app = express();
  app.disable('x-powered-by');

  app.use(healthRouter(config));

  app.use((_req, res) => {
    res.status(404).json({ error: 'not_found' });
  });

  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    console.error(err);
    res.status(err.status ?? 500).json({ error: 'internal_error' });
  });

  return app;
}
