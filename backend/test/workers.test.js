import { test, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import { ProfileExistsError, ProfileNotFoundError } from '../src/workers/repository.js';

// Hermetic: fake token verifier, fake Admin Auth, in-memory worker repository.
// Tokens carry the role claim as it was when the token was minted; the fake
// user records hold the *current* claims (like Firebase).

const tokens = {
  'new-a': { uid: 'a' }, // freshly registered: no role in token
  'rider-a': { uid: 'a', role: 'rider' },
  'new-b': { uid: 'b' },
  'rider-b': { uid: 'b', role: 'rider' },
  admin: { uid: 'adm', role: 'admin' },
  'stale-admin': { uid: 'adm' }, // promoted to admin after this token was minted
  'odd-role': { uid: 'odd' },
};

let users; // uid -> { customClaims }
let claimWrites;
let store; // uid -> profile
let failNextCreate;
let failGet;
let nowMs;

const fakeAuth = {
  async getUser(uid) {
    if (!users[uid]) throw new Error('user-not-found');
    return { uid, customClaims: users[uid].customClaims };
  },
  async setCustomUserClaims(uid, claims) {
    claimWrites.push({ uid, claims });
    users[uid].customClaims = claims;
  },
};

const iso = () => new Date((nowMs += 1000)).toISOString();

const fakeWorkers = {
  async get(uid) {
    if (failGet) throw new Error('firestore-secret-detail');
    return store[uid] ? { ...store[uid] } : null;
  },
  async create(uid, fields) {
    if (failNextCreate) {
      failNextCreate = false;
      throw new Error('firestore-secret-detail');
    }
    if (store[uid]) throw new ProfileExistsError();
    const t = iso();
    store[uid] = { uid, ...fields, created_at: t, updated_at: t };
    return { ...store[uid] };
  },
  async update(uid, fields) {
    if (!store[uid]) throw new ProfileNotFoundError();
    store[uid] = { ...store[uid], ...fields, updated_at: iso() };
    return { ...store[uid] };
  },
};

const verifyIdToken = async (token) => {
  if (!Object.hasOwn(tokens, token)) throw new Error('bad token');
  return tokens[token];
};

let server;
let baseUrl;
let logged;
const originalError = console.error;

before(async () => {
  const app = createApp(loadConfig({ NODE_ENV: 'test' }), { verifyIdToken, auth: fakeAuth, workers: fakeWorkers });
  await new Promise((resolve) => {
    server = app.listen(0, '127.0.0.1', resolve);
  });
  baseUrl = `http://127.0.0.1:${server.address().port}`;
  console.error = (...args) => logged.push(args);
});

after(() => {
  console.error = originalError;
  return new Promise((resolve) => server.close(resolve));
});

beforeEach(() => {
  users = {
    a: { customClaims: undefined },
    b: { customClaims: undefined },
    adm: { customClaims: { role: 'admin' } },
    odd: { customClaims: { role: 'superuser' } },
  };
  claimWrites = [];
  store = {};
  failNextCreate = false;
  failGet = false;
  nowMs = Date.UTC(2026, 0, 1);
  logged = [];
});

const valid = { name: 'Rahul Kumar', phone: '9876543210', city: 'Bengaluru', platform: 'zepto' };

async function call(method, path, { token, body, raw, headers = {} } = {}) {
  const h = { ...headers };
  if (token) h.Authorization = `Bearer ${token}`;
  let payload;
  if (raw !== undefined) {
    h['Content-Type'] = 'application/json';
    payload = raw;
  } else if (body !== undefined && method !== 'GET') {
    h['Content-Type'] = 'application/json';
    payload = JSON.stringify(body);
  }
  const res = await fetch(`${baseUrl}${path}`, { method, headers: h, body: payload });
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null, text };
}

const me = '/api/workers/me';

test('every method requires a valid token', async () => {
  for (const method of ['GET', 'POST', 'PATCH']) {
    for (const token of [undefined, 'bad-token']) {
      const res = await call(method, me, { token, body: valid });
      assert.equal(res.status, 401, `${method} ${token}`);
      assert.deepEqual(res.body, { error: 'unauthenticated' });
    }
  }
  assert.deepEqual(store, {});
  assert.deepEqual(claimWrites, []);
});

test('new user: GET 404, POST creates profile and assigns rider role, GET 200', async () => {
  assert.deepEqual((await call('GET', me, { token: 'new-a' })).body, { error: 'profile_not_found' });

  const created = await call('POST', me, { token: 'new-a', body: { ...valid, phone: '+91 98765 43210' } });
  assert.equal(created.status, 201);
  assert.equal(created.body.token_refresh_required, true);
  assert.deepEqual(created.body.profile, {
    uid: 'a',
    ...valid,
    created_at: '2026-01-01T00:00:01.000Z',
    updated_at: '2026-01-01T00:00:01.000Z',
  });
  assert.deepEqual(claimWrites, [{ uid: 'a', claims: { role: 'rider' } }]);
  assert.deepEqual(store.a, created.body.profile);

  const fetched = await call('GET', me, { token: 'rider-a' });
  assert.equal(fetched.status, 200);
  assert.deepEqual(fetched.body, { profile: created.body.profile, token_refresh_required: false });
});

