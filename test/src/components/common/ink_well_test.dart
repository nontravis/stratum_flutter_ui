import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

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

/// Material localizations whose menu tooltip differs from the default.
class _MenuLocalizations extends DefaultMaterialLocalizations {
  const new();

  @override
  String get showMenuTooltip => 'Open menu';
}

class _MenuLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const new();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture(const _MenuLocalizations());

  @override
  bool shouldReload(_MenuLocalizationsDelegate old) => false;
}

/// [child] under a [MaterialApp], which a [TextField] needs.
Widget _appHost(Widget child) {
  return MaterialApp(home: Material(child: themedHost(child)));
}

Future<void> _controlK(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

const _keyA = SingleActivator(LogicalKeyboardKey.keyA);
const _controlKey = SingleActivator(LogicalKeyboardKey.keyK, control: true);

Future<void> _shiftF10(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.f10);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
}

Future<TestGesture> _mouse(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await tester.pump();
  return gesture;
}

/// The widget types under the one [StratumInkWell], in tree order.
List<String> _surfaceTypes(WidgetTester tester) {
  final types = <String>[];
  void visit(Element element) {
    types.add('${element.widget.runtimeType}');
    element.visitChildElements(visit);
  }

  tester.element(find.byType(StratumInkWell)).visitChildElements(visit);
  return types;
}

