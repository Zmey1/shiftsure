// Run via `npm run test:rules` (Firestore emulator started by firebase emulators:exec).
// Rules are NOT passed to initializeTestEnvironment: the emulator loads them from
// ../firebase.json, so these tests exercise the rules as actually configured.
import { test, before, after, afterEach, describe } from 'node:test';
import assert from 'node:assert/strict';
import { initializeTestEnvironment, assertFails } from '@firebase/rules-unit-testing';
import { doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc, addDoc } from 'firebase/firestore';

const PROJECT_ID = 'demo-shiftsure';
const SEEDED = 'items/seeded';
const NESTED = 'items/seeded/children/child';

let env;

before(async () => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'FIRESTORE_EMULATOR_HOST not set; run via `npm run test:rules`');
  assert.match(PROJECT_ID, /^demo-/, 'rules tests must only use an emulator demo project');
  env = await initializeTestEnvironment({ projectId: PROJECT_ID });
});

afterEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env?.cleanup();
});

async function seed() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), SEEDED), { v: 1 });
    await setDoc(doc(ctx.firestore(), NESTED), { v: 1 });
  });
}

const clients = {
  unauthenticated: () => env.unauthenticatedContext(),
  'rider (role claim)': () => env.authenticatedContext('rider-1', { role: 'rider' }),
  'admin (role claim)': () => env.authenticatedContext('admin-1', { role: 'admin' }),
};

test('control: seeded data exists and is visible with rules disabled', async () => {
  await seed();
  await env.withSecurityRulesDisabled(async (ctx) => {
    assert.equal((await getDoc(doc(ctx.firestore(), SEEDED))).exists(), true);
  });
});

for (const [name, makeContext] of Object.entries(clients)) {
  describe(`${name}: all client access denied`, () => {
    let db;
    before(async () => {
      db = makeContext().firestore();
    });

    test('get existing document', async () => {
      await seed();
      await assertFails(getDoc(doc(db, SEEDED)));
    });

    test('get missing document', async () => {
      await assertFails(getDoc(doc(db, 'items/missing')));
    });

    test('list collection', async () => {
      await seed();
      await assertFails(getDocs(collection(db, 'items')));
    });

    test('list nested subcollection', async () => {
      await seed();
      await assertFails(getDocs(collection(db, SEEDED, 'children')));
    });

    test('create with explicit id', async () => {
      await assertFails(setDoc(doc(db, 'items/new'), { v: 1 }));
    });

    test('create with auto id', async () => {
      await assertFails(addDoc(collection(db, 'items'), { v: 1 }));
    });

    test('update existing document', async () => {
      await seed();
      await assertFails(updateDoc(doc(db, SEEDED), { v: 2 }));
    });

    test('overwrite existing document', async () => {
      await seed();
      await assertFails(setDoc(doc(db, SEEDED), { v: 2 }));
    });

    test('delete existing document', async () => {
      await seed();
      await assertFails(deleteDoc(doc(db, SEEDED)));
    });

    test('write to nested path', async () => {
      await seed();
      await assertFails(setDoc(doc(db, NESTED), { v: 2 }));
    });

    test('data is unchanged after attempted writes', async () => {
      await seed();
      await assertFails(updateDoc(doc(db, SEEDED), { v: 2 }));
      await assertFails(deleteDoc(doc(db, SEEDED)));
      await env.withSecurityRulesDisabled(async (ctx) => {
        const snap = await getDoc(doc(ctx.firestore(), SEEDED));
        assert.deepEqual(snap.data(), { v: 1 });
      });
    });
  });
}
