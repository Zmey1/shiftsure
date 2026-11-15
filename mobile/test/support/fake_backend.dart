import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shiftsure_rider/api/api_client.dart';
import 'package:shiftsure_rider/app.dart';
import 'package:shiftsure_rider/config/app_config.dart';

import 'fake_auth_service.dart';

Map<String, dynamic> profileJson(
  String uid, {
  String name = 'Rahul Kumar',
  String phone = '9876543210',
  String city = 'Bengaluru',
  String platform = 'zepto',
  String? darkStoreId,
}) => {
  'uid': uid,
  'name': name,
  'phone': phone,
  'city': city,
  'platform': platform,
  'dark_store_id': darkStoreId,
  'zone_id': darkStoreId == null ? null : fakeStores[darkStoreId]!['zone_id'],
  'dark_store': darkStoreId == null ? null : storeSummary(darkStoreId),
  'created_at': '2026-01-01T00:00:00.000Z',
  'updated_at': '2026-01-01T00:00:00.000Z',
};

/// A tiny made-up catalog. Test values only; the app never hardcodes any.
const fakeStores = <String, Map<String, String>>{
  'st-a1': {
    'name': 'Test Store A1',
    'platform': 'zepto',
    'city': 'Bengaluru',
    'zone_id': 'zn-a',
    'zone_name': 'Test Zone A',
  },
  'st-a2': {
    'name': 'Test Store A2',
    'platform': 'zepto',
    'city': 'Bengaluru',
    'zone_id': 'zn-b',
    'zone_name': 'Test Zone B',
  },
  'st-c1': {
    'name': 'Test Store C1',
    'platform': 'zepto',
    'city': 'Chennai',
    'zone_id': 'zn-c',
    'zone_name': 'Test Zone C',
  },
  'st-k1': {
    'name': 'Test Store K1',
    'platform': 'blinkit',
    'city': 'Kochi',
    'zone_id': 'zn-k',
    'zone_name': 'Test Zone K',
  },
};

Map<String, dynamic> storeSummary(String id) => {
  'id': id,
  'name': fakeStores[id]!['name'],
  'zone': {
    'id': fakeStores[id]!['zone_id'],
    'name': fakeStores[id]!['zone_name'],
  },
};

bool _storeFits(String id, Map<String, dynamic> profile) {
  final s = fakeStores[id];
  return s != null &&
      s['platform'] == profile['platform'] &&
      s['city']!.toLowerCase() == (profile['city'] as String).toLowerCase();
}

/// In-memory stand-in for the backend's `/health`, `/api/workers/me`,
/// `/api/workers/me/dark-store`, and `/api/dark-stores`.
/// The "verified uid" is the fake auth service's current user, like the real
/// backend deriving it from the ID token.
class FakeBackend {
  FakeBackend(this.auth, {Map<String, Map<String, dynamic>>? profiles})
    : profiles = profiles ?? {};

  final FakeAuthService auth;

  /// uid -> stored profile JSON.
  final Map<String, Map<String, dynamic>> profiles;

  final requests = <http.Request>[];

  /// Value of `token_refresh_required` on successful GETs.
  bool refreshRequiredOnGet = false;

  /// When true, PATCH returns 403 until the client has force-refreshed its
  /// token (simulates a token minted before the rider role was assigned).
  bool patchNeedsRefresh = false;

  /// Return a response to short-circuit normal handling (failures, delays).
  Future<http.Response?> Function(http.Request request)? intercept;

  late final client = MockClient(_handle);

  ApiClient api() => ApiClient(
    baseUrl: Uri.parse('http://localhost:3000'),
    tokenProvider: auth.getIdToken,
    client: client,
  );

  Iterable<http.Request> calls(
    String method, [
    String path = '/api/workers/me',
  ]) => requests.where((r) => r.method == method && r.url.path == path);

  static http.Response _json(int status, Object body) =>
      http.Response(jsonEncode(body), status);

  Future<http.Response> _handle(http.Request req) async {
    requests.add(req);
    final intercepted = await intercept?.call(req);
    if (intercepted != null) return intercepted;

    if (req.url.path == '/health') return _json(200, {'status': 'ok'});
    final uid = auth.currentUser?.uid;
    if (uid == null) return _json(401, {'error': 'unauthenticated'});
    final existing = profiles[uid];

    if (req.url.path == '/api/dark-stores' && req.method == 'GET') {
      if (existing == null) return _json(404, {'error': 'profile_not_found'});
      final platform = existing['platform'];
      return _json(200, {
        'demo': true,
        'platform': platform,
        'city': existing['city'],
        'stores': [
          for (final id in fakeStores.keys)
            if (_storeFits(id, existing)) storeSummary(id),
        ],
        'available_cities': {
          for (final s in fakeStores.values)
            if (s['platform'] == platform) s['city'],
        }.toList(),
      });
    }
    if (req.url.path == '/api/workers/me/dark-store' && req.method == 'PUT') {
      if (existing == null) return _json(404, {'error': 'profile_not_found'});
      final id =
          (jsonDecode(req.body) as Map<String, dynamic>)['dark_store_id'];
      if (!fakeStores.containsKey(id)) {
        return _json(422, {'error': 'store_not_found'});
      }
      if (!_storeFits(id as String, existing)) {
        return _json(422, {'error': 'store_mismatch'});
      }
      profiles[uid] = {
        ...existing,
        'dark_store_id': id,
        'zone_id': fakeStores[id]!['zone_id'],
        'dark_store': storeSummary(id),
      };
      return _json(200, {'profile': profiles[uid]});
    }
    if (req.url.path != '/api/workers/me') {
      return _json(404, {'error': 'not_found'});
    }

    switch (req.method) {
      case 'GET':
        if (existing == null) return _json(404, {'error': 'profile_not_found'});
        return _json(200, {
          'profile': existing,
          'token_refresh_required': refreshRequiredOnGet,
        });
      case 'POST':
        if (existing != null) return _json(409, {'error': 'profile_exists'});
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        profiles[uid] = {...profileJson(uid), ...body};
        return _json(201, {
          'profile': profiles[uid],
          'token_refresh_required': true,
        });
      case 'PATCH':
        if (patchNeedsRefresh && auth.refreshes == 0) {
          return _json(403, {'error': 'forbidden'});
        }
        if (existing == null) return _json(404, {'error': 'profile_not_found'});
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        final merged = {...existing, ...body};
        // Like the backend: a platform/city change re-validates the store.
        final storeId = merged['dark_store_id'];
        if (storeId is String && !_storeFits(storeId, merged)) {
          merged
            ..['dark_store_id'] = null
            ..['zone_id'] = null
            ..['dark_store'] = null;
        }
        profiles[uid] = merged;
        return _json(200, {'profile': profiles[uid]});
    }
    return _json(404, {'error': 'not_found'});
  }
}

/// Pumps the whole app against [backend] and settles.
Future<void> pumpShiftSure(WidgetTester tester, FakeBackend backend) async {
  await tester.pumpWidget(
    ShiftSureApp(
      config: AppConfig.parse('http://localhost:3000'),
      auth: backend.auth,
      apiClient: backend.api(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester, Map<String, String> fields) async {
  for (final e in fields.entries) {
    await tester.enterText(find.byKey(Key(e.key)), e.value);
  }
}

Finder button(String label) => find.widgetWithText(FilledButton, label);

/// Completes when [completer] does; for holding a request in flight.
Future<http.Response?> held(Completer<void> completer) async {
  await completer.future;
  return null;
}
