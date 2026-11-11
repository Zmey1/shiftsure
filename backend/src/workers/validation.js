/**
 * Worker profile validation. The backend is authoritative; the rider app
 * mirrors these rules for UX only.
 *
 * Errors are reported per field as stable codes: 'required', 'invalid',
 * 'unknown_field'. Values are normalized (trimmed, whitespace collapsed,
 * phone reduced to 10 digits) before they are stored.
 */

/** Stored platform values. Display labels live in the client. */
export const PLATFORMS = Object.freeze(['zepto', 'blinkit', 'swiggy_instamart', 'other']);

/** The only fields a client may write. Everything else is server-managed. */
export const PROFILE_FIELDS = Object.freeze(['name', 'phone', 'city', 'platform']);

const NAME_PATTERN = /^[\p{L}\p{M}][\p{L}\p{M} .'-]*$/u;
const INDIAN_MOBILE = /^[6-9]\d{9}$/;

function normalizeText(value) {
  return value.normalize('NFC').trim().replace(/\s+/g, ' ');
}

function textField(min, max) {
  return (value) => {
    if (typeof value !== 'string') return { error: 'invalid' };
    const v = normalizeText(value);
    if (v === '') return { error: 'required' };
    const length = [...v].length;
    if (length < min || length > max || !NAME_PATTERN.test(v)) return { error: 'invalid' };
    return { value: v };
  };
}

function phone(value) {
  if (typeof value !== 'string') return { error: 'invalid' };
  let v = value.trim().replace(/[\s-]/g, '');
  if (v === '') return { error: 'required' };
  if (v.startsWith('+91')) v = v.slice(3);
  if (!INDIAN_MOBILE.test(v)) return { error: 'invalid' };
  return { value: v };
}

function platform(value) {
  if (typeof value !== 'string') return { error: 'invalid' };
  if (value === '') return { error: 'required' };
  if (!PLATFORMS.includes(value)) return { error: 'invalid' };
  return { value };
}

const VALIDATORS = Object.freeze({
  name: textField(2, 80),
  phone,
  city: textField(2, 60),
  platform,
});

/**
 * Validate a create (`partial: false`, all fields required) or update
 * (`partial: true`, at least one field) request body.
 *
 * Returns `{ ok: true, value }` with only normalized profile fields, or
 * `{ ok: false, fields }` mapping field names to error codes. A body that is
 * not a plain JSON object, or an empty update, yields `fields: { _body: ... }`.
 */
export function validateProfileInput(body, { partial }) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    return { ok: false, fields: { _body: 'invalid' } };
  }

  const fields = {};
  const value = {};

  for (const key of Object.keys(body)) {
    if (!PROFILE_FIELDS.includes(key)) fields[key] = 'unknown_field';
  }

  for (const key of PROFILE_FIELDS) {
    if (!Object.hasOwn(body, key)) {
      if (!partial) fields[key] = 'required';
      continue;
    }
    const result = VALIDATORS[key](body[key]);
    if (result.error) fields[key] = result.error;
    else value[key] = result.value;
  }

  if (partial && Object.keys(body).length === 0) fields._body = 'empty';

  return Object.keys(fields).length > 0 ? { ok: false, fields } : { ok: true, value };
}
