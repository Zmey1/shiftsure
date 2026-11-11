import { FieldValue } from 'firebase-admin/firestore';
import { PROFILE_FIELDS } from './validation.js';

export const WORKERS_COLLECTION = 'workers';

// gRPC status codes surfaced by the Firestore Admin SDK.
const ALREADY_EXISTS = 6;
const NOT_FOUND = 5;

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

    async update(uid, fields) {
      try {
        // update() fails if the document is missing and never touches created_at.
        await ref(uid).update({ ...fields, updated_at: FieldValue.serverTimestamp() });
      } catch (err) {
        if (err?.code === NOT_FOUND) throw new ProfileNotFoundError();
        throw err;
      }
      return toProfile(await ref(uid).get());
    },
  };
}
