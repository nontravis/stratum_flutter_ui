import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import 'fakes/fake_stratum_theme.dart';

const _child = SizedBox(width: 40, height: 20);

void _noop() {}

class _Probe extends StatefulWidget {
  const new();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) => _child;
}

typedef _Build = Widget Function({
  required StratumInteraction interaction,
  WidgetStyle? style,
  Widget child,
});

/// Every box layout with `interaction`, `style`, and one `child`.
final _layouts = <String, _Build>{
  'ContainerLayout': ({required interaction, style, child = _child}) =>
      ContainerLayout(interaction: interaction, style: style, child: child),
  'ColumnLayout': ({required interaction, style, child = _child}) =>
      ColumnLayout(
        interaction: interaction,
        style: style,
        mainAxisSize: MainAxisSize.min,
        children: [child],
      ),
  'RowLayout': ({required interaction, style, child = _child}) => RowLayout(
    interaction: interaction,
    style: style,
    mainAxisSize: MainAxisSize.min,
    children: [child],
  ),
  'StackLayout': ({required interaction, style, child = _child}) =>
      StackLayout(interaction: interaction, style: style, children: [child]),
  'WrapLayout': ({required interaction, style, child = _child}) =>
      WrapLayout(interaction: interaction, style: style, children: [child]),
};

Finder _semantics(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
  );
}

void main() {
  group('ContainerLayout interaction', () {
    testWidgets('keeps semantics inside the box without callbacks', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(
          const ContainerLayout(
            interaction: StratumInteraction(),
            semantics: SemanticsProperties(label: 'card'),
            child: _child,
          ),
        ),
      );

      expect(find.byType(StratumInkWell), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AnimatedStyledBox),
          matching: _semantics('card'),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('card'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('toggling onTap with semantics keeps the child State', (
      tester,
    ) async {
      Widget build(GestureTapCallback? onTap) => themedHost(
        ContainerLayout(
          semantics: const SemanticsProperties(label: 'card'),
          interaction: StratumInteraction(onTap: onTap),
          child: const _Probe(),
        ),
      );

      await tester.pumpWidget(build(null));
      final before = tester.state(find.byType(_Probe));
      await tester.pumpWidget(build(_noop));

      expect(tester.state(find.byType(_Probe)), same(before));
    });

    testWidgets('keeps the margin outside the ink well', (tester) async {
      await tester.pumpWidget(
        themedHost(
          const ContainerLayout(
            style: WidgetStyle(
              width: 40,
              height: 20,
              margin: EdgeInsets.all(8),
            ),
            interaction: StratumInteraction(onTap: _noop),
            child: SizedBox.expand(),
          ),
        ),
      );

      expect(tester.getSize(find.byType(StratumInkWell)), const Size(40, 20));
      expect(tester.getSize(find.byType(ContainerLayout)), const Size(56, 36));
    });

    testWidgets('puts the ink well under the rotation', (tester) async {
      await tester.pumpWidget(
        themedHost(
          const ContainerLayout(
            rotate: 45,
            interaction: StratumInteraction(onTap: _noop),
            child: _child,
          ),
        ),
      );

      expect(
        find.ancestor(
          of: find.byType(StratumInkWell),
          matching: find.byType(Transform),
        ),
        findsOneWidget,
      );
    });

    testWidgets('gives the style radius and semantics to the ink well', (
      tester,
    ) async {
      const radius = BorderRadius.all(Radius.circular(8));
      await tester.pumpWidget(
        themedHost(
          const ContainerLayout(
            style: WidgetStyle(borderRadius: radius),
            semantics: SemanticsProperties(label: 'card'),
            interaction: StratumInteraction(onTap: _noop),
            child: _child,
          ),
        ),
      );

      final inkWell = tester.widget<StratumInkWell>(
        find.byType(StratumInkWell),
      );
      expect(inkWell.borderRadius, radius);
      expect(inkWell.semantics?.label, 'card');
      expect(
        find.ancestor(
          of: find.byType(StratumInkWell),
          matching: _semantics('card'),
        ),
        findsNothing,
      );
    });
  });

  group('layout interaction', () {
    for (final MapEntry(key: name, value: build) in _layouts.entries) {
      testWidgets('$name forwards onSecondaryTap', (tester) async {
        var count = 0;
        await tester.pumpWidget(
          themedHost(
            build(
              interaction: StratumInteraction(onSecondaryTap: () => count++),
            ),
          ),
        );

        await tester.tap(
          find.byType(StratumInkWell),
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();

        expect(count, 1);
      });

      testWidgets('$name reads as a dimmed button when disabled', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          themedHost(
            build(
              interaction: const StratumInteraction(
                onTap: _noop,
                disabled: true,
              ),
            ),
          ),
        );

        expect(
          tester.getSemantics(find.byType(StratumInkWell)),
          isSemantics(
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            hasTapAction: false,
          ),
        );
        handle.dispose();
      });

      testWidgets('$name keeps the child State as callbacks come and go', (
        tester,
      ) async {
        Widget host(GestureTapCallback? onTap) => themedHost(
          build(
            interaction: StratumInteraction(onTap: onTap),
            child: const _Probe(),
          ),
        );

        await tester.pumpWidget(host(null));
        final before = tester.state(find.byType(_Probe));
        await tester.pumpWidget(host(_noop));
        expect(find.byType(StratumInkWell), findsOneWidget);
        expect(tester.state(find.byType(_Probe)), same(before));

        await tester.pumpWidget(host(null));
        expect(find.byType(StratumInkWell), findsNothing);
        expect(tester.state(find.byType(_Probe)), same(before));
      });

      testWidgets('$name animates a style over 100 ms without callbacks', (
        tester,
      ) async {
        await tester.pumpWidget(
          themedHost(
            build(
              interaction: const StratumInteraction(),
              style: const WidgetStyle(width: 40, height: 20),
            ),
          ),
        );

        final box = tester.widget<AnimatedStyledBox>(
          find.byType(AnimatedStyledBox),
        );
        expect(
          box.style?.animationStyle?.duration,
          const Duration(milliseconds: 100),
        );
      });
    }
  });
}
