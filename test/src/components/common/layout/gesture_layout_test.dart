import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/layout/container_layout.dart';
import 'package:stratum_ui/src/components/common/layout/gesture_column_layout.dart';
import 'package:stratum_ui/src/components/common/layout/gesture_container_layout.dart';
import 'package:stratum_ui/src/components/common/layout/gesture_row_layout.dart';
import 'package:stratum_ui/src/components/common/layout/gesture_stack_layout.dart';
import 'package:stratum_ui/src/components/common/layout/gesture_wrap_layout.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/components/common/stratum_ink_well.dart';

import '../fakes/fake_stratum_theme.dart';

const _child = SizedBox(width: 40, height: 20);

void _noop() {}

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
    testWidgets('builds a plain ContainerLayout without callbacks', (
      tester,
    ) async {
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
      expect(box.boxBuilder, isNull);
      expect(box.semantics?.label, 'card');
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
}
