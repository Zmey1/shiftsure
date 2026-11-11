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
 * deps: { verifyIdToken, auth (Admin Auth: getUser, setCustomUserClaims),
 *         workers (see workers/repository.js) }
 */
export function workersRouter({ verifyIdToken, auth, workers }) {
  const router = Router();
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
    return res.status(200).json({ profile, token_refresh_required: role !== 'rider' });
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
    return res.status(201).json({ profile, token_refresh_required: role !== 'rider' });
  });

  router.patch('/me', requireRole('rider'), async (req, res) => {
    const input = validateProfileInput(req.body, { partial: true });
    if (!input.ok) return validationFailed(res, input.fields);

    try {
      const profile = await workers.update(req.user.uid, input.value);
      return res.status(200).json({ profile });
    } catch (err) {
      if (err instanceof ProfileNotFoundError) return res.status(404).json({ error: 'profile_not_found' });
      throw err;
    }
  });

  return router;
}
