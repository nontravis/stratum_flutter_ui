# StratumInkWell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `StratumInkWell`, the design system's one tap surface, and rebuild `GestureContainerLayout` and the four gesture layouts on it with one callback naming convention.

**Architecture:** `StratumInkWell` wraps `InkWell` with ink turned off, paints a flat hover and press overlay over its child from the `WidgetStatesController`, draws a `FocusSpread` ring per `FocusType`, and adds a container semantics node with a button role and a disabled flag. `AnimatedStyledBox` gains a `boxBuilder` hook between its size constraints and its margin, and `GestureContainerLayout` passes `StratumInkWell` through it, so the overlay, ring, and hit area match the styled box.

**Tech Stack:** Flutter 3.47.3, Dart ^3.13.3, flutter_test, very_good_analysis 11.

**Spec:** `docs/superpowers/specs/2026-10-01-stratum-ink-well-design.md` (sections 2 to 9, with the planning amendments in section 12)

## Global Constraints

- Work in the main working tree, not a git worktree: it holds owner work in progress, and other sessions edit this repository.
- Run tests with `flutter test --no-pub <path>`.
- Lints come from very_good_analysis 11 with the overrides in `analysis_options.yaml`: package imports in `lib/`, sorted directives, constructors before fields, lines at most 80 characters, single quotes. `always_put_required_named_parameters_first` is ignored.
- New and fully replaced classes use the `const new(` constructor form.
- `stratum_ink_well.dart` imports only the libraries it uses. The gesture layout files keep their `package:stratum_ui/src/src.dart` import.
- Primitive callbacks are `onTap`, `onDoubleTap`, `onLongPress`, `onSecondaryTap`. No `onSecondaryPress` or `onPress` may remain under `lib/src/components/common/layout/`.
- Overlay: `theme.color.overlayHover` while hovered, `theme.color.overlayActive` while pressed, animated over 100 ms with `Curves.easeInOutSine`. The ring uses the `FocusSpread` default color.
- The `lib` baseline is 8 analyzer errors, all in `custom_scroll_view.dart`, `grid_view.dart`, and `list_view.dart` (owner work in progress). Never edit those files; the count must stay 8.
- Commit with explicit paths: `git add -- <paths>` then `git commit -m "<message>" -- <paths>`. Never commit `lib/stratum_ui.dart`, `lib/src/src.dart`, `lib/src/components/common/common.dart`, or `lib/src/components/common/focus_spread.dart` (untracked owner file that `stratum_ink_well.dart` imports).
- Some commits absorb owner edits already in the tree, which this plan keeps: the `easeInOutSine` default and its doc in `animated_styled_box.dart`, the curve pin test in `animated_styled_box_test.dart`, the barrel import in `container_layout.dart`, the monitor import path in `container_layout_test.dart`, and formatting in `gesture_container_layout.dart` and `gesture_column_layout.dart`.
- Tests that change the theme swap `lightTheme`: `StratumThemeApplication.updateShouldNotify` compares only `lightTheme`.
- Conventional Commits with a scope; no `Co-Authored-By` line and no AI attribution.

## Review Focus

- `disabled` turning true while the controller holds `pressed` must clear the overlay without a "setState() called during build" error, because `InkWell` updates the controller inside its own `didUpdateWidget`. Pinned in Task 1.
- A caller that replaces `statesController` must see the overlay follow the new controller and ignore the old one. Pinned in Task 1.
- A `BorderRadiusDirectional` under right-to-left text must paint the overlay and ring without error. Pinned in Task 1.
- Toggling `disabled` must keep the child's `State`, so a form field or animation inside the tap surface survives. Pinned in Task 1.
- A gesture layout with `semantics` and no callback must keep its semantics on the plain `ContainerLayout`. Pinned in Task 3.

---

### Task 1: StratumInkWell

**Files:**
- Create: `test/src/components/common/fakes/fake_stratum_theme.dart`
- Create: `test/src/components/common/stratum_ink_well_test.dart`
- Create: `lib/src/components/common/stratum_ink_well.dart`

**Interfaces:**
- Consumes: `FocusSpread({required Widget child, BorderRadiusGeometry? borderRadius, double spread, bool focus, Color? color})` from `focus_spread.dart`; `FocusType { focused, focusedVisible, none, invisible }` from `themes/constant/focus_type.dart`; `context.theme.color.overlayHover` and `.overlayActive` from `extensions/context_extension.dart`.
- Produces: `StratumInkWell` with the constructor in step 4. `test/src/components/common/fakes/fake_stratum_theme.dart` exports `fakeHover`, `fakeActive`, `FakeStratumTheme({Color hover, Color active})`, `fakeTheme`, and `Widget themedHost(Widget child, {StratumThemeData? theme, TextDirection textDirection})`; Task 3 reuses them.

