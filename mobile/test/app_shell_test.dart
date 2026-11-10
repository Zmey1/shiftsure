import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shiftsure_rider/api/api_client.dart';
import 'package:shiftsure_rider/app.dart';
import 'package:shiftsure_rider/auth/auth_service.dart';
import 'package:shiftsure_rider/config/app_config.dart';
import 'support/fake_auth_service.dart';

void main() {
  testWidgets('navigates between the four placeholder tabs', (tester) async {
    final api = ApiClient(
      baseUrl: Uri.parse('http://localhost:3000'),
      client: MockClient((_) async => http.Response('{"status":"ok"}', 200)),
    );
    await tester.pumpWidget(
      ShiftSureApp(
        config: AppConfig.parse('http://localhost:3000'),
        auth: FakeAuthService(user: const AuthUser(uid: 'u1')),
        apiClient: api,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Placeholder · planned for PR #8'), findsOneWidget);

    for (final (label, pr) in [('Policy', 9), ('Claims', 12), ('Wallet', 14)]) {
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
