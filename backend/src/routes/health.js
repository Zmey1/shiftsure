import { Router } from 'express';

export function healthRouter(config) {
  const router = Router();

  router.get('/health', (_req, res) => {
    res.status(200).json({
      status: 'ok',
      service: config.serviceName,
      uptimeSeconds: Math.floor(process.uptime()),
    });
  });

  return router;
}
