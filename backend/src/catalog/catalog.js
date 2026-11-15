import { PLATFORMS, normalizeText } from '../workers/validation.js';

/**
 * Backend-managed dark-store catalog (read-only).
 *
 * The backend alone decides which stores a rider may pick and which zone a
 * store resolves to. There is no default or fallback zone: `zone_id` only
 * ever comes from a store that passed `checkAssignment`.
 *
 * City matching: a worker's free-text `city` (PR #10) matches a catalog city
 * when both are equal after normalization (NFC, trimmed, whitespace
 * collapsed, case-folded). No aliases ("Bangalore") yet.
 */

/** Machine-readable reasons a store cannot be assigned. */
export const ASSIGNMENT_ERRORS = Object.freeze(['store_not_found', 'store_unavailable', 'store_mismatch']);

const cityKey = (name) => normalizeText(name).toLocaleLowerCase('en');

function indexById(items, kind, problems) {
  const map = new Map();
  for (const item of items) {
    if (typeof item?.id !== 'string' || item.id === '') problems.push(`${kind}: missing id`);
    else if (map.has(item.id)) problems.push(`${kind} ${item.id}: duplicate id`);
    else map.set(item.id, item);
  }
  return map;
}

/**
 * Check catalog integrity: unique ids; non-empty, unique city names; every
 * zone in a known city; every store in a known zone and city, in the same
 * city as its zone, on a supported platform, with a boolean `active`.
 * Returns a list of problems (empty when valid).
 */
export function catalogProblems({ cities = [], zones = [], stores = [] }) {
  const problems = [];
  const cityById = indexById(cities, 'city', problems);
  const zoneById = indexById(zones, 'zone', problems);
  indexById(stores, 'store', problems);

  const names = new Set();
  for (const city of cities) {
    if (typeof city?.name !== 'string' || normalizeText(city.name) === '') {
      problems.push(`city ${city?.id}: missing name`);
      continue;
    }
    const key = cityKey(city.name);
    if (names.has(key)) problems.push(`city ${city.id}: duplicate name`);
    names.add(key);
  }
  for (const zone of zones) {
    if (typeof zone?.name !== 'string' || zone.name === '') problems.push(`zone ${zone?.id}: missing name`);
    if (!cityById.has(zone?.city_id)) problems.push(`zone ${zone?.id}: unknown city ${zone?.city_id}`);
  }
  for (const store of stores) {
    const id = store?.id;
    if (typeof store?.name !== 'string' || store.name === '') problems.push(`store ${id}: missing name`);
    if (!PLATFORMS.includes(store?.platform) || store.platform === 'other') {
      problems.push(`store ${id}: unsupported platform ${store?.platform}`);
    }
    if (typeof store?.active !== 'boolean') problems.push(`store ${id}: active must be a boolean`);
    if (!cityById.has(store?.city_id)) problems.push(`store ${id}: unknown city ${store?.city_id}`);
    const zone = zoneById.get(store?.zone_id);
    if (!zone) problems.push(`store ${id}: unknown zone ${store?.zone_id}`);
    else if (zone.city_id !== store.city_id) problems.push(`store ${id}: zone ${zone.id} is in another city`);
  }
  return problems;
}

/** Build the catalog from `data`. Throws if the data fails integrity checks. */
export function createCatalog(data) {
  const problems = catalogProblems(data);
  if (problems.length > 0) throw new Error(`Invalid dark-store catalog:\n  ${problems.join('\n  ')}`);

  const cities = new Map(data.cities.map((c) => [c.id, c]));
  const cityIdByKey = new Map(data.cities.map((c) => [cityKey(c.name), c.id]));
  const zones = new Map(data.zones.map((z) => [z.id, z]));
  const stores = new Map(data.stores.map((s) => [s.id, s]));

  const cityIdOf = (name) => (typeof name === 'string' ? (cityIdByKey.get(cityKey(name)) ?? null) : null);
  const matches = (store, { platform, city }) => store.platform === platform && store.city_id === cityIdOf(city);

  const summary = (store) => {
    const zone = zones.get(store.zone_id);
    return { id: store.id, name: store.name, zone: { id: zone.id, name: zone.name } };
  };

  return {
    /** Active stores for a worker's `{ platform, city }`, as API summaries. */
    listStores(worker) {
      return [...stores.values()].filter((s) => s.active && matches(s, worker)).map(summary);
    },

    /** Display names of the cities with at least one active store on `platform`. */
    citiesFor(platform) {
      const ids = new Set([...stores.values()].filter((s) => s.active && s.platform === platform).map((s) => s.city_id));
      return [...ids].map((id) => cities.get(id).name);
    },

    /**
     * Validate that `storeId` exists, is active, and matches the worker's
     * platform and city. Returns `{ ok: true, dark_store_id, zone_id }` or
     * `{ ok: false, error }` with one of ASSIGNMENT_ERRORS.
     */
    checkAssignment(storeId, worker) {
      const store = stores.get(storeId);
      if (!store) return { ok: false, error: 'store_not_found' };
      if (!store.active) return { ok: false, error: 'store_unavailable' };
      if (!matches(store, worker)) return { ok: false, error: 'store_mismatch' };
      return { ok: true, dark_store_id: store.id, zone_id: store.zone_id };
    },

    /** Display summary of a stored assignment, or null if unknown or unset. */
    describe(storeId) {
      const store = typeof storeId === 'string' ? stores.get(storeId) : undefined;
      return store ? summary(store) : null;
    },
  };
}
