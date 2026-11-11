import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiftsure_rider/auth/auth_service.dart';

import 'support/fake_auth_service.dart';
import 'support/fake_backend.dart';

void main() {
  testWidgets('Home shows the profile; other tabs are placeholders', (
    tester,
  ) async {
    final auth = FakeAuthService(user: const AuthUser(uid: 'u1'));
    await pumpShiftSure(
      tester,
      FakeBackend(auth, profiles: {'u1': profileJson('u1')}),
    );

    expect(find.text('Hi, Rahul Kumar'), findsOneWidget);
    expect(find.text('Zepto · Bengaluru'), findsOneWidget);
    expect(find.textContaining('Placeholder'), findsNothing);

    for (final (label, pr) in [
      ('Policy', 11),
      ('Claims', 14),
      ('Wallet', 16),
    ]) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Placeholder · planned for PR #$pr'),
        findsOneWidget,
        reason: label,
      );
    }
  });
}
