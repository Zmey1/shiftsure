/**
 * Trusted rider-role onboarding.
 *
 * The only claim this code ever writes is `role: 'rider'`, and only for a
 * user whose Firebase user record has no role yet. Clients cannot influence
 * the value. Existing roles (notably 'admin') are never overwritten.
 */

export class RoleConflictError extends Error {
  constructor() {
    super('user already has a non-rider role');
    this.name = 'RoleConflictError';
  }
}

/**
 * Ensure `uid` has the rider role.
 *
 * Reads the *current* custom claims from the user record rather than trusting
 * the caller's ID token, which can be up to an hour stale. Existing non-role
 * claims are preserved because setCustomUserClaims replaces the whole object.
 *
 * Resolves to `{ assigned: true }` if the claim was just set (the client must
 * refresh its ID token to see it) or `{ assigned: false }` if the user was
 * already a rider. Throws RoleConflictError for any other existing role.
 *
 * Limitation: read-then-write is not atomic. No admin-assignment code exists
 * yet; when it is added it must not race with this.
 */
export async function ensureRiderRole(auth, uid) {
  const user = await auth.getUser(uid);
  const claims = user.customClaims ?? {};
  if (claims.role === 'rider') return { assigned: false };
  if (claims.role !== undefined) throw new RoleConflictError();
  await auth.setCustomUserClaims(uid, { ...claims, role: 'rider' });
  return { assigned: true };
}
