import { FieldValue } from 'firebase-admin/firestore';
import { PROFILE_FIELDS } from './validation.js';

export const WORKERS_COLLECTION = 'workers';

/** Server-managed dark-store assignment fields. Absent means unassigned. */
export const ASSIGNMENT_FIELDS = Object.freeze(['dark_store_id', 'zone_id']);

// gRPC status code surfaced by the Firestore Admin SDK.
const ALREADY_EXISTS = 6;

export class ProfileExistsError extends Error {
  constructor() {
    super('worker profile already exists');
    this.name = 'ProfileExistsError';
  }
}

export class ProfileNotFoundError extends Error {
  constructor() {
    super('worker profile not found');
    this.name = 'ProfileNotFoundError';
  }
}

function isoOrNull(timestamp) {
  return typeof timestamp?.toDate === 'function' ? timestamp.toDate().toISOString() : null;
}

/** Map a worker document to the API shape. Only known fields are exposed. */
function toProfile(snap) {
  const data = snap.data();
  const profile = { uid: snap.id };
  for (const key of PROFILE_FIELDS) profile[key] = data[key] ?? null;
  for (const key of ASSIGNMENT_FIELDS) profile[key] = data[key] ?? null;
  profile.created_at = isoOrNull(data.created_at);
  profile.updated_at = isoOrNull(data.updated_at);
  return profile;
}

/**
 * Firestore-backed worker profiles at `workers/{uid}`.
 *
 * `fields` must already be validated (see validation.js). Timestamps are
 * always set here, server-side. `create` is atomic: it fails if the document
 * exists, so concurrent duplicate requests cannot both succeed.
 *
 * `update` and `assignDarkStore` run in Firestore transactions, so a store is
 * always validated against the platform and city it is stored with: a
 * concurrent profile edit and store assignment cannot leave an incompatible
 * `dark_store_id`/`zone_id` behind (Firestore retries the loser on the new
 * data).
 */
export function createWorkerRepository(db) {
  const ref = (uid) => db.collection(WORKERS_COLLECTION).doc(uid);

  return {
    async get(uid) {
      const snap = await ref(uid).get();
      return snap.exists ? toProfile(snap) : null;
    },

    async create(uid, fields) {
      try {
        await ref(uid).create({
          ...fields,
          created_at: FieldValue.serverTimestamp(),
          updated_at: FieldValue.serverTimestamp(),
        });
      } catch (err) {
        if (err?.code === ALREADY_EXISTS) throw new ProfileExistsError();
        throw err;
      }
      return toProfile(await ref(uid).get());
    },

    /**
     * Apply `fields`. If the worker has a dark store and
     * `assignmentStillValid(merged)` returns false for the updated profile,
     * the assignment (`dark_store_id`, `zone_id`) is removed in the same write.
     */
    async update(uid, fields, { assignmentStillValid } = {}) {
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref(uid));
        if (!snap.exists) throw new ProfileNotFoundError();
        const merged = { ...snap.data(), ...fields };
        const write = { ...fields, updated_at: FieldValue.serverTimestamp() };
        if (merged.dark_store_id != null && assignmentStillValid && !assignmentStillValid(merged)) {
          for (const key of ASSIGNMENT_FIELDS) write[key] = FieldValue.delete();
        }
        // update() never touches created_at.
        tx.update(ref(uid), write);
      });
      return toProfile(await ref(uid).get());
    },

    /**
     * Set the worker's dark store. `resolve(current)` receives the stored
     * profile data and returns `{ dark_store_id, zone_id }`, or throws to
     * abort without writing.
     */
    async assignDarkStore(uid, resolve) {
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref(uid));
        if (!snap.exists) throw new ProfileNotFoundError();
        const { dark_store_id, zone_id } = resolve(snap.data());
        tx.update(ref(uid), { dark_store_id, zone_id, updated_at: FieldValue.serverTimestamp() });
      });
      return toProfile(await ref(uid).get());
    },
  };
}
