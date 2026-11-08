import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import express from 'express';
import { authenticate, requireRole } from '../src/middleware/auth.js';

// Fake verifier: token "rider"/"admin"/"none"/"weird"/"nouid" map to claims; anything else is rejected.
const SECRET_DETAIL = 'secret-verifier-detail';
const tokens = {
  rider: { uid: 'u1', role: 'rider' },
  admin: { uid: 'u2', role: 'admin' },
  none: { uid: 'u3' },
  weird: { uid: 'u4', role: 'superuser' },
  nouid: { role: 'admin' },
  emptyuid: { uid: '', role: 'admin' },
  numuid: { uid: 5, role: 'admin' },
};
const verifyIdToken = async (token) => {
  if (!Object.hasOwn(tokens, token)) throw new Error(SECRET_DETAIL);
  return tokens[token];
};

let server;
let baseUrl;

before(async () => {
  const app = express();
  app.use(express.json());
  app.get('/me', authenticate(verifyIdToken), (req, res) => res.json(req.user));
  app.get('/rider', authenticate(verifyIdToken), requireRole('rider'), (_req, res) => res.json({ ok: true }));
  app.get('/admin', authenticate(verifyIdToken), requireRole('admin'), (_req, res) => res.json({ ok: true }));
  app.get('/either', authenticate(verifyIdToken), requireRole('rider', 'admin'), (_req, res) => res.json({ ok: true }));
  app.get('/unauthed-guard', requireRole('admin'), (_req, res) => res.json({ ok: true }));
  await new Promise((resolve) => {
    server = app.listen(0, '127.0.0.1', resolve);
  });
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(() => new Promise((resolve) => server.close(resolve)));

const get = (path, headers = {}) => fetch(`${baseUrl}${path}`, { headers });
const bearer = (token) => ({ Authorization: `Bearer ${token}` });

test('missing, malformed, or non-Bearer headers return 401', async () => {
  for (const header of [undefined, '', 'Bearer', 'Bearer ', 'Basic rider', 'rider', 'Bearer rider extra']) {
    const res = await get('/me', header === undefined ? {} : { Authorization: header });
    assert.equal(res.status, 401, String(header));
    assert.deepEqual(await res.json(), { error: 'unauthenticated' });
    assert.equal(res.headers.get('www-authenticate'), 'Bearer');
  }
});

test('invalid token returns 401 without leaking verifier details', async () => {
  const res = await get('/me', bearer('bad-token'));
  assert.equal(res.status, 401);
  const text = await res.text();
  assert.deepEqual(JSON.parse(text), { error: 'unauthenticated' });
  assert.ok(!text.includes(SECRET_DETAIL));
  assert.ok(!text.includes('bad-token'));
});

test('Bearer scheme is case-insensitive', async () => {
  const res = await get('/me', { Authorization: 'bearer rider' });
  assert.equal(res.status, 200);
});

test('valid token sets req.user from verified claims only', async () => {
  const res = await get('/me', bearer('admin'));
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { uid: 'u2', role: 'admin' });
});

test('decoded token without a nonempty string uid returns 401', async () => {
  for (const token of ['nouid', 'emptyuid', 'numuid']) {
    const res = await get('/me', bearer(token));
    assert.equal(res.status, 401, token);
  }
});

test('missing or unknown role claim yields role null and 403 on guarded routes', async () => {
  for (const token of ['none', 'weird']) {
    const me = await get('/me', bearer(token));
    assert.equal((await me.json()).role, null);
    const res = await get('/either', bearer(token));
    assert.equal(res.status, 403, token);
    assert.deepEqual(await res.json(), { error: 'forbidden' });
  }
});

test('requireRole enforces the exact role', async () => {
  assert.equal((await get('/rider', bearer('rider'))).status, 200);
  assert.equal((await get('/rider', bearer('admin'))).status, 403);
  assert.equal((await get('/admin', bearer('admin'))).status, 200);
  assert.equal((await get('/admin', bearer('rider'))).status, 403);
  assert.equal((await get('/either', bearer('rider'))).status, 200);
  assert.equal((await get('/either', bearer('admin'))).status, 200);
});

test('client-supplied role in headers, query, or body is ignored', async () => {
  const headers = { ...bearer('rider'), 'X-Role': 'admin', Role: 'admin', 'Content-Type': 'application/json' };
  assert.equal((await get('/admin?role=admin', headers)).status, 403);
  const res = await fetch(`${baseUrl}/admin`, {
    method: 'GET',
    headers,
  });
  assert.equal(res.status, 403);
  const me = await (await get('/me?role=admin&uid=u2', headers)).json();
  assert.deepEqual(me, { uid: 'u1', role: 'rider' });
});

test('requireRole without authenticate returns 401, not access', async () => {
  const res = await get('/unauthed-guard');
  assert.equal(res.status, 401);
});