test('role assignment preserves other existing custom claims', async () => {
  users.a.customClaims = { beta: true };
  assert.equal((await call('POST', me, { token: 'new-a', body: valid })).status, 201);
  assert.deepEqual(users.a.customClaims, { beta: true, role: 'rider' });
});

test('existing rider creating a profile does not rewrite claims', async () => {
  users.a.customClaims = { role: 'rider' };
  const res = await call('POST', me, { token: 'rider-a', body: valid });
  assert.equal(res.status, 201);
  assert.equal(res.body.token_refresh_required, false);
  assert.deepEqual(claimWrites, []);
});

test('admins are refused and their claims are never changed', async () => {
  for (const token of ['admin', 'stale-admin']) {
    for (const method of ['GET', 'POST', 'PATCH']) {
      const res = await call(method, me, { token, body: valid });
      // A stale token (no role yet) reading a non-existent profile just sees 404.
      const expected = token === 'stale-admin' && method === 'GET' ? 404 : 403;
      assert.equal(res.status, expected, `${token} ${method}`);
    }
  }
  // Even with a stale token showing no role, a profile planted for the admin
  // does not trigger role "recovery".
  store.adm = { uid: 'adm', ...valid, created_at: iso(), updated_at: iso() };
  assert.equal((await call('GET', me, { token: 'stale-admin' })).status, 403);
  assert.deepEqual(users.adm.customClaims, { role: 'admin' });
  assert.deepEqual(claimWrites, []);
  assert.equal(store.adm.name, valid.name);
  assert.equal(Object.keys(store).length, 1);
});

test('a user with an unknown existing role is refused, not overwritten', async () => {
  const res = await call('POST', me, { token: 'odd-role', body: valid });
  assert.equal(res.status, 403);
  assert.deepEqual(users.odd.customClaims, { role: 'superuser' });
  assert.deepEqual(store, {});
});

test('client-supplied role, uid, or timestamps are rejected', async () => {
  for (const extra of [{ role: 'admin' }, { uid: 'b' }, { created_at: 'x' }, { dark_store_id: 'ds1' }, { zone_id: 'z1' }]) {
    const res = await call('POST', me, { token: 'new-a', body: { ...valid, ...extra } });
    assert.equal(res.status, 400, JSON.stringify(extra));
    assert.equal(res.body.error, 'validation_failed');
    assert.equal(res.body.fields[Object.keys(extra)[0]], 'unknown_field');
  }
  assert.deepEqual(store, {});
  assert.deepEqual(claimWrites, [], 'invalid requests must not assign a role');
});

test('POST validates the body', async () => {
  const res = await call('POST', me, { token: 'new-a', body: { ...valid, phone: '123', platform: 'uber' } });
  assert.equal(res.status, 400);
  assert.deepEqual(res.body, { error: 'validation_failed', fields: { phone: 'invalid', platform: 'invalid' } });

  assert.equal((await call('POST', me, { token: 'new-a' })).status, 400);
  assert.equal((await call('POST', me, { token: 'new-a', body: [valid] })).status, 400);
  const malformed = await call('POST', me, { token: 'new-a', raw: '{"name":' });
  assert.equal(malformed.status, 400);
  assert.deepEqual(malformed.body, { error: 'invalid_json' });
  const big = await call('POST', me, { token: 'new-a', body: { ...valid, name: 'a'.repeat(20_000) } });
  assert.equal(big.status, 413);
});

test('duplicate creation returns 409 and keeps the original', async () => {
  await call('POST', me, { token: 'new-a', body: valid });
  const res = await call('POST', me, { token: 'rider-a', body: { ...valid, name: 'Someone Else' } });
  assert.equal(res.status, 409);
  assert.deepEqual(res.body, { error: 'profile_exists' });
  assert.equal(store.a.name, valid.name);
});

test('interrupted onboarding: claim set but profile write failed, retry succeeds', async () => {
  failNextCreate = true;
  const first = await call('POST', me, { token: 'new-a', body: valid });
  assert.equal(first.status, 500);
  assert.deepEqual(first.body, { error: 'internal_error' });
  assert.ok(!first.text.includes('secret'));
  assert.deepEqual(users.a.customClaims, { role: 'rider' });
  assert.equal(store.a, undefined);

  // App restarts; profile is still missing, so it shows setup and retries
  // (its token may or may not have been refreshed yet).
  assert.equal((await call('GET', me, { token: 'new-a' })).status, 404);
  const retry = await call('POST', me, { token: 'new-a', body: valid });
  assert.equal(retry.status, 201);
  assert.equal(retry.body.token_refresh_required, true);
  assert.equal(claimWrites.length, 1, 'role is assigned only once');
});

