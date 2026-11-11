import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shiftsure_rider/auth/auth_service.dart';
import 'package:shiftsure_rider/navigation/app_shell.dart';
import 'package:shiftsure_rider/screens/edit_profile_screen.dart';
import 'package:shiftsure_rider/screens/login_screen.dart';
import 'package:shiftsure_rider/screens/profile_screen.dart';
import 'package:shiftsure_rider/screens/profile_setup_screen.dart';

import 'support/fake_auth_service.dart';
import 'support/fake_backend.dart';

FakeBackend backendFor(
  String uid, {
  Map<String, Map<String, dynamic>>? profiles,
}) => FakeBackend(
  FakeAuthService(user: AuthUser(uid: uid)),
  profiles: profiles,
);

Future<void> chooseEntry(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('profile-platform')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> fillValidProfile(WidgetTester tester) async {
  await fill(tester, {
    'profile-name': '  Asha   Rao ',
    'profile-phone': '+91 98765-43210',
    'profile-city': 'Bengaluru',
  });
  await chooseEntry(tester, 'Swiggy Instamart');
}

void main() {
  testWidgets('a user without a profile sees setup, not the app shell', (
    tester,
  ) async {
    await pumpShiftSure(tester, backendFor('new'));
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets('a user with a profile goes straight to the app shell', (
    tester,
  ) async {
    final backend = backendFor('u1', profiles: {'u1': profileJson('u1')});
    await pumpShiftSure(tester, backend);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(ProfileSetupScreen), findsNothing);
    expect(backend.auth.refreshes, 0);
  });

  testWidgets('setup validates fields before submitting', (tester) async {
    final backend = backendFor('new');
    await pumpShiftSure(tester, backend);

    await tester.tap(button('Save profile'));
    await tester.pump();
    expect(find.text('Enter your name.'), findsOneWidget);
    expect(find.text('Enter your phone number.'), findsOneWidget);
    expect(find.text('Enter your city.'), findsOneWidget);
    expect(find.text('Choose your platform.'), findsOneWidget);

    await fill(tester, {
      'profile-name': 'A1',
      'profile-phone': '12345',
      'profile-city': 'X',
    });
    await tester.tap(button('Save profile'));
    await tester.pump();
    expect(find.text("Use letters, spaces, and . ' - only."), findsOneWidget);
    expect(find.text('Enter a 10-digit Indian mobile number.'), findsOneWidget);
    expect(find.text('Use at least 2 characters.'), findsOneWidget);
    expect(backend.calls('POST'), isEmpty);
  });

  testWidgets(
    'setup posts only the four normalized fields, refreshes the token, then '
    'shows the app',
    (tester) async {
      final backend = backendFor('new');
      await pumpShiftSure(tester, backend);
      await fillValidProfile(tester);
      await tester.tap(button('Save profile'));
      await tester.pumpAndSettle();

      final post = backend.calls('POST').single;
      expect(jsonDecode(post.body), {
        'name': 'Asha Rao',
        'phone': '9876543210',
        'city': 'Bengaluru',
        'platform': 'swiggy_instamart',
      });
      expect(post.headers['Content-Type'], startsWith('application/json'));
      expect(post.headers['Authorization'], 'Bearer token-1');
      expect(backend.auth.calls, contains('refreshToken'));
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.text('Hi, Asha Rao'), findsOneWidget);
      expect(find.text('Swiggy Instamart · Bengaluru'), findsOneWidget);
    },
  );

  testWidgets('a second tap while saving does not submit twice', (
    tester,
  ) async {
    final backend = backendFor('new');
    final release = Completer<void>();
    await pumpShiftSure(tester, backend);
    backend.intercept = (req) async =>
        req.method == 'POST' ? held(release) : null;

    await fillValidProfile(tester);
    await tester.tap(button('Save profile'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    release.complete();
    await tester.pumpAndSettle();
    expect(backend.calls('POST'), hasLength(1));
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('a failed save shows an error and stays on setup', (
    tester,
  ) async {
    final backend = backendFor('new');
    await pumpShiftSure(tester, backend);
    backend.intercept = (req) async => req.method == 'POST'
        ? http.Response('{"error":"internal_error"}', 500)
        : null;

    await fillValidProfile(tester);
    await tester.tap(button('Save profile'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save your profile (500). Try again.'),
      findsOneWidget,
    );
    expect(find.byType(ProfileSetupScreen), findsOneWidget);

    // Retrying (e.g. after the backend set the claim but failed the write)
    // completes onboarding.
    backend.intercept = null;
    await tester.tap(button('Save profile'));
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('if the profile already exists on create, it is loaded', (
    tester,
  ) async {
    final backend = backendFor('u1');
    await pumpShiftSure(tester, backend);
    // Created elsewhere (another device, or a lost earlier response).
    backend.profiles['u1'] = profileJson('u1', name: 'Existing Name');

    await fillValidProfile(tester);
    await tester.tap(button('Save profile'));
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('Hi, Existing Name'), findsOneWidget);
  });

  testWidgets('a load failure shows Retry, which recovers', (tester) async {
    final backend = backendFor('u1', profiles: {'u1': profileJson('u1')});
    backend.intercept = (_) async => throw const SocketException('refused');
    await pumpShiftSure(tester, backend);
    expect(find.text('Could not reach the server.'), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
    expect(find.byType(ProfileSetupScreen), findsNothing);

    backend.intercept = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('sign out is available from setup and from a load error', (
    tester,
  ) async {
    final backend = backendFor('new');
    await pumpShiftSure(tester, backend);
    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    final failing = backendFor('u1');
    failing.intercept = (_) async => http.Response('', 503);
    await tester.pumpWidget(const SizedBox());
    await pumpShiftSure(tester, failing);
    expect(find.text('Could not load your profile (503).'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('interrupted onboarding: a stale token is refreshed on load', (
    tester,
  ) async {
    final backend = backendFor('u1', profiles: {'u1': profileJson('u1')})
      ..refreshRequiredOnGet = true;
    await pumpShiftSure(tester, backend);
    expect(find.byType(AppShell), findsOneWidget);
    expect(backend.auth.refreshes, 1);
  });

  testWidgets('after sign-out, the next user gets their own profile check', (
    tester,
  ) async {
    final backend = backendFor('u1', profiles: {'u1': profileJson('u1')});
    await pumpShiftSure(tester, backend);
    expect(find.text('Hi, Rahul Kumar'), findsOneWidget);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    backend.auth.nextUid = 'u2';
    await fill(tester, {'email': 'u2@example.com', 'password': 'secret1'});
    await tester.tap(button('Sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect(find.text('Hi, Rahul Kumar'), findsNothing);
  });

  testWidgets('registration leads to profile setup', (tester) async {
    final backend = FakeBackend(FakeAuthService());
    await pumpShiftSure(tester, backend);
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await fill(tester, {
      'email': 'new@example.com',
      'password': 'secret1',
      'confirm': 'secret1',
    });
    await tester.tap(button('Create account'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
  });

  testWidgets('view and edit profile sends only changed fields', (
    tester,
  ) async {
    final backend = backendFor('u1', profiles: {'u1': profileJson('u1')});
    await pumpShiftSure(tester, backend);

    await tester.tap(find.text('View profile'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('Zepto'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsOneWidget);
    await fill(tester, {'profile-city': ' Mumbai '});
    await chooseEntry(tester, 'Blinkit');
    await tester.tap(button('Save changes'));
    await tester.pumpAndSettle();

    expect(jsonDecode(backend.calls('PATCH').single.body), {
      'city': 'Mumbai',
      'platform': 'blinkit',
    });
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Mumbai'), findsOneWidget);
    expect(find.text('Blinkit'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Blinkit · Mumbai'), findsOneWidget);
  });

  testWidgets('saving an unchanged profile makes no request', (tester) async {
    final backend = backendFor('u1', profiles: {'u1': profileJson('u1')});
    await pumpShiftSure(tester, backend);
    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    await tester.tap(button('Save changes'));
    await tester.pumpAndSettle();
    expect(backend.calls('PATCH'), isEmpty);
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('an edit rejected for a stale token refreshes and retries once', (
    tester,
  ) async {
    final backend = backendFor('u1', profiles: {'u1': profileJson('u1')})
      ..patchNeedsRefresh = true;
    await pumpShiftSure(tester, backend);
    await tester.tap(find.text('View profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    await fill(tester, {'profile-name': 'Rahul K'});
    await tester.tap(button('Save changes'));
    await tester.pumpAndSettle();

    final patches = backend.calls('PATCH').toList();
    expect(patches, hasLength(2));
    expect(patches[0].headers['Authorization'], 'Bearer token-1');
    expect(patches[1].headers['Authorization'], 'Bearer token-2');
    expect(find.text('Rahul K'), findsOneWidget);
  });

  testWidgets('an edit validation error keeps the rider on the edit screen', (
    tester,
  ) async {
    final backend = backendFor('u1', profiles: {'u1': profileJson('u1')});
    await pumpShiftSure(tester, backend);
    backend.intercept = (req) async => req.method == 'PATCH'
        ? http.Response(
            '{"error":"validation_failed","fields":{"city":"invalid"}}',
            400,
          )
        : null;
    await tester.tap(find.text('View profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    await fill(tester, {'profile-city': 'Pune'});
    await tester.tap(button('Save changes'));
    await tester.pumpAndSettle();
    expect(
      find.text('Some details were not accepted. Check them and try again.'),
      findsOneWidget,
    );
    expect(find.byType(EditProfileScreen), findsOneWidget);
  });
}
