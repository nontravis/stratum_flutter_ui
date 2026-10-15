// NFR-U04 n/a: the surface paints no text of its own; the child owns any
// text and scales on its own (US-04 gate block).
// NFR-U09 n/a: every gesture the surface offers is a single tap, and Enter
// runs the same action (US-04 gate block).

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/ink_well.dart'
    show semanticsWithoutHeading, tapSurfaceHeadingLevel;
import 'package:stratum_ui/src/src.dart';

import 'fakes/fake_stratum_theme.dart';

const _box = SizedBox(width: 40, height: 20);

/// Smaller than every platform's minimum tap target (NFR-U05).
const _small = SizedBox(width: 20, height: 20);

/// Larger than every platform's minimum tap target (NFR-U05).
const _large = SizedBox(width: 60, height: 60);

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

/// A component on the stateless base that holds a tap surface, as a button
/// built on the base does.
class _Component extends StratumStatelessWidget {
  const new({super.disabled, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// The overlay inside [InkWell]; the ring above it paints a foreground
/// [DecoratedBox] too.
Finder get _overlay => find.descendant(
  of: find.byType(InkWell),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is DecoratedBox &&
        widget.position == DecorationPosition.foreground,
  ),
);

/// The overlay color, or null when the overlay paints nothing.
Color? _overlayColor(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(_overlay);
  final color = (box.decoration as BoxDecoration).color;
  return color == null || color.a == 0 ? null : color;
}

/// Whether the ring shows: its state is focused.
bool _ring(WidgetTester tester) =>
    tester.widget<StratumFocusBorder>(find.byType(StratumFocusBorder)).state ==
    FullWidgetState.focused;

/// The side the ring paints, from the [DecoratedBox] right below it.
BorderSide _ringSide(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(StratumFocusBorder),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  final shape = (box.decoration as ShapeDecoration).shape;
  return (shape as RoundedRectangleBorder).side;
}

/// Runs [body] with [defaultTargetPlatform] overridden to [platform],
/// restored before this returns so the test framework's invariant check,
/// which runs ahead of a widget test's own `addTearDown` queue, never sees
/// it still set.
Future<void> _withTargetPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

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

/// [child] under a bare [Localizations] for [locale] that holds widgets
/// localizations only, so material localizations are absent.
Widget _localeHost(Locale locale, Widget child) {
  return Localizations(
    locale: locale,
    delegates: const [DefaultWidgetsLocalizations.delegate],
    child: themedHost(child),
  );
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

/// The widgets the one [StratumInkWell] builds, from its root down to
/// [InkWell]'s child, skipping the SDK's own internals.
List<Widget> _surfaceChain(WidgetTester tester) {
  final chain = <Widget>[];
  late Widget root;
  tester
      .element(find.byType(StratumInkWell))
      .visitChildElements((element) => root = element.widget);
  for (Widget? widget = root; widget != null;) {
    chain.add(widget);
    widget = switch (widget) {
      Semantics(:final child) => child,
      StratumFocusBorder(:final child) => child,
      MouseRegion(:final child) => child,
      CallbackShortcuts(:final child) => child,
      Focus(:final child) => child,
      Material(:final child) => child,
      InkWell(:final child) => child,
      // Matches the private `_TapTargetPadding` by its public supertype,
      // since a private type is unreachable from this library.
      SingleChildRenderObjectWidget(:final child) => child,
      _ => null,
    };
  }
  return chain;
}

/// A text field with no controller, so only its State holds the text.
const _noteField = SizedBox(width: 200, child: TextField());

/// Types 'note' into the one [TextField], which takes focus; returns its
/// [EditableText] State.
Future<State> _typeNote(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), 'note');
  await tester.pump();
  return tester.state(find.byType(EditableText));
}

/// Expects the [EditableText] State [before], its text 'note', the cursor
/// after it, and primary focus.
void _expectNoteKept(WidgetTester tester, State before) {
  final field = tester.widget<EditableText>(find.byType(EditableText));
  expect(tester.state(find.byType(EditableText)), same(before));
  expect(field.controller.text, 'note');
  expect(field.controller.selection, const TextSelection.collapsed(offset: 4));
  expect(field.focusNode.hasPrimaryFocus, isTrue);
}

/// [_surfaceChain]'s types on the plain tap path, with the ring inside the
/// tap-target padding so it hugs the real child, not the grown hit box
/// (NFR-U05): an activation callback, empty shortcuts, and no
/// onSecondaryTap.
const _plainTapPathTypes = [
  'Semantics',
  'MouseRegion',
  '_TapTargetPadding',
  'StratumFocusBorder',
  'Material',
  'InkWell',
  '_StateOverlay',
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

    testWidgets('fo06/us04/fr01: a hovered state paints overlayHover', (
      tester,
    ) async {
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

    testWidgets("fo06/us11/fr01: fades over the theme's fast level", (
      tester,
    ) async {
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

    testWidgets('NFR-U03: disableAnimations snaps the overlay to hover on '
        'one pump', (tester) async {
      final states = _states({});
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: themedHost(
            StratumInkWell(onTap: _noop, statesController: states, child: _box),
            theme: motionTheme(),
          ),
        ),
      );

      states.update(WidgetState.hovered, true);
      await tester.pump();

      expect(
        tester
            .widget<TweenAnimationBuilder<Color?>>(
              find.byType(TweenAnimationBuilder<Color?>),
            )
            .duration,
        Duration.zero,
      );
      expect(_overlayColor(tester), fakeHover);
    });

    testWidgets('NFR-U03: FakeAccessibilityFeatures.reduceMotion snaps the '
        'overlay to hover on one pump', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final states = _states({});
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(onTap: _noop, statesController: states, child: _box),
          theme: motionTheme(),
        ),
      );

      states.update(WidgetState.hovered, true);
      await tester.pump();

      expect(
        tester
            .widget<TweenAnimationBuilder<Color?>>(
              find.byType(TweenAnimationBuilder<Color?>),
            )
            .duration,
        Duration.zero,
      );
      expect(_overlayColor(tester), fakeHover);
    });

