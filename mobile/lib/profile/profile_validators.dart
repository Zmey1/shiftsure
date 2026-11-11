// Client-side checks that mirror backend/src/workers/validation.js. They are
// for fast feedback only; the backend is authoritative.

final _namePattern = RegExp(r"^[\p{L}\p{M}][\p{L}\p{M} .'-]*$", unicode: true);
final _indianMobile = RegExp(r'^[6-9]\d{9}$');

/// Trims and collapses internal whitespace.
String normalizeText(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Strips spaces, hyphens and a leading +91. The result may still be invalid.
String normalizePhone(String value) {
  var v = value.trim().replaceAll(RegExp(r'[\s-]'), '');
  if (v.startsWith('+91')) v = v.substring(3);
  return v;
}

String? _text(String? value, String label, int max) {
  final v = normalizeText(value ?? '');
  if (v.isEmpty) return 'Enter your $label.';
  final length = v.runes.length;
  if (length < 2) return 'Use at least 2 characters.';
  if (length > max) return 'Use at most $max characters.';
  if (!_namePattern.hasMatch(v)) {
    return "Use letters, spaces, and . ' - only.";
  }
  return null;
}

String? validateName(String? value) => _text(value, 'name', 80);

String? validateCity(String? value) => _text(value, 'city', 60);

String? validatePhone(String? value) {
  final v = normalizePhone(value ?? '');
  if (v.isEmpty) return 'Enter your phone number.';
  if (!_indianMobile.hasMatch(v)) {
    return 'Enter a 10-digit Indian mobile number.';
  }
  return null;
}
