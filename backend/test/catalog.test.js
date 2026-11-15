import { test } from 'node:test';
import assert from 'node:assert/strict';
import { catalogProblems, createCatalog } from '../src/catalog/catalog.js';
import { DEMO_CATALOG } from '../src/catalog/demo-catalog.js';

const catalog = createCatalog(DEMO_CATALOG);

const base = () => ({
  cities: [
    { id: 'c1', name: 'Alpha City' },
    { id: 'c2', name: 'Beta City' },
  ],
  zones: [
    { id: 'z1', name: 'Zone 1', city_id: 'c1' },
    { id: 'z2', name: 'Zone 2', city_id: 'c2' },
  ],
  stores: [{ id: 's1', name: 'Store 1', platform: 'zepto', city_id: 'c1', zone_id: 'z1', active: true }],
});

test('the demo catalog passes integrity checks', () => {
  assert.deepEqual(catalogProblems(DEMO_CATALOG), []);
});

test('the demo catalog is labelled as demonstration data', () => {
  for (const item of [...DEMO_CATALOG.zones, ...DEMO_CATALOG.stores]) {
    assert.match(item.id, /^demo-/);
    assert.match(item.name, /^Demo /);
  }
});

test('integrity checks reject inconsistent data', () => {
  const cases = [
    [(d) => d.cities.push({ id: 'c1', name: 'Gamma' }), /city c1: duplicate id/],
    [(d) => d.cities.push({ id: 'c3', name: ' alpha  CITY ' }), /city c3: duplicate name/],
    [(d) => d.cities.push({ id: 'c3', name: '  ' }), /city c3: missing name/],
    [(d) => d.zones.push({ id: 'z1', name: 'Dup', city_id: 'c1' }), /zone z1: duplicate id/],
    [(d) => d.zones.push({ id: 'z3', name: 'Z3', city_id: 'nowhere' }), /zone z3: unknown city nowhere/],
    [(d) => d.stores.push({ ...d.stores[0] }), /store s1: duplicate id/],
    [(d) => (d.stores[0].zone_id = 'z9'), /store s1: unknown zone z9/],
    [(d) => (d.stores[0].city_id = 'c9'), /store s1: unknown city c9/],
    [(d) => (d.stores[0].zone_id = 'z2'), /store s1: zone z2 is in another city/],
    [(d) => (d.stores[0].platform = 'uber'), /store s1: unsupported platform uber/],
    [(d) => (d.stores[0].platform = 'other'), /store s1: unsupported platform other/],
    [(d) => delete d.stores[0].active, /store s1: active must be a boolean/],
    [(d) => (d.stores[0].name = ''), /store s1: missing name/],
    [(d) => d.stores.push({ name: 'No id' }), /store: missing id/],
  ];
  for (const [mutate, expected] of cases) {
    const data = base();
    mutate(data);
    assert.throws(() => createCatalog(data), expected, String(expected));
  }
  assert.doesNotThrow(() => createCatalog(base()));
});

test('listStores filters by platform and normalized city, active stores only', () => {
  const blr = catalog.listStores({ platform: 'zepto', city: 'Bengaluru' });
  assert.deepEqual(
    blr.map((s) => s.id),
    ['demo-ds-blr-zepto-1', 'demo-ds-blr-zepto-2'],
  );
  assert.deepEqual(blr[0], {
    id: 'demo-ds-blr-zepto-1',
    name: 'Demo Zepto Store BLR-1A',
    zone: { id: 'demo-zone-blr-1', name: 'Demo Zone BLR-1' },
  });
  assert.deepEqual(catalog.listStores({ platform: 'zepto', city: '  bengaluru ' }), blr);
  // MUM-2B is inactive.
  assert.deepEqual(
    catalog.listStores({ platform: 'zepto', city: 'Mumbai' }).map((s) => s.id),
    ['demo-ds-mum-zepto-1'],
  );
  assert.deepEqual(catalog.listStores({ platform: 'zepto', city: 'Pune' }), []);
  assert.deepEqual(catalog.listStores({ platform: 'other', city: 'Bengaluru' }), []);
  assert.deepEqual(catalog.listStores({ platform: 'zepto', city: null }), []);
});

test('citiesFor lists catalog cities with active stores on a platform', () => {
  assert.deepEqual(catalog.citiesFor('zepto'), ['Bengaluru', 'Mumbai']);
  assert.deepEqual(catalog.citiesFor('other'), []);
  const data = base();
  data.stores.push({ id: 's2', name: 'Store 2', platform: 'blinkit', city_id: 'c2', zone_id: 'z2', active: false });
  assert.deepEqual(createCatalog(data).citiesFor('blinkit'), []);
});

test('checkAssignment validates existence, availability, and platform/city compatibility', () => {
  const rider = { platform: 'zepto', city: 'Bengaluru' };
  assert.deepEqual(catalog.checkAssignment('demo-ds-blr-zepto-1', rider), {
    ok: true,
    dark_store_id: 'demo-ds-blr-zepto-1',
    zone_id: 'demo-zone-blr-1',
  });
  assert.deepEqual(catalog.checkAssignment('nope', rider), { ok: false, error: 'store_not_found' });
  assert.deepEqual(catalog.checkAssignment('__proto__', rider), { ok: false, error: 'store_not_found' });
  assert.deepEqual(catalog.checkAssignment(undefined, rider), { ok: false, error: 'store_not_found' });
  assert.deepEqual(catalog.checkAssignment('demo-ds-mum-zepto-2', { platform: 'zepto', city: 'Mumbai' }), {
    ok: false,
    error: 'store_unavailable',
  });
  assert.deepEqual(catalog.checkAssignment('demo-ds-blr-blinkit-1', rider), { ok: false, error: 'store_mismatch' });
  assert.deepEqual(catalog.checkAssignment('demo-ds-mum-zepto-1', rider), { ok: false, error: 'store_mismatch' });
});

test('stores on different platforms can share a zone', () => {
  const zepto = catalog.checkAssignment('demo-ds-blr-zepto-1', { platform: 'zepto', city: 'Bengaluru' });
  const blinkit = catalog.checkAssignment('demo-ds-blr-blinkit-1', { platform: 'blinkit', city: 'Bengaluru' });
  assert.equal(zepto.zone_id, blinkit.zone_id);
  assert.notEqual(zepto.dark_store_id, blinkit.dark_store_id);
});

test('describe returns a display summary or null', () => {
  assert.equal(catalog.describe('demo-ds-mum-zepto-1').zone.name, 'Demo Zone MUM-1');
  assert.equal(catalog.describe(null), null);
  assert.equal(catalog.describe('gone'), null);
});