- [ ] **Step 1: Write the fake theme helper**

Create `test/src/components/common/fakes/fake_stratum_theme.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/color/transparent.dart';
import 'package:stratum_ui/src/themes/theme_application.dart';
import 'package:stratum_ui/src/themes/theme_color.dart';
import 'package:stratum_ui/src/themes/theme_data.dart';

/// Hover overlay color of [fakeTheme].
const fakeHover = Color(0x11000000);

/// Press overlay color of [fakeTheme].
const fakeActive = Color(0x22000000);

class _FakeTransparent extends Fake implements TransparentColors {
  @override
  Color get t0 => const Color(0x00000000);
}

class _FakeColors extends Fake implements BaseThemeColor {
  new(this.overlayHover, this.overlayActive);

  @override
  final Color overlayHover;

  @override
  final Color overlayActive;

  @override
  Color get borderBrand => const Color(0xFF0000FF);

  @override
  TransparentColors get transparent => _FakeTransparent();
}

/// A theme that answers only what the interaction widgets read.
class FakeStratumTheme extends Fake implements StratumThemeData {
  new({Color hover = fakeHover, Color active = fakeActive})
    : color = _FakeColors(hover, active);

  @override
  final BaseThemeColor color;
}

/// The default theme of [themedHost].
final fakeTheme = FakeStratumTheme();

/// Places [child] in a [Center] under a [StratumThemeApplication] and a
/// [Directionality].
Widget themedHost(
  Widget child, {
  StratumThemeData? theme,
  TextDirection textDirection = TextDirection.ltr,
}) {
  return StratumThemeApplication(
    themeMode: ThemeMode.light,
    lightTheme: theme ?? fakeTheme,
    darkTheme: null,
    child: Directionality(
      textDirection: textDirection,
      child: Center(child: child),
    ),
  );
}
```

- [ ] **Step 2: Write the failing tests**

Create `test/src/components/common/stratum_ink_well_test.dart`:

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/focus_spread.dart';
import 'package:stratum_ui/src/components/common/stratum_ink_well.dart';
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

