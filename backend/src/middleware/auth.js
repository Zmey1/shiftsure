export const ROLES = Object.freeze(['rider', 'admin']);

const BEARER = /^Bearer ([^\s]+)$/i;

function unauthenticated(res) {
  res.set('WWW-Authenticate', 'Bearer');
  return res.status(401).json({ error: 'unauthenticated' });
}

/**
 * Verify a Firebase ID token from `Authorization: Bearer <token>`.
 * Sets req.user = { uid, role }. `role` comes only from the verified token's
 * `role` custom claim and is null unless it is a known role.
 * Failure details are never sent to the client.
 */
export function authenticate(verifyIdToken) {
  return async (req, res, next) => {
    const match = BEARER.exec(req.headers.authorization ?? '');
    if (!match) return unauthenticated(res);

    let decoded;
    try {
      decoded = await verifyIdToken(match[1]);
    } catch {
      return unauthenticated(res);
    }

    const uid = decoded?.uid;
    if (typeof uid !== 'string' || uid === '') return unauthenticated(res);

    req.user = { uid, role: ROLES.includes(decoded.role) ? decoded.role : null };
    next();
  };
}

/** Allow only authenticated users whose verified role is one of `roles`. */
export function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user) return unauthenticated(res);
    if (!roles.includes(req.user.role)) return res.status(403).json({ error: 'forbidden' });
    next();
  };
}