/// [_surfaceTypes] of the plain tap path on master `ff3c890`: an activation
/// callback, empty shortcuts, no onSecondaryTap, and [_box] as the child.
const _plainTapPathTypes = [
  'Semantics',
  'FocusSpread',
  'AnimatedContainer',
  'Container',
  'DecoratedBox',
  'Padding',
  'MouseRegion',
  'Material',
  'ClipPath',
  '_ShapeBorderPaint',
  'CustomPaint',
  'NotificationListener<LayoutChangedNotification>',
  '_InkFeatures',
  'AnimatedDefaultTextStyle',
  'DefaultTextStyle',
  'InkWell',
  '_InkResponseStateWidget',
  '_ParentInkResponseProvider',
  'Actions',
  '_ActionsScope',
  'Focus',
  '_FocusInheritedScope',
  'Semantics',
  'MouseRegion',
  'Builder',
  'DefaultSelectionStyle',
  'Semantics',
  'GestureDetector',
  'RawGestureDetector',
  'Listener',
  '_StateOverlay',
  'ListenableBuilder',
  'TweenAnimationBuilder<Color?>',
  'DecoratedBox',
  'SizedBox',
];

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
      await tester.pumpWidget(build(fakeStratumTheme(hover: next)));
      await tester.pumpAndSettle();

      expect(_overlayColor(tester), next);
    });

    testWidgets("us11/fr01: fades over the theme's fast level", (tester) async {
      await tester.pumpWidget(
        themedHost(const StratumInkWell(onTap: _noop, child: _box)),
      );
      final standard = tester.widget<TweenAnimationBuilder<Color?>>(
        find.byType(TweenAnimationBuilder<Color?>),
      );
      expect(standard.duration, const Duration(milliseconds: 125));
      expect(standard.curve, Curves.easeInOutSine);

      await tester.pumpWidget(
        themedHost(
          const StratumInkWell(onTap: _noop, child: _box),
          theme: motionTheme(standard: const StratumNamedCurve('easeOut')),
        ),
      );
      final themed = tester.widget<TweenAnimationBuilder<Color?>>(
        find.byType(TweenAnimationBuilder<Color?>),
      );
      expect(themed.duration, const Duration(milliseconds: 77));
      expect(themed.curve, Curves.easeOut);
    });

    testWidgets("C1: under reduced motion the fade keeps the theme's "
        'duration', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await tester.pumpWidget(
        themedHost(
          const StratumInkWell(onTap: _noop, child: _box),
          theme: motionTheme(),
        ),
      );

      expect(
        tester
            .widget<TweenAnimationBuilder<Color?>>(
              find.byType(TweenAnimationBuilder<Color?>),
            )
            .duration,
        const Duration(milliseconds: 77),
      );
    });

    testWidgets('us11/fr01: a fast level with no duration or curve fades at '
        'zero duration on easeInOutSine', (tester) async {
      final theme = fakeTheme.copyWith(
        animation: StratumAnimation(
          veryFast: StratumAnimation.packageDefault.veryFast,
          fast: const AnimationStyle(),
          normal: StratumAnimation.packageDefault.normal,
          slow: StratumAnimation.packageDefault.slow,
          verySlow: StratumAnimation.packageDefault.verySlow,
          appear: StratumAnimation.packageDefault.appear,
          defaultLevel: StratumMotionLevel.fast,
        ),
      );

      await tester.pumpWidget(
        themedHost(
          const StratumInkWell(onTap: _noop, child: _box),
          theme: theme,
        ),
      );

      final builder = tester.widget<TweenAnimationBuilder<Color?>>(
        find.byType(TweenAnimationBuilder<Color?>),
      );
      expect(builder.duration, Duration.zero);
      expect(builder.curve, Curves.easeInOutSine);
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

    // autofocus has no activation callback and no shortcuts, so it never
    // satisfies tapSurfaceTakesFocus's activation check. autofocus still
    // honors a directional NavigationMode (49a2d6b), which ignores that
    // check (us04/fr03).
    testWidgets(
      '(pin) autofocus with no activation holds focus in directional mode',
      (tester) async {
        final node = _node();
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              navigationMode: NavigationMode.directional,
            ),
            child: themedHost(
              StratumInkWell(
                onHover: (_) {},
                autofocus: true,
                focusNode: node,
                child: _box,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(node.hasFocus, isTrue);
      },
    );

    testWidgets(
      '(pin) autofocus with no activation stays unfocused in traditional '
      'mode',
      (tester) async {
        final node = _node();
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              navigationMode: NavigationMode.traditional,
            ),
            child: themedHost(
              StratumInkWell(
                onHover: (_) {},
                autofocus: true,
                focusNode: node,
                child: _box,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(node.hasFocus, isFalse);
      },
    );
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
    testWidgets('tap, long press, and secondary tap call back', (tester) async {
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
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
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

  group('StratumInkWell context-menu key', () {
    testWidgets('the context-menu key and Shift+F10 call onSecondaryTap', (
      tester,
    ) async {
      var calls = 0;
      final node = _node();
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(
            onSecondaryTap: () => calls++,
            focusNode: node,
            child: _box,
          ),
        ),
      );
      node.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await _shiftF10(tester);

      expect(calls, 2);
    });

    testWidgets('neither key fires while disabled', (tester) async {
      var calls = 0;
      final inner = _node();
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(
            onSecondaryTap: () => calls++,
            disabled: true,
            child: Focus(focusNode: inner, child: _box),
          ),
        ),
      );
      inner.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await _shiftF10(tester);

      expect(calls, 0);
    });

    testWidgets('the semantics action takes secondaryTapSemanticsLabel', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(
          const StratumInkWell(
            onSecondaryTap: _noop,
            secondaryTapSemanticsLabel: 'Row options',
            child: _box,
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(StratumInkWell)),
        isSemantics(
          customActions: [const CustomSemanticsAction(label: 'Row options')],
        ),
      );
      handle.dispose();
    });

    testWidgets('the semantics action falls back to showMenuTooltip', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        Localizations(
          locale: const Locale('en'),
          delegates: const [
            _MenuLocalizationsDelegate(),
            DefaultWidgetsLocalizations.delegate,
          ],
          child: themedHost(
            const StratumInkWell(onSecondaryTap: _noop, child: _box),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(StratumInkWell)),
        isSemantics(
          customActions: [const CustomSemanticsAction(label: 'Open menu')],
        ),
      );
      handle.dispose();
    });

    testWidgets("without localizations the semantics action reads 'Show "
        "menu'", (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(const StratumInkWell(onSecondaryTap: _noop, child: _box)),
      );

      expect(
        tester.getSemantics(find.byType(StratumInkWell)),
        isSemantics(
          customActions: [const CustomSemanticsAction(label: 'Show menu')],
        ),
      );
      handle.dispose();
    });

    testWidgets('toggling disabled keeps the child State', (tester) async {
      Widget build({required bool disabled}) => themedHost(
        StratumInkWell(
          onSecondaryTap: _noop,
          disabled: disabled,
          child: const _Probe(),
        ),
      );

      await tester.pumpWidget(build(disabled: false));
      final before = tester.state(find.byType(_Probe));
      await tester.pumpWidget(build(disabled: true));

      expect(tester.state(find.byType(_Probe)), same(before));
    });

    testWidgets('a disabled surface has no semantics action', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(
          const StratumInkWell(
            onSecondaryTap: _noop,
            disabled: true,
            child: _box,
          ),
        ),
      );

      final data = tester
          .getSemantics(find.byType(StratumInkWell))
          .getSemanticsData();
      expect(data.customSemanticsActionIds ?? const <int>[], isEmpty);
      handle.dispose();
    });
  });

  group('StratumInkWell shortcuts', () {
    testWidgets('a binding fires only while the surface has focus', (
      tester,
    ) async {
      var calls = 0;
      final node = _node();
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(
            onTap: _noop,
            shortcuts: {_controlKey: () => calls++},
            focusNode: node,
            child: _box,
          ),
        ),
      );

      await _controlK(tester);
      expect(calls, 0);

      node.requestFocus();
      await tester.pump();
      await _controlK(tester);
      expect(calls, 1);
    });

    testWidgets('a binding never fires while disabled', (tester) async {
      var calls = 0;
      final inner = _node();
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(
            onTap: _noop,
            disabled: true,
            shortcuts: {_controlKey: () => calls++},
            child: Focus(focusNode: inner, child: _box),
          ),
        ),
      );
      inner.requestFocus();
      await tester.pump();

      await _controlK(tester);

      expect(calls, 0);
    });

    testWidgets('an empty map builds no CallbackShortcuts', (tester) async {
      await tester.pumpWidget(
        themedHost(const StratumInkWell(onTap: _noop, child: _box)),
      );
      expect(find.byType(CallbackShortcuts), findsNothing);

      await tester.pumpWidget(
        themedHost(
          const StratumInkWell(
            onTap: _noop,
            shortcuts: {_keyA: _noop},
            child: _box,
          ),
        ),
      );
      expect(find.byType(CallbackShortcuts), findsOneWidget);
    });

    testWidgets('an unmodified binding is skipped inside a TextField', (
      tester,
    ) async {
      var letters = 0;
      var commands = 0;
      final field = _node();
      await tester.pumpWidget(
        _appHost(
          StratumInkWell(
            onTap: _noop,
            shortcuts: {_keyA: () => letters++, _controlKey: () => commands++},
            child: SizedBox(width: 200, child: TextField(focusNode: field)),
          ),
        ),
      );
      field.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await _controlK(tester);

      expect(letters, 0);
      expect(commands, 1);
    });

    testWidgets('a shortcut-only surface takes focus on the caller node', (
      tester,
    ) async {
      _useHighlightStrategy(FocusHighlightStrategy.alwaysTraditional);
      final handle = tester.ensureSemantics();
      var calls = 0;
      final node = _node();
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(
            shortcuts: {_keyA: () => calls++},
            focusNode: node,
            child: _box,
          ),
        ),
      );

      node.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);

      expect(node.hasPrimaryFocus, isTrue);
      expect(calls, 1);
      expect(_ring(tester), isTrue);
      expect(
        tester.getSemantics(find.byType(StratumInkWell)),
        isSemantics(isButton: false, isFocusable: true, isFocused: true),
      );
      handle.dispose();
    });
  });

  group('StratumInkWell child State', () {
    testWidgets('the plain tap path keeps its widget tree', (tester) async {
      await tester.pumpWidget(
        themedHost(const StratumInkWell(onTap: _noop, child: _box)),
      );

      expect(_surfaceTypes(tester), _plainTapPathTypes);
    });

    // Each builder returns the surface with the toggled setting off or on.
    final toggles = <String, StratumInkWell Function({required bool on})>{
      'onTap': ({required on}) =>
          StratumInkWell(onTap: on ? _noop : null, child: const _Probe()),
      'onDoubleTap': ({required on}) =>
          StratumInkWell(onDoubleTap: on ? _noop : null, child: const _Probe()),
      'onLongPress': ({required on}) =>
          StratumInkWell(onLongPress: on ? _noop : null, child: const _Probe()),
      'onSecondaryTap': ({required on}) => StratumInkWell(
        onTap: _noop,
        onSecondaryTap: on ? _noop : null,
        child: const _Probe(),
      ),
      'onTap beside shortcuts': ({required on}) => StratumInkWell(
        onTap: on ? _noop : null,
        shortcuts: const {_keyA: _noop},
        child: const _Probe(),
      ),
      'disabled beside shortcuts': ({required on}) => StratumInkWell(
        disabled: on,
        shortcuts: const {_keyA: _noop},
        child: const _Probe(),
      ),
      'shortcuts beside onTap': ({required on}) => StratumInkWell(
        onTap: _noop,
        shortcuts: on ? const {_keyA: _noop} : const {},
        child: const _Probe(),
      ),
      'shortcuts with no activation callback': ({required on}) =>
          StratumInkWell(
            shortcuts: on ? const {_keyA: _noop} : const {},
            child: const _Probe(),
          ),
    };
    for (final MapEntry(key: name, value: surface) in toggles.entries) {
      testWidgets('toggling $name keeps the child State', (tester) async {
        await tester.pumpWidget(themedHost(surface(on: false)));
        final before = tester.state(find.byType(_Probe));

        await tester.pumpWidget(themedHost(surface(on: true)));
        expect(tester.state(find.byType(_Probe)), same(before));

        await tester.pumpWidget(themedHost(surface(on: false)));
        expect(tester.state(find.byType(_Probe)), same(before));
      });
    }

    final activations = <String, GestureTapCallback?>{
      'onTap': _noop,
      'no activation callback': null,
    };
    for (final MapEntry(key: name, value: onTap) in activations.entries) {
      testWidgets('with $name, toggling shortcuts keeps the typed text, the '
          'cursor, and focus, and a binding still fires', (tester) async {
        var calls = 0;
        final bindings = {_controlKey: () => calls++};
        Widget build(Map<ShortcutActivator, VoidCallback> shortcuts) =>
            _appHost(
              StratumInkWell(
                onTap: onTap,
                shortcuts: shortcuts,
                child: const SizedBox(width: 200, child: TextField()),
              ),
            );
        EditableText field() =>
            tester.widget<EditableText>(find.byType(EditableText));
        void expectKept(State before) {
          expect(tester.state(find.byType(EditableText)), same(before));
          expect(field().controller.text, 'note');
          expect(
            field().controller.selection,
            const TextSelection.collapsed(offset: 4),
          );
          expect(field().focusNode.hasPrimaryFocus, isTrue);
        }

        await tester.pumpWidget(build(const {}));
        await tester.enterText(find.byType(TextField), 'note');
        await tester.pump();
        final before = tester.state(find.byType(EditableText));

        await tester.pumpWidget(build(bindings));
        expectKept(before);
        await _controlK(tester);
        expect(calls, 1);

        await tester.pumpWidget(build(const {}));
        expectKept(before);
      });
    }
  });

  group('StratumInkWell focus keep-alive', () {
    final surfaces = <String, Widget Function(FocusNode node)>{
      'a focused tap surface': (node) => StratumInkWell(
        onTap: _noop,
        focusNode: node,
        child: const SizedBox(height: 100),
      ),
      'a shortcut-only surface': (node) => StratumInkWell(
        shortcuts: const {_keyA: _noop},
        focusNode: node,
        child: const SizedBox(height: 100),
      ),
    };
    for (final MapEntry(key: name, value: surface) in surfaces.entries) {
      testWidgets('$name survives scrolling past the cache extent in touch '
          'mode', (tester) async {
        _useHighlightStrategy(FocusHighlightStrategy.alwaysTouch);
        final node = _node();
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          themedHost(
            SizedBox(
              height: 300,
              child: ListView.builder(
                controller: controller,
                itemCount: 100,
                itemBuilder: (context, index) =>
                    index == 0 ? surface(node) : const SizedBox(height: 100),
              ),
            ),
          ),
        );
        node.requestFocus();
        await tester.pump();

        controller.jumpTo(5000);
        await tester.pump();

        expect(node.hasFocus, isTrue);
        expect(
          find.byType(StratumInkWell, skipOffstage: false),
          findsOneWidget,
        );
      });
    }
  });
}