Color? _overlayColor(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(_overlay);
  return (box.decoration as BoxDecoration).color;
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

void main() {
  group('StratumInkWell overlay', () {
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
      await tester.pump();
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
        containsSemantics(
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
        containsSemantics(
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
        containsSemantics(isButton: false, hasEnabledState: false),
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
        containsSemantics(
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
        containsSemantics(isButton: false, hasTapAction: false),
      );
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
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test --no-pub test/src/components/common/stratum_ink_well_test.dart`
Expected: FAIL at load with `Error when reading 'lib/src/components/common/stratum_ink_well.dart'` (the file does not exist yet).

- [ ] **Step 4: Write the implementation**

Create `lib/src/components/common/stratum_ink_well.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:stratum_ui/src/components/common/focus_spread.dart';
import 'package:stratum_ui/src/extensions/context_extension.dart';
import 'package:stratum_ui/src/themes/constant/focus_type.dart';

/// The tap surface of the design system.
///
/// Builds on [InkWell] for gestures, keyboard activation, focus, and hover,
/// and adds what [InkWell] leaves out:
///
/// * a flat overlay over [child]: the theme's `overlayHover` while hovered
///   and `overlayActive` while pressed;
/// * a [FocusSpread] ring, shown per [focusType];
/// * a semantics node with a button role and a disabled flag.
///
/// Primitives name callbacks after the gesture ([onTap]); components built
/// on this widget name theirs after the intent (`onPressed`).
class StratumInkWell extends StatefulWidget {
  const new({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.onHover,
    this.onHighlightChanged,
    this.disabled = false,
    this.statesController,
    this.borderRadius,
    this.disabledPressAnimation = false,
    this.mouseCursor,
    this.focusNode,
    this.focusType = FocusType.focusedVisible,
    this.showFocusOnPrimary = true,
    this.canRequestFocus = true,
    this.autofocus = false,
    this.onFocusChange,
    this.semantics,
    this.excludeFromSemantics = false,
    this.enableFeedback = true,
  });

  final Widget child;
  final GestureTapCallback? onTap;
  final GestureTapCallback? onDoubleTap;
  final GestureLongPressCallback? onLongPress;
  final GestureTapCallback? onSecondaryTap;

  /// Called with true when a pointer enters and false when it leaves, also
  /// when no activation callback is set.
  final ValueChanged<bool>? onHover;
  final ValueChanged<bool>? onHighlightChanged;

  /// Turns off every callback, the overlay, the ring, and focus; semantics
  /// then report a disabled button.
  final bool disabled;

  /// Receives the interaction states from [InkWell] and drives the overlay.
  ///
  /// A controller that starts with a state, for example
  /// `{WidgetState.hovered}`, shows that state without a pointer.
  final WidgetStatesController? statesController;

  /// Shape of the overlay and the focus ring.
  final BorderRadiusGeometry? borderRadius;

  /// Turns off the hover and press overlay.
  final bool disabledPressAnimation;
  final MouseCursor? mouseCursor;
  final FocusNode? focusNode;

  /// Whether this widget takes focus, when it shows the ring, and whether
  /// a tap requests focus ([FocusType.focused] only).
  final FocusType focusType;

  /// Shows the ring only while this widget holds primary focus.
  final bool showFocusOnPrimary;
  final bool canRequestFocus;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;

  /// Replaces the default button role; `container` and `enabled` are still
  /// set.
  final SemanticsProperties? semantics;
  final bool excludeFromSemantics;

  /// Plays the platform click and long-press feedback.
  final bool enableFeedback;

  @override
  State<StratumInkWell> createState() => _StratumInkWellState();
}

class _StratumInkWellState extends State<StratumInkWell> {
  // Created on first use and kept until dispose, as TextField does, so a
  // node that InkWell's Focus still holds is never disposed mid-update.
  FocusNode? _internalFocusNode;
  WidgetStatesController? _internalStatesController;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  WidgetStatesController get _statesController =>
      widget.statesController ??
      (_internalStatesController ??= WidgetStatesController());

  bool get _hasActivation =>
      widget.onTap != null ||
      widget.onDoubleTap != null ||
      widget.onLongPress != null ||
      widget.onSecondaryTap != null;

  bool get _canFocus =>
      !widget.disabled &&
      widget.focusType != FocusType.none &&
      widget.canRequestFocus;

  bool get _hasRing =>
      widget.focusType == FocusType.focused ||
      widget.focusType == FocusType.focusedVisible;

  bool get _ringVisible {
    if (widget.disabled) return false;
    final node = _focusNode;
    final focused = widget.showFocusOnPrimary
        ? node.hasPrimaryFocus
        : node.hasFocus;
    if (!focused) return false;
    return switch (widget.focusType) {
      FocusType.focused => true,
      FocusType.focusedVisible =>
        FocusManager.instance.highlightMode ==
            FocusHighlightMode.traditional,
      FocusType.none || FocusType.invisible => false,
    };
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
    FocusManager.instance.addHighlightModeListener(_handleHighlightMode);
  }

  @override
  void didUpdateWidget(StratumInkWell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _internalFocusNode)?.removeListener(
        _handleFocusChange,
      );
      _focusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_handleHighlightMode);
    _focusNode.removeListener(_handleFocusChange);
    _internalFocusNode?.dispose();
    _internalStatesController?.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_hasRing) setState(() {});
  }

  void _handleHighlightMode(FocusHighlightMode mode) {
    if (widget.focusType == FocusType.focusedVisible &&
        _focusNode.hasFocus) {
      setState(() {});
    }
  }

  void _handleTap() {
    if (widget.focusType == FocusType.focused) _focusNode.requestFocus();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.color;
    final disabled = widget.disabled;
    final canFocus = _canFocus;
    final onHover = widget.onHover;

    Widget result = InkWell(
      onTap: disabled || widget.onTap == null ? null : _handleTap,
      onDoubleTap: disabled ? null : widget.onDoubleTap,
      onLongPress: disabled ? null : widget.onLongPress,
      onSecondaryTap: disabled ? null : widget.onSecondaryTap,
      onHighlightChanged: disabled ? null : widget.onHighlightChanged,
      onFocusChange: widget.onFocusChange,
      mouseCursor:
          widget.mouseCursor ??
          (disabled ? SystemMouseCursors.forbidden : null),
      focusNode: _focusNode,
      canRequestFocus: canFocus,
      autofocus: widget.autofocus && canFocus,
      statesController: _statesController,
      enableFeedback: widget.enableFeedback,
      excludeFromSemantics: widget.excludeFromSemantics,
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      child: _StateOverlay(
        states: _statesController,
        hoverColor: colors.overlayHover,
        pressedColor: colors.overlayActive,
        enabled: !disabled && !widget.disabledPressAnimation,
        borderRadius: widget.borderRadius,
        child: widget.child,
      ),
    );
    result = Material(type: MaterialType.transparency, child: result);
    if (onHover != null) {
      // Kept in place while disabled so toggling disabled never changes
      // the structure below.
      result = MouseRegion(
        onEnter: disabled ? null : (_) => onHover(true),
        onExit: disabled ? null : (_) => onHover(false),
        child: result,
      );
    }
    if (_hasRing) {
      result = FocusSpread(
        focus: _ringVisible,
        borderRadius: widget.borderRadius,
        child: result,
      );
    }
    if (!widget.excludeFromSemantics) {
      final properties = widget.semantics;
      if (properties != null) {
        result = Semantics.fromProperties(
          properties: properties,
          child: result,
        );
      }
      final hasActivation = _hasActivation;
      result = Semantics(
        container: true,
        enabled: hasActivation ? !disabled : null,
        button: hasActivation && properties == null ? true : null,
        child: result,
      );
    }
    return result;
  }
}

/// Paints the hover and press overlay over [child] from [states].
///
/// It listens to [states] itself, below [InkWell]: [InkWell] updates the
/// controller inside its own update, and a listener above it would call
/// `setState` while a descendant builds.
class _StateOverlay extends StatelessWidget {
  const new({
    required this.states,
    required this.hoverColor,
    required this.pressedColor,
    required this.enabled,
    required this.borderRadius,
    required this.child,
  });

  static const _duration = Duration(milliseconds: 100);

  final WidgetStatesController states;
  final Color hoverColor;
  final Color pressedColor;
  final bool enabled;
  final BorderRadiusGeometry? borderRadius;
  final Widget child;

  Color? _target(Set<WidgetState> value) {
    if (!enabled || value.contains(WidgetState.disabled)) return null;
    if (value.contains(WidgetState.pressed)) return pressedColor;
    if (value.contains(WidgetState.hovered)) return hoverColor;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: states,
      builder: (context, child) => TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: _target(states.value)),
        duration: _duration,
        curve: Curves.easeInOutSine,
        builder: (context, color, child) => DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(color: color, borderRadius: borderRadius),
          child: child,
        ),
        child: child,
      ),
      child: child,
    );
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test --no-pub test/src/components/common/stratum_ink_well_test.dart`
Expected: PASS, `All tests passed!` (31 tests).

- [ ] **Step 6: Analyze the new files**

Run: `flutter analyze --no-pub lib/src/components/common/stratum_ink_well.dart test/src/components/common/stratum_ink_well_test.dart test/src/components/common/fakes/fake_stratum_theme.dart`
Expected: `No issues found!`. Fix any info or warning the analyzer reports in these three files before you commit.

- [ ] **Step 7: Commit**

```bash
git add -- lib/src/components/common/stratum_ink_well.dart test/src/components/common/stratum_ink_well_test.dart test/src/components/common/fakes/fake_stratum_theme.dart
git commit -m "feat(ink_well): add StratumInkWell with flat overlay, focus ring, and button semantics" -- lib/src/components/common/stratum_ink_well.dart test/src/components/common/stratum_ink_well_test.dart test/src/components/common/fakes/fake_stratum_theme.dart
```

---

### Task 2: boxBuilder on AnimatedStyledBox and ContainerLayout

**Files:**
- Modify: `lib/src/components/common/style/animated_styled_box.dart` (typedef above the class; constructor; field; `_boxKey`; `_buildBox` between the size constraints and the margin)
- Modify: `lib/src/components/common/layout/container_layout.dart` (constructor, field, `AnimatedStyledBox` call)
- Test: `test/src/components/common/style/animated_styled_box_test.dart`
- Test: `test/src/components/common/layout/container_layout_test.dart`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `typedef StyledBoxBuilder = Widget Function(WidgetStyle style, Widget box);` in `animated_styled_box.dart`; `AnimatedStyledBox.boxBuilder` and `ContainerLayout.boxBuilder`, both `StyledBoxBuilder?`. Task 3 passes a `StyledBoxBuilder` to `ContainerLayout`.

- [ ] **Step 1: Write the failing AnimatedStyledBox tests**

In `test/src/components/common/style/animated_styled_box_test.dart`, replace the `_host` function with:

```dart
Widget _host(
  WidgetStyle? style, {
  Widget? child = const SizedBox(width: 40, height: 20),
  double? ratio,
  StyledBoxBuilder? boxBuilder,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: AnimatedStyledBox(
        style: style,
        ratio: ratio,
        boxBuilder: boxBuilder,
        child: child,
      ),
    ),
  );
}
```

Add these declarations below `_fillColor`:

```dart
class _BoxProbe extends StatefulWidget {
  const new({required this.child});

