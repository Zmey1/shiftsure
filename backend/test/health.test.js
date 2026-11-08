import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';

let server;
let baseUrl;

before(async () => {
  const app = createApp(loadConfig({ NODE_ENV: 'test', SERVICE_NAME: 'test-service' }));
  await new Promise((resolve) => {
    server = app.listen(0, '127.0.0.1', resolve);
  });
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(() => new Promise((resolve) => server.close(resolve)));

test('GET /health returns 200 with JSON status', async () => {
  const res = await fetch(`${baseUrl}/health`);
  assert.equal(res.status, 200);
  assert.match(res.headers.get('content-type'), /application\/json/);
  const body = await res.json();
  assert.equal(body.status, 'ok');
  assert.equal(body.service, 'test-service');
  assert.equal(typeof body.uptimeSeconds, 'number');
});

test('does not expose x-powered-by', async () => {
  const res = await fetch(`${baseUrl}/health`);
  assert.equal(res.headers.get('x-powered-by'), null);
});

test('unknown routes return a JSON 404', async () => {
  const res = await fetch(`${baseUrl}/nope`);
  assert.equal(res.status, 404);
  assert.deepEqual(await res.json(), { error: 'not_found' });
});
