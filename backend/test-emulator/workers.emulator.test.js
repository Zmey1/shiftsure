// Run via `npm run test:emulator` (Auth + Firestore emulators started by
// firebase emulators:exec). Exercises the real Admin SDK paths that the
// hermetic tests fake: Firestore create/update semantics, server timestamps,
// custom-claim assignment, ID-token refresh picking up the new claim, and
// transactional dark-store assignment (including concurrent edits).
import { test, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';
import { createCatalog } from '../src/catalog/catalog.js';
import { DEMO_CATALOG } from '../src/catalog/demo-catalog.js';
import { loadConfig } from '../src/config.js';
import { createFirebaseServices } from '../src/firebase.js';
import {
  ProfileExistsError,
  ProfileNotFoundError,
  WORKERS_COLLECTION,
  createWorkerRepository,
} from '../src/workers/repository.js';

const PROJECT_ID = 'demo-shiftsure';
const { FIRESTORE_EMULATOR_HOST, FIREBASE_AUTH_EMULATOR_HOST } = process.env;
const API_KEY = 'fake-api-key'; // the Auth emulator accepts any key

let services;
let repo;
let catalog;
let server;
let baseUrl;

before(async () => {
  assert.ok(FIRESTORE_EMULATOR_HOST, 'FIRESTORE_EMULATOR_HOST not set; run via `npm run test:emulator`');
  assert.ok(FIREBASE_AUTH_EMULATOR_HOST, 'FIREBASE_AUTH_EMULATOR_HOST not set; run via `npm run test:emulator`');
  const config = loadConfig({ NODE_ENV: 'test', FIREBASE_PROJECT_ID: PROJECT_ID });
  assert.match(config.firebaseProjectId, /^demo-/, 'emulator tests must only use a demo project');

  services = createFirebaseServices(config);
  repo = createWorkerRepository(services.db);
  catalog = createCatalog(DEMO_CATALOG);
  const app = createApp(config, { verifyIdToken: services.verifyIdToken, auth: services.auth, workers: repo, catalog });
  await new Promise((resolve) => {
    server = app.listen(0, '127.0.0.1', resolve);
  });
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(() => new Promise((resolve) => server?.close(resolve)));

beforeEach(async () => {
  await fetch(`http://${FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`, {
    method: 'DELETE',
  });
  await fetch(`http://${FIREBASE_AUTH_EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/accounts`, {
    method: 'DELETE',
  });
});

const valid = { name: 'Rahul Kumar', phone: '9876543210', city: 'Bengaluru', platform: 'zepto' };

async function emulatorAuth(path, body) {
  const res = await fetch(`http://${FIREBASE_AUTH_EMULATOR_HOST}/${path}?key=${API_KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  assert.equal(res.ok, true, `${path}: ${res.status}`);
  return res.json();
}

/** Register like the app does (email/password) and return its tokens. */
async function signUp(email) {
  const r = await emulatorAuth('identitytoolkit.googleapis.com/v1/accounts:signUp', {
    email,
    password: 'secret1',
    returnSecureToken: true,
  });
  return { uid: r.localId, idToken: r.idToken, refreshToken: r.refreshToken };
}

/** Equivalent of the client's getIdToken(forceRefresh: true). */
async function refresh(refreshToken) {
  const r = await emulatorAuth('securetoken.googleapis.com/v1/token', {
    grant_type: 'refresh_token',
    refresh_token: refreshToken,
  });
  return r.id_token;
}

async function call(method, idToken, body, path = '/api/workers/me') {
  const res = await fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${idToken}`,
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { status: res.status, body: await res.json() };
}

test('repository: create, duplicate, update, and server timestamps', async () => {
  assert.equal(await repo.get('w1'), null);
  const created = await repo.create('w1', valid);
  assert.equal(created.uid, 'w1');
  assert.equal(created.name, valid.name);
  assert.match(created.created_at, /^\d{4}-\d\d-\d\dT/);
  assert.equal(created.created_at, created.updated_at);

  await assert.rejects(repo.create('w1', { ...valid, name: 'Other' }), ProfileExistsError);
  assert.equal((await repo.get('w1')).name, valid.name);

  const updated = await repo.update('w1', { city: 'Mumbai' });
  assert.equal(updated.city, 'Mumbai');
  assert.equal(updated.name, valid.name);
  assert.equal(updated.created_at, created.created_at);
  assert.ok(updated.updated_at >= created.updated_at);

  await assert.rejects(repo.update('missing', { city: 'Pune' }), ProfileNotFoundError);
  assert.equal((await services.db.collection(WORKERS_COLLECTION).doc('missing').get()).exists, false);

  const stored = (await services.db.collection(WORKERS_COLLECTION).doc('w1').get()).data();
  assert.deepEqual(Object.keys(stored).sort(), ['city', 'created_at', 'name', 'phone', 'platform', 'updated_at']);
});

test('onboarding end to end: rider claim is assigned and appears after token refresh', async () => {
  const { uid, idToken, refreshToken } = await signUp('rider@example.com');
  assert.equal((await services.verifyIdToken(idToken)).role, undefined);

  assert.equal((await call('GET', idToken)).status, 404);
  const created = await call('POST', idToken, valid);
  assert.equal(created.status, 201);
  assert.equal(created.body.token_refresh_required, true);
  assert.equal(created.body.profile.uid, uid);
  assert.deepEqual((await services.auth.getUser(uid)).customClaims, { role: 'rider' });

  // The old token still has no role, so rider-only routes refuse it...
  assert.equal((await call('PATCH', idToken, { city: 'Pune' })).status, 403);
  // ...until the client force-refreshes.
  const fresh = await refresh(refreshToken);
  assert.equal((await services.verifyIdToken(fresh)).role, 'rider');
  const patched = await call('PATCH', fresh, { city: 'Pune' });
  assert.equal(patched.status, 200);
  assert.equal(patched.body.profile.city, 'Pune');
  assert.deepEqual(await call('GET', fresh), {
    status: 200,
    body: { profile: patched.body.profile, token_refresh_required: false },
  });
});

test('existing claims are preserved and admins are never downgraded', async () => {
  const rider = await signUp('beta@example.com');
  await services.auth.setCustomUserClaims(rider.uid, { beta: true });
  assert.equal((await call('POST', rider.idToken, valid)).status, 201);
  assert.deepEqual((await services.auth.getUser(rider.uid)).customClaims, { beta: true, role: 'rider' });

  const admin = await signUp('admin@example.com');
  await services.auth.setCustomUserClaims(admin.uid, { role: 'admin' });
  // Even the stale pre-promotion token cannot create a worker profile.
  assert.equal((await call('POST', admin.idToken, valid)).status, 403);
  assert.equal((await call('POST', await refresh(admin.refreshToken), valid)).status, 403);
  assert.deepEqual((await services.auth.getUser(admin.uid)).customClaims, { role: 'admin' });
  assert.equal(await repo.get(admin.uid), null);
});

/** Sign up, create a profile, and return a token that carries the rider role. */
async function onboardedRider(email, profile = valid) {
  const { uid, idToken, refreshToken } = await signUp(email);
  assert.equal((await call('POST', idToken, profile)).status, 201);
  return { uid, token: await refresh(refreshToken) };
}

const storedKeys = async (uid) =>
  Object.keys((await services.db.collection(WORKERS_COLLECTION).doc(uid).get()).data()).sort();

test('dark store: assign through the API, then a city change clears it', async () => {
  const { uid, token } = await onboardedRider('store@example.com');
  const listed = await call('GET', token, undefined, '/api/dark-stores');
  assert.equal(listed.status, 200);
  assert.ok(listed.body.stores.some((s) => s.id === 'demo-ds-blr-zepto-1'));

  const assigned = await call('PUT', token, { dark_store_id: 'demo-ds-blr-zepto-1' }, '/api/workers/me/dark-store');
  assert.equal(assigned.status, 200);
  assert.equal(assigned.body.profile.zone_id, 'demo-zone-blr-1');
  assert.deepEqual(await storedKeys(uid), [
    'city', 'created_at', 'dark_store_id', 'name', 'phone', 'platform', 'updated_at', 'zone_id',
  ]);

  const mismatch = await call('PUT', token, { dark_store_id: 'demo-ds-mum-zepto-1' }, '/api/workers/me/dark-store');
  assert.deepEqual([mismatch.status, mismatch.body], [422, { error: 'store_mismatch' }]);
  assert.equal((await repo.get(uid)).dark_store_id, 'demo-ds-blr-zepto-1');

  const moved = await call('PATCH', token, { city: 'Mumbai' });
  assert.equal(moved.status, 200);
  assert.deepEqual([moved.body.profile.dark_store_id, moved.body.profile.zone_id], [null, null]);
  // Cleared means the fields are removed, not set to a fallback.
  assert.deepEqual(await storedKeys(uid), ['city', 'created_at', 'name', 'phone', 'platform', 'updated_at']);
});

test('dark store: concurrent profile edits and assignments never leave an incompatible store', async () => {
  const { uid, token } = await onboardedRider('race@example.com');
  const assign = (id) => call('PUT', token, { dark_store_id: id }, '/api/workers/me/dark-store');
  const cities = ['Mumbai', 'Bengaluru'];

  for (let round = 0; round < 10; round++) {
    // Assign a store valid for the *current* city while the city is changed
    // away from it (and, from round 5, also flip the platform) at the same time.
    const before = await repo.get(uid);
    const storeId = catalog.listStores(before)[0].id;
    const next = cities[(cities.indexOf(before.city) + 1) % 2];
    const edit = round < 5 ? { city: next } : { city: next, platform: round % 2 ? 'blinkit' : 'zepto' };
    const [put, patch] = await Promise.all([assign(storeId), call('PATCH', token, edit)]);

    assert.equal(patch.status, 200, `round ${round}`);
    assert.ok([200, 422].includes(put.status), `round ${round}: PUT ${put.status}`);

    const saved = await repo.get(uid);
    if (saved.dark_store_id !== null) {
      const check = catalog.checkAssignment(saved.dark_store_id, saved);
      assert.equal(check.ok, true, `round ${round}: incompatible ${saved.dark_store_id} for ${saved.platform}/${saved.city}`);
      assert.equal(saved.zone_id, check.zone_id, `round ${round}: zone does not match store`);
    } else {
      assert.equal(saved.zone_id, null, `round ${round}: zone without store`);
    }
  }
});