  final Widget child;

  @override
  State<_BoxProbe> createState() => _BoxProbeState();
}

class _BoxProbeState extends State<_BoxProbe> {
  @override
  Widget build(BuildContext context) => widget.child;
}

Widget _probe(WidgetStyle style, Widget box) => _BoxProbe(child: box);
```

Add this group at the end of `main()`:

```dart
  group('AnimatedStyledBox boxBuilder', () {
    testWidgets('wraps the box inside the margin and outside the size', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const WidgetStyle(
            width: 40,
            height: 20,
            margin: EdgeInsets.all(8),
          ),
          boxBuilder: _probe,
        ),
      );

      expect(
        find.ancestor(
          of: find.byType(_BoxProbe),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Padding &&
                widget.padding == const EdgeInsets.all(8),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(_BoxProbe),
          matching: find.byType(ConstrainedBox),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(find.byType(_BoxProbe)), const Size(40, 20));
    });

    testWidgets('keeps the builder State when an Opacity appears', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const WidgetStyle(width: 40, height: 20), boxBuilder: _probe),
      );
      final before = tester.state(find.byType(_BoxProbe));

      await tester.pumpWidget(
        _host(
          const WidgetStyle(width: 40, height: 20, opacity: 0.5),
          boxBuilder: _probe,
        ),
      );

      expect(find.byType(Opacity), findsOneWidget);
      expect(tester.state(find.byType(_BoxProbe)), same(before));
    });

    testWidgets('passes the style of the current frame', (tester) async {
      final radii = <BorderRadiusGeometry?>[];
      Widget record(WidgetStyle style, Widget box) {
        radii.add(style.borderRadius);
        return box;
      }

      const linear = AnimationStyle(
        duration: Duration(milliseconds: 100),
        curve: Curves.linear,
      );

      await tester.pumpWidget(
        _host(
          const WidgetStyle(
            borderRadius: BorderRadius.zero,
            animationStyle: linear,
          ),
          boxBuilder: record,
        ),
      );
      await tester.pumpWidget(
        _host(
          const WidgetStyle(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            animationStyle: linear,
          ),
          boxBuilder: record,
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(radii.last, const BorderRadius.all(Radius.circular(4)));
    });

    testWidgets('applies with a null style', (tester) async {
      await tester.pumpWidget(_host(null, boxBuilder: _probe));

      expect(find.byType(_BoxProbe), findsOneWidget);
    });
  });
