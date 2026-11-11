import { getApp, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const APP_NAME = 'shiftsure';

function adminApp(config) {
  return getApps().some((a) => a.name === APP_NAME)
    ? getApp(APP_NAME)
    : initializeApp({ projectId: config.firebaseProjectId }, APP_NAME);
}

/**
 * Initialize Firebase Admin (once) with an explicit project id and return a
 * token verifier: (idToken) => Promise<DecodedIdToken>.
 *
 * No credentials are configured: verifying ID tokens only needs the project id.
 * If FIREBASE_AUTH_EMULATOR_HOST is set, the SDK verifies against the local
 * Auth emulator (config.js forbids that in production).
 */
export function createVerifyIdToken(config) {
  const auth = getAuth(adminApp(config));
  return (idToken) => auth.verifyIdToken(idToken);
}

/**
 * Admin SDK services used by the API: { verifyIdToken, auth, db }.
 *
 * Firestore access and custom-claim writes need credentials: none against the
 * local emulators (FIRESTORE_EMULATOR_HOST / FIREBASE_AUTH_EMULATOR_HOST), and
 * Application Default Credentials against a real project. Nothing is
 * contacted until the first request.
 */
export function createFirebaseServices(config) {
  const app = adminApp(config);
  const auth = getAuth(app);
  return {
    verifyIdToken: (idToken) => auth.verifyIdToken(idToken),
    auth,
    db: getFirestore(app),
  };
}
