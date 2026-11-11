import { test } from 'node:test';
import assert from 'node:assert/strict';
import { PLATFORMS, validateProfileInput } from '../src/workers/validation.js';

const valid = { name: 'Rahul Kumar', phone: '9876543210', city: 'Bengaluru', platform: 'zepto' };
const create = (body) => validateProfileInput(body, { partial: false });
const update = (body) => validateProfileInput(body, { partial: true });

test('accepts a valid profile and returns only normalized profile fields', () => {
  assert.deepEqual(create(valid), { ok: true, value: valid });
  const r = create({ name: '  Rahul   Kumar ', phone: '+91 98765-43210', city: ' New  Delhi ', platform: 'blinkit' });
  assert.deepEqual(r, {
    ok: true,
    value: { name: 'Rahul Kumar', phone: '9876543210', city: 'New Delhi', platform: 'blinkit' },
  });
});

test('supported platforms are exactly the stored values', () => {
  assert.deepEqual(PLATFORMS, ['zepto', 'blinkit', 'swiggy_instamart', 'other']);
  for (const platform of PLATFORMS) assert.equal(create({ ...valid, platform }).ok, true, platform);
  for (const platform of ['Zepto', 'swiggy', 'Swiggy Instamart', 'uber', 1, null]) {
    assert.deepEqual(create({ ...valid, platform }).fields, { platform: 'invalid' }, String(platform));
  }
});

test('create requires every field', () => {
  assert.deepEqual(create({}).fields, {
    name: 'required',
    phone: 'required',
    city: 'required',
    platform: 'required',
  });
  assert.deepEqual(create({ ...valid, name: '   ' }).fields, { name: 'required' });
});

test('name and city accept letters (including non-Latin) and . \' - only', () => {
  for (const name of ['Ravi', "D'Souza", 'Anne-Marie J.', 'रवि कुमार', 'Ló']) {
    assert.equal(create({ ...valid, name }).ok, true, name);
  }
  for (const name of ['R', 'x'.repeat(81), 'Rahul1', '<script>', '-Rahul', 'a@b', 42]) {
    assert.deepEqual(create({ ...valid, name }).fields, { name: 'invalid' }, String(name));
  }
  assert.equal(create({ ...valid, city: 'x'.repeat(60) }).ok, true);
  for (const city of ['B', 'x'.repeat(61), 'Pune 411001', {}]) {
    assert.deepEqual(create({ ...valid, city }).fields, { city: 'invalid' }, String(city));
  }
});

test('phone must be a 10-digit Indian mobile number, optionally +91-prefixed', () => {
  for (const phone of ['6000000000', '+919876543210', '98765 43210']) {
    assert.equal(create({ ...valid, phone }).ok, true, phone);
  }
  for (const phone of ['5876543210', '987654321', '98765432101', '919876543210', '+1 9876543210', 'abcdefghij', 9876543210]) {
    assert.deepEqual(create({ ...valid, phone }).fields, { phone: 'invalid' }, String(phone));
  }
});

test('unknown, server-managed, and future assignment fields are rejected', () => {
  for (const key of ['uid', 'role', 'created_at', 'updated_at', 'dark_store_id', 'zone_id', 'email']) {
    const r = create({ ...valid, [key]: 'x' });
    assert.equal(r.ok, false, key);
    assert.deepEqual(r.fields, { [key]: 'unknown_field' }, key);
  }
});

test('non-object bodies are rejected', () => {
  for (const body of [undefined, null, 'x', 1, [valid]]) {
    assert.deepEqual(create(body), { ok: false, fields: { _body: 'invalid' } }, String(body));
  }
});

test('update accepts a subset but not an empty body', () => {
  assert.deepEqual(update({ city: 'Mumbai' }), { ok: true, value: { city: 'Mumbai' } });
  assert.deepEqual(update({}).fields, { _body: 'empty' });
  assert.deepEqual(update({ phone: '123' }).fields, { phone: 'invalid' });
  assert.deepEqual(update({ created_at: 'x' }).fields, { created_at: 'unknown_field' });
});
