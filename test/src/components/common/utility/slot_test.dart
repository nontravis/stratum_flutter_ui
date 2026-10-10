import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

void main() {
  group('StratumSlot', () {
    testWidgets('co01-01/us01/fr01/e01: with no name the label reads ❖ Slot', (
      tester,
    ) async {
      await tester.pumpWidget(themedHost(const StratumSlot()));

      expect(find.text('❖ Slot'), findsOneWidget);
    });
  });

  group('renames', () {
    testWidgets('renames: the deprecated Slot still draws the placeholder', (
      tester,
    ) async {
      await tester.pumpWidget(
        themedHost(
          // Deliberate: this test proves the deprecated alias still works.
          // ignore: deprecated_member_use_from_same_package
          const Slot(name: 'Header'),
        ),
      );

      expect(find.byType(StratumSlot), findsOneWidget);
      expect(find.text('❖ Header'), findsOneWidget);
    });
  });
}
