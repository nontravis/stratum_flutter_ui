import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/focus_spread.dart';
import 'package:stratum_ui/src/components/common/ink_well.dart';
import 'package:stratum_ui/src/themes/constant/focus_type.dart';
import 'package:stratum_ui/src/themes/theme_data.dart';

import 'fakes/fake_stratum_theme.dart';

const _box = SizedBox(width: 40, height: 20);

void _noop() {}

class _Probe extends StatefulWidget {
  const new();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) => _box;
}

Finder get _overlay => find.byWidgetPredicate(
  (widget) =>
      widget is DecoratedBox &&
      widget.position == DecorationPosition.foreground,
);

/// The overlay color, or null when the overlay paints nothing.
Color? _overlayColor(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(_overlay);
  final color = (box.decoration as BoxDecoration).color;
  return color == null || color.a == 0 ? null : color;
}

bool _ring(WidgetTester tester) =>
    tester.widget<FocusSpread>(find.byType(FocusSpread)).focus;

void _useHighlightStrategy(FocusHighlightStrategy strategy) {
  FocusManager.instance.highlightStrategy = strategy;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );
}

WidgetStatesController _states(Set<WidgetState> value) {
  final controller = WidgetStatesController(value);
  addTearDown(controller.dispose);
  return controller;
}

FocusNode _node() {
  final node = FocusNode();
  addTearDown(node.dispose);
  return node;
}

Future<TestGesture> _mouse(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await tester.pump();
  return gesture;
}