```

- [ ] **Step 2: Write the failing ContainerLayout test**

In `test/src/components/common/layout/container_layout_test.dart`, add this test inside the `ContainerLayout` group, after `hands style and layout values to AnimatedStyledBox`:

```dart
    testWidgets('hands boxBuilder to AnimatedStyledBox', (tester) async {
      Widget builder(WidgetStyle style, Widget box) => box;

      await tester.pumpWidget(
        _host(
          ContainerLayout(
            boxBuilder: builder,
            child: const SizedBox(width: 40, height: 20),
          ),
        ),
      );

      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.boxBuilder, builder);
    });
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test --no-pub test/src/components/common/style/animated_styled_box_test.dart test/src/components/common/layout/container_layout_test.dart`
Expected: FAIL at compile with `Type 'StyledBoxBuilder' not found` and `No named parameter with the name 'boxBuilder'`.

- [ ] **Step 4: Add boxBuilder to AnimatedStyledBox**

In `lib/src/components/common/style/animated_styled_box.dart`, insert above the class doc comment (`/// Paints a [WidgetStyle] around [child] ...`):

```dart
/// Wraps the styled box of an [AnimatedStyledBox] with the style of the
/// current animation frame; see [AnimatedStyledBox.boxBuilder].
typedef StyledBoxBuilder = Widget Function(WidgetStyle style, Widget box);

```

Replace the constructor parameter list:

```dart
  new({
    super.key,
    this.style,
    this.ratio,
    this.transform,
    this.transformAlignment,
    super.onEnd,
    this.boxBuilder,
    this.child,
  }) : super(
```

Add this field between `final AlignmentGeometry? transformAlignment;` and `final Widget? child;`:

```dart

  /// Wraps the box after its size constraints and before its margin,
  /// transform, and opacity.
  ///
  /// Receives the style of the current animation frame. The result keeps
  /// its State when wrappers above it come and go.
  final StyledBoxBuilder? boxBuilder;
```

In `_AnimatedStyledBoxState`, add below the `_childKey` field:

```dart
  final GlobalKey _boxKey = GlobalKey(debugLabel: 'AnimatedStyledBox.box');
```

In `_buildBox`, replace:

```dart
    final constraints = _constraints(style);
    if (constraints != null) {
      current = ConstrainedBox(constraints: constraints, child: current);
    }
    final margin = style.margin;
```

with:

```dart
    final constraints = _constraints(style);
    if (constraints != null) {
      current = ConstrainedBox(constraints: constraints, child: current);
    }
    final boxBuilder = widget.boxBuilder;
    if (boxBuilder != null) {
      current = KeyedSubtree(
        key: _boxKey,
        child: boxBuilder(style, current),
      );
    }
    final margin = style.margin;
```

- [ ] **Step 5: Forward boxBuilder from ContainerLayout**

In `lib/src/components/common/layout/container_layout.dart`, replace the end of the constructor:

```dart
    this.onEndAnimate,
    this.child,
  });
```

