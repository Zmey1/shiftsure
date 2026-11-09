import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shiftsure_rider/api/api_client.dart';
import 'package:shiftsure_rider/widgets/backend_status_card.dart';

Widget host(MockClientHandler handler) {
  final api = ApiClient(
    baseUrl: Uri.parse('http://localhost:3000'),
    client: MockClient(handler),
  );
  return MaterialApp(
    home: Scaffold(body: BackendStatusCard(api: api)),
  );
}

void main() {
  testWidgets('shows reachable when /health succeeds', (tester) async {
    await tester.pumpWidget(
      host((_) async => http.Response('{"status":"ok"}', 200)),
    );
    expect(find.text('Checking…'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Backend reachable'), findsOneWidget);
  });

  testWidgets('shows an error, and Retry checks once more', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      host((_) async {
        calls++;
        if (calls == 1) throw const SocketException('refused');
        return http.Response('{"status":"ok"}', 200);
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not reach the server.'), findsOneWidget);
    expect(calls, 1); // no polling

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Backend reachable'), findsOneWidget);
    expect(calls, 2);
  });
}