test('interrupted onboarding: profile created but token never refreshed', async () => {
  await call('POST', me, { token: 'new-a', body: valid });
  // App was closed before refreshing: the old no-role token is still in use.
  const res = await call('GET', me, { token: 'new-a' });
  assert.equal(res.status, 200);
  assert.equal(res.body.token_refresh_required, true);
  assert.equal(res.body.profile.uid, 'a');
  // PATCH needs the rider claim in the token, so the client must refresh first.
  assert.equal((await call('PATCH', me, { token: 'new-a', body: { city: 'Mumbai' } })).status, 403);
  assert.equal((await call('PATCH', me, { token: 'rider-a', body: { city: 'Mumbai' } })).status, 200);
});

test('GET with a profile but a missing claim repairs the claim', async () => {
  store.a = { uid: 'a', ...valid, created_at: iso(), updated_at: iso() };
  const res = await call('GET', me, { token: 'new-a' });
  assert.equal(res.status, 200);
  assert.equal(res.body.token_refresh_required, true);
  assert.deepEqual(users.a.customClaims, { role: 'rider' });
});

test('PATCH updates only the given fields and preserves created_at', async () => {
  const created = (await call('POST', me, { token: 'new-a', body: valid })).body.profile;
  const res = await call('PATCH', me, { token: 'rider-a', body: { city: '  Navi  Mumbai ', platform: 'other' } });
  assert.equal(res.status, 200);
  assert.deepEqual(res.body.profile, {
    ...created,
    city: 'Navi Mumbai',
    platform: 'other',
    updated_at: '2026-01-01T00:00:02.000Z',
  });
  assert.equal(res.body.profile.created_at, created.created_at);
});

test('PATCH rejects immutable, unknown, invalid, and empty updates', async () => {
  await call('POST', me, { token: 'new-a', body: valid });
  const before = { ...store.a };
  for (const body of [{ created_at: '2020-01-01' }, { updated_at: 'x' }, { uid: 'b' }, { role: 'admin' }, { phone: '1' }, {}]) {
    const res = await call('PATCH', me, { token: 'rider-a', body });
    assert.equal(res.status, 400, JSON.stringify(body));
    assert.equal(res.body.error, 'validation_failed');
  }
  assert.deepEqual(store.a, before);
  assert.deepEqual(users.a.customClaims, { role: 'rider' });
});

test('PATCH without a profile returns 404', async () => {
  users.a.customClaims = { role: 'rider' };
  const res = await call('PATCH', me, { token: 'rider-a', body: { city: 'Pune' } });
  assert.equal(res.status, 404);
  assert.deepEqual(res.body, { error: 'profile_not_found' });
});

test("a worker cannot read or modify another worker's profile", async () => {
  await call('POST', me, { token: 'new-b', body: { ...valid, name: 'Bina Rao' } });
  const bBefore = { ...store.b };

  // No route addresses another uid.
  for (const method of ['GET', 'PATCH', 'POST']) {
    const res = await call(method, '/api/workers/b', { token: 'rider-a', body: { city: 'Pune' } });
    assert.equal(res.status, 404, method);
  }
  // Query strings, headers, and body cannot redirect to another uid.
  const got = await call('GET', `${me}?uid=b`, { token: 'new-a', headers: { 'X-User-Id': 'b' } });
  assert.equal(got.status, 404);
  const posted = await call('POST', `${me}?uid=b`, { token: 'new-a', body: valid, headers: { 'X-User-Id': 'b' } });
  assert.equal(posted.status, 201);
  assert.equal(posted.body.profile.uid, 'a');
  users.a.customClaims = { role: 'rider' };
  const patched = await call('PATCH', `${me}?uid=b`, { token: 'rider-a', body: { city: 'Pune' } });
  assert.equal(patched.body.profile.uid, 'a');

  assert.deepEqual(store.b, bBefore);
  assert.equal(store.a.city, 'Pune');
});

test('storage errors return a generic 500 without leaking details', async () => {
  failGet = true;
  const res = await call('GET', me, { token: 'rider-a' });
  assert.equal(res.status, 500);
  assert.deepEqual(res.body, { error: 'internal_error' });
  assert.ok(!res.text.includes('secret'));
  assert.equal(logged.length, 1);
});

test('health stays available without Firebase services', async () => {
  const res = await call('GET', '/health');
  assert.equal(res.status, 200);
});
