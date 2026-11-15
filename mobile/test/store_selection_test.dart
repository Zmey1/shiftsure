import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shiftsure_rider/auth/auth_service.dart';
import 'package:shiftsure_rider/profile/dark_store.dart';
import 'package:shiftsure_rider/profile/worker_profile.dart';
import 'package:shiftsure_rider/screens/profile_screen.dart';
import 'package:shiftsure_rider/screens/select_store_screen.dart';

import 'support/fake_auth_service.dart';
import 'support/fake_backend.dart';

FakeBackend riderWith(Map<String, dynamic> profile) => FakeBackend(
  FakeAuthService(user: const AuthUser(uid: 'u1')),
  profiles: {'u1': profile},
);

Future<void> openStoresFromProfile(WidgetTester tester) async {
  await tester.tap(find.text('View profile'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton, 'Choose'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a rider chooses a store from the profile screen', (
    tester,
  ) async {
    final backend = riderWith(profileJson('u1'));
    await pumpShiftSure(tester, backend);
    await openStoresFromProfile(tester);

    expect(find.byType(SelectStoreScreen), findsOneWidget);
    expect(find.textContaining('Demonstration data'), findsOneWidget);
    expect(find.text('Stores for Zepto in Bengaluru'), findsOneWidget);
    expect(find.text('Test Store A1'), findsOneWidget);
    expect(find.text('Zone: Test Zone B'), findsOneWidget);
    // Other cities and platforms are not offered.
    expect(find.text('Test Store C1'), findsNothing);
    expect(find.text('Test Store K1'), findsNothing);

    await tester.tap(find.byKey(const Key('store-st-a2')));
    await tester.pumpAndSettle();

    expect(
      jsonDecode(
        backend.calls('PUT', '/api/workers/me/dark-store').single.body,
      ),
      {'dark_store_id': 'st-a2'},
    );
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Test Store A2 · Zone: Test Zone B'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Change'), findsOneWidget);

    // Home reflects the assignment and stops prompting.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Test Store A2 · Zone: Test Zone B'), findsOneWidget);
    expect(find.text('Choose your dark store'), findsNothing);
  });

  testWidgets('Home prompts an unassigned rider to choose a store', (
    tester,
  ) async {
    final backend = riderWith(profileJson('u1'));
    await pumpShiftSure(tester, backend);
    await tester.tap(find.text('Choose your dark store'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Store A1'));
    await tester.pumpAndSettle();

    expect(find.text('Hi, Rahul Kumar'), findsOneWidget);
    expect(find.text('Test Store A1 · Zone: Test Zone A'), findsOneWidget);
    expect(find.text('Choose your dark store'), findsNothing);
  });

  testWidgets(
    'the empty state names the rider city, platform, and covered cities',
    (tester) async {
      await pumpShiftSure(tester, riderWith(profileJson('u1', city: 'Pune')));
      await openStoresFromProfile(tester);
      expect(
        find.text(
          'There are no demo dark stores for Zepto in Pune. Demo Zepto stores '
          'are available in: Bengaluru, Chennai. Edit your profile to change '
          'your city.',
        ),
        findsOneWidget,
      );
    },
  );

  test('the empty message covers platforms with no stores anywhere', () {
    const listing = DarkStoreListing(
      platform: DeliveryPlatform.other,
      city: 'Surat',
      stores: [],
      availableCities: [],
      demo: true,
    );
    expect(
      emptyStoresMessage(listing),
      'There are no demo dark stores for Other in Surat. The demo catalog has '
      'no Other stores in any city. Edit your profile to change your platform.',
    );
  });

  testWidgets('a load failure shows Retry, which recovers', (tester) async {
    final backend = riderWith(profileJson('u1'));
    var fail = true;
    backend.intercept = (req) async =>
        fail && req.url.path == '/api/dark-stores'
        ? http.Response('{"error":"internal_error"}', 500)
        : null;
    await pumpShiftSure(tester, backend);
    await openStoresFromProfile(tester);
    expect(find.text('Could not load dark stores (500).'), findsOneWidget);

    fail = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Test Store A1'), findsOneWidget);
  });

  testWidgets('a rejected choice explains why and reloads the list', (
    tester,
  ) async {
    final backend = riderWith(profileJson('u1'));
    backend.intercept = (req) async => req.method == 'PUT'
        ? http.Response('{"error":"store_mismatch"}', 422)
        : null;
    await pumpShiftSure(tester, backend);
    await openStoresFromProfile(tester);
    await tester.tap(find.text('Test Store A1'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Test Store A1 does not serve Zepto in Bengaluru. Choose another store.',
      ),
      findsOneWidget,
    );
    expect(find.byType(SelectStoreScreen), findsOneWidget);
    expect(backend.calls('GET', '/api/dark-stores'), hasLength(2));
  });

  testWidgets('a store request with a stale token refreshes and retries once', (
    tester,
  ) async {
    final backend = riderWith(profileJson('u1'));
    backend.intercept = (req) async =>
        req.url.path == '/api/dark-stores' && backend.auth.refreshes == 0
        ? http.Response('{"error":"forbidden"}', 403)
        : null;
    await pumpShiftSure(tester, backend);
    await openStoresFromProfile(tester);
    expect(backend.calls('GET', '/api/dark-stores'), hasLength(2));
    expect(find.text('Test Store A1'), findsOneWidget);
  });

  testWidgets('a city change that clears the store tells the rider', (
    tester,
  ) async {
    final backend = riderWith(profileJson('u1', darkStoreId: 'st-a1'));
    await pumpShiftSure(tester, backend);
    expect(find.text('Test Store A1 · Zone: Test Zone A'), findsOneWidget);

    await tester.tap(find.text('View profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    await fill(tester, {'profile-city': 'Chennai'});
    await tester.tap(button('Save changes'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Your dark store no longer matches Zepto in Chennai, so it was '
        'removed. Choose a new one.',
      ),
      findsOneWidget,
    );
    expect(find.text('Not selected'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Choose your dark store'), findsOneWidget);
  });

  testWidgets('an edit that keeps the store shows no notice', (tester) async {
    final backend = riderWith(profileJson('u1', darkStoreId: 'st-a1'));
    await pumpShiftSure(tester, backend);
    await tester.tap(find.text('View profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    await fill(tester, {'profile-name': 'Rahul K'});
    await tester.tap(button('Save changes'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Test Store A1 · Zone: Test Zone A'), findsOneWidget);
  });
}