void main() {
  group('StratumInkWell overlay', () {
    testWidgets('an idle overlay has no color to paint', (tester) async {
      await tester.pumpWidget(
        themedHost(const StratumInkWell(onTap: _noop, child: _box)),
      );

      final box = tester.widget<DecoratedBox>(_overlay);
      expect((box.decoration as BoxDecoration).color, isNull);
    });

    testWidgets('a hovered state paints overlayHover', (tester) async {
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(
            onTap: _noop,
            statesController: _states({WidgetState.hovered}),
            child: _box,
          ),
        ),
      );

      expect(_overlayColor(tester), fakeHover);
    });

    testWidgets('pressed wins over hovered', (tester) async {
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(
            onTap: _noop,
            statesController: _states({
              WidgetState.hovered,
              WidgetState.pressed,
            }),
            child: _box,
          ),
        ),
      );

      expect(_overlayColor(tester), fakeActive);
    });

    testWidgets('disabled paints nothing', (tester) async {
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(
            onTap: _noop,
            disabled: true,
            statesController: _states({
              WidgetState.hovered,
              WidgetState.pressed,
            }),
            child: _box,
          ),
        ),
      );

      expect(_overlayColor(tester), isNull);
    });

    testWidgets('disabledPressAnimation paints nothing', (tester) async {
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(
            onTap: _noop,
            disabledPressAnimation: true,
            statesController: _states({WidgetState.pressed}),
            child: _box,
          ),
        ),
      );

      expect(_overlayColor(tester), isNull);
    });

    testWidgets('no activation callback paints nothing', (tester) async {
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(
            onHover: (_) {},
            statesController: _states({WidgetState.hovered}),
            child: _box,
          ),
        ),
      );

      expect(_overlayColor(tester), isNull);
    });

    testWidgets('a new theme changes the overlay color', (tester) async {
      final states = _states({WidgetState.hovered});
      Widget build(StratumThemeData theme) => themedHost(
        StratumInkWell(onTap: _noop, statesController: states, child: _box),
        theme: theme,
      );
      const next = Color(0x33000000);

      await tester.pumpWidget(build(fakeTheme));
      await tester.pumpWidget(build(FakeStratumTheme(hover: next)));
      await tester.pumpAndSettle();

      expect(_overlayColor(tester), next);
    });

    testWidgets('animates for 100 ms with easeInOutSine', (tester) async {
      await tester.pumpWidget(
        themedHost(const StratumInkWell(onTap: _noop, child: _box)),
      );

      final tween = tester.widget<TweenAnimationBuilder<Color?>>(
        find.byType(TweenAnimationBuilder<Color?>),
      );
      expect(tween.duration, const Duration(milliseconds: 100));
      expect(tween.curve, Curves.easeInOutSine);
    });

    testWidgets('paints over the child, inside InkWell', (tester) async {
      await tester.pumpWidget(
        themedHost(const StratumInkWell(onTap: _noop, child: _Probe())),
      );

      expect(
        find.descendant(of: find.byType(InkWell), matching: _overlay),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _overlay, matching: find.byType(_Probe)),
        findsOneWidget,
      );
    });

    testWidgets('turning disabled on while pressed clears the overlay', (
      tester,
    ) async {
      final states = _states({WidgetState.hovered, WidgetState.pressed});
      Widget build({required bool disabled}) => themedHost(
        StratumInkWell(
          onTap: _noop,
          disabled: disabled,
          statesController: states,
          child: _box,
        ),
      );

      await tester.pumpWidget(build(disabled: false));
      await tester.pumpWidget(build(disabled: true));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_overlayColor(tester), isNull);
    });

    testWidgets('a new statesController drives the overlay', (tester) async {
      final first = _states({WidgetState.hovered});
      final second = _states({});
      Widget build(WidgetStatesController states) => themedHost(
        StratumInkWell(onTap: _noop, statesController: states, child: _box),
      );

      await tester.pumpWidget(build(first));
      await tester.pumpWidget(build(second));
      await tester.pumpAndSettle();
      expect(_overlayColor(tester), isNull);

      first.update(WidgetState.pressed, true);
      await tester.pumpAndSettle();
      expect(_overlayColor(tester), isNull);

      second.update(WidgetState.hovered, true);
      await tester.pumpAndSettle();
      expect(_overlayColor(tester), fakeHover);
    });

    testWidgets('a real hover and press drive the overlay', (tester) async {
      await tester.pumpWidget(
        themedHost(const StratumInkWell(onTap: _noop, child: _box)),
      );
      final center = tester.getCenter(find.byType(StratumInkWell));
      final mouse = await _mouse(tester);

      await mouse.moveTo(center);
      await tester.pumpAndSettle();
      expect(_overlayColor(tester), fakeHover);

      await mouse.down(center);
      await tester.pump(kPressTimeout);
      await tester.pumpAndSettle();
      expect(_overlayColor(tester), fakeActive);

      await mouse.up();
      await tester.pumpAndSettle();
      expect(_overlayColor(tester), fakeHover);
    });

    testWidgets('returning to the internal controller drops a stale hover', (
      tester,
    ) async {
      final caller = _states({});
      Widget build(WidgetStatesController? states) => themedHost(
        StratumInkWell(onTap: _noop, statesController: states, child: _box),
      );
      await tester.pumpWidget(build(null));
      final mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byType(StratumInkWell)));
      await tester.pumpAndSettle();
      expect(_overlayColor(tester), fakeHover);

      await tester.pumpWidget(build(caller));
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      await tester.pumpWidget(build(null));
      await tester.pumpAndSettle();

      expect(_overlayColor(tester), isNull);
    });

    testWidgets('a directional radius paints under right-to-left text', (
      tester,
    ) async {
      final node = _node();
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(
            onTap: _noop,
            focusNode: node,
            focusType: FocusType.focused,
            borderRadius: const BorderRadiusDirectional.only(
              topStart: Radius.circular(8),
            ),
            statesController: _states({WidgetState.hovered}),
            child: _box,
          ),
          textDirection: TextDirection.rtl,
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_overlayColor(tester), fakeHover);
      expect(_ring(tester), isTrue);
    });

    testWidgets('toggling disabled keeps the child State', (tester) async {
      Widget build({required bool disabled}) => themedHost(
        StratumInkWell(
          onTap: _noop,
          onHover: (_) {},
          disabled: disabled,
          child: const _Probe(),
        ),
      );

      await tester.pumpWidget(build(disabled: false));
      final before = tester.state(find.byType(_Probe));
      await tester.pumpWidget(build(disabled: true));

      expect(tester.state(find.byType(_Probe)), same(before));
    });

    testWidgets('toggling onHover keeps the child State', (tester) async {
      Widget build(ValueChanged<bool>? onHover) => themedHost(
        StratumInkWell(onTap: _noop, onHover: onHover, child: const _Probe()),
      );

      await tester.pumpWidget(build(null));
      final before = tester.state(find.byType(_Probe));
      await tester.pumpWidget(build((_) {}));

      expect(tester.state(find.byType(_Probe)), same(before));
    });
  });

  group('StratumInkWell focus', () {
    testWidgets('unmounting leaves a caller focusNode usable', (tester) async {
      final node = _node();
      await tester.pumpWidget(
        themedHost(StratumInkWell(onTap: _noop, focusNode: node, child: _box)),
      );
      await tester.pumpWidget(themedHost(_box));

      expect(() => node.addListener(_noop), returnsNormally);
    });

    testWidgets('the focus node swaps between internal and caller', (
      tester,
    ) async {
      final node = _node();
      Widget build(FocusNode? focusNode) => themedHost(
        StratumInkWell(onTap: _noop, focusNode: focusNode, child: _box),
      );

      await tester.pumpWidget(build(null));
      await tester.pumpWidget(build(node));
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue);

      await tester.pumpWidget(build(null));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(node.hasFocus, isFalse);
    });

    testWidgets('focusedVisible shows the ring only in traditional mode', (
      tester,
    ) async {
      _useHighlightStrategy(FocusHighlightStrategy.alwaysTraditional);
      final node = _node();
      await tester.pumpWidget(
        themedHost(StratumInkWell(onTap: _noop, focusNode: node, child: _box)),
      );

      node.requestFocus();
      await tester.pumpAndSettle();
      expect(_ring(tester), isTrue);

      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      await tester.pump();
      expect(_ring(tester), isFalse);
    });

    testWidgets('focused takes focus on tap and shows the ring', (
      tester,
    ) async {
      _useHighlightStrategy(FocusHighlightStrategy.alwaysTouch);
      final node = _node();
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(
            onTap: _noop,
            focusNode: node,
            focusType: FocusType.focused,
            child: _box,
          ),
        ),
      );

      await tester.tap(find.byType(StratumInkWell));
      await tester.pump();

      expect(node.hasFocus, isTrue);
      expect(_ring(tester), isTrue);
    });

    testWidgets('focusedVisible leaves focus on another node after a tap', (
      tester,
    ) async {
      final other = _node();
      await tester.pumpWidget(
        themedHost(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Focus(
                focusNode: other,
                child: const SizedBox(width: 10, height: 10),
              ),
              const StratumInkWell(onTap: _noop, child: _box),
            ],
          ),
        ),
      );
      other.requestFocus();
      await tester.pump();

      await tester.tap(find.byType(StratumInkWell));
      await tester.pump();

      expect(other.hasFocus, isTrue);
    });

    testWidgets('none cannot take focus and has no ring', (tester) async {
      final node = _node();
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(
            onTap: _noop,
            focusNode: node,
            focusType: FocusType.none,
            child: _box,
          ),
        ),
      );

      node.requestFocus();
      await tester.pump();

      expect(node.hasFocus, isFalse);
      expect(find.byType(FocusSpread), findsNothing);
    });

    testWidgets('invisible takes focus and has no ring', (tester) async {
      final node = _node();
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(
            onTap: _noop,
            focusNode: node,
            focusType: FocusType.invisible,
            child: _box,
          ),
        ),
      );

      node.requestFocus();
      await tester.pump();

      expect(node.hasFocus, isTrue);
      expect(find.byType(FocusSpread), findsNothing);
    });

    testWidgets('disabled cannot take focus', (tester) async {
      _useHighlightStrategy(FocusHighlightStrategy.alwaysTraditional);
      final node = _node();
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(
            onTap: _noop,
            disabled: true,
            focusNode: node,
            child: _box,
          ),
        ),
      );

      node.requestFocus();
      await tester.pump();

      expect(node.hasFocus, isFalse);
      expect(_ring(tester), isFalse);
    });

    testWidgets('onFocusChange reports each change', (tester) async {
      final node = _node();
      final changes = <bool>[];
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(
            onTap: _noop,
            focusNode: node,
            onFocusChange: changes.add,
            child: _box,
          ),
        ),
      );

      node.requestFocus();
      await tester.pump();
      node.unfocus();
      await tester.pump();

      expect(changes, [true, false]);
    });
  });

  group('StratumInkWell semantics', () {
    testWidgets('an activation callback gives an enabled button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(const StratumInkWell(onTap: _noop, child: _box)),
      );

      expect(
        tester.getSemantics(find.byType(StratumInkWell)),
        isSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('disabled gives a dimmed button with no action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(
          const StratumInkWell(onTap: _noop, disabled: true, child: _box),
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

    testWidgets('onHover alone gives no button', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(StratumInkWell(onHover: (_) {}, child: _box)),
      );

      expect(
        tester.getSemantics(find.byType(StratumInkWell)),
        isSemantics(isButton: false, hasEnabledState: false),
      );
      handle.dispose();
    });

    testWidgets('semantics hands the role to the caller', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(
          const StratumInkWell(
            onTap: _noop,
            semantics: SemanticsProperties(checked: true),
            child: _box,
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(StratumInkWell)),
        isSemantics(
          isButton: false,
          hasCheckedState: true,
          isChecked: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('excludeFromSemantics adds nothing', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(
          const StratumInkWell(
            onTap: _noop,
            excludeFromSemantics: true,
            child: _box,
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(StratumInkWell)),
        isSemantics(isButton: false, hasTapAction: false),
      );
      handle.dispose();
    });

    testWidgets('excludeFromSemantics keeps the caller semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(
          const StratumInkWell(
            onTap: _noop,
            excludeFromSemantics: true,
            semantics: SemanticsProperties(label: 'Open settings'),
            child: _box,
          ),
        ),
      );

      expect(find.bySemanticsLabel('Open settings'), findsOneWidget);
      handle.dispose();
    });
  });

  group('StratumInkWell gestures', () {
    testWidgets('tap, long press, and secondary tap call back', (
      tester,
    ) async {
      final calls = <String>[];
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(
            onTap: () => calls.add('tap'),
            onLongPress: () => calls.add('long'),
            onSecondaryTap: () => calls.add('secondary'),
            child: _box,
          ),
        ),
      );
      final target = find.byType(StratumInkWell);

      await tester.tap(target);
      await tester.pumpAndSettle();
      await tester.longPress(target);
      await tester.pumpAndSettle();
      await tester.tap(
        target,
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      expect(calls, ['tap', 'long', 'secondary']);
    });

    testWidgets('a double tap calls onDoubleTap', (tester) async {
      var count = 0;
      await tester.pumpWidget(
        themedHost(StratumInkWell(onDoubleTap: () => count++, child: _box)),
      );
      final target = find.byType(StratumInkWell);

      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(target);
      await tester.pumpAndSettle();

      expect(count, 1);
    });

    testWidgets('disabled calls nothing', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(
            onTap: () => calls.add('tap'),
            onLongPress: () => calls.add('long'),
            disabled: true,
            child: _box,
          ),
        ),
      );
      final target = find.byType(StratumInkWell);

      await tester.tap(target);
      await tester.longPress(target);
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
    });

    testWidgets('Enter calls onTap on a focused widget', (tester) async {
      var taps = 0;
      final node = _node();
      await tester.pumpWidget(
        themedHost(
          Shortcuts(
            shortcuts: WidgetsApp.defaultShortcuts,
            child: StratumInkWell(
              onTap: () => taps++,
              focusNode: node,
              child: _box,
            ),
          ),
        ),
      );
      node.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('onHover alone reports enter and exit', (tester) async {
      final hovers = <bool>[];
      await tester.pumpWidget(
        themedHost(StratumInkWell(onHover: hovers.add, child: _box)),
      );
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      await gesture.moveTo(tester.getCenter(find.byType(StratumInkWell)));
      await tester.pump();
      await gesture.moveTo(Offset.zero);
      await tester.pump();

      expect(hovers, [true, false]);
    });
  });
}
