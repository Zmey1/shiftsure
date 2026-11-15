/**
 * FICTIONAL DEMONSTRATION DATA. Not real dark stores, zones, or delivery
 * boundaries.
 *
 * Every store and zone below is made up for the prototype. The names only
 * mention a delivery platform so that platform filtering can be exercised;
 * they are not affiliated with, sourced from, or endorsed by any platform,
 * and they carry no addresses or coordinates. Do not replace them with
 * publicly sourced store locations without permission.
 *
 * Model: a dark store is a rider's (future) weekly insurance pool membership;
 * a zone is the geographic area used for exposure and disruption coverage.
 * Several stores can share one zone and still keep separate pools.
 * `createCatalog` (catalog.js) checks the integrity of this data at startup.
 */
export const DEMO_CATALOG = {
  cities: [
    { id: 'bengaluru', name: 'Bengaluru' },
    { id: 'mumbai', name: 'Mumbai' },
  ],
  zones: [
    { id: 'demo-zone-blr-1', name: 'Demo Zone BLR-1', city_id: 'bengaluru' },
    { id: 'demo-zone-blr-2', name: 'Demo Zone BLR-2', city_id: 'bengaluru' },
    { id: 'demo-zone-mum-1', name: 'Demo Zone MUM-1', city_id: 'mumbai' },
    { id: 'demo-zone-mum-2', name: 'Demo Zone MUM-2', city_id: 'mumbai' },
  ],
  stores: [
    // demo-zone-blr-1 is shared by two platforms' stores (separate pools, one zone).
    { id: 'demo-ds-blr-zepto-1', name: 'Demo Zepto Store BLR-1A', platform: 'zepto', city_id: 'bengaluru', zone_id: 'demo-zone-blr-1', active: true },
    { id: 'demo-ds-blr-blinkit-1', name: 'Demo Blinkit Store BLR-1B', platform: 'blinkit', city_id: 'bengaluru', zone_id: 'demo-zone-blr-1', active: true },
    { id: 'demo-ds-blr-zepto-2', name: 'Demo Zepto Store BLR-2A', platform: 'zepto', city_id: 'bengaluru', zone_id: 'demo-zone-blr-2', active: true },
    { id: 'demo-ds-blr-instamart-1', name: 'Demo Instamart Store BLR-2B', platform: 'swiggy_instamart', city_id: 'bengaluru', zone_id: 'demo-zone-blr-2', active: true },
    { id: 'demo-ds-mum-zepto-1', name: 'Demo Zepto Store MUM-1A', platform: 'zepto', city_id: 'mumbai', zone_id: 'demo-zone-mum-1', active: true },
    { id: 'demo-ds-mum-blinkit-1', name: 'Demo Blinkit Store MUM-1B', platform: 'blinkit', city_id: 'mumbai', zone_id: 'demo-zone-mum-1', active: true },
    { id: 'demo-ds-mum-instamart-1', name: 'Demo Instamart Store MUM-2A', platform: 'swiggy_instamart', city_id: 'mumbai', zone_id: 'demo-zone-mum-2', active: true },
    // Inactive: listed nowhere and cannot be assigned (exercises the availability check).
    { id: 'demo-ds-mum-zepto-2', name: 'Demo Zepto Store MUM-2B', platform: 'zepto', city_id: 'mumbai', zone_id: 'demo-zone-mum-2', active: false },
  ],
};
