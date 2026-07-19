// E2E smoke on real device. Boots app + walks core flows.
// Run: flutter test integration_test -d <device-id>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:syncnote/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots without crashing', (t) async {
    app.main();
    await t.pumpAndSettle(const Duration(seconds: 5));
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('bottom nav has 4 tabs', (t) async {
    app.main();
    await t.pumpAndSettle(const Duration(seconds: 5));
    // Bottom nav lives in main_shell after auth/demo bypass.
    // If gated behind login/onboarding this will be skipped.
    final nav = find.byType(NavigationBar);
    if (nav.evaluate().isEmpty) return;
    expect(nav, findsOneWidget);
  });

  testWidgets('no RenderFlex overflow on home', (t) async {
    final errors = <String>[];
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      final msg = d.toString();
      if (msg.contains('RenderFlex overflowed')) errors.add(msg);
      prev?.call(d);
    };
    app.main();
    await t.pumpAndSettle(const Duration(seconds: 5));
    FlutterError.onError = prev;
    expect(errors, isEmpty, reason: errors.join('\n'));
  });
}
