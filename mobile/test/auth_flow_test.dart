import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shiftsure_rider/api/api_client.dart';
import 'package:shiftsure_rider/app.dart';
import 'package:shiftsure_rider/auth/auth_service.dart';
import 'package:shiftsure_rider/config/app_config.dart';
import 'package:shiftsure_rider/navigation/app_shell.dart';
import 'package:shiftsure_rider/screens/login_screen.dart';
import 'package:shiftsure_rider/screens/register_screen.dart';

import 'support/fake_auth_service.dart';

Future<FakeAuthService> pumpApp(
  WidgetTester tester, {
  FakeAuthService? auth,
  Map<String, String>? seenHeaders,
}) async {
  final fake = auth ?? FakeAuthService();
  final api = ApiClient(
    baseUrl: Uri.parse('http://localhost:3000'),
    tokenProvider: fake.getIdToken,
    client: MockClient((req) async {
      seenHeaders?.addAll(req.headers);
      return http.Response('{"status":"ok"}', 200);
    }),
  );
  await tester.pumpWidget(
    ShiftSureApp(
      config: AppConfig.parse('http://localhost:3000'),
      auth: fake,
      apiClient: api,
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

Future<void> fill(WidgetTester tester, Map<String, String> fields) async {
  for (final e in fields.entries) {
    await tester.enterText(find.byKey(Key(e.key)), e.value);
  }
}

Finder button(String label) => find.widgetWithText(FilledButton, label);

void main() {
  testWidgets('signed out shows login; signed in shows the rider app', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await pumpApp(
      tester,
      auth: FakeAuthService(user: const AuthUser(uid: 'u1')),
    );
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('login validates input before calling the service', (
    tester,
  ) async {
    final auth = await pumpApp(tester);
    await tester.tap(button('Sign in'));
    await tester.pump();
    expect(find.text('Enter your email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);

    await fill(tester, {'email': 'nope', 'password': '123'});
    await tester.tap(button('Sign in'));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Use at least 6 characters.'), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('login succeeds and shows the rider app', (tester) async {
    final auth = await pumpApp(tester);
    await fill(tester, {'email': ' rider@example.com ', 'password': 'secret1'});
    await tester.tap(button('Sign in'));
    await tester.pumpAndSettle();

    expect(auth.calls, ['signIn:rider@example.com']);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('login shows a loading indicator, then a readable error', (
    tester,
  ) async {
    final auth = await pumpApp(tester);
    auth.gate = Completer<void>();
    auth.failure = const AuthFailure('Incorrect email or password.');
    await fill(tester, {'email': 'rider@example.com', 'password': 'secret1'});
    await tester.tap(button('Sign in'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    auth.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('registration checks password confirmation then signs up', (
    tester,
  ) async {
    final auth = await pumpApp(tester);
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);

    await fill(tester, {
      'email': 'new@example.com',
      'password': 'secret1',
      'confirm': 'different',
    });
    await tester.tap(button('Create account'));
    await tester.pump();
    expect(find.text('Passwords differ.'), findsOneWidget);
    expect(auth.calls, isEmpty);

    await fill(tester, {'confirm': 'secret1'});
    await tester.tap(button('Create account'));
    await tester.pumpAndSettle();
    expect(auth.calls, ['signUp:new@example.com']);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(RegisterScreen), findsNothing);
  });

  testWidgets('registration shows a readable error', (tester) async {
    final auth = await pumpApp(tester);
    auth.failure = const AuthFailure(
      'An account with this email already exists.',
    );
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await fill(tester, {
      'email': 'new@example.com',
      'password': 'secret1',
      'confirm': 'secret1',
    });
    await tester.tap(button('Create account'));
    await tester.pumpAndSettle();
    expect(find.textContaining('already exists'), findsOneWidget);
    expect(find.byType(RegisterScreen), findsOneWidget);
  });

  testWidgets('logout returns to login', (tester) async {
    final auth = await pumpApp(
      tester,
      auth: FakeAuthService(user: const AuthUser(uid: 'u1')),
    );
    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    expect(auth.calls, ['signOut']);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets('ID token is sent to the API only while signed in', (
    tester,
  ) async {
    final headers = <String, String>{};
    final auth = await pumpApp(
      tester,
      auth: FakeAuthService(user: const AuthUser(uid: 'u1')),
      seenHeaders: headers,
    );
    // Home loads /health on startup.
    expect(headers['Authorization'], 'Bearer token-1');

    await auth.signOut();
    headers.clear();
    final api = ApiClient(
      baseUrl: Uri.parse('http://localhost:3000'),
      tokenProvider: auth.getIdToken,
      client: MockClient((req) async {
        headers.addAll(req.headers);
        return http.Response('{}', 200);
      }),
    );
    await api.getJson('/health');
    expect(headers.containsKey('Authorization'), isFalse);
  });
}
