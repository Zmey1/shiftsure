import { test } from 'node:test';
import assert from 'node:assert/strict';
import { writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { ENV_FILE_PATH, loadConfig, loadEnvFileIfPresent } from '../src/config.js';

test('applies defaults for an empty env', () => {
  assert.deepEqual(loadConfig({}), {
    nodeEnv: 'development',
    port: 3000,
    serviceName: 'shiftsure-backend',
    firebaseProjectId: 'demo-shiftsure',
  });
});

test('parses valid overrides', () => {
  const config = loadConfig({ NODE_ENV: 'test', PORT: '0', SERVICE_NAME: 'svc' });
  assert.deepEqual(config, {
    nodeEnv: 'test',
    port: 0,
    serviceName: 'svc',
    firebaseProjectId: 'demo-shiftsure',
  });
});

test('treats blank values as unset', () => {
  assert.equal(loadConfig({ PORT: '  ', NODE_ENV: '' }).port, 3000);
});

test('config is frozen', () => {
  assert.throws(() => {
    'use strict';
    loadConfig({}).port = 1;
  }, TypeError);
});

test('rejects invalid PORT values', () => {
  for (const PORT of ['abc', '-1', '65536', '3.5', '1e3']) {
    assert.throws(() => loadConfig({ PORT }), /PORT must be an integer/, PORT);
  }
});

test('rejects invalid NODE_ENV', () => {
  assert.throws(() => loadConfig({ NODE_ENV: 'staging' }), /NODE_ENV must be one of/);
});

test('reports every problem at once', () => {
  assert.throws(
    () => loadConfig({ NODE_ENV: 'x', PORT: 'y' }),
    (err) => /NODE_ENV/.test(err.message) && /PORT/.test(err.message),
  );
});

test('FIREBASE_PROJECT_ID overrides the demo default', () => {
  assert.equal(loadConfig({ FIREBASE_PROJECT_ID: ' my-proj ' }).firebaseProjectId, 'my-proj');
});

test('production requires a real FIREBASE_PROJECT_ID', () => {
  assert.throws(() => loadConfig({ NODE_ENV: 'production' }), /FIREBASE_PROJECT_ID is required/);
  assert.throws(
    () => loadConfig({ NODE_ENV: 'production', FIREBASE_PROJECT_ID: 'demo-shiftsure' }),
    /must not be a demo-/,
  );
  assert.equal(
    loadConfig({ NODE_ENV: 'production', FIREBASE_PROJECT_ID: 'real-proj' }).firebaseProjectId,
    'real-proj',
  );
});

test('production rejects FIREBASE_AUTH_EMULATOR_HOST', () => {
  assert.throws(
    () =>
      loadConfig({
        NODE_ENV: 'production',
        FIREBASE_PROJECT_ID: 'real-proj',
        FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099',
      }),
    /FIREBASE_AUTH_EMULATOR_HOST must not be set/,
  );
});

test('production rejects FIRESTORE_EMULATOR_HOST', () => {
  assert.throws(
    () =>
      loadConfig({
        NODE_ENV: 'production',
        FIREBASE_PROJECT_ID: 'real-proj',
        FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080',
      }),
    /FIRESTORE_EMULATOR_HOST must not be set/,
  );
});

test('missing .env file is not an error', () => {
  assert.equal(loadEnvFileIfPresent(join(tmpdir(), 'shiftsure-does-not-exist.env')), false);
});

test('loads an existing env file without overriding existing variables', () => {
  const dir = mkdtempSync(join(tmpdir(), 'shiftsure-env-'));
  const file = join(dir, '.env');
  writeFileSync(file, 'SHIFTSURE_TEST_NEW=from_file\nSHIFTSURE_TEST_KEEP=from_file\n');
  process.env.SHIFTSURE_TEST_KEEP = 'from_env';
  try {
    assert.equal(loadEnvFileIfPresent(file), true);
    assert.equal(process.env.SHIFTSURE_TEST_NEW, 'from_file');
    assert.equal(process.env.SHIFTSURE_TEST_KEEP, 'from_env');
  } finally {
    delete process.env.SHIFTSURE_TEST_NEW;
    delete process.env.SHIFTSURE_TEST_KEEP;
    rmSync(dir, { recursive: true, force: true });
  }
});

test('default env file path is backend/.env, independent of cwd', () => {
  assert.match(ENV_FILE_PATH.replaceAll('\\', '/'), /\/backend\/\.env$/);
});