with:

```dart
    this.onEndAnimate,
    this.boxBuilder,
    this.child,
  });
```

Add this field between the `onEndAnimate` field and `final Widget? child;`:

```dart

  /// Wraps the styled box inside its margin, transform, and opacity; see
  /// [AnimatedStyledBox.boxBuilder].
  final StyledBoxBuilder? boxBuilder;
```

In `build`, replace:

```dart
      onEnd: duration > Duration.zero ? onEndAnimate : null,
      child: child,
    );
```

with:

```dart
      onEnd: duration > Duration.zero ? onEndAnimate : null,
      boxBuilder: boxBuilder,
      child: child,
    );
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test --no-pub test/src/components/common/style/ test/src/components/common/layout/`
Expected: PASS, including every existing AnimatedStyledBox and layout test.

- [ ] **Step 7: Analyze the touched files**

Run: `flutter analyze --no-pub lib/src/components/common/style/animated_styled_box.dart lib/src/components/common/layout/container_layout.dart test/src/components/common/style/animated_styled_box_test.dart test/src/components/common/layout/container_layout_test.dart`
Expected: no issue on a line this task added or changed. Issues on untouched lines existed before this task; leave them.

- [ ] **Step 8: Commit**

This commit absorbs the owner's uncommitted edits in these four files (see Global Constraints).

```bash
git add -- lib/src/components/common/style/animated_styled_box.dart lib/src/components/common/layout/container_layout.dart test/src/components/common/style/animated_styled_box_test.dart test/src/components/common/layout/container_layout_test.dart
git commit -m "feat(style): add a boxBuilder hook inside the margin of AnimatedStyledBox" -- lib/src/components/common/style/animated_styled_box.dart lib/src/components/common/layout/container_layout.dart test/src/components/common/style/animated_styled_box_test.dart test/src/components/common/layout/container_layout_test.dart
```

---

### Task 3: Gesture layouts on StratumInkWell

**Files:**
- Modify: `lib/src/components/common/common.dart` (add one export; leave uncommitted)
- Replace: `lib/src/components/common/layout/gesture_container_layout.dart`
- Modify: `lib/src/components/common/layout/gesture_column_layout.dart`, `gesture_row_layout.dart`, `gesture_stack_layout.dart`, `gesture_wrap_layout.dart` (renames; `_hasGestures` in stack and wrap)
- Test: `test/src/components/common/layout/gesture_layout_test.dart`

**Interfaces:**
- Consumes: `StratumInkWell` (Task 1); `StyledBoxBuilder` and `ContainerLayout.boxBuilder` (Task 2); `themedHost` from `test/src/components/common/fakes/fake_stratum_theme.dart` (Task 1).
- Produces: `GestureContainerLayout`, `GestureColumnLayout`, `GestureRowLayout`, `GestureStackLayout`, `GestureWrapLayout` with `onTap` and `onSecondaryTap`; no `onSecondaryPress` or `onPress`.

- [ ] **Step 1: Write the failing tests**

