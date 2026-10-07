// FocusSpread stays for one minor version; these tests pin what it builds.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

const _box = SizedBox(width: 40, height: 20);

StratumFocusBorder _ring(WidgetTester tester) =>
    tester.widget<StratumFocusBorder>(find.byType(StratumFocusBorder));

void main() {
  group('FocusSpread', () {
    testWidgets(
      'us04/fr03/e10: builds StratumFocusBorder, its color passed on as '
      'customColor, focus as the focused state, inside as insideEdge',
      (tester) async {
        const red = Color(0xFFFF0000);
        const radius = BorderRadius.all(Radius.circular(6));
        await tester.pumpWidget(
          themedHost(
            const FocusSpread(
              focus: true,
              color: red,
              inside: true,
              borderRadius: radius,
              child: _box,
            ),
          ),
        );

        final ring = _ring(tester);
        expect(ring.style, StratumFocusBorderStyle.outside);
        expect(ring.state, FullWidgetState.focused);
        expect(ring.customColor, red);
        expect(ring.color, isNull);
        expect(ring.insideEdge, isTrue);
        expect(ring.borderRadius, radius);
        expect(ring.child, same(_box));
      },
    );

    testWidgets(
      'us04/fr03/e10: an unfocused FocusSpread with no inside builds the '
      'normal look around its child in the theme color',
      (tester) async {
        await tester.pumpWidget(themedHost(const FocusSpread(child: _box)));

        final ring = _ring(tester);
        expect(ring.state, FullWidgetState.normal);
        expect(ring.insideEdge, isFalse);
        expect(ring.customColor, isNull);
        expect(ring.borderRadius, isNull);
      },
    );
  });
}
