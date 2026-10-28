import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whale_ledger/ui/common.dart';

void main() {
  testWidgets('Pressable 按下当帧即进入按压态，抬起后保持 holdMs 再恢复',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Pressable(
              scale: 0.9,
              downMs: 30,
              upMs: 30,
              holdMs: 80,
              builder: (bool down) => SizedBox(
                width: 80,
                height: 80,
                child: Text(down ? 'down' : 'up'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('up'), findsOneWidget);

    final TestGesture g =
        await tester.startGesture(tester.getCenter(find.byType(Pressable)));
    await tester.pump();

    // pointerdown 当帧就应该进入按压态，不能等抬起
    expect(find.text('down'), findsOneWidget);
    final AnimatedScale s = tester.widget<AnimatedScale>(
      find.descendant(
        of: find.byType(Pressable),
        matching: find.byType(AnimatedScale),
      ),
    );
    expect(s.scale, 0.9);
    expect(s.duration, const Duration(milliseconds: 30));

    await g.up();
    await tester.pump();
    // holdMs 内保持，避免快速点击时缩放看不见
    expect(find.text('down'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('up'), findsOneWidget);
  });

  testWidgets('Pressable 点击仍会触发 onTap', (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Pressable(
              onTap: () => taps++,
              child: const SizedBox(width: 80, height: 80),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(Pressable));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
