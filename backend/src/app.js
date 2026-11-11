import express from 'express';
import { healthRouter } from './routes/health.js';
import { workersRouter } from './routes/workers.js';

/**
 * Create the Express app. Does not listen on any port.
 *
 * `services` ({ verifyIdToken, auth, workers }) enables the authenticated API
 * routes. Without it only `/health` is served, which keeps the health check
 * free of any Firebase dependency.
 */
export function createApp(config, services) {
  const app = express();
  app.disable('x-powered-by');

  app.use(healthRouter(config));
  if (services) app.use('/api/workers', workersRouter(services));

  app.use((_req, res) => {
    res.status(404).json({ error: 'not_found' });
  });

  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    if (err.type === 'entity.parse.failed') {
      return res.status(400).json({ error: 'invalid_json' });
    }
    if (err.type === 'entity.too.large') {
      return res.status(413).json({ error: 'payload_too_large' });
    }
    console.error(err);
    res.status(err.status ?? 500).json({ error: 'internal_error' });
  });

  return app;
}
