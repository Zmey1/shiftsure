import { getApp, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

const APP_NAME = 'shiftsure';

/**
 * Initialize Firebase Admin (once) with an explicit project id and return a
 * token verifier: (idToken) => Promise<DecodedIdToken>.
 *
 * No credentials are configured: verifying ID tokens only needs the project id.
 * If FIREBASE_AUTH_EMULATOR_HOST is set, the SDK verifies against the local
 * Auth emulator (config.js forbids that in production).
 */
export function createVerifyIdToken(config) {
  const app = getApps().some((a) => a.name === APP_NAME)
    ? getApp(APP_NAME)
    : initializeApp({ projectId: config.firebaseProjectId }, APP_NAME);
  const auth = getAuth(app);
  return (idToken) => auth.verifyIdToken(idToken);
}
