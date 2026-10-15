import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/layout/scroll_frame.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

const _content = SizedBox(width: 40, height: 20);

/// Smaller than every platform's minimum tap target (NFR-U05).
const _small = SizedBox(width: 20, height: 20);

void _noop() {}

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

/// The smallest [BoxLayout]: its content is a fixed box.
class _Layout extends BoxLayout {
  const new({
    super.style,
    super.ratio,
    super.rotate,
    super.transform,
    super.transformAlignment,
    super.keepAlive,
    super.repaintBoundary,
    super.semantics,
    super.onEndAnimate,
    super.interaction,
    super.scroll,
    this.axis = Axis.vertical,
  });

  final Axis axis;

  @override
  Axis get scrollDirection => axis;

  @override
  Widget buildContent(BuildContext context) => _content;
}

Finder _inLayout(Finder matching) {
  return find.descendant(of: find.byType(_Layout), matching: matching);
}

void main() {
  group('BoxLayout bare tier', () {
    testWidgets('builds no AnimatedStyledBox and no StatefulElement', (
      tester,
    ) async {
      await tester.pumpWidget(themedHost(const _Layout()));

      expect(find.byType(AnimatedStyledBox), findsNothing);
      expect(
        _inLayout(find.byElementPredicate((e) => e is StatefulElement)),
        findsNothing,
      );
      expect(tester.getSize(find.byType(_Layout)), const Size(40, 20));
    });

    testWidgets(
      'fo06/us01/fr01: semantics, repaintBoundary, and keepAlive stay bare',
      (tester) async {
        await tester.pumpWidget(
          themedHost(
            const _Layout(
              semantics: SemanticsProperties(label: 'box'),
              repaintBoundary: true,
              keepAlive: true,
            ),
          ),
        );

        expect(find.byType(AnimatedStyledBox), findsNothing);
        expect(_inLayout(find.byType(RepaintBoundary)), findsOneWidget);
        expect(find.bySemanticsLabel('box'), findsOneWidget);
      },
    );
  });

  group('BoxLayout box tier', () {
    final rules = <String, _Layout>{
      'style': const _Layout(style: WidgetStyle()),
      'ratio': const _Layout(ratio: 2),
      'rotate': const _Layout(rotate: 0),
      'transform': _Layout(transform: Matrix4.identity()),
      'interaction': const _Layout(interaction: Interaction()),
      'scroll': const _Layout(scroll: Scroll()),
    };
    for (final MapEntry(key: name, value: layout) in rules.entries) {
      testWidgets('$name alone builds the box', (tester) async {
        await tester.pumpWidget(themedHost(layout));

        expect(find.byType(AnimatedStyledBox), findsOneWidget);
      });
    }

    testWidgets('ratio, transform, and transformAlignment reach the box', (
      tester,
    ) async {
      final matrix = Matrix4.identity()..scaleByDouble(2.0, 2.0, 2.0, 1.0);
      await tester.pumpWidget(
        themedHost(
          _Layout(
            style: const WidgetStyle(),
            ratio: 2,
            transform: matrix,
            transformAlignment: Alignment.topLeft,
          ),
        ),
      );

      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.ratio, 2);
      expect(box.transform, matrix);
      expect(box.transformAlignment, Alignment.topLeft);
    });

    testWidgets('a ratio of 0 reaches the box as null', (tester) async {
      await tester.pumpWidget(
        themedHost(const _Layout(style: WidgetStyle(), ratio: 0)),
      );

      expect(
        tester.widget<AnimatedStyledBox>(find.byType(AnimatedStyledBox)).ratio,
        isNull,
      );
    });

    testWidgets(
      'fo06/us01/fr01: wraps from outside in: keepAlive, repaint, rotate',
      (tester) async {
        await tester.pumpWidget(
          themedHost(
            const _Layout(
              style: WidgetStyle(),
              rotate: 90,
              repaintBoundary: true,
              keepAlive: true,
            ),
          ),
        );

        final box = find.byType(AnimatedStyledBox);
        final rotate = find.ancestor(of: box, matching: find.byType(Transform));
        final repaint = _inLayout(find.byType(RepaintBoundary));
        expect(rotate, findsOneWidget);
        expect(repaint, findsOneWidget);
        expect(find.ancestor(of: rotate, matching: repaint), findsOneWidget);
      },
    );

    testWidgets('the semantic rect equals the box and excludes the margin', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(
          const _Layout(
            style: WidgetStyle(
              width: 40,
              height: 20,
              margin: EdgeInsets.all(8),
            ),
            semantics: SemanticsProperties(label: 'box'),
          ),
        ),
      );

      expect(tester.getSize(find.byType(_Layout)), const Size(56, 36));
      final node = tester.getSemantics(find.bySemanticsLabel('box'));
      expect(node.rect.size, const Size(40, 20));
      handle.dispose();
    });

    testWidgets('an interaction without callbacks adds no tap surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        themedHost(const _Layout(interaction: Interaction())),
      );

      expect(find.byType(StratumInkWell), findsNothing);
    });

    final surfaces = <String, Interaction>{
      'onTap': const Interaction(onTap: _noop),
      'onDoubleTap': const Interaction(onDoubleTap: _noop),
      'onLongPress': const Interaction(onLongPress: _noop),
      'onSecondaryTap': const Interaction(onSecondaryTap: _noop),
      'onHover': Interaction(onHover: (_) {}),
      'onHighlightChanged': Interaction(onHighlightChanged: (_) {}),
      'onFocusChange': Interaction(onFocusChange: (_) {}),
      'shortcuts': const Interaction(
        shortcuts: {SingleActivator(LogicalKeyboardKey.keyA): _noop},
      ),
    };
    for (final MapEntry(key: name, value: interaction) in surfaces.entries) {
      testWidgets('$name builds the tap surface', (tester) async {
        await tester.pumpWidget(themedHost(_Layout(interaction: interaction)));

        expect(find.byType(StratumInkWell), findsOneWidget);
      });
    }

    testWidgets('hands every interaction field to the tap surface', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      final states = WidgetStatesController();
      addTearDown(states.dispose);
      void hover(bool value) {}
      void highlight(bool value) {}
      void focus(bool value) {}
      void doubleTap() {}
      void longPress() {}
      void secondaryTap() {}
      const label = SemanticsProperties(label: 'box');
      const shortcuts = {SingleActivator(LogicalKeyboardKey.keyA): _noop};
      await tester.pumpWidget(
        themedHost(
          _Layout(
            style: const WidgetStyle(
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
            semantics: label,
            interaction: Interaction(
              onTap: _noop,
              onDoubleTap: doubleTap,
              onLongPress: longPress,
              onSecondaryTap: secondaryTap,
              onHover: hover,
              onHighlightChanged: highlight,
              mouseCursor: SystemMouseCursors.grab,
              enableFeedback: false,
              tapTargetSize: TapTargetSize.shrinkWrap,
              disabledPressAnimation: true,
              focusNode: node,
              focusType: FocusType.focused,
              showFocusOnPrimary: false,
              canRequestFocus: false,
              autofocus: true,
              onFocusChange: focus,
              disabled: true,
              statesController: states,
              excludeFromSemantics: true,
              secondaryTapSemanticsLabel: 'Options',
              shortcuts: shortcuts,
            ),
          ),
        ),
      );

      final ink = tester.widget<StratumInkWell>(find.byType(StratumInkWell));
      expect(ink.onTap, _noop);
      expect(ink.onDoubleTap, doubleTap);
      expect(ink.onLongPress, longPress);
      expect(ink.onSecondaryTap, secondaryTap);
      expect(ink.onHover, hover);
      expect(ink.onHighlightChanged, highlight);
      expect(ink.mouseCursor, SystemMouseCursors.grab);
      expect(ink.enableFeedback, isFalse);
      expect(ink.tapTargetSize, TapTargetSize.shrinkWrap);
      expect(ink.disabledPressAnimation, isTrue);
      expect(ink.focusNode, same(node));
      expect(ink.focusType, FocusType.focused);
      expect(ink.showFocusOnPrimary, isFalse);
      expect(ink.canRequestFocus, isFalse);
      expect(ink.autofocus, isTrue);
      expect(ink.onFocusChange, focus);
      expect(ink.disabled, isTrue);
      expect(ink.statesController, same(states));
      expect(ink.excludeFromSemantics, isTrue);
      expect(ink.secondaryTapSemanticsLabel, 'Options');
      expect(ink.shortcuts, same(shortcuts));
      expect(ink.semantics, same(label));
      expect(ink.borderRadius, const BorderRadius.all(Radius.circular(6)));
    });

    testWidgets(
      'NFR-U05: tapTargetSize forwards to the tap surface, growing the '
      'footprint by default and keeping it with shrinkWrap',
      (tester) async {
        await _withTargetPlatform(TargetPlatform.android, () async {
          await tester.pumpWidget(
            themedHost(
              const ContainerLayout(
                interaction: Interaction(onTap: _noop),
                child: _small,
              ),
            ),
          );

          expect(
            tester.getSize(find.byType(StratumInkWell)),
            const Size(48, 48),
          );

          await tester.pumpWidget(
            themedHost(
              const ContainerLayout(
                interaction: Interaction(
                  onTap: _noop,
                  tapTargetSize: TapTargetSize.shrinkWrap,
                ),
                child: _small,
              ),
            ),
          );

          expect(
            tester.getSize(find.byType(StratumInkWell)),
            const Size(20, 20),
          );
        });
      },
    );

    testWidgets(
      "fo06/us11/fr01: an interaction animates a style over the theme's "
      'fast level by default',
      (tester) async {
        await tester.pumpWidget(
          themedHost(
            const _Layout(
              style: WidgetStyle(width: 40),
              interaction: Interaction(),
            ),
            theme: motionTheme(),
          ),
        );

        final style = tester
            .widget<AnimatedStyledBox>(find.byType(AnimatedStyledBox))
            .style
            ?.animationStyle;
        expect(style?.duration, const Duration(milliseconds: 77));
        expect(style?.reverseDuration, const Duration(microseconds: 49280));
        expect(style?.curve, Curves.easeInOutSine);
      },
    );

    testWidgets('fo06/us11/fr01: with no theme above it takes the package '
        "default's fast level", (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: _Layout(
            style: WidgetStyle(width: 40),
            interaction: Interaction(),
          ),
        ),
      );

      expect(
        tester
            .widget<AnimatedStyledBox>(find.byType(AnimatedStyledBox))
            .style
            ?.animationStyle,
        StratumAnimation.packageDefault.fast,
      );
    });

    testWidgets('C1: under reduced motion the default timing still comes '
        'from the theme', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await tester.pumpWidget(
        themedHost(
          const _Layout(
            style: WidgetStyle(width: 40),
            interaction: Interaction(),
          ),
          theme: motionTheme(),
        ),
      );

      expect(
        tester
            .widget<AnimatedStyledBox>(find.byType(AnimatedStyledBox))
            .style
            ?.animationStyle
            ?.duration,
        const Duration(milliseconds: 77),
      );
    });

    testWidgets("an interaction keeps the style's own animation", (
      tester,
    ) async {
      const own = AnimationStyle(duration: Duration(milliseconds: 300));
      await tester.pumpWidget(
        themedHost(
          const _Layout(
            style: WidgetStyle(animationStyle: own),
            interaction: Interaction(),
          ),
        ),
      );

      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.style?.animationStyle, own);
    });

    testWidgets('onEndAnimate fires once under the fast default', (
      tester,
    ) async {
      var ends = 0;
      Widget build(Color color) => themedHost(
        _Layout(
          style: WidgetStyle(backgroundColor: color),
          interaction: const Interaction(),
          onEndAnimate: () => ends++,
        ),
      );

      await tester.pumpWidget(build(const Color(0xFFFF0000)));
      await tester.pumpWidget(build(const Color(0xFF0000FF)));
      await tester.pumpAndSettle();

      expect(ends, 1);
    });

    testWidgets('onEndAnimate reaches only an animated style', (tester) async {
      await tester.pumpWidget(
        themedHost(const _Layout(style: WidgetStyle(), onEndAnimate: _noop)),
      );
      expect(
        tester.widget<AnimatedStyledBox>(find.byType(AnimatedStyledBox)).onEnd,
        isNull,
      );

      await tester.pumpWidget(
        themedHost(
          const _Layout(
            style: WidgetStyle(
              animationStyle: AnimationStyle(
                duration: Duration(milliseconds: 100),
              ),
            ),
            onEndAnimate: _noop,
          ),
        ),
      );
      expect(
        tester.widget<AnimatedStyledBox>(find.byType(AnimatedStyledBox)).onEnd,
        _noop,
      );
    });
  });

  group('BoxLayout scroll', () {
    testWidgets('scrolls inside the box along scrollDirection', (tester) async {
      await tester.pumpWidget(
        themedHost(
          const _Layout(
            style: WidgetStyle(backgroundColor: Color(0xFFFFFFFF)),
            scroll: Scroll(),
            axis: Axis.horizontal,
          ),
        ),
      );

      final scroll = find.byType(SingleChildScrollView);
      expect(
        find.ancestor(of: scroll, matching: find.byType(AnimatedStyledBox)),
        findsOneWidget,
      );
      expect(
        tester.widget<SingleChildScrollView>(scroll).scrollDirection,
        Axis.horizontal,
      );
      expect(
        find.ancestor(of: scroll, matching: find.byType(ScrollConfiguration)),
        findsWidgets,
      );
    });

    testWidgets('a null scroll builds no scroll view', (tester) async {
      await tester.pumpWidget(themedHost(const _Layout(style: WidgetStyle())));

      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(find.byType(ScrollFrame), findsNothing);
    });

    testWidgets('every Scroll field reaches the scroll view', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      const physics = BouncingScrollPhysics();
      await tester.pumpWidget(
        themedHost(
          _Layout(
            scroll: Scroll(
              direction: Axis.horizontal,
              reverse: true,
              controller: controller,
              primary: false,
              physics: physics,
              showScrollbar: false,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              restorationId: 'box',
            ),
          ),
        ),
      );

      final view = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(view.scrollDirection, Axis.horizontal);
      expect(view.reverse, isTrue);
      expect(view.controller, same(controller));
      expect(view.primary, isFalse);
      expect(view.physics, same(physics));
      expect(
        view.keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.onDrag,
      );
      expect(view.restorationId, 'box');
      expect(
        tester.widget<ScrollFrame>(find.byType(ScrollFrame)).showScrollbar,
        isFalse,
      );
    });

    testWidgets('scroll.physics applies on top of the theme', (tester) async {
      await tester.pumpWidget(
        themedHost(
          const SizedBox(
            width: 100,
            height: 100,
            child: ColumnLayout(
              scroll: Scroll(physics: BouncingScrollPhysics()),
              children: [SizedBox(height: 500)],
            ),
          ),
        ),
      );

      final types = <Type>[];
      for (
        ScrollPhysics? physics = tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position
            .physics;
        physics != null;
        physics = physics.parent
      ) {
        types.add(physics.runtimeType);
      }
      expect(
        types,
        containsAll([BouncingScrollPhysics, ClampingScrollPhysics]),
      );
    });

    final horizontal = <String, Widget>{
      'ContainerLayout': const ContainerLayout(
        scroll: Scroll(direction: Axis.horizontal),
        child: SizedBox(width: 500, height: 20),
      ),
      'StackLayout': const StackLayout(
        scroll: Scroll(direction: Axis.horizontal),
        children: [SizedBox(width: 500, height: 20)],
      ),
    };
    for (final MapEntry(key: name, value: layout) in horizontal.entries) {
      testWidgets('direction: Axis.horizontal scrolls a $name sideways', (
        tester,
      ) async {
        await tester.pumpWidget(
          themedHost(SizedBox(width: 100, height: 50, child: layout)),
        );

        expect(
          tester
              .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
              .scrollDirection,
          Axis.horizontal,
        );
        expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable))
              .position
              .maxScrollExtent,
          400,
        );
      });
    }

    final dialogs = <String, Widget>{
      'StackLayout': const StackLayout(
        scroll: Scroll(),
        children: [SizedBox(width: 200, height: 40)],
      ),
      'WrapLayout': const WrapLayout(
        scroll: Scroll(),
        children: [SizedBox(width: 200, height: 40)],
      ),
      'ColumnLayout': const ColumnLayout(
        scroll: Scroll(),
        children: [SizedBox(width: 200, height: 40)],
      ),
    };
    for (final MapEntry(key: name, value: layout) in dialogs.entries) {
      testWidgets('a scrolling $name lays out inside AlertDialog content', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(home: AlertDialog(content: layout)),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
      });
    }

    testWidgets('ratio with scroll shapes the frame and scrolls the content', (
      tester,
    ) async {
      await tester.pumpWidget(
        themedHost(
          const SizedBox(
            width: 320,
            child: ColumnLayout(
              ratio: 16 / 9,
              style: WidgetStyle(backgroundColor: Color(0xFFFFFFFF)),
              scroll: Scroll(),
              children: [SizedBox(height: 600)],
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(ColumnLayout)), const Size(320, 180));
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position
            .maxScrollExtent,
        420,
      );
    });

    // The tap-surface focus rule (us04/fr03): not disabled, canRequestFocus,
    // a focus type other than none, and an activation callback or a
    // shortcut. The box gives up its own Tab stop exactly when it holds.
    const shortcut = {SingleActivator(LogicalKeyboardKey.keyA): _noop};
    for (final (name, surfaceStop, interaction)
        in <(String, bool, Interaction Function(FocusNode))>[
          ('onTap', true, (n) => Interaction(onTap: _noop, focusNode: n)),
          (
            'onDoubleTap',
            true,
            (n) => Interaction(onDoubleTap: _noop, focusNode: n),
          ),
          (
            'onLongPress',
            true,
            (n) => Interaction(onLongPress: _noop, focusNode: n),
          ),
          (
            'onSecondaryTap',
            true,
            (n) => Interaction(onSecondaryTap: _noop, focusNode: n),
          ),
          (
            'shortcuts only',
            true,
            (n) => Interaction(shortcuts: shortcut, focusNode: n),
          ),
          (
            'onHover only',
            false,
            (n) => Interaction(onHover: (_) {}, focusNode: n),
          ),
          (
            'disabled',
            false,
            (n) => Interaction(onTap: _noop, disabled: true, focusNode: n),
          ),
          (
            'disabled shortcuts',
            false,
            (n) =>
                Interaction(shortcuts: shortcut, disabled: true, focusNode: n),
          ),
          (
            'canRequestFocus false',
            false,
            (n) =>
                Interaction(onTap: _noop, canRequestFocus: false, focusNode: n),
          ),
          (
            'FocusType.none',
            false,
            (n) => Interaction(
              onTap: _noop,
              focusType: FocusType.none,
              focusNode: n,
            ),
          ),
        ]) {
      testWidgets('(pin) a scrolling box with $name has one Tab stop, the '
          '${surfaceStop ? 'tap surface' : 'box itself'}', (tester) async {
        final surface = FocusNode(debugLabel: 'surface');
        addTearDown(surface.dispose);
        await tester.pumpWidget(
          themedHost(
            _Layout(
              style: const WidgetStyle(),
              scroll: const Scroll(),
              interaction: interaction(surface),
            ),
          ),
        );

        final stops = [
          for (final node
              in FocusManager.instance.rootScope.traversalDescendants)
            if (node is! FocusScopeNode) node,
        ];
        expect(stops, hasLength(1));
        expect(
          stops.single.debugLabel,
          surfaceStop ? 'surface' : 'ScrollFocus',
        );
      }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
    }

    testWidgets('changing reverse or showScrollbar keeps the scroll offset', (
      tester,
    ) async {
      Widget build({bool reverse = false, bool? showScrollbar}) {
        return themedHost(
          SizedBox(
            width: 100,
            height: 100,
            child: ColumnLayout(
              style: const WidgetStyle(),
              scroll: Scroll(reverse: reverse, showScrollbar: showScrollbar),
              children: const [SizedBox(height: 500)],
            ),
          ),
        );
      }

      double pixels() => tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .pixels;

      await tester.pumpWidget(build());
      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .jumpTo(100);
      await tester.pump();

      await tester.pumpWidget(build(showScrollbar: false));
      expect(pixels(), 100);

      await tester.pumpWidget(build(showScrollbar: false, reverse: true));
      expect(pixels(), 100);
    });
  });
}