    testWidgets(
      'fo06/us11/fr01: a fast level with no duration or curve fades at '
      'zero duration on easeInOutSine',
      (tester) async {
        final theme = fakeTheme.copyWith(
          animation: StratumAnimation(
            micro: StratumAnimation.packageDefault.micro,
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
      },
    );

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
    testWidgets(
      'fo06/us04/fr03/e01: unmounting leaves a caller focusNode usable',
      (tester) async {
        final node = _node();
        await tester.pumpWidget(
          themedHost(
            StratumInkWell(onTap: _noop, focusNode: node, child: _box),
          ),
        );
        await tester.pumpWidget(themedHost(_box));

        expect(() => node.addListener(_noop), returnsNormally);
      },
    );

    testWidgets('fo06/us04/fr03/e02: the focus node swaps between internal and '
        'caller', (tester) async {
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

    testWidgets('unmounting while the ring is mid-fade throws nothing', (
      tester,
    ) async {
      _useHighlightStrategy(FocusHighlightStrategy.alwaysTraditional);
      final node = _node();
      await tester.pumpWidget(
        themedHost(StratumInkWell(onTap: _noop, focusNode: node, child: _box)),
      );
      node.requestFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      await tester.pumpWidget(themedHost(_box));

      expect(tester.takeException(), isNull);
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

    testWidgets(
      'fo06/us04/fr03/e04: focusedVisible leaves focus on another node '
      'after a tap',
      (tester) async {
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
      },
    );

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
      expect(find.byType(StratumFocusBorder), findsNothing);
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
      expect(find.byType(StratumFocusBorder), findsNothing);
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

    testWidgets(
      'us04/nf01: the ring is the outside style at the surface radius, in '
      "the theme's border.subtle.blue while focused",
      (tester) async {
        _useHighlightStrategy(FocusHighlightStrategy.alwaysTraditional);
        const radius = BorderRadius.all(Radius.circular(8));
        final node = _node();
        await tester.pumpWidget(
          themedHost(
            StratumInkWell(
              onTap: _noop,
              focusNode: node,
              borderRadius: radius,
              child: _box,
            ),
          ),
        );
        final ring = tester.widget<StratumFocusBorder>(
          find.byType(StratumFocusBorder),
        );
        expect(ring.insideEdge, isFalse);
        expect(ring.borderRadius, radius);
        expect(ring.customStyle, isNull);
        expect(_ringSide(tester).color.a, 0);

        node.requestFocus();
        await tester.pumpAndSettle();

        expect(
          _ringSide(tester).color,
          isSameColorAs(fakeTheme.color.border.subtle.blue),
        );
      },
    );

    testWidgets('fo06/us04/fr03/e05: a hovered and focused surface shows the '
        'focused look', (tester) async {
      _useHighlightStrategy(FocusHighlightStrategy.alwaysTraditional);
      final node = _node();
      await tester.pumpWidget(
        themedHost(StratumInkWell(onTap: _noop, focusNode: node, child: _box)),
      );
      node.requestFocus();
      final mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byType(StratumInkWell)));
      await tester.pumpAndSettle();

      expect(_overlayColor(tester), fakeHover);
      expect(_ring(tester), isTrue);
      expect(
        _ringSide(tester).color,
        isSameColorAs(fakeTheme.color.border.subtle.blue),
      );
    });

    testWidgets(
      'fo06/us04/fr03/e12: a focused surface in another state still shows the '
      'ring; a disabled one takes no focus and shows none',
      (tester) async {
        _useHighlightStrategy(FocusHighlightStrategy.alwaysTraditional);
        final node = _node();
        final states = _states({WidgetState.error, WidgetState.selected});
        Widget build({required bool disabled}) => themedHost(
          StratumInkWell(
            key: ValueKey(disabled),
            onTap: _noop,
            focusNode: node,
            statesController: states,
            disabled: disabled,
            child: _box,
          ),
        );
        await tester.pumpWidget(build(disabled: false));
        node.requestFocus();
        await tester.pumpAndSettle();
        expect(_ring(tester), isTrue);

        // A new, disabled surface on the same node and states.
        await tester.pumpWidget(build(disabled: true));
        node.requestFocus();
        await tester.pumpAndSettle();
        expect(node.hasFocus, isFalse);
        expect(_ring(tester), isFalse);
        expect(_ringSide(tester).color.a, 0);
      },
    );

    testWidgets('fo06/us04/fr03/e03: a focused surface that turns disabled loses focus and '
        'its ring', (tester) async {
      _useHighlightStrategy(FocusHighlightStrategy.alwaysTraditional);
      final node = _node();
      Widget build({required bool disabled}) => themedHost(
        StratumInkWell(
          onTap: _noop,
          focusNode: node,
          disabled: disabled,
          child: _box,
        ),
      );
      await tester.pumpWidget(build(disabled: false));
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(_ring(tester), isTrue);

      await tester.pumpWidget(build(disabled: true));
      await tester.pumpAndSettle();
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
    // honors a directional NavigationMode (542001a), which ignores that
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
    testWidgets(
      'fo06/us04/s4: an activation callback gives an enabled button',
      (tester) async {
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
      },
    );

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

    testWidgets('fo06/us04/fr02/e01: semantics hands the role to the caller', (
      tester,
    ) async {
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

    testWidgets(
      'fo06/us04/fr02: a label-only semantics keeps the button role',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          themedHost(
            const StratumInkWell(
              onTap: _noop,
              semantics: SemanticsProperties(label: 'Open settings'),
              child: _box,
            ),
          ),
        );

        expect(
          tester.getSemantics(find.byType(StratumInkWell)),
          isSemantics(
            label: 'Open settings',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        handle.dispose();
      },
    );

    testWidgets('fo06/us04/fr02/e06: button false opts out even with a label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(
          const StratumInkWell(
            onTap: _noop,
            semantics: SemanticsProperties(button: false, label: 'Close'),
            child: _box,
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(StratumInkWell)),
        isSemantics(
          label: 'Close',
          isButton: false,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets(
      'fo06/us04/fr02/e07: an image semantics keeps the button role',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          themedHost(
            const StratumInkWell(
              onTap: _noop,
              semantics: SemanticsProperties(image: true, label: 'Avatar'),
              child: _box,
            ),
          ),
        );

        expect(
          tester.getSemantics(find.byType(StratumInkWell)),
          isSemantics(
            label: 'Avatar',
            isImage: true,
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us04/fr02/e07: a header semantics keeps the button role',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          themedHost(
            const StratumInkWell(
              onTap: _noop,
              semantics: SemanticsProperties(header: true, label: 'Recent'),
              child: _box,
            ),
          ),
        );

        expect(
          tester.getSemantics(find.byType(StratumInkWell)),
          isSemantics(
            label: 'Recent',
            isHeader: true,
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us04/fr02/e07: a selected semantics keeps the button role',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          themedHost(
            const StratumInkWell(
              onTap: _noop,
              semantics: SemanticsProperties(selected: true, label: 'Week'),
              child: _box,
            ),
          ),
        );

        expect(
          tester.getSemantics(find.byType(StratumInkWell)),
          isSemantics(
            label: 'Week',
            hasSelectedState: true,
            isSelected: true,
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us04/fr02/e07: an enabled semantics keeps the button role',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          themedHost(
            const StratumInkWell(
              onTap: _noop,
              semantics: SemanticsProperties(enabled: true, label: 'Save'),
              child: _box,
            ),
          ),
        );

        expect(
          tester.getSemantics(find.byType(StratumInkWell)),
          isSemantics(
            label: 'Save',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us04/fr02/e07: a caller enabled false wins over the surface',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          themedHost(
            const StratumInkWell(
              onTap: _noop,
              semantics: SemanticsProperties(enabled: false, label: 'Save'),
              child: _box,
            ),
          ),
        );

        expect(
          tester.getSemantics(find.byType(StratumInkWell)),
          isSemantics(
            label: 'Save',
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            hasTapAction: true,
          ),
        );
        handle.dispose();
      },
    );

    testWidgets('fo06/us04/fr02/e08: a none role keeps the button role', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(
          const StratumInkWell(
            onTap: _noop,
            semantics: SemanticsProperties(
              role: SemanticsRole.none,
              label: 'Save',
            ),
            child: _box,
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(StratumInkWell)),
        isSemantics(
          label: 'Save',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets(
      'fo06/us04/fr02/e02: a label-only semantics with no activation callback '
      'adds no button',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          themedHost(
            StratumInkWell(
              onHover: (_) {},
              semantics: const SemanticsProperties(label: 'Status'),
              child: _box,
            ),
          ),
        );

        expect(
          tester.getSemantics(find.byType(StratumInkWell)),
          isSemantics(
            label: 'Status',
            isButton: false,
            hasEnabledState: false,
            hasTapAction: false,
          ),
        );
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us04/fr02/e01: a false-valued role field still removes the '
      'button role',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          themedHost(
            const StratumInkWell(
              onTap: _noop,
              semantics: SemanticsProperties(checked: false, label: 'Mute'),
              child: _box,
            ),
          ),
        );

        expect(
          tester.getSemantics(find.byType(StratumInkWell)),
          isSemantics(
            label: 'Mute',
            isButton: false,
            hasCheckedState: true,
            isChecked: false,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us04/fr02: a disabled label-only semantics reads as a dimmed '
      'button',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          themedHost(
            const StratumInkWell(
              onTap: _noop,
              disabled: true,
              semantics: SemanticsProperties(label: 'Open settings'),
              child: _box,
            ),
          ),
        );

        expect(
          tester.getSemantics(find.byType(StratumInkWell)),
          isSemantics(
            label: 'Open settings',
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            hasTapAction: false,
          ),
        );
        handle.dispose();
      },
    );

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

  group('fo06/us04/fr02, s03/inv8: tapSurfaceHeadingLevel', () {
    int? level(
      SemanticsProperties? semantics, {
      bool isWeb = true,
      bool hasActivation = true,
      bool excludeFromSemantics = false,
    }) => tapSurfaceHeadingLevel(
      isWeb: isWeb,
      hasActivation: hasActivation,
      excludeFromSemantics: excludeFromSemantics,
      semantics: semantics,
    );

    test('fo06/us04/fr02/e07: a header button on web takes level 2', () {
      expect(
        level(const SemanticsProperties(header: true, label: 'Recent')),
        2,
      );
    });

    test(
      'fo06/us04/fr02/e07: a caller button true splits with no callback',
      () {
        const semantics = SemanticsProperties(button: true, header: true);
        expect(level(semantics, hasActivation: false), 2);
      },
    );

    test('fo06/us04/fr02/e07: a caller button true wins over a link', () {
      const semantics = SemanticsProperties(
        button: true,
        link: true,
        header: true,
      );
      expect(level(semantics, hasActivation: false), 2);
    });

    test('fo06/us04/fr02/e07: native platforms never split', () {
      expect(
        level(const SemanticsProperties(header: true), isWeb: false),
        isNull,
      );
      expect(
        level(const SemanticsProperties(headingLevel: 3), isWeb: false),
        isNull,
      );
    });

    test(
      'fo06/us04/fr02/e07: no header and no headingLevel gives no split',
      () {
        expect(level(null), isNull);
        expect(level(const SemanticsProperties(label: 'Recent')), isNull);
        expect(
          level(const SemanticsProperties(header: false, label: 'Recent')),
          isNull,
        );
        expect(
          level(const SemanticsProperties(image: true, label: 'Avatar')),
          isNull,
        );
      },
    );

    test('fo06/us04/fr02/e09: a headingLevel from 1 to 6 sets the level', () {
      for (var value = 1; value <= 6; value++) {
        expect(level(SemanticsProperties(headingLevel: value)), value);
      }
    });

    test('fo06/us04/fr02/e09: a headingLevel wins over header', () {
      expect(
        level(const SemanticsProperties(header: true, headingLevel: 4)),
        4,
      );
    });

    test('fo06/us04/fr02/e08: a role of none still splits', () {
      expect(
        level(
          const SemanticsProperties(role: SemanticsRole.none, header: true),
        ),
        2,
      );
    });

    test('fo06/us04/fr02/e01: a node that is no button gives no split', () {
      expect(
        level(const SemanticsProperties(header: true), hasActivation: false),
        isNull,
      );
      expect(
        level(const SemanticsProperties(link: true, header: true)),
        isNull,
      );
      expect(
        level(const SemanticsProperties(role: SemanticsRole.tab, header: true)),
        isNull,
      );
    });

    test('fo06/us04/fr02/e06: a caller button false gives no split', () {
      expect(
        level(const SemanticsProperties(button: false, header: true)),
        isNull,
      );
    });

    test('fo06/us04/fr02/e03: excludeFromSemantics gives no split', () {
      expect(
        level(
          const SemanticsProperties(header: true),
          excludeFromSemantics: true,
        ),
        isNull,
      );
      expect(
        level(
          const SemanticsProperties(button: true, header: true),
          excludeFromSemantics: true,
        ),
        isNull,
      );
    });
  });

  group('fo06/us04/fr02, s03/inv8: semanticsWithoutHeading', () {
    /// A caller semantics with many fields set besides `header` and
    /// `headingLevel`, so the tripwire sees any field the subclass drops.
    SemanticsProperties properties({
      bool? header,
      int? headingLevel,
      TextDirection? textDirection = TextDirection.ltr,
    }) => SemanticsProperties(
      header: header,
      headingLevel: headingLevel,
      textDirection: textDirection,
      label: 'Recent',
      value: '3 new',
      hint: 'Opens the list',
      tooltip: 'Recent items',
      identifier: 'recent',
      enabled: true,
      selected: false,
      focused: true,
      image: true,
      liveRegion: true,
      onTap: _noop,
      onLongPress: _noop,
    );

    /// Pumps [node] under one container node and returns that node's data.
    Future<SemanticsData> dataOf(
      WidgetTester tester,
      Widget node, {
      TextDirection direction = TextDirection.ltr,
    }) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: direction,
          child: Center(child: Semantics(container: true, child: node)),
        ),
      );
      return tester.getSemantics(find.byWidget(node)).getSemanticsData();
    }

    testWidgets(
      'fo06/us04/fr02/e07: drops header and headingLevel and keeps every other '
      'field',
      (tester) async {
        final handle = tester.ensureSemantics();
        final plain = await dataOf(
          tester,
          Semantics.fromProperties(
            properties: properties(header: true, headingLevel: 3),
            child: _box,
          ),
        );
        final stripped = await dataOf(
          tester,
          semanticsWithoutHeading(
            properties: properties(header: true, headingLevel: 3),
            child: _box,
          ),
        );
        final expected = await dataOf(
          tester,
          Semantics.fromProperties(properties: properties(), child: _box),
        );

        expect(plain.flagsCollection.isHeader, isTrue);
        expect(plain.headingLevel, 3);
        expect(stripped.flagsCollection.isHeader, isFalse);
        expect(stripped.headingLevel, 0);
        expect(stripped, expected);
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us04/fr02/e07: takes the ambient direction like Semantics',
      (tester) async {
        final handle = tester.ensureSemantics();
        final stripped = await dataOf(
          tester,
          semanticsWithoutHeading(
            properties: properties(
              header: true,
              headingLevel: 3,
              textDirection: null,
            ),
            child: _box,
          ),
          direction: TextDirection.rtl,
        );
        final expected = await dataOf(
          tester,
          Semantics.fromProperties(
            properties: properties(textDirection: null),
            child: _box,
          ),
          direction: TextDirection.rtl,
        );

        expect(stripped.textDirection, TextDirection.rtl);
        expect(stripped, expected);
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us04/fr02/e07: an update keeps header and headingLevel off',
      (tester) async {
        final handle = tester.ensureSemantics();
        await dataOf(
          tester,
          semanticsWithoutHeading(
            properties: const SemanticsProperties(header: true, label: 'Old'),
            child: _box,
          ),
        );
        final updated = await dataOf(
          tester,
          semanticsWithoutHeading(
            properties: const SemanticsProperties(
              headingLevel: 4,
              label: 'New',
            ),
            child: _box,
          ),
        );

        expect(updated.label, 'New');
        expect(updated.flagsCollection.isHeader, isFalse);
        expect(updated.headingLevel, 0);
        handle.dispose();
      },
    );
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

    testWidgets('fo06/us04/s3: Enter calls onTap on a focused widget', (
      tester,
    ) async {
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

  group('StratumInkWell inside a disabled component', () {
    testWidgets('fo06/us04/fr02/e10, fo08/us07/s12: a press already down is '
        'cancelled when the component turns disabled and runs no tap', (
      tester,
    ) async {
      var taps = 0;
      final states = _states({});
      // One instance across both pumps, so only the disabled scope tells
      // the surface about the flip.
      final surface = StratumInkWell(
        onTap: () => taps++,
        statesController: states,
        child: _box,
      );
      Widget build({required bool disabled}) =>
          themedHost(_Component(disabled: disabled, child: surface));
      await tester.pumpWidget(build(disabled: false));
      final press = await tester.startGesture(
        tester.getCenter(find.byType(StratumInkWell)),
      );
      await tester.pump(kPressTimeout);
      expect(states.value, contains(WidgetState.pressed));

      await tester.pumpWidget(build(disabled: true));
      expect(states.value, isNot(contains(WidgetState.pressed)));
      await press.up();
      await tester.pump(kDoubleTapTimeout);

      expect(taps, 0);
    });

    testWidgets(
      'fo06/us04/fr02/e10: a long press already down never fires once '
      'the component turns disabled',
      (tester) async {
        var longPresses = 0;
        Widget build({required bool disabled}) => themedHost(
          _Component(
            disabled: disabled,
            child: StratumInkWell(
              onLongPress: () => longPresses++,
              child: _box,
            ),
          ),
        );
        await tester.pumpWidget(build(disabled: false));
        final press = await tester.startGesture(
          tester.getCenter(find.byType(StratumInkWell)),
        );
        await tester.pump(kPressTimeout);

        await tester.pumpWidget(build(disabled: true));
        await tester.pump(kLongPressTimeout);
        await press.up();
        await tester.pumpAndSettle();

        expect(longPresses, 0);
      },
    );

    testWidgets(
      'fo06/us04/fr02/e10: it reads as a dimmed button with no action, '
      'as its own disabled gives',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          themedHost(
            const _Component(
              disabled: true,
              child: StratumInkWell(onTap: _noop, child: _box),
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
      },
    );

    testWidgets('fo06/us04/fr02/e10: enabled again, it takes taps', (
      tester,
    ) async {
      var taps = 0;
      Widget build({required bool disabled}) => themedHost(
        _Component(
          disabled: disabled,
          child: StratumInkWell(onTap: () => taps++, child: _box),
        ),
      );
      await tester.pumpWidget(build(disabled: true));
      await tester.pumpWidget(build(disabled: false));

      await tester.tap(find.byType(StratumInkWell));
      await tester.pump(kDoubleTapTimeout);

      expect(taps, 1);
    });
  });

  group('StratumInkWell hover on a disabled flip', () {
    Future<TestGesture> hoverOver(WidgetTester tester) async {
      final mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byType(StratumInkWell)));
      await tester.pump();
      return mouse;
    }

    testWidgets('fo06/us04/fr04/e05: turning disabled under the pointer calls '
        'onHover(false) once', (tester) async {
      final hovers = <bool>[];
      Widget build({required bool disabled}) => themedHost(
        StratumInkWell(
          onTap: _noop,
          onHover: hovers.add,
          disabled: disabled,
          child: _box,
        ),
      );
      await tester.pumpWidget(build(disabled: false));
      await hoverOver(tester);

      await tester.pumpWidget(build(disabled: true));
      await tester.pump();

      expect(hovers, [true, false]);
    });

    testWidgets('fo06/us04/fr04/e05: a component turning disabled under the '
        'pointer calls onHover(false) once', (tester) async {
      final hovers = <bool>[];
      // One instance across the pumps, so only the disabled scope tells
      // the surface about the flip.
      final surface = StratumInkWell(
        onTap: _noop,
        onHover: hovers.add,
        child: _box,
      );
      Widget build({required bool disabled}) =>
          themedHost(_Component(disabled: disabled, child: surface));
      await tester.pumpWidget(build(disabled: false));
      await hoverOver(tester);

      await tester.pumpWidget(build(disabled: true));
      await tester.pump();

      expect(hovers, [true, false]);
    });

    testWidgets('fo06/us04/fr04/e05: while disabled, the pointer leaving and '
        'coming back calls nothing', (tester) async {
      final hovers = <bool>[];
      Widget build({required bool disabled}) => themedHost(
        StratumInkWell(
          onTap: _noop,
          onHover: hovers.add,
          disabled: disabled,
          child: _box,
        ),
      );
      await tester.pumpWidget(build(disabled: false));
      final mouse = await hoverOver(tester);
      await tester.pumpWidget(build(disabled: true));
      await tester.pump();

      await mouse.moveTo(Offset.zero);
      await tester.pump();
      await mouse.moveTo(tester.getCenter(find.byType(StratumInkWell)));
      await tester.pump();

      expect(hovers, [true, false]);
    });

    testWidgets('fo06/us04/fr04/e06: enabled again under a still pointer, '
        'onHover(true) fires once within one frame', (tester) async {
      final hovers = <bool>[];
      Widget build({required bool disabled}) => themedHost(
        StratumInkWell(
          onTap: _noop,
          onHover: hovers.add,
          disabled: disabled,
          child: _box,
        ),
      );
      await tester.pumpWidget(build(disabled: false));
      await hoverOver(tester);
      await tester.pumpWidget(build(disabled: true));
      await tester.pump();

      await tester.pumpWidget(build(disabled: false));
      await tester.pump();

      expect(hovers, [true, false, true]);
    });

    testWidgets('fo06/us04/fr04/e06: a component enabled again under a still '
        'pointer calls onHover(true) once within one frame', (tester) async {
      final hovers = <bool>[];
      final surface = StratumInkWell(
        onTap: _noop,
        onHover: hovers.add,
        child: _box,
      );
      Widget build({required bool disabled}) =>
          themedHost(_Component(disabled: disabled, child: surface));
      await tester.pumpWidget(build(disabled: false));
      await hoverOver(tester);
      await tester.pumpWidget(build(disabled: true));
      await tester.pump();

      await tester.pumpWidget(build(disabled: false));
      await tester.pump();

      expect(hovers, [true, false, true]);
    });

    testWidgets('fo06/us04/fr04/e06: enabled again after the pointer left, '
        'onHover is not called', (tester) async {
      final hovers = <bool>[];
      Widget build({required bool disabled}) => themedHost(
        StratumInkWell(
          onTap: _noop,
          onHover: hovers.add,
          disabled: disabled,
          child: _box,
        ),
      );
      await tester.pumpWidget(build(disabled: false));
      final mouse = await hoverOver(tester);
      await tester.pumpWidget(build(disabled: true));
      await tester.pump();
      await mouse.moveTo(Offset.zero);
      await tester.pump();

      await tester.pumpWidget(build(disabled: false));
      await tester.pump();

      expect(hovers, [true, false]);
    });

    testWidgets(
      'fo06/us04/fr04/e03, fo06/us04/fr04/e05, fo06/us04/fr04/e06: with no '
      'activation callback, onHover follows the flip both ways',
      (tester) async {
        final hovers = <bool>[];
        Widget build({required bool disabled}) => themedHost(
          StratumInkWell(onHover: hovers.add, disabled: disabled, child: _box),
        );
        await tester.pumpWidget(build(disabled: false));
        await hoverOver(tester);

        await tester.pumpWidget(build(disabled: true));
        await tester.pump();
        await tester.pumpWidget(build(disabled: false));
        await tester.pump();

        expect(hovers, [true, false, true]);
      },
    );

    testWidgets(
      "fo06/us04/fr04/e05: an onHover that sets an ancestor's state on "
      'the flip runs after the frame, with no build error',
      (tester) async {
        final hovers = <bool>[];
        var disabled = false;
        late StateSetter setHost;
        await tester.pumpWidget(
          themedHost(
            StatefulBuilder(
              builder: (context, setState) {
                setHost = setState;
                return StratumInkWell(
                  onTap: _noop,
                  disabled: disabled,
                  onHover: (value) => setState(() => hovers.add(value)),
                  child: _box,
                );
              },
            ),
          ),
        );
        await hoverOver(tester);

        setHost(() => disabled = true);
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(hovers, [true, false]);
      },
    );
  });

  group('StratumInkWell context-menu key', () {
    testWidgets('fo06/us05/fr01, fo06/us05/s1: the context-menu key calls '
        'onSecondaryTap', (tester) async {
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

      expect(calls, 1);
    });

    testWidgets('fo06/us05/s2: Shift+F10 calls onSecondaryTap', (tester) async {
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

      await _shiftF10(tester);

      expect(calls, 1);
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
      tester.platformDispatcher.localeTestValue = const Locale('en');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
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

    testWidgets('fo06/us05/fr04/e01: under th the action reads the Thai '
        'built-in label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _localeHost(
          const Locale('th'),
          const StratumInkWell(onSecondaryTap: _noop, child: _box),
        ),
      );

      expect(
        tester.getSemantics(find.byType(StratumInkWell)),
        isSemantics(
          customActions: [const CustomSemanticsAction(label: 'แสดงเมนู')],
        ),
      );
      handle.dispose();
    });

    testWidgets('fo06/us05/fr04/e02: under ja the action reads the English '
        'built-in label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _localeHost(
          const Locale('ja'),
          const StratumInkWell(onSecondaryTap: _noop, child: _box),
        ),
      );

      expect(
        tester.getSemantics(find.byType(StratumInkWell)),
        isSemantics(
          customActions: [const CustomSemanticsAction(label: 'Show menu')],
        ),
      );
      handle.dispose();
    });

    testWidgets('fo09/us01/fr02: under th secondaryTapSemanticsLabel wins '
        'over the built-in label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _localeHost(
          const Locale('th'),
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

    testWidgets(
      'fo06/us05/fr04: under th the material showMenuTooltip wins over '
      'the built-in label',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          Localizations(
            locale: const Locale('th'),
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
      },
    );

    testWidgets('fo06/us05/s3: the action label follows the app language from '
        'English to Thai', (tester) async {
      final handle = tester.ensureSemantics();
      const surface = StratumInkWell(onSecondaryTap: _noop, child: _box);
      await tester.pumpWidget(_localeHost(const Locale('en'), surface));
      expect(
        tester.getSemantics(find.byType(StratumInkWell)),
        isSemantics(
          customActions: [const CustomSemanticsAction(label: 'Show menu')],
        ),
      );

      await tester.pumpWidget(_localeHost(const Locale('th'), surface));

      expect(
        tester.getSemantics(find.byType(StratumInkWell)),
        isSemantics(
          customActions: [const CustomSemanticsAction(label: 'แสดงเมนู')],
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
    testWidgets(
      'fo06/us05/fr02, fo06/us05/s4: a binding fires only while the surface '
      'has focus',
      (tester) async {
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
      },
    );

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

    testWidgets(
      'fo06/us05/s5: an unmodified binding is skipped inside a TextField',
      (tester) async {
        var letters = 0;
        var commands = 0;
        final field = _node();
        await tester.pumpWidget(
          _appHost(
            StratumInkWell(
              onTap: _noop,
              shortcuts: {
                _keyA: () => letters++,
                _controlKey: () => commands++,
              },
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
      },
    );

    testWidgets('fo06/us05/s6: a binding does not fire while focus rests on '
        'another surface', (tester) async {
      var calls = 0;
      final rowNode = _node();
      final otherNode = _node();
      await tester.pumpWidget(
        themedHost(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StratumInkWell(
                onTap: _noop,
                shortcuts: {_controlKey: () => calls++},
                focusNode: rowNode,
                child: _box,
              ),
              StratumInkWell(onTap: _noop, focusNode: otherNode, child: _box),
            ],
          ),
        ),
      );

      otherNode.requestFocus();
      await tester.pump();
      await _controlK(tester);

      expect(calls, 0);
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
      Key? materialKey() =>
          _surfaceChain(tester).whereType<Material>().single.key;
      await tester.pumpWidget(
        themedHost(const StratumInkWell(onTap: _noop, child: _box)),
      );
      final key = materialKey();
      await tester.pumpWidget(
        themedHost(const StratumInkWell(onTap: _noop, child: _Probe())),
      );

      expect(
        _surfaceChain(tester).map((widget) => '${widget.runtimeType}'),
        _plainTapPathTypes,
      );
      // The one change from master: Material carries the State's own key.
      expect(key, isA<GlobalKey>());
      expect(materialKey(), same(key));
    });

    testWidgets('a shortcut-only surface hands InkWell a node it owns, so '
        "InkWell's Focus adds no listener per toggle", (tester) async {
      Widget build(Map<ShortcutActivator, VoidCallback> shortcuts) =>
          themedHost(StratumInkWell(shortcuts: shortcuts, child: _box));
      final inkFocus = find
          .descendant(of: find.byType(InkWell), matching: find.byType(Focus))
          .first;
      FocusNode? inkNode() => tester.widget<Focus>(inkFocus).focusNode;

      await tester.pumpWidget(build(const {_keyA: _noop}));
      final owned = inkNode();
      await tester.pumpWidget(build(const {}));
      await tester.pumpWidget(build(const {_keyA: _noop}));

      // A null node makes the SDK Focus keep its listener on its own node
      // across each null-to-node swap, one more per toggle.
      expect(owned, isNotNull);
      expect(inkNode(), same(owned));
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
        await tester.pumpWidget(build(const {}));
        final before = await _typeNote(tester);

        await tester.pumpWidget(build(bindings));
        _expectNoteKept(tester, before);
        await _controlK(tester);
        expect(calls, 1);

        await tester.pumpWidget(build(const {}));
        _expectNoteKept(tester, before);
      });
    }

    // Each builder returns the surface around [_noteField] with the setting
    // off or on.
    final focusToggles = <String, StratumInkWell Function({required bool on})>{
      'onSecondaryTap': ({required on}) => StratumInkWell(
        onTap: _noop,
        onSecondaryTap: on ? _noop : null,
        child: _noteField,
      ),
      'onTap beside shortcuts': ({required on}) => StratumInkWell(
        onTap: on ? _noop : null,
        shortcuts: const {_controlKey: _noop},
        child: _noteField,
      ),
      'onTap and disabled beside shortcuts': ({required on}) => StratumInkWell(
        onTap: on ? _noop : null,
        disabled: on,
        shortcuts: const {_controlKey: _noop},
        child: _noteField,
      ),
    };
    for (final MapEntry(key: name, value: surface) in focusToggles.entries) {
      testWidgets('toggling $name keeps the typed text, the cursor, and '
          'focus', (tester) async {
        await tester.pumpWidget(_appHost(surface(on: false)));
        final before = await _typeNote(tester);

        await tester.pumpWidget(_appHost(surface(on: true)));
        _expectNoteKept(tester, before);

        await tester.pumpWidget(_appHost(surface(on: false)));
        _expectNoteKept(tester, before);
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
      testWidgets(
        'fo06/us04/fr05: $name survives scrolling past the cache extent in '
        'touch mode',
        (tester) async {
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
        },
      );
    }
  });

  group('StratumInkWell US-04 scenarios', () {
    testWidgets(
      'fo06/us04/s1: pressing a card covers it with the pressed overlay, and '
      'releasing it runs its action',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          themedHost(StratumInkWell(onTap: () => taps++, child: _box)),
        );
        final press = await tester.startGesture(
          tester.getCenter(find.byType(StratumInkWell)),
        );
        await tester.pump(kPressTimeout);
        await tester.pumpAndSettle();
        expect(_overlayColor(tester), fakeActive);
        expect(taps, 0);

        await press.up();
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(_overlayColor(tester), isNull);
      },
    );

    testWidgets(
      'fo06/us04/s2: a pointer entering a card fades the hover overlay in over '
      "the theme's fast level",
      (tester) async {
        await tester.pumpWidget(
          themedHost(
            const StratumInkWell(onTap: _noop, child: _box),
            theme: motionTheme(fast: const Duration(milliseconds: 100)),
          ),
        );
        final mouse = await _mouse(tester);
        await mouse.moveTo(tester.getCenter(find.byType(StratumInkWell)));
        await tester.pump();
        expect(_overlayColor(tester), isNull);

        await tester.pump(const Duration(milliseconds: 50));
        final half = _overlayColor(tester)!;
        expect(half.a, greaterThan(0));
        expect(half.a, lessThan(fakeHover.a));

        await tester.pump(const Duration(milliseconds: 50));
        expect(_overlayColor(tester), fakeHover);
      },
    );

    testWidgets('fo06/us04/s5: tabbing to a card shows the ring around it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _appHost(const StratumInkWell(onTap: _noop, child: _box)),
      );
      expect(_ring(tester), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(_ring(tester), isTrue);
      expect(
        _ringSide(tester).color,
        isSameColorAs(fakeTheme.color.border.subtle.blue),
      );
    });

    testWidgets('fo06/us04/s6: a tap on a card leaves focus and the on-screen keyboard on a '
        'text field', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _appHost(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _noteField,
              StratumInkWell(onTap: () => taps++, child: _box),
            ],
          ),
        ),
      );
      await tester.showKeyboard(find.byType(TextField));
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(find.byType(StratumInkWell));
      await tester.pump();

      expect(taps, 1);
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.focusNode.hasPrimaryFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets(
      'fo06/us04/s7: a disabled card runs nothing on a tap or Enter, shows no '
      'overlay, and reads as a dimmed button',
      (tester) async {
        final handle = tester.ensureSemantics();
        var taps = 0;
        final node = _node();
        await tester.pumpWidget(
          _appHost(
            StratumInkWell(
              onTap: () => taps++,
              disabled: true,
              focusNode: node,
              child: _box,
            ),
          ),
        );

        await tester.tap(find.byType(StratumInkWell));
        node.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(taps, 0);
        expect(_overlayColor(tester), isNull);
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
      },
    );
  });

  group('StratumInkWell tap target', () {
    testWidgets('fo06/us04/fr06: NFR-U05: pads a 20x20 child to 44x44 on '
        'iOS', (tester) async {
      await _withTargetPlatform(TargetPlatform.iOS, () async {
        await tester.pumpWidget(
          themedHost(const StratumInkWell(onTap: _noop, child: _small)),
        );

        expect(tester.getSize(find.byType(StratumInkWell)), const Size(44, 44));
      });
    });

    testWidgets('NFR-U05: pads a 20x20 child to 48x48 on android', (
      tester,
    ) async {
      await _withTargetPlatform(TargetPlatform.android, () async {
        await tester.pumpWidget(
          themedHost(const StratumInkWell(onTap: _noop, child: _small)),
        );

        expect(tester.getSize(find.byType(StratumInkWell)), const Size(48, 48));
      });
    });

    testWidgets('NFR-U05: pads a 20x20 child to 24x24 on macOS', (
      tester,
    ) async {
      await _withTargetPlatform(TargetPlatform.macOS, () async {
        await tester.pumpWidget(
          themedHost(const StratumInkWell(onTap: _noop, child: _small)),
        );

        expect(tester.getSize(find.byType(StratumInkWell)), const Size(24, 24));
      });
    });

    testWidgets(
      'NFR-U05: a tap 2px outside the child but inside the padded box '
      'still fires onTap',
      (tester) async {
        await _withTargetPlatform(TargetPlatform.android, () async {
          var taps = 0;
          await tester.pumpWidget(
            themedHost(StratumInkWell(onTap: () => taps++, child: _small)),
          );
          final topLeft = tester.getTopLeft(find.byType(StratumInkWell));

          await tester.tapAt(topLeft + const Offset(2, 2));

          expect(taps, 1);
        });
      },
    );

    testWidgets('NFR-U05: shrinkWrap keeps the child its own 20x20 size', (
      tester,
    ) async {
      await _withTargetPlatform(TargetPlatform.android, () async {
        await tester.pumpWidget(
          themedHost(
            const StratumInkWell(
              onTap: _noop,
              tapTargetSize: TapTargetSize.shrinkWrap,
              child: _small,
            ),
          ),
        );

        expect(tester.getSize(find.byType(StratumInkWell)), const Size(20, 20));
      });
    });

    testWidgets('NFR-U05: a child larger than the minimum keeps its own '
        'size', (tester) async {
      await _withTargetPlatform(TargetPlatform.android, () async {
        await tester.pumpWidget(
          themedHost(const StratumInkWell(onTap: _noop, child: _large)),
        );

        expect(tester.getSize(find.byType(StratumInkWell)), const Size(60, 60));
      });
    });

    testWidgets(
      'NFR-U05: meets androidTapTargetGuideline on a labeled 20x20 child',
      (tester) async {
        await _withTargetPlatform(TargetPlatform.android, () async {
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(
            themedHost(
              const StratumInkWell(
                onTap: _noop,
                semantics: SemanticsProperties(label: 'Close'),
                child: _small,
              ),
            ),
          );

          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          handle.dispose();
        });
      },
    );

    testWidgets(
      'NFR-U05: meets iOSTapTargetGuideline on a labeled 20x20 child',
      (tester) async {
        await _withTargetPlatform(TargetPlatform.iOS, () async {
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(
            themedHost(
              const StratumInkWell(
                onTap: _noop,
                semantics: SemanticsProperties(label: 'Close'),
                child: _small,
              ),
            ),
          );

          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          handle.dispose();
        });
      },
    );

    testWidgets('NFR-U05: the padding adds no semantics node, so the '
        "child's semantics read unchanged", (tester) async {
      await _withTargetPlatform(TargetPlatform.android, () async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          themedHost(
            const StratumInkWell(
              onTap: _noop,
              semantics: SemanticsProperties(label: 'Close'),
              child: _small,
            ),
          ),
        );

        expect(
          tester.getSemantics(find.byType(StratumInkWell)),
          isSemantics(
            label: 'Close',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        handle.dispose();
      });
    });

    testWidgets(
      'NFR-U05: an IntrinsicWidth ancestor still reserves the platform '
      'minimum',
      (tester) async {
        await _withTargetPlatform(TargetPlatform.android, () async {
          await tester.pumpWidget(
            themedHost(
              const IntrinsicWidth(
                child: StratumInkWell(onTap: _noop, child: _small),
              ),
            ),
          );

          expect(tester.getSize(find.byType(StratumInkWell)).width, 48);
        });
      },
    );

    testWidgets(
      'NFR-U05: an IntrinsicHeight ancestor still reserves the platform '
      'minimum',
      (tester) async {
        await _withTargetPlatform(TargetPlatform.android, () async {
          await tester.pumpWidget(
            themedHost(
              const IntrinsicHeight(
                child: StratumInkWell(onTap: _noop, child: _small),
              ),
            ),
          );

          expect(tester.getSize(find.byType(StratumInkWell)).height, 48);
        });
      },
    );

    testWidgets(
      'NFR-U05: the dry baseline carries the centering offset once the '
      "box grows past the child's own size",
      (tester) async {
        await _withTargetPlatform(TargetPlatform.android, () async {
          const probe = Text('A');
          await tester.pumpWidget(
            themedHost(const StratumInkWell(onTap: _noop, child: probe)),
          );

          const constraints = BoxConstraints();
          const baseline = TextBaseline.alphabetic;
          final surface = tester.renderObject<RenderBox>(
            find.byType(StratumInkWell),
          );
          final child = tester.renderObject<RenderBox>(find.byType(Text));
          final childBaseline = child.getDryBaseline(constraints, baseline)!;
          final childSize = child.getDryLayout(constraints);
          final boxSize = surface.getDryLayout(constraints);
          final centeringOffset = Alignment.center
              .alongOffset(boxSize - childSize as Offset)
              .dy;

          expect(
            surface.getDryBaseline(constraints, baseline),
            childBaseline + centeringOffset,
          );
        });
      },
    );

    testWidgets(
      'NFR-U05: the focus ring hugs the real 20x20 child, not the grown '
      'hit box',
      (tester) async {
        await _withTargetPlatform(TargetPlatform.android, () async {
          await tester.pumpWidget(
            themedHost(const StratumInkWell(onTap: _noop, child: _small)),
          );

          expect(
            tester.getSize(find.byType(StratumFocusBorder)),
            const Size(20, 20),
          );
          expect(
            tester.getSize(find.byType(StratumInkWell)),
            const Size(48, 48),
          );
        });
      },
    );
  });

  group('StratumInkWell focus style levels', () {
    const red = Color(0xFFFF0000);
    const green = Color(0xFF00FF00);

    Widget host({
      StratumInkWellStyle? customStyle,
      FocusNode? node,
      Key? key,
    }) => StratumInkWell(
      key: key,
      onTap: _noop,
      focusNode: node,
      customStyle: customStyle,
      child: _box,
    );

    Widget app(Widget child, {Map<Type, Object> parts = const {}}) =>
        themedHost(
          StratumComponentDefaults(
            styles: const {},
            parts: parts,
            child: child,
          ),
        );

    testWidgets('fo06/us04/fr03/e15, fo03/us06/fr01/e04: the tap surface '
        "style's focus wins field by field over the every-ring style", (
      tester,
    ) async {
      _useHighlightStrategy(FocusHighlightStrategy.alwaysTraditional);
      final node = _node();
      await tester.pumpWidget(
        app(
          host(node: node),
          parts: const {
            StratumFocusBorder: StratumFocusBorderStyle(
              color: WidgetStatePropertyAll(red),
              width: WidgetStatePropertyAll(5),
            ),
            StratumInkWell: StratumInkWellStyle(
              focus: StratumFocusBorderStyle(
                color: WidgetStatePropertyAll(green),
              ),
            ),
          },
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();

      final side = _ringSide(tester);
      expect(side.color, isSameColorAs(green));
      expect(side.width, 5);
    });

    testWidgets("fo06/us04/fr03/e16: one surface's customStyle restyles its "
        'own ring and no other', (tester) async {
      _useHighlightStrategy(FocusHighlightStrategy.alwaysTraditional);
      final mine = _node();
      final other = _node();
      await tester.pumpWidget(
        app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              host(
                key: const ValueKey('mine'),
                node: mine,
                customStyle: const StratumInkWellStyle(
                  focus: StratumFocusBorderStyle(
                    color: WidgetStatePropertyAll(red),
                  ),
                ),
              ),
              host(key: const ValueKey('other'), node: other),
            ],
          ),
        ),
      );
      BorderSide ringOf(String key) {
        final box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.descendant(
                  of: find.byKey(ValueKey(key)),
                  matching: find.byType(StratumFocusBorder),
                ),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final shape = (box.decoration as ShapeDecoration).shape;
        return (shape as RoundedRectangleBorder).side;
      }

      mine.requestFocus();
      await tester.pumpAndSettle();
      expect(ringOf('mine').color, isSameColorAs(red));

      other.requestFocus();
      await tester.pumpAndSettle();
      expect(
        ringOf('other').color,
        isSameColorAs(fakeTheme.color.border.subtle.blue),
      );
    });
  });

  group('StratumInkWell accessibility gate', () {
    testWidgets('NFR-U06: a surface with an activation callback reads as an '
        'enabled button with its label', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(
          const StratumInkWell(
            onTap: _noop,
            semantics: SemanticsProperties(label: 'Save'),
            child: _box,
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(StratumInkWell)),
        isSemantics(
          label: 'Save',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('NFR-U02: Tab reaches the surface and its focused look '
        'differs from idle', (tester) async {
      await tester.pumpWidget(
        _appHost(const StratumInkWell(onTap: _noop, child: _box)),
      );
      expect(_ring(tester), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_ring(tester), isTrue);
      expect(_ringSide(tester).color.a, greaterThan(0));
    });

    testWidgets('NFR-U01: a labeled surface passes the labeled tap target '
        'guideline', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(
          const StratumInkWell(
            onTap: _noop,
            semantics: SemanticsProperties(label: 'Save'),
            child: _box,
          ),
        ),
      );
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('NFR-U01 exception, us04/nf01: the app-wide tap surface style '
        'replaces the ring token that fails 3:1', (tester) async {
      _useHighlightStrategy(FocusHighlightStrategy.alwaysTraditional);
      const strong = Color(0xFF1D4ED8);
      final node = _node();
      await tester.pumpWidget(
        themedHost(
          StratumComponentDefaults(
            styles: const {},
            parts: const {
              StratumInkWell: StratumInkWellStyle(
                focus: StratumFocusBorderStyle(
                  color: WidgetStatePropertyAll(strong),
                ),
              ),
            },
            child: StratumInkWell(onTap: _noop, focusNode: node, child: _box),
          ),
          theme: defaultThemeSet.light,
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(_ringSide(tester).color, isSameColorAs(strong));
    });

    Widget highContrast(Widget child) => StratumThemeApplication(
      themes: defaultThemeSet,
      themeMode: ThemeMode.light,
      highContrast: StratumHighContrastMode.on,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );

    testWidgets('NFR-U07, NFR-U08: under high contrast the focused surface '
        'shows the ring shape in the high-contrast token', (tester) async {
      _useHighlightStrategy(FocusHighlightStrategy.alwaysTraditional);
      final node = _node();
      await tester.pumpWidget(
        highContrast(
          StratumInkWell(onTap: _noop, focusNode: node, child: _box),
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();

      final side = _ringSide(tester);
      expect(side.width, 3);
      expect(
        side.color,
        isSameColorAs(defaultThemeSet.highContrastLight!.focus.outsideColor),
      );
    });

    testWidgets('NFR-U08: a disabled surface announces disabled, not a '
        'color change alone', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(
          const StratumInkWell(onTap: _noop, disabled: true, child: _box),
        ),
      );
      expect(
        tester.getSemantics(find.byType(StratumInkWell)),
        isSemantics(hasEnabledState: true, isEnabled: false),
      );
      semantics.dispose();
    });

    testWidgets("NFR-E01: the hover overlay follows the theme's state.hover", (
      tester,
    ) async {
      Future<Color?> hovered(StratumThemeData theme) async {
        final states = _states({});
        await tester.pumpWidget(
          themedHost(
            StratumInkWell(onTap: _noop, statesController: states, child: _box),
            theme: theme,
          ),
        );
        states.update(WidgetState.hovered, true);
        await tester.pumpAndSettle();
        return _overlayColor(tester);
      }

      expect(await hovered(fakeTheme), fakeHover);
      expect(
        await hovered(fakeStratumTheme(hover: const Color(0x33000000))),
        const Color(0x33000000),
      );
    });

    testWidgets("NFR-E02: focus, the tap surface style's one field, shows on "
        'its ring, and the ring width keeps the theme default', (tester) async {
      _useHighlightStrategy(FocusHighlightStrategy.alwaysTraditional);
      const red = Color(0xFFFF0000);
      final node = _node();
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(
            onTap: _noop,
            focusNode: node,
            customStyle: const StratumInkWellStyle(
              focus: StratumFocusBorderStyle(
                color: WidgetStatePropertyAll(red),
              ),
            ),
            child: _box,
          ),
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();

      final side = _ringSide(tester);
      expect(side.color, isSameColorAs(red));
      expect(side.width, fakeTheme.focus.outsideWidth);
    });
  });
}
