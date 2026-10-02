import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui_example/typography_demo.dart';

void main() {
  testWidgets('loads the default theme and lists its types and sizes', (
    tester,
  ) async {
    final theme = await tester.runAsync(loadDemoTheme);

    await tester.pumpWidget(TypographyDemoApp(theme: theme!));

    expect(find.text('header s56'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('table s10'), 300);
    expect(find.text('table s10'), findsOneWidget);
  });

  testWidgets('switches the window size and the text scale', (tester) async {
    final theme = await tester.runAsync(loadDemoTheme);
    await tester.pumpWidget(TypographyDemoApp(theme: theme!));
    TextStyle sample() =>
        tester.widget<Text>(find.byKey(const ValueKey('header s56'))).style!;

    await tester.tap(find.text('mobile'));
    await tester.pumpAndSettle();
    expect(sample().fontSize, 56);
    expect(sample().height, closeTo(72 / 56, 1e-9));

    await tester.tap(find.text('200%'));
    await tester.pumpAndSettle();
    expect(sample().height, closeTo((112 + 16) / 112, 1e-9));

    await tester.tap(find.text('bigDesktop'));
    await tester.pumpAndSettle();
    expect(sample().fontSize, 58);
  });
}
