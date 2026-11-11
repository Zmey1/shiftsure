import { createApp } from './app.js';
import { loadConfig, loadEnvFileIfPresent } from './config.js';
import { createFirebaseServices } from './firebase.js';
import { createWorkerRepository } from './workers/repository.js';

let config;
try {
  loadEnvFileIfPresent();
  config = loadConfig();
} catch (err) {
  console.error(err.message);
  process.exit(1);
}

const { verifyIdToken, auth, db } = createFirebaseServices(config);
const services = { verifyIdToken, auth, workers: createWorkerRepository(db) };

const server = createApp(config, services).listen(config.port, () => {
  console.log(`${config.serviceName} listening on port ${server.address().port} (${config.nodeEnv})`);
});

function shutdown(signal) {
  console.log(`${signal} received, shutting down`);
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 10_000).unref();
}
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
