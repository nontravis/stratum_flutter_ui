import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

void _noop() {}

/// A tappable list row, 300 px wide: a title and a subtitle, at least
/// [minHeight] tall. It stays clear of the screen edges, where the target
/// size guideline skips a node as possibly scrolled off.
Widget _row({double minHeight = 48, bool labeled = true}) {
  final row = RowLayout(
    style: WidgetStyle(
      minHeight: minHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
    ),
    interaction: const StratumInteraction(onTap: _noop),
    children: [
      if (labeled)
        const ColumnLayout(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text('Wi-Fi'), Text('Connected')],
        )
      else
        const SizedBox(width: 100, height: 20),
    ],
  );
  return SizedBox(width: 300, child: row);
}

void main() {
  group('accessibility guidelines', () {
    testWidgets('a tappable row has a label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedHost(_row()));

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('a tappable row without text has no label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedHost(_row(labeled: false)));

      await expectLater(
        tester,
        doesNotMeetGuideline(labeledTapTargetGuideline),
      );
      handle.dispose();
    });

    testWidgets('a 48 px tappable row meets the Android target size', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedHost(_row()));

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('a 40 px tappable row misses the Android target size', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(SizedBox(height: 40, child: _row(minHeight: 0))),
      );

      await expectLater(
        tester,
        doesNotMeetGuideline(androidTapTargetGuideline),
      );
      handle.dispose();
    });

    testWidgets('(pin) a 48 px row of two lines grows at twice the text '
        'size without overflow', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: themedHost(_row()),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(RowLayout)).height, greaterThan(48));
    });
  });
}
