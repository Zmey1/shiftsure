import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

// Always backend/.env, regardless of the current working directory.
export const ENV_FILE_PATH = fileURLToPath(new URL('../.env', import.meta.url));

const NODE_ENVS = ['development', 'test', 'production'];

/**
 * Load backend/.env into process.env if the file exists.
 * Variables already set in the environment take precedence over the file.
 * Returns true if a file was loaded.
 */
export function loadEnvFileIfPresent(path = ENV_FILE_PATH) {
  if (!existsSync(path)) return false;
  process.loadEnvFile(path);
  return true;
}

function isBlank(value) {
  return value === undefined || value.trim() === '';
}

/**
 * Build a validated, frozen config from an env object (defaults to process.env).
 * Throws one Error listing every problem found.
 */
export function loadConfig(env = process.env) {
  const errors = [];

  const nodeEnv = isBlank(env.NODE_ENV) ? 'development' : env.NODE_ENV.trim();
  if (!NODE_ENVS.includes(nodeEnv)) {
    errors.push(`NODE_ENV must be one of ${NODE_ENVS.join(', ')} (got "${nodeEnv}")`);
  }

  let port = 3000;
  if (!isBlank(env.PORT)) {
    const raw = env.PORT.trim();
    port = Number(raw);
    if (!/^\d+$/.test(raw) || port > 65535) {
      errors.push(`PORT must be an integer between 0 and 65535 (got "${raw}")`);
    }
  }

  const serviceName = isBlank(env.SERVICE_NAME) ? 'shiftsure-backend' : env.SERVICE_NAME.trim();

  if (errors.length > 0) {
    throw new Error(`Invalid configuration:\n- ${errors.join('\n- ')}`);
  }

  return Object.freeze({ nodeEnv, port, serviceName });
}
