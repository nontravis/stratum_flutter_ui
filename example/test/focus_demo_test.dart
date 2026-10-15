import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_example/focus_demo.dart';

void main() {
  testWidgets(
    'f01/us04/s1, f01/us04/fr01: pumping FocusDemo shows four numbered '
    'checks in a scrolling column, each exposing its written steps text '
    'and the layout it exercises',
    (tester) async {
      final theme = await tester.runAsync(loadFocusDemoTheme);

      await tester.pumpWidget(FocusDemoApp(themes: theme!));

      expect(find.textContaining('1. Focus group.'), findsOneWidget);
      expect(
        find.textContaining('2. Reveal past the viewport.'),
        findsOneWidget,
      );
      expect(find.textContaining('3. Focus handoff.'), findsOneWidget);
      expect(find.textContaining('4. Text field.'), findsOneWidget);

      expect(find.byType(RowLayout), findsNWidgets(2));
      expect(find.byType(CallbackShortcuts), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    },
  );
}
