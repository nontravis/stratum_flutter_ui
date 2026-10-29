import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';

import '../../common/fakes/fake_stratum_theme.dart';

// The plain look drawn alone (US-01 FR-06 E07, E08; s03 INV-21): the toast
// symbols come through the public barrel only, so a missing export fails to
// compile.

StratumToastNotice _notice({
  FeedbackState kind = FeedbackState.negative,
  VoidCallback? close,
  StratumToastAction? action,
}) => StratumToastNotice(
  message: 'Could not save',
  kind: kind,
  placement: const StratumToastPlacement.float(StratumToastCorner.bottomEnd),
  insets: EdgeInsets.zero,
  pageSnack: null,
  customStyle: null,
  close: close ?? () {},
  closeLabel: 'Close it',
  kindLabel: 'Error',
  action: action,
);

Widget _app(Widget Function(BuildContext context) home) => MaterialApp(
  builder: (context, child) => StratumThemeApplication(
    themes: StratumThemeSet(light: fakeTheme),
    themeMode: ThemeMode.light,
    child: child!,
  ),
  home: Scaffold(body: Builder(builder: home)),
);

void main() {
  testWidgets(
    'NFR-U01: NFR-U05: co05_07/us01/fr06/e07: co05_07/us01/s23: drawn alone, '
    'outside any host, it keeps the kind name, the close label, and the tap '
    'target',
    (tester) async {
      final handle = tester.ensureSemantics();
      var closed = 0;
      await tester.pumpWidget(
        _app(
          (_) => Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 360,
              child: StratumToastPlainLook(
                notice: _notice(close: () => closed++),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Could not save'), findsOneWidget);
      expect(find.bySemanticsLabel('Error'), findsOneWidget);
      expect(find.bySemanticsLabel('Close it'), findsOneWidget);
      // No timer runs: the notice stays and no frame is left scheduled.
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Could not save'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(closed, 0);

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

      await tester.tap(find.bySemanticsLabel('Close it'));
      await tester.pump();
      expect(closed, 1);
      handle.dispose();
    },
  );

  testWidgets(
    'co05_07/us01/fr06/e08: an app builder that wraps the plain look renders '
    'it inside the host',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => StratumThemeApplication(
            themes: StratumThemeSet(light: fakeTheme),
            themeMode: ThemeMode.light,
            child: StratumToastHost(
              builder: (context, notice) => Padding(
                padding: const EdgeInsets.all(3),
                child: StratumToastPlainLook(notice: notice),
              ),
              child: child!,
            ),
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => context.showToast(message: 'Wrapped'),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('Wrapped'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Wrapped'),
          matching: find.byType(StratumToastPlainLook),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Wrapped'), findsNothing);
    },
  );
}