Create `test/src/components/common/layout/gesture_layout_test.dart`:

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
        await tester.pumpWidget(themedHost(build(onTap: _noop, disabled: true)));

        expect(
          tester.getSemantics(find.byType(StratumInkWell)),
          containsSemantics(
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test --no-pub test/src/components/common/layout/gesture_layout_test.dart`
Expected: FAIL at compile with `No named parameter with the name 'onSecondaryTap'`.

- [ ] **Step 3: Export StratumInkWell from the common barrel**

In `lib/src/components/common/common.dart`, add `export 'stratum_ink_well.dart';` between `export 'style/style.dart';` and `export 'web_view/web_view.dart';`. Do not commit this file (owner work in progress); the handoff in Task 4 reports it.

- [ ] **Step 4: Replace GestureContainerLayout**

Replace the whole content of `lib/src/components/common/layout/gesture_container_layout.dart` with:

```dart
import 'package:stratum_ui/src/src.dart';

/// A [ContainerLayout] that reacts to taps, hover, and focus.
///
/// Interaction comes from [StratumInkWell], placed through
/// [ContainerLayout.boxBuilder] inside the style's margin, transform, and
/// opacity, so the overlay, focus ring, and hit area match the styled box.
/// Without any callback it builds a plain [ContainerLayout].
class GestureContainerLayout extends StatelessWidget {
  const new({
    super.key,
    this.style,
    this.ratio,
    this.rotate,
    this.keepAlive = false,
    this.repaintBoundary = false,
    this.debug = false,
    this.transform,
    this.transformAlignment,
    this.onEndAnimate,
    //=== InkWell ===//
    this.disabledPressAnimation = false,
    this.disabled = false,
    this.onTap,
    this.onSecondaryTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onHighlightChanged,
    this.onHover,
    this.mouseCursor,
    this.enableFeedback = true,
    this.excludeFromSemantics = false,
    this.focusNode,
    this.focusType = FocusType.focusedVisible,
    this.showFocusOnPrimary = true,
    this.canRequestFocus = true,
    this.onFocusChange,
    this.autofocus = false,
    this.statesController,
    this.semantics,
    //===============//
    this.child,
  });

  ///========== Frame ==========///
  final double? rotate; // 0-360 degree
  final double? ratio;

  ///========== Layout ==========///
  final AlignmentGeometry? transformAlignment;
  final Matrix4? transform;
  final bool keepAlive;
  final bool repaintBoundary;
  final bool debug;

  ///===== Animate ======///
  final VoidCallback? onEndAnimate;

  ///========== Style ==========///
  /// Style changes animate over 100 ms unless the style sets its own
  /// `animationStyle`, keeping the old `animate: true` default.
  final WidgetStyle? style;

  ///===== InkWell ======///
  final bool disabledPressAnimation;
  final bool disabled;
  final GestureTapCallback? onTap;
  final GestureTapCallback? onSecondaryTap;
  final GestureTapCallback? onDoubleTap;
  final GestureLongPressCallback? onLongPress;
  final ValueChanged<bool>? onHighlightChanged;
  final ValueChanged<bool>? onHover;
  final MouseCursor? mouseCursor;
  final bool enableFeedback;
  final bool excludeFromSemantics;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChange;
  final FocusType focusType;
  final bool showFocusOnPrimary;
  final bool autofocus;
  final bool canRequestFocus;
  final WidgetStatesController? statesController;

  final SemanticsProperties? semantics;

  ///===== Child Widget ======///
  final Widget? child;

  static const _defaultAnimation = AnimationStyle(
    duration: Duration(milliseconds: 100),
  );

  WidgetStyle? get _effectiveStyle {
    final style = this.style;
    if (style == null || style.animationStyle != null) return style;
    return style.copyWith(animationStyle: _defaultAnimation);
  }

  /// Whether any callback asks for [StratumInkWell]. `disabled` does not
  /// count, so a disabled layout still reads as a dimmed button.
  bool get _hasInteraction =>
      onTap != null ||
      onSecondaryTap != null ||
      onDoubleTap != null ||
      onLongPress != null ||
      onHighlightChanged != null ||
      onHover != null ||
      onFocusChange != null;

  @override
  Widget build(BuildContext context) {
    final interactive = _hasInteraction;
    return ContainerLayout(
      style: _effectiveStyle,
      ratio: ratio,
      rotate: rotate,
      transform: transform,
      transformAlignment: transformAlignment,
      keepAlive: keepAlive,
      repaintBoundary: repaintBoundary,
      debug: debug,
      semantics: interactive ? null : semantics,
      onEndAnimate: onEndAnimate,
      boxBuilder: interactive ? _buildInkWell : null,
      child: child,
    );
  }

  Widget _buildInkWell(WidgetStyle style, Widget box) {
    return StratumInkWell(
      borderRadius: style.borderRadius,
      disabled: disabled,
      disabledPressAnimation: disabledPressAnimation,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onSecondaryTap: onSecondaryTap,
      onHover: onHover,
      onHighlightChanged: onHighlightChanged,
      statesController: statesController,
      mouseCursor: mouseCursor,
      focusNode: focusNode,
      focusType: focusType,
      showFocusOnPrimary: showFocusOnPrimary,
      canRequestFocus: canRequestFocus,
      autofocus: autofocus,
      onFocusChange: onFocusChange,
      semantics: semantics,
      excludeFromSemantics: excludeFromSemantics,
      enableFeedback: enableFeedback,
      child: box,
    );
  }
}
```

- [ ] **Step 5: Rename the callbacks in the four other gesture layouts**

Run from the package root:

```bash
perl -pi -e 's/\bonSecondaryPress\b/onSecondaryTap/g; s/\bonPress\b/onTap/g' \
  lib/src/components/common/layout/gesture_column_layout.dart \
  lib/src/components/common/layout/gesture_row_layout.dart \
  lib/src/components/common/layout/gesture_stack_layout.dart \
  lib/src/components/common/layout/gesture_wrap_layout.dart
```

In `gesture_wrap_layout.dart` this also turns `onTap: onPress,` into `onTap: onTap,`.

- [ ] **Step 6: Stop skipping the wrapper for disabled stack and wrap layouts**

In `lib/src/components/common/layout/gesture_stack_layout.dart`, replace:

```dart
  }) : _hasGestures = !disabled && (onTap != null ||
            onSecondaryTap != null ||
            onDoubleTap != null ||
            onLongPress != null ||
            onHighlightChanged != null ||
            onHover != null ||
            onFocusChange != null);
