import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

const _content = SizedBox(width: 40, height: 20);

void _noop() {}

/// The smallest [BoxLayout]: its content is a fixed box.
class _Layout extends BoxLayout {
  const new({
    super.style,
    super.ratio,
    super.rotate,
    super.transform,
    super.keepAlive,
    super.repaintBoundary,
    super.debug,
    super.semantics,
    super.onEndAnimate,
    super.interaction,
    super.scrollable,
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

    testWidgets('semantics, repaintBoundary, debug, and keepAlive stay bare', (
      tester,
    ) async {
      await tester.pumpWidget(
        themedHost(
          const _Layout(
            semantics: SemanticsProperties(label: 'box'),
            repaintBoundary: true,
            debug: true,
            keepAlive: true,
          ),
        ),
      );

      expect(find.byType(AnimatedStyledBox), findsNothing);
      expect(_inLayout(find.byType(RepaintBoundary)), findsOneWidget);
      expect(_inLayout(find.byType(WidgetPerformanceMonitor)), findsOneWidget);
      expect(find.bySemanticsLabel('box'), findsOneWidget);
    });
  });

  group('BoxLayout box tier', () {
    final rules = <String, _Layout>{
      'style': const _Layout(style: WidgetStyle()),
      'ratio': const _Layout(ratio: 2),
      'rotate': const _Layout(rotate: 0),
      'transform': _Layout(transform: Matrix4.identity()),
      'interaction': const _Layout(interaction: StratumInteraction()),
      'scrollable': const _Layout(scrollable: true),
    };
    for (final MapEntry(key: name, value: layout) in rules.entries) {
      testWidgets('$name alone builds the box', (tester) async {
        await tester.pumpWidget(themedHost(layout));

        expect(find.byType(AnimatedStyledBox), findsOneWidget);
      });
    }

    testWidgets('wraps from outside in: keepAlive, debug, repaint, rotate', (
      tester,
    ) async {
      await tester.pumpWidget(
        themedHost(
          const _Layout(
            style: WidgetStyle(),
            rotate: 90,
            repaintBoundary: true,
            debug: true,
            keepAlive: true,
          ),
        ),
      );

      final box = find.byType(AnimatedStyledBox);
      final rotate = find.ancestor(of: box, matching: find.byType(Transform));
      final repaint = _inLayout(find.byType(RepaintBoundary));
      final monitor = _inLayout(find.byType(WidgetPerformanceMonitor));
      expect(rotate, findsOneWidget);
      expect(repaint, findsOneWidget);
      expect(find.ancestor(of: rotate, matching: repaint), findsOneWidget);
      expect(find.ancestor(of: repaint, matching: monitor), findsOneWidget);
    });

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
        themedHost(const _Layout(interaction: StratumInteraction())),
      );

      expect(find.byType(StratumInkWell), findsNothing);
    });

    final surfaces = <String, StratumInteraction>{
      'onTap': const StratumInteraction(onTap: _noop),
      'onDoubleTap': const StratumInteraction(onDoubleTap: _noop),
      'onLongPress': const StratumInteraction(onLongPress: _noop),
      'onSecondaryTap': const StratumInteraction(onSecondaryTap: _noop),
      'onHover': StratumInteraction(onHover: (_) {}),
      'onHighlightChanged': StratumInteraction(onHighlightChanged: (_) {}),
      'onFocusChange': StratumInteraction(onFocusChange: (_) {}),
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
      await tester.pumpWidget(
        themedHost(
          _Layout(
            style: const WidgetStyle(
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
            semantics: label,
            interaction: StratumInteraction(
              onTap: _noop,
              onDoubleTap: doubleTap,
              onLongPress: longPress,
              onSecondaryTap: secondaryTap,
              onHover: hover,
              onHighlightChanged: highlight,
              mouseCursor: SystemMouseCursors.grab,
              enableFeedback: false,
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
      expect(ink.semantics, same(label));
      expect(ink.borderRadius, const BorderRadius.all(Radius.circular(6)));
    });

    testWidgets('an interaction animates a style over 100 ms by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        themedHost(
          const _Layout(
            style: WidgetStyle(width: 40),
            interaction: StratumInteraction(),
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

    testWidgets("an interaction keeps the style's own animation", (
      tester,
    ) async {
      const own = AnimationStyle(duration: Duration(milliseconds: 300));
      await tester.pumpWidget(
        themedHost(
          const _Layout(
            style: WidgetStyle(animationStyle: own),
            interaction: StratumInteraction(),
          ),
        ),
      );

      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.style?.animationStyle, own);
    });

    testWidgets('onEndAnimate fires once under the 100 ms default', (
      tester,
    ) async {
      var ends = 0;
      Widget build(Color color) => themedHost(
        _Layout(
          style: WidgetStyle(backgroundColor: color),
          interaction: const StratumInteraction(),
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

  group('BoxLayout scrollable', () {
    testWidgets('scrolls inside the box along scrollDirection', (tester) async {
      await tester.pumpWidget(
        themedHost(
          const _Layout(
            style: WidgetStyle(backgroundColor: Color(0xFFFFFFFF)),
            scrollable: true,
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
  });
}
