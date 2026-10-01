import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/ink_well.dart';
import 'package:stratum_ui/src/components/common/layout/container_layout.dart';
import 'package:stratum_ui/src/components/common/layout/gesture_column_layout.dart';
import 'package:stratum_ui/src/components/common/layout/gesture_container_layout.dart';
import 'package:stratum_ui/src/components/common/layout/gesture_row_layout.dart';
import 'package:stratum_ui/src/components/common/layout/gesture_stack_layout.dart';
import 'package:stratum_ui/src/components/common/layout/gesture_wrap_layout.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';

import '../fakes/fake_stratum_theme.dart';

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

typedef _Root =
    Widget Function({GestureTapCallback? onTap, WidgetStyle? style});

final _roots = <String, _Root>{
  'GestureStackLayout': ({onTap, style}) => GestureStackLayout(
    onTap: onTap,
    style: style,
    children: const [_Probe()],
  ),
  'GestureWrapLayout': ({onTap, style}) => GestureWrapLayout(
    onTap: onTap,
    style: style,
    children: const [_Probe()],
  ),
};

typedef _Build =
    Widget Function({
      GestureTapCallback? onTap,
      GestureTapCallback? onSecondaryTap,
      bool disabled,
    });

final _layouts = <String, _Build>{
  'GestureContainerLayout': ({onTap, onSecondaryTap, disabled = false}) =>
      GestureContainerLayout(
        onTap: onTap,
        onSecondaryTap: onSecondaryTap,
        disabled: disabled,
        child: _child,
      ),
  'GestureColumnLayout': ({onTap, onSecondaryTap, disabled = false}) =>
      GestureColumnLayout(
        onTap: onTap,
        onSecondaryTap: onSecondaryTap,
        disabled: disabled,
        mainAxisSize: MainAxisSize.min,
        children: const [_child],
      ),
  'GestureRowLayout': ({onTap, onSecondaryTap, disabled = false}) =>
      GestureRowLayout(
        onTap: onTap,
        onSecondaryTap: onSecondaryTap,
        disabled: disabled,
        mainAxisSize: MainAxisSize.min,
        children: const [_child],
      ),
  'GestureStackLayout': ({onTap, onSecondaryTap, disabled = false}) =>
      GestureStackLayout(
        onTap: onTap,
        onSecondaryTap: onSecondaryTap,
        disabled: disabled,
        children: const [_child],
      ),
  'GestureWrapLayout': ({onTap, onSecondaryTap, disabled = false}) =>
      GestureWrapLayout(
        onTap: onTap,
        onSecondaryTap: onSecondaryTap,
        disabled: disabled,
        children: const [_child],
      ),
};

void main() {
  group('GestureContainerLayout', () {
    testWidgets('keeps semantics inside the box without callbacks', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(
          const GestureContainerLayout(
            semantics: SemanticsProperties(label: 'card'),
            child: _child,
          ),
        ),
      );

      expect(find.byType(StratumInkWell), findsNothing);
      final box = tester.widget<ContainerLayout>(find.byType(ContainerLayout));
      expect(box.semantics, isNull);
      expect(find.bySemanticsLabel('card'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('toggling onTap with semantics keeps the child State', (
      tester,
    ) async {
      Widget build(GestureTapCallback? onTap) => themedHost(
        GestureContainerLayout(
          semantics: const SemanticsProperties(label: 'card'),
          onTap: onTap,
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
          const GestureContainerLayout(
            style: WidgetStyle(
              width: 40,
              height: 20,
              margin: EdgeInsets.all(8),
            ),
            onTap: _noop,
            child: SizedBox.expand(),
          ),
        ),
      );

      expect(tester.getSize(find.byType(StratumInkWell)), const Size(40, 20));
      expect(
        tester.getSize(find.byType(GestureContainerLayout)),
        const Size(56, 36),
      );
    });

    testWidgets('puts the ink well under the rotation', (tester) async {
      await tester.pumpWidget(
        themedHost(
          const GestureContainerLayout(
            rotate: 45,
            onTap: _noop,
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
          const GestureContainerLayout(
            style: WidgetStyle(borderRadius: radius),
            semantics: SemanticsProperties(label: 'card'),
            onTap: _noop,
            child: _child,
          ),
        ),
      );

      final inkWell = tester.widget<StratumInkWell>(
        find.byType(StratumInkWell),
      );
      expect(inkWell.borderRadius, radius);
      expect(inkWell.semantics?.label, 'card');
      final box = tester.widget<ContainerLayout>(find.byType(ContainerLayout));
      expect(box.semantics, isNull);
    });
  });

  group('gesture layouts', () {
    for (final MapEntry(key: name, value: build) in _layouts.entries) {
      testWidgets('$name forwards onSecondaryTap', (tester) async {
        var count = 0;
        await tester.pumpWidget(
          themedHost(build(onSecondaryTap: () => count++)),
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
          themedHost(build(onTap: _noop, disabled: true)),
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
    }
  });

  group('stack and wrap', () {
    for (final MapEntry(key: name, value: build) in _roots.entries) {
      testWidgets('$name keeps the children State when onTap toggles', (
        tester,
      ) async {
        await tester.pumpWidget(themedHost(build()));
        final before = tester.state(find.byType(_Probe));
        await tester.pumpWidget(themedHost(build(onTap: _noop)));

        expect(tester.state(find.byType(_Probe)), same(before));
      });

      testWidgets('$name animates a style over 100 ms without callbacks', (
        tester,
      ) async {
        await tester.pumpWidget(
          themedHost(build(style: const WidgetStyle(width: 40, height: 20))),
        );

        final box = tester.widget<ContainerLayout>(
          find.byType(ContainerLayout),
        );
        expect(
          box.style?.animationStyle?.duration,
          const Duration(milliseconds: 100),
        );
      });
    }
  });
}
