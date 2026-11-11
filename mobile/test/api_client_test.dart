import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shiftsure_rider/api/api_client.dart';
import 'package:shiftsure_rider/api/api_exception.dart';

ApiClient clientFor(
  Future<http.Response> Function(http.Request) handler, {
  String base = 'http://localhost:3000',
  TokenProvider? tokenProvider,
  Duration timeout = const Duration(seconds: 1),
}) {
  return ApiClient(
    baseUrl: Uri.parse(base),
    client: MockClient(handler),
    tokenProvider: tokenProvider,
    timeout: timeout,
  );
}

Future<ApiException> failure(ApiClient api, [String path = '/health']) async {
  try {
    await api.getJson(path);
  } on ApiException catch (e) {
    return e;
  }
  fail('expected ApiException');
}

void main() {
  test('GET returns the decoded JSON object', () async {
    final api = clientFor((req) async {
      expect(req.method, 'GET');
      expect(req.url.toString(), 'http://localhost:3000/health');
      return http.Response('{"status":"ok"}', 200);
    });
    expect(await api.getJson('/health'), {'status': 'ok'});
  });

  test(
    'joins paths with a base URL that has a prefix or trailing slash',
    () async {
      final seen = <String>[];
      final api = clientFor((req) async {
        seen.add(req.url.path);
        return http.Response('{}', 200);
      }, base: 'https://example.test/api/');
      await api.getJson('health');
      await api.getJson('/health');
      expect(seen, ['/api/health', '/api/health']);
    },
  );

  test('attaches a bearer token when the provider returns one', () async {
    final api = clientFor((req) async {
      expect(req.headers['Authorization'], 'Bearer abc');
      return http.Response('{}', 200);
    }, tokenProvider: () async => 'abc');
    await api.getJson('/x');
  });

  test('omits Authorization when there is no token', () async {
    final api = clientFor((req) async {
      expect(req.headers.containsKey('Authorization'), isFalse);
      return http.Response('{}', 200);
    }, tokenProvider: () async => null);
    await api.getJson('/x');
  });

  test('non-2xx maps to an http error with status and backend code', () async {
    final api = clientFor(
      (_) async => http.Response('{"error":"unauthenticated"}', 401),
    );
    final e = await failure(api);
    expect(e.kind, ApiErrorKind.http);
    expect(e.statusCode, 401);
    expect(e.code, 'unauthenticated');
  });

  test('non-2xx with a non-JSON body still reports the status', () async {
    final e = await failure(clientFor((_) async => http.Response('oops', 502)));
    expect(e.kind, ApiErrorKind.http);
    expect(e.statusCode, 502);
    expect(e.code, isNull);
  });

  test('2xx with a non-object body is an invalid response', () async {
    for (final body in ['not json', '[1,2]']) {
      final e = await failure(clientFor((_) async => http.Response(body, 200)));
      expect(e.kind, ApiErrorKind.invalidResponse, reason: body);
    }
  });

  test('connection failures map to a network error', () async {
    final e = await failure(
      clientFor((_) async => throw const SocketException('refused')),
    );
    expect(e.kind, ApiErrorKind.network);
  });

  test('a slow server maps to a timeout error', () async {
    final e = await failure(
      clientFor(
        (_) => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 20),
      ),
    );
    expect(e.kind, ApiErrorKind.timeout);
  });

  test('POST and PATCH send a JSON body with the bearer token', () async {
    final seen = <http.Request>[];
    final api = clientFor((req) async {
      seen.add(req);
      return http.Response('{"ok":true}', req.method == 'POST' ? 201 : 200);
    }, tokenProvider: () async => 'abc');

    expect(await api.postJson('/api/x', {'a': 1}), {'ok': true});
    expect(await api.patchJson('/api/x', {'b': 'c'}), {'ok': true});

    expect(seen.map((r) => r.method), ['POST', 'PATCH']);
    expect(seen.map((r) => r.body), ['{"a":1}', '{"b":"c"}']);
    for (final r in seen) {
      expect(r.url.toString(), 'http://localhost:3000/api/x');
      expect(r.headers['Content-Type'], startsWith('application/json'));
      expect(r.headers['Authorization'], 'Bearer abc');
    }
  });

  test('GET sends no body or Content-Type', () async {
    final api = clientFor((req) async {
      expect(req.body, isEmpty);
      expect(req.headers.containsKey('Content-Type'), isFalse);
      return http.Response('{}', 200);
    });
    await api.getJson('/x');
  });

  test('write errors keep the status, code, and error body', () async {
    final api = clientFor(
      (_) async => http.Response(
        '{"error":"validation_failed","fields":{"phone":"invalid"}}',
        400,
      ),
    );
    try {
      await api.postJson('/x', {});
      fail('expected ApiException');
    } on ApiException catch (e) {
      expect(e.kind, ApiErrorKind.http);
      expect(e.statusCode, 400);
      expect(e.code, 'validation_failed');
      expect(e.body?['fields'], {'phone': 'invalid'});
    }
  });

  test('a slow write maps to a timeout error', () async {
    final api = clientFor(
      (_) => Completer<http.Response>().future,
      timeout: const Duration(milliseconds: 20),
    );
    await expectLater(
      api.patchJson('/x', {}),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.timeout),
      ),
    );
  });
}
