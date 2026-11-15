import express, { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';
import { ProfileExistsError, ProfileNotFoundError } from '../workers/repository.js';
import { RoleConflictError, ensureRiderRole } from '../workers/roles.js';
import { validateProfileInput } from '../workers/validation.js';

const forbidden = (res) => res.status(403).json({ error: 'forbidden' });

/**
 * Workers who are onboarding (no role yet) or riders. Admin accounts are not
 * worker accounts and are refused.
 */
function workerOrOnboarding(req, res, next) {
  if (req.user.role === null || req.user.role === 'rider') return next();
  return forbidden(res);
}

function validationFailed(res, fields) {
  return res.status(400).json({ error: 'validation_failed', fields });
}

class StoreAssignmentError extends Error {
  constructor(code) {
    super(code);
    this.name = 'StoreAssignmentError';
    this.code = code;
  }
}

/** Body of `PUT /me/dark-store`: exactly `{ dark_store_id: <non-empty string> }`. */
function validateStoreChoice(body) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    return { ok: false, fields: { _body: 'invalid' } };
  }
  const fields = {};
  for (const key of Object.keys(body)) {
    if (key !== 'dark_store_id') fields[key] = 'unknown_field';
  }
  const id = body.dark_store_id;
  if (!Object.hasOwn(body, 'dark_store_id') || id === '') fields.dark_store_id = 'required';
  else if (typeof id !== 'string' || id.length > 100) fields.dark_store_id = 'invalid';
  return Object.keys(fields).length > 0 ? { ok: false, fields } : { ok: true, value: id };
}

/**
 * The authenticated worker's own profile. There is deliberately no `:uid`
 * route: the profile is always `workers/{verified uid}`, so no request can
 * address another worker's document.
 *
 * `token_refresh_required` is true when the caller's ID token does not yet
 * carry the rider role (it was just assigned, or onboarding was interrupted
 * before the app refreshed its token). The client should then force-refresh
 * its ID token.
 *
 * Dark-store assignment: `PUT /me/dark-store` validates the chosen store
 * against the *stored* platform and city (never request data) and resolves
 * `zone_id` from it, inside a transaction. A `PATCH` that changes platform or
 * city re-validates an existing assignment and clears it if it no longer
 * fits. Profile responses add a display-only `dark_store` summary.
 *
 * deps: { verifyIdToken, auth (Admin Auth: getUser, setCustomUserClaims),
 *         workers (see workers/repository.js), catalog (see catalog/catalog.js) }
 */
export function workersRouter({ verifyIdToken, auth, workers, catalog }) {
  const router = Router();
  const withStore = (profile) => ({ ...profile, dark_store: catalog.describe(profile.dark_store_id) });

  router.use(authenticate(verifyIdToken));
  router.use(express.json({ limit: '10kb' }));

  router.get('/me', workerOrOnboarding, async (req, res) => {
    const { uid, role } = req.user;
    const profile = await workers.get(uid);
    if (!profile) return res.status(404).json({ error: 'profile_not_found' });

    if (role !== 'rider') {
      // Recovery: a profile exists but the token has no role. Make sure the
      // claim is set (idempotent) and tell the client to refresh.
      try {
        await ensureRiderRole(auth, uid);
      } catch (err) {
        if (err instanceof RoleConflictError) return forbidden(res);
        throw err;
      }
    }
    return res.status(200).json({ profile: withStore(profile), token_refresh_required: role !== 'rider' });
  });

  router.post('/me', workerOrOnboarding, async (req, res) => {
    const { uid, role } = req.user;
    const input = validateProfileInput(req.body, { partial: false });
    if (!input.ok) return validationFailed(res, input.fields);

    // Claim first, then profile: if the profile write fails the claim is
    // already in place and a retry of this request completes onboarding.
    try {
      await ensureRiderRole(auth, uid);
    } catch (err) {
      if (err instanceof RoleConflictError) return forbidden(res);
      throw err;
    }

    let profile;
    try {
      profile = await workers.create(uid, input.value);
    } catch (err) {
      if (err instanceof ProfileExistsError) return res.status(409).json({ error: 'profile_exists' });
      throw err;
    }
    return res.status(201).json({ profile: withStore(profile), token_refresh_required: role !== 'rider' });
  });

  router.patch('/me', requireRole('rider'), async (req, res) => {
    const input = validateProfileInput(req.body, { partial: true });
    if (!input.ok) return validationFailed(res, input.fields);

    // Only a platform or city change can invalidate the assignment; checking
    // only then keeps a store that was later deactivated from being dropped by
    // an unrelated edit (e.g. a name change).
    const affectsStore = 'platform' in input.value || 'city' in input.value;
    const assignmentStillValid = affectsStore
      ? (merged) => catalog.checkAssignment(merged.dark_store_id, merged).ok
      : undefined;

    try {
      const profile = await workers.update(req.user.uid, input.value, { assignmentStillValid });
      return res.status(200).json({ profile: withStore(profile) });
    } catch (err) {
      if (err instanceof ProfileNotFoundError) return res.status(404).json({ error: 'profile_not_found' });
      throw err;
    }
  });

  router.put('/me/dark-store', requireRole('rider'), async (req, res) => {
    const input = validateStoreChoice(req.body);
    if (!input.ok) return validationFailed(res, input.fields);

    try {
      const profile = await workers.assignDarkStore(req.user.uid, (current) => {
        const result = catalog.checkAssignment(input.value, current);
        if (!result.ok) throw new StoreAssignmentError(result.error);
        return { dark_store_id: result.dark_store_id, zone_id: result.zone_id };
      });
      return res.status(200).json({ profile: withStore(profile) });
    } catch (err) {
      if (err instanceof ProfileNotFoundError) return res.status(404).json({ error: 'profile_not_found' });
      if (err instanceof StoreAssignmentError) return res.status(422).json({ error: err.code });
      throw err;
    }
  });

  return router;
}