```

with:

```dart
  }) : _hasGestures =
           onTap != null ||
           onSecondaryTap != null ||
           onDoubleTap != null ||
           onLongPress != null ||
           onHighlightChanged != null ||
           onHover != null ||
           onFocusChange != null;
```

In `lib/src/components/common/layout/gesture_wrap_layout.dart`, replace:

```dart
       _hasGestures =
           !disabled &&
           (onTap != null ||
               onSecondaryTap != null ||
               onDoubleTap != null ||
               onLongPress != null ||
               onHighlightChanged != null ||
               onHover != null ||
               onFocusChange != null);
```

with:

```dart
       _hasGestures =
           onTap != null ||
           onSecondaryTap != null ||
           onDoubleTap != null ||
           onLongPress != null ||
           onHighlightChanged != null ||
           onHover != null ||
           onFocusChange != null;
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test --no-pub test/src/components/common/`
Expected: PASS for every test under `test/src/components/common/`, including the 14 tests in `gesture_layout_test.dart`.

- [ ] **Step 8: Check analyzer and names**

Run: `flutter analyze --no-pub lib 2>&1 | grep -E '^\s*error' | wc -l`
Expected: `8`.

Run: `flutter analyze --no-pub lib 2>&1 | grep -E '^\s*error' | grep -vE 'custom_scroll_view|grid_view|list_view'`
Expected: no output.

Run: `flutter analyze --no-pub lib/src/components/common/layout/ test/src/components/common/layout/gesture_layout_test.dart 2>&1 | grep -E 'gesture_'`
Expected: no output (no issue in a gesture file).

Run: `grep -rnE 'onSecondaryPress|\bonPress\b|keyboard\.addHandler' lib/src/components/common/layout/`
Expected: no output.

- [ ] **Step 9: Commit**

Leave `common.dart` out of the commit.

```bash
git add -- lib/src/components/common/layout/gesture_container_layout.dart lib/src/components/common/layout/gesture_column_layout.dart lib/src/components/common/layout/gesture_row_layout.dart lib/src/components/common/layout/gesture_stack_layout.dart lib/src/components/common/layout/gesture_wrap_layout.dart test/src/components/common/layout/gesture_layout_test.dart
git commit -m "refactor(layout): build the gesture layouts on StratumInkWell and rename to onSecondaryTap" -- lib/src/components/common/layout/gesture_container_layout.dart lib/src/components/common/layout/gesture_column_layout.dart lib/src/components/common/layout/gesture_row_layout.dart lib/src/components/common/layout/gesture_stack_layout.dart lib/src/components/common/layout/gesture_wrap_layout.dart test/src/components/common/layout/gesture_layout_test.dart
```

---

### Task 4: Verification and records

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-stratum-ink-well-design.md` (status line)
- Outside the repository: `profile/memory/project_stratum_ui_ink_well.md`, `profile/memory/ROADMAP.md` (under `<workspace>/`)

**Interfaces:**
- Consumes: Tasks 1 to 3.
- Produces: the spec section 9 evidence and the updated records.

- [ ] **Step 1: Run spec section 9 verification**

Run: `flutter test --no-pub test/src/components/common/`
Expected: `All tests passed!`.

Run: `flutter analyze --no-pub lib 2>&1 | grep -E '^\s*error' | grep -vcE 'custom_scroll_view|grid_view|list_view'`
Expected: `0`.

Run: `grep -rnE 'onSecondaryPress|\bonPress\b|keyboard\.addHandler' lib/src/components/common/layout/`
Expected: no output.

- [ ] **Step 2: Mark the spec implemented**

In `docs/superpowers/specs/2026-10-01-stratum-ink-well-design.md`, replace the status line with:

```markdown
- **Status:** Implemented on master on YYYY-MM-DD; planning amendments in section 12.
```

Write today's date in ISO form in place of `YYYY-MM-DD`, then commit:

```bash
git add -- docs/superpowers/specs/2026-10-01-stratum-ink-well-design.md
git commit -m "docs(ink_well): mark the StratumInkWell design implemented" -- docs/superpowers/specs/2026-10-01-stratum-ink-well-design.md
```

- [ ] **Step 3: Update the memory entry and the roadmap**

Append a dated section to `profile/memory/project_stratum_ui_ink_well.md` with the commit range, the test count, and the uncommitted `common.dart` export, and bump `verified:`. Delete the `## stratum-ink-well` phase from `profile/memory/ROADMAP.md` and bump `updated:`.

- [ ] **Step 4: Report the handoff**

Tell the owner, in one message: the commits, the test and analyzer results, and that `lib/src/components/common/common.dart` now carries an uncommitted `export 'stratum_ink_well.dart';` next to the owner's own edits in that file.
