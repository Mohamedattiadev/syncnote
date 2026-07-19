import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncnote/widgets/pressable_scale.dart';

void main() {
  testWidgets('PressableScale invokes onTap and scales on press', (tester) async {
    int taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: PressableScale(
            onTap: () => taps++,
            child: const SizedBox(
              width: 100, height: 100,
              child: ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      ),
    ));
    expect(find.byType(AnimatedScale), findsOneWidget);
    await tester.tap(find.byType(PressableScale));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('PressableScale disabled when onTap is null', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PressableScale(
          child: SizedBox(width: 50, height: 50),
        ),
      ),
    ));
    // Should still render without crash.
    expect(find.byType(PressableScale), findsOneWidget);
  });
}
