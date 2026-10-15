import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

/// A card an app builds outside the package from the public building
/// blocks only: the stateless component base, a [ContainerLayout], and the
/// tap surface the layout's [Interaction] builds (FO-08 US-04).
class _Card extends StratumStatelessWidget {
  const new({super.size, this.customStyle, required this.onTap});

  final VoidCallback onTap;

  /// The card's own instance style, declared on the component as every
  /// component that takes one declares it (FO-08 US-01 FR-01 E04).
  final WidgetStyle? customStyle;

  static const _defaults = WidgetStyle(padding: EdgeInsets.all(8));

  @override
  Widget build(BuildContext context) {
    return ContainerLayout(
      style: resolveStyle(context, _defaults, customStyle),
      interaction: Interaction(onTap: onTap),
      child: const SizedBox(width: 40, height: 40),
    );
  }
}

/// The overlay inside the card's [StratumInkWell]; null when it paints
/// nothing.
Color? _overlayColor(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(InkWell),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.position == DecorationPosition.foreground,
      ),
    ),
  );
  final color = (box.decoration as BoxDecoration).color;
  return color == null || color.a == 0 ? null : color;
}

void main() {
  testWidgets(
    'fo08/us04/fr01, fo08/us04/s1, fo08/us04/s2: a card composed from the '
    'public building blocks shows the flat pressed overlay on tap, runs '
    'its action, and resolves a custom style and size the way a Stratum '
    'component does',
    (tester) async {
      var taps = 0;
      final card = _Card(size: WidgetSize.huge, onTap: () => taps++);
      await tester.pumpWidget(themedHost(card));

      // Scenario 1 — pressing the card shows the flat overlay and tapping
      // runs its action, exactly as StratumInkWell does for a Stratum
      // component.
      final press = await tester.startGesture(
        tester.getCenter(find.byType(_Card)),
      );
      await tester.pump(kPressTimeout);
      await tester.pumpAndSettle();
      expect(_overlayColor(tester), fakeActive);

      await press.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(_overlayColor(tester), isNull);

      // Scenario 2 — the card resolves a custom style and size through the
      // same base methods every Stratum component reads.
      final custom = _Card(
        size: WidgetSize.huge,
        customStyle: const WidgetStyle(opacity: 1),
        onTap: () {},
      );
      final context = tester.element(find.byType(_Card));
      final style = custom.resolveStyle(
        context,
        _Card._defaults,
        custom.customStyle,
      );
      expect(style.opacity, 1);
      expect(style.padding, _Card._defaults.padding);
      expect(custom.resolveDefaultSize(context), WidgetSize.huge);
    },
  );
}
