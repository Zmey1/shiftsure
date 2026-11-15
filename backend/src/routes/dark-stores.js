import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.js';

/**
 * `GET /api/dark-stores`: the demo stores a rider may choose from.
 *
 * Filtered by the platform and city stored in the caller's own profile; the
 * request cannot choose them (query parameters are ignored), so the list is
 * exactly what `PUT /api/workers/me/dark-store` will accept.
 * `available_cities` names the catalog cities with stores on the rider's
 * platform, so the app can explain an empty list.
 *
 * deps: { verifyIdToken, workers (see workers/repository.js), catalog }
 */
export function darkStoresRouter({ verifyIdToken, workers, catalog }) {
  const router = Router();
  router.use(authenticate(verifyIdToken));

  router.get('/', requireRole('rider'), async (req, res) => {
    const profile = await workers.get(req.user.uid);
    if (!profile) return res.status(404).json({ error: 'profile_not_found' });

    return res.status(200).json({
      demo: true,
      platform: profile.platform,
      city: profile.city,
      stores: catalog.listStores(profile),
      available_cities: catalog.citiesFor(profile.platform),
    });
  });

  return router;
}
