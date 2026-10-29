import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/layout/layout_slots.dart';

import '../support/catalog_theme.dart';

const _appKey = ValueKey('layout-slots-application');

/// Pumps [child] under the default theme.
Future<void> _pump(WidgetTester tester, Widget child) async {
  final themes = await loadDefaultThemeSet();
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en')],
      home: StratumThemeApplication(
        key: _appKey,
        themes: themes,
        themeMode: ThemeMode.light,
        child: child,
      ),
    ),
  );
}

void main() {
  testWidgets('fo11/us06/fr01: slotChildren names each place', (tester) async {
    final children = slotChildren(3);

    expect(children, hasLength(3));
    await _pump(tester, ColumnLayout(children: children));

    expect(find.text('❖ child 1'), findsOneWidget);
    expect(find.text('❖ child 2'), findsOneWidget);
    expect(find.text('❖ child 3'), findsOneWidget);
    expect(find.text('❖ child 4'), findsNothing);
  });

  testWidgets('fo11/us06/fr01: slotChildren(count) paints count named slots', (
    tester,
  ) async {
    await _pump(tester, ColumnLayout(children: slotChildren(2)));
    expect(find.byType(StratumSlot), findsNWidgets(2));

    await _pump(tester, ColumnLayout(children: slotChildren(5)));
    expect(find.byType(StratumSlot), findsNWidgets(5));
    for (var i = 1; i <= 5; i++) {
      expect(find.text('❖ child $i'), findsOneWidget);
    }
  });
}
