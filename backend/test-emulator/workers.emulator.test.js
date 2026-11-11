// Run via `npm run test:emulator` (Auth + Firestore emulators started by
// firebase emulators:exec). Exercises the real Admin SDK paths that the
// hermetic tests fake: Firestore create/update semantics, server timestamps,
// custom-claim assignment, and ID-token refresh picking up the new claim.
import { test, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';
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
let server;
let baseUrl;

before(async () => {
  assert.ok(FIRESTORE_EMULATOR_HOST, 'FIRESTORE_EMULATOR_HOST not set; run via `npm run test:emulator`');
  assert.ok(FIREBASE_AUTH_EMULATOR_HOST, 'FIREBASE_AUTH_EMULATOR_HOST not set; run via `npm run test:emulator`');
  const config = loadConfig({ NODE_ENV: 'test', FIREBASE_PROJECT_ID: PROJECT_ID });
  assert.match(config.firebaseProjectId, /^demo-/, 'emulator tests must only use a demo project');

  services = createFirebaseServices(config);
  repo = createWorkerRepository(services.db);
  const app = createApp(config, { verifyIdToken: services.verifyIdToken, auth: services.auth, workers: repo });
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

async function call(method, idToken, body) {
  const res = await fetch(`${baseUrl}/api/workers/me`, {
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
