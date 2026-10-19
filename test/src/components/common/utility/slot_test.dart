import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

void main() {
  group('StratumSlot', () {
    testWidgets(
      'co01_01/us01/fr01/e01, co01_01/us01/s2: with no name the label reads ❖ Slot',
      (tester) async {
        await tester.pumpWidget(themedHost(const StratumSlot()));

        expect(find.text('❖ Slot'), findsOneWidget);
      },
    );
  });
}
