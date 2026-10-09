import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/base/disabled.dart';
import 'package:stratum_ui/src/components/common/utility/show.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

/// The key of the content every [_show] wraps.
const _content = Key('content');

/// A box with a fixed size, so a size transition has somewhere to grow or
/// shrink toward.
class _Box extends StatefulWidget {
  const new();

  @override
  State<_Box> createState() => _BoxState();
}

class _BoxState extends State<_Box> {
  @override
  Widget build(BuildContext context) => const SizedBox(width: 100, height: 40);
}

/// A [StratumShow] around a [_Box] keyed [_content], or [child] when given.
StratumShow _show({
  required bool visible,
  StratumShowTransition transition = StratumShowTransition.sizeAndFade,
  StratumShowSlideDirection slideDirection = StratumShowSlideDirection.end,
  Duration? duration,
  Duration? reverseDuration,
  bool maintainState = false,
  Widget? child,
}) => StratumShow(
  visible: visible,
  transition: transition,
  slideDirection: slideDirection,
  duration: duration,
  reverseDuration: reverseDuration,
  maintainState: maintainState,
  child: child ?? const KeyedSubtree(key: _content, child: _Box()),
);

/// [show] between two texts, in a themed row sized to its children, so a
/// row that takes no space still reports [Size.zero]. [reduced] wraps the
/// host in a [MediaQuery] asking for `disableAnimations`.
Widget _row(
  Widget show, {
  StratumThemeData? theme,
  TextDirection direction = TextDirection.ltr,
  bool reduced = false,
}) {
  final host = themedHost(
    Row(
      mainAxisSize: MainAxisSize.min,
      children: [const Text('A'), show, const Text('B')],
    ),
    theme: theme,
    textDirection: direction,
  );
  return reduced
      ? MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: host,
        )
      : host;
}

/// Pumps [initial], settles it, then pumps [updated] with no further pump,
/// so a caller's own pumps read the motion from its first frame.
Future<void> _toggle(
  WidgetTester tester,
  Widget initial,
  Widget updated,
) async {
  await tester.pumpWidget(initial);
  await tester.pumpAndSettle();
  await tester.pumpWidget(updated);
}

/// The size of the one [StratumShow] in the tree.
Size _size(WidgetTester tester) => tester.getSize(find.byType(StratumShow));

/// The opacity the one [FadeTransition] in the tree reads now.
double _opacity(WidgetTester tester) =>
    tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value;

/// Every label in the live semantics tree, walked fresh. `find
/// .bySemanticsLabel` reads each render object's own cached
/// `debugSemantics`, which an ancestor's `ExcludeSemantics` toggle does not
/// invalidate on its excluded descendants (`rendering/object.dart`:
/// `visitChildrenForSemantics` returns before visiting them); walking the
/// owner's root node reads what a screen reader receives instead.
Set<String> _semanticsLabels(WidgetTester tester) {
  final labels = <String>{};
  void visit(SemanticsNode node) {
    if (node.label.isNotEmpty) labels.add(node.label);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  final root =
      tester.binding.rootPipelineOwner.semanticsOwner?.rootSemanticsNode;
  if (root != null) visit(root);
  return labels;
}

void main() {
  group('StratumShow sizes and fades', () {
    testWidgets('us15/fr01, us15/s1, us15/fr01/e02: hidden content grows '
        'and fades in over 125 ms by default', (tester) async {
      await _toggle(
        tester,
        _row(_show(visible: false)),
        _row(_show(visible: true)),
      );
      await tester.pump(const Duration(milliseconds: 60));
      expect(_size(tester).width, inExclusiveRange(0, 100));
      expect(_size(tester).height, inExclusiveRange(0, 40));
      expect(_opacity(tester), inExclusiveRange(0, 1));

      await tester.pump(const Duration(milliseconds: 65));
      expect(_size(tester), const Size(100, 40));
      expect(_opacity(tester), 1.0);
    });

    testWidgets('us15/s2: shown content shrinks and fades out over 80 ms, '
        'then takes no space and is unmounted', (tester) async {
      await _toggle(
        tester,
        _row(_show(visible: true)),
        _row(_show(visible: false)),
      );
      await tester.pump(const Duration(milliseconds: 40));
      expect(_size(tester).width, inExclusiveRange(0, 100));
      expect(_opacity(tester), inExclusiveRange(0, 1));

      await tester.pump(const Duration(milliseconds: 40));
      // One more tick past the 80 ms hide: AnimationController reports
      // dismissed a tick after its value reaches 0 (isDone is strict `>`).
      await tester.pump(const Duration(milliseconds: 1));
      expect(_size(tester), Size.zero);
      expect(find.byKey(_content, skipOffstage: false), findsNothing);
    });

    testWidgets('us15/fr01/e01: a rebuild with the same visible runs no '
        'motion', (tester) async {
      await tester.pumpWidget(_row(_show(visible: true)));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_row(_show(visible: true)));

      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('us15/fr01/e03, us15/s9: a 400 ms show, then the theme hide', (
      tester,
    ) async {
      const slow = Duration(milliseconds: 400);
      await _toggle(
        tester,
        _row(_show(visible: false, duration: slow)),
        _row(_show(visible: true, duration: slow)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(_size(tester).width, lessThan(100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_size(tester).width, 100);

      await tester.pumpWidget(_row(_show(visible: false, duration: slow)));
      await tester.pump(const Duration(milliseconds: 80));
      // One more tick past the hide: see the us15/s2 comment above.
      await tester.pump(const Duration(milliseconds: 1));
      expect(_size(tester), Size.zero);
    });

    testWidgets('us15/fr01: a caller hide duration sets the hide alone', (
      tester,
    ) async {
      const slowHide = Duration(milliseconds: 300);
      await _toggle(
        tester,
        _row(_show(visible: false, reverseDuration: slowHide)),
        _row(_show(visible: true, reverseDuration: slowHide)),
      );
      await tester.pump(const Duration(milliseconds: 125));
      expect(_size(tester), const Size(100, 40));

      await tester.pumpWidget(
        _row(_show(visible: false, reverseDuration: slowHide)),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(_size(tester).width, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 100));
      // One more tick past the hide: see the us15/s2 comment above.
      await tester.pump(const Duration(milliseconds: 1));
      expect(_size(tester), Size.zero);
    });

    testWidgets('us15/fr01/e04: a theme whose default level is normal takes '
        '200 ms to show and 128 ms to hide', (tester) async {
      final theme = fakeTheme.copyWith(
        animation: StratumAnimation.fromConfig(
          defaultThemeConfig.animation.copyWith(defaultLevel: 'normal'),
        ),
      );
      await _toggle(
        tester,
        _row(_show(visible: false), theme: theme),
        _row(_show(visible: true), theme: theme),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(_size(tester).width, lessThan(100));
      await tester.pump(const Duration(milliseconds: 50));
      expect(_size(tester).width, 100);

      await tester.pumpWidget(_row(_show(visible: false), theme: theme));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_size(tester).width, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 28));
      // One more tick past the hide: see the us15/s2 comment above.
      await tester.pump(const Duration(milliseconds: 1));
      expect(_size(tester), Size.zero);
    });

    testWidgets('us15/fr01/e05: a caller curve runs both ways, backward on '
        'the hide', (tester) async {
      StratumShow show({required bool visible}) => StratumShow(
        visible: visible,
        curve: Curves.easeIn,
        child: const KeyedSubtree(key: _content, child: _Box()),
      );
      await _toggle(
        tester,
        _row(show(visible: false)),
        _row(show(visible: true)),
      );
      await tester.pump(const Duration(milliseconds: 62));
      expect(
        _size(tester).width,
        closeTo(100 * Curves.easeIn.transform(62 / 125), 2),
      );

      await tester.pumpAndSettle();
      await tester.pumpWidget(_row(show(visible: false)));
      await tester.pump(const Duration(milliseconds: 20));
      // 20 ms into an 80 ms hide, the controller reads 0.75 (PD9).
      expect(
        _size(tester).width,
        closeTo(100 * Curves.easeIn.transform(1 - 20 / 80), 2),
      );
    });

    testWidgets('a hide during a show shrinks from where it is', (
      tester,
    ) async {
      await _toggle(
        tester,
        _row(_show(visible: false)),
        _row(_show(visible: true)),
      );
      await tester.pump(const Duration(milliseconds: 60));
      final width = _size(tester).width;

      await tester.pumpWidget(_row(_show(visible: false)));
      await tester.pump(const Duration(milliseconds: 1));

      expect(_size(tester).width, closeTo(width, 3));
    });

    testWidgets('us15/s3: fade takes the full size at once and fades in', (
      tester,
    ) async {
      await _toggle(
        tester,
        _row(_show(visible: false, transition: StratumShowTransition.fade)),
        _row(_show(visible: true, transition: StratumShowTransition.fade)),
      );
      await tester.pump();
      expect(_size(tester), const Size(100, 40));
      await tester.pump(const Duration(milliseconds: 60));
      expect(_opacity(tester), inExclusiveRange(0, 1));
    });

    testWidgets('us15/fr01: fade fades out at its full size, then takes no '
        'space', (tester) async {
      await _toggle(
        tester,
        _row(_show(visible: true, transition: StratumShowTransition.fade)),
        _row(_show(visible: false, transition: StratumShowTransition.fade)),
      );
      await tester.pump(const Duration(milliseconds: 40));
      expect(_size(tester), const Size(100, 40));
      expect(_opacity(tester), inExclusiveRange(0, 1));

      await tester.pumpAndSettle();
      expect(_size(tester), Size.zero);
    });

    testWidgets('us15/s4: size grows with no fade', (tester) async {
      await _toggle(
        tester,
        _row(_show(visible: false, transition: StratumShowTransition.size)),
        _row(_show(visible: true, transition: StratumShowTransition.size)),
      );
      await tester.pump(const Duration(milliseconds: 60));

      expect(_size(tester).width, inExclusiveRange(0, 100));
      expect(_opacity(tester), 1.0);
    });

    testWidgets('us15/fr01: size shrinks with no fade, then takes no space', (
      tester,
    ) async {
      await _toggle(
        tester,
        _row(_show(visible: true, transition: StratumShowTransition.size)),
        _row(_show(visible: false, transition: StratumShowTransition.size)),
      );
      await tester.pump(const Duration(milliseconds: 40));
      expect(_size(tester).width, inExclusiveRange(0, 100));
      expect(_opacity(tester), 1.0);

      await tester.pumpAndSettle();
      expect(_size(tester), Size.zero);
    });

    testWidgets('us15/fr03/e01, us15/s14: hidden content takes no width in a '
        'row and no height in a column', (tester) async {
      await tester.pumpWidget(_row(_show(visible: false)));
      expect(_size(tester), Size.zero);
      expect(
        tester.getTopRight(find.text('A')).dx,
        tester.getTopLeft(find.text('B')).dx,
      );

      await tester.pumpWidget(
        themedHost(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [const Text('A'), _show(visible: false), const Text('B')],
          ),
        ),
      );
      expect(_size(tester), Size.zero);
      expect(
        tester.getBottomLeft(find.text('A')).dy,
        tester.getTopLeft(find.text('B')).dy,
      );
    });

    for (final (direction, corner) in [
      (TextDirection.ltr, 'top left'),
      (TextDirection.rtl, 'top right'),
    ]) {
      testWidgets('us15/fr03/e02: a size change anchors at the $corner', (
        tester,
      ) async {
        await _toggle(
          tester,
          _row(_show(visible: false), direction: direction),
          _row(_show(visible: true), direction: direction),
        );
        await tester.pump(const Duration(milliseconds: 60));

        final show = find.byType(StratumShow);
        final content = find.byKey(_content);
        expect(_size(tester).width, inExclusiveRange(0, 100));
        expect(tester.getTopLeft(content).dy, tester.getTopLeft(show).dy);
        expect(
          direction == TextDirection.ltr
              ? tester.getTopLeft(content).dx
              : tester.getTopRight(content).dx,
          direction == TextDirection.ltr
              ? tester.getTopLeft(show).dx
              : tester.getTopRight(show).dx,
        );
      });
    }

    testWidgets('us15/fr03/e06: shown again, the content builds fresh', (
      tester,
    ) async {
      await tester.pumpWidget(_row(_show(visible: true)));
      final state = tester.state(find.byType(_Box));
      await tester.pumpWidget(_row(_show(visible: false)));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_row(_show(visible: true)));

      expect(tester.state(find.byType(_Box)), isNot(same(state)));
    });

    testWidgets('layout s03 invariant 47: the show is not wrapped in the '
        'disabled wrapper', (tester) async {
      await tester.pumpWidget(_row(_show(visible: true)));

      expect(
        find.ancestor(
          of: find.byType(StratumShow),
          matching: find.byType(StratumDisabled),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(StratumShow),
          matching: find.byType(StratumDisabled),
        ),
        findsNothing,
      );
    });
  });

  group('StratumShow slides', () {
    double left(WidgetTester tester) =>
        tester.getTopLeft(find.byKey(_content)).dx;
    double top(WidgetTester tester) =>
        tester.getTopLeft(find.byKey(_content)).dy;
    double showLeft(WidgetTester tester) =>
        tester.getTopLeft(find.byType(StratumShow)).dx;
    double showTop(WidgetTester tester) =>
        tester.getTopLeft(find.byType(StratumShow)).dy;

    Future<void> slideIn(
      WidgetTester tester,
      StratumShowSlideDirection direction, {
      TextDirection text = TextDirection.ltr,
    }) => _toggle(
      tester,
      _row(
        _show(
          visible: false,
          transition: StratumShowTransition.slide,
          slideDirection: direction,
        ),
        direction: text,
      ),
      _row(
        _show(
          visible: true,
          transition: StratumShowTransition.slide,
          slideDirection: direction,
        ),
        direction: text,
      ),
    );

    testWidgets('us15/fr02/e01, us15/s5: no direction in a left-to-right app '
        'slides in from the right by its own width while it fades in', (
      tester,
    ) async {
      await _toggle(
        tester,
        _row(_show(visible: false, transition: StratumShowTransition.slide)),
        _row(_show(visible: true, transition: StratumShowTransition.slide)),
      );
      await tester.pump();
      expect(left(tester), showLeft(tester) + 100);
      expect(_size(tester), const Size(100, 40));

      await tester.pump(const Duration(milliseconds: 60));
      expect(
        left(tester),
        inExclusiveRange(showLeft(tester), showLeft(tester) + 100),
      );
      expect(_opacity(tester), inExclusiveRange(0, 1));

      await tester.pump(const Duration(milliseconds: 65));
      expect(left(tester), showLeft(tester));
      expect(_opacity(tester), 1.0);
    });

    testWidgets('us15/fr02/e02, us15/s6: end under right to left comes from '
        'the left; start comes from the right', (tester) async {
      await slideIn(
        tester,
        StratumShowSlideDirection.end,
        text: TextDirection.rtl,
      );
      await tester.pump();
      expect(left(tester), showLeft(tester) - 100);

      await slideIn(
        tester,
        StratumShowSlideDirection.start,
        text: TextDirection.rtl,
      );
      await tester.pump();
      expect(left(tester), showLeft(tester) + 100);
    });

    for (final (direction, sign) in [
      (StratumShowSlideDirection.top, -1),
      (StratumShowSlideDirection.bottom, 1),
    ]) {
      for (final text in TextDirection.values) {
        testWidgets('us15/fr02/e03: ${direction.name} moves by its own height '
            'in ${text.name}', (tester) async {
          await slideIn(tester, direction, text: text);
          await tester.pump();

          expect(top(tester), showTop(tester) + sign * 40);
          expect(left(tester), showLeft(tester));
        });
      }
    }

    testWidgets('us15/fr02: a hide slides out toward the same edge, then '
        'takes no space', (tester) async {
      await _toggle(
        tester,
        _row(_show(visible: true, transition: StratumShowTransition.slide)),
        _row(_show(visible: false, transition: StratumShowTransition.slide)),
      );
      await tester.pump(const Duration(milliseconds: 40));
      expect(left(tester), greaterThan(showLeft(tester)));
      expect(_size(tester), const Size(100, 40));

      await tester.pump(const Duration(milliseconds: 40));
      // One more tick past the 80 ms hide: AnimationController reports
      // dismissed a tick after its value reaches 0 (isDone is strict `>`).
      await tester.pump(const Duration(milliseconds: 1));
      expect(_size(tester), Size.zero);
      expect(find.byKey(_content, skipOffstage: false), findsNothing);
    });

    testWidgets('a hide during a show reverses from where it is', (
      tester,
    ) async {
      await _toggle(
        tester,
        _row(_show(visible: false, transition: StratumShowTransition.slide)),
        _row(_show(visible: true, transition: StratumShowTransition.slide)),
      );
      await tester.pump(const Duration(milliseconds: 60));
      final at = left(tester);
      final opacity = _opacity(tester);

      await tester.pumpWidget(
        _row(_show(visible: false, transition: StratumShowTransition.slide)),
      );
      await tester.pump(const Duration(milliseconds: 1));

      expect(left(tester), closeTo(at, 3));
      expect(_opacity(tester), closeTo(opacity, 0.03));
    });

    testWidgets('us15/fr02/e04: a slide direction with another transition '
        'has no effect', (tester) async {
      await _toggle(
        tester,
        _row(
          _show(visible: false, slideDirection: StratumShowSlideDirection.top),
        ),
        _row(
          _show(visible: true, slideDirection: StratumShowSlideDirection.top),
        ),
      );
      await tester.pump(const Duration(milliseconds: 60));

      expect(top(tester), showTop(tester));
      expect(left(tester), showLeft(tester));
    });

    testWidgets('PD6: one clip bounds the slide to the show box', (
      tester,
    ) async {
      await tester.pumpWidget(
        _row(_show(visible: true, transition: StratumShowTransition.slide)),
      );

      expect(
        find.descendant(
          of: find.byType(StratumShow),
          matching: find.byType(ClipRect),
        ),
        findsOneWidget,
      );
    });
  });

  group('StratumShow input, focus, and maintainState', () {
    testWidgets('us15/fr03/e04, us15/s10: a tap during the hide reaches '
        'nothing inside the leaving content', (tester) async {
      var taps = 0;
      Widget build({required bool visible}) => _row(
        _show(
          visible: visible,
          child: KeyedSubtree(
            key: _content,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox(width: 100, height: 40),
            ),
          ),
        ),
      );
      await _toggle(tester, build(visible: true), build(visible: false));
      await tester.pump(const Duration(milliseconds: 10));

      await tester.tap(find.byKey(_content), warnIfMissed: false);
      await tester.pump(kDoubleTapTimeout);

      expect(taps, 0);
    });

    testWidgets('us15/fr03: from the frame it turns hidden, the leaving '
        'content is out of the semantics tree', (tester) async {
      final handle = tester.ensureSemantics();
      Widget build({required bool visible}) => _row(
        _show(
          visible: visible,
          child: KeyedSubtree(
            key: _content,
            child: Semantics(
              label: 'Inside',
              child: const SizedBox(width: 100, height: 40),
            ),
          ),
        ),
      );
      await _toggle(tester, build(visible: true), build(visible: false));
      await tester.pump();

      expect(_semanticsLabels(tester), isNot(contains('Inside')));
      handle.dispose();
    });

    testWidgets('us15/fr03/e03, us15/s11: focus inside hiding content moves '
        'to the show node, and Tab moves on from there', (tester) async {
      final field = FocusNode(debugLabel: 'field');
      final after = FocusNode(debugLabel: 'after');
      addTearDown(field.dispose);
      addTearDown(after.dispose);
      Widget build({required bool visible}) => themedHost(
        Shortcuts(
          shortcuts: WidgetsApp.defaultShortcuts,
          child: Actions(
            actions: WidgetsApp.defaultActions,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _show(
                  visible: visible,
                  child: KeyedSubtree(
                    key: _content,
                    child: Focus(
                      focusNode: field,
                      child: const SizedBox(width: 100, height: 40),
                    ),
                  ),
                ),
                Focus(
                  focusNode: after,
                  child: const SizedBox(width: 10, height: 10),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpWidget(build(visible: true));
      field.requestFocus();
      await tester.pump();

      await tester.pumpWidget(build(visible: false));
      await tester.pump();

      expect(field.hasFocus, isFalse);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'StratumShow');

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(after.hasPrimaryFocus, isTrue);
    });

    testWidgets('focus outside the show stays where it is', (tester) async {
      final outside = FocusNode(debugLabel: 'outside');
      addTearDown(outside.dispose);
      Widget build({required bool visible}) => themedHost(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Focus(
              focusNode: outside,
              child: const SizedBox(width: 10, height: 10),
            ),
            _show(visible: visible),
          ],
        ),
      );
      await tester.pumpWidget(build(visible: true));
      outside.requestFocus();
      await tester.pump();

      await tester.pumpWidget(build(visible: false));
      await tester.pump();

      expect(outside.hasPrimaryFocus, isTrue);
    });

    testWidgets('us15/fr03/e05, us15/s12: content kept alive keeps its State '
        'while hidden, with no size', (tester) async {
      await tester.pumpWidget(_row(_show(visible: true, maintainState: true)));
      final state = tester.state(find.byType(_Box));

      await tester.pumpWidget(_row(_show(visible: false, maintainState: true)));
      await tester.pumpAndSettle();
      expect(_size(tester), Size.zero);
      expect(find.byType(_Box), findsNothing);
      expect(find.byType(_Box, skipOffstage: false), findsOneWidget);

      await tester.pumpWidget(_row(_show(visible: true, maintainState: true)));
      expect(tester.state(find.byType(_Box)), same(state));
    });

    testWidgets('us15/fr03/e05: content kept alive stops its tickers while '
        'hidden', (tester) async {
      bool ticking() => TickerMode.valuesOf(
        tester.element(find.byType(_Box, skipOffstage: false)),
      ).enabled;
      await tester.pumpWidget(_row(_show(visible: true, maintainState: true)));
      expect(ticking(), isTrue);

      await tester.pumpWidget(_row(_show(visible: false, maintainState: true)));
      await tester.pumpAndSettle();
      expect(ticking(), isFalse);

      await tester.pumpWidget(_row(_show(visible: true, maintainState: true)));
      expect(ticking(), isTrue);
    });

    testWidgets('us15/fr03/e05, us15/s13: content kept alive takes no focus '
        'and leaves the semantics tree', (tester) async {
      final handle = tester.ensureSemantics();
      final before = FocusNode(debugLabel: 'before');
      final field = FocusNode(debugLabel: 'field');
      final after = FocusNode(debugLabel: 'after');
      addTearDown(before.dispose);
      addTearDown(field.dispose);
      addTearDown(after.dispose);
      await tester.pumpWidget(
        themedHost(
          Shortcuts(
            shortcuts: WidgetsApp.defaultShortcuts,
            child: Actions(
              actions: WidgetsApp.defaultActions,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Focus(
                    focusNode: before,
                    child: const SizedBox(width: 10, height: 10),
                  ),
                  _show(
                    visible: false,
                    maintainState: true,
                    child: KeyedSubtree(
                      key: _content,
                      child: Semantics(
                        label: 'Inside',
                        child: Focus(
                          focusNode: field,
                          child: const SizedBox(width: 100, height: 40),
                        ),
                      ),
                    ),
                  ),
                  Focus(
                    focusNode: after,
                    child: const SizedBox(width: 10, height: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(_content, skipOffstage: false), findsOneWidget);
      expect(_semanticsLabels(tester), isNot(contains('Inside')));

      field.requestFocus();
      await tester.pump();
      expect(field.hasFocus, isFalse);

      before.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(after.hasPrimaryFocus, isTrue);
      handle.dispose();
    });
  });

  group('StratumShow under reduced motion', () {
    testWidgets('us15/fr04/e01, us15/s7: sizeAndFade takes its full size at '
        'once and fades in', (tester) async {
      await _toggle(
        tester,
        _row(_show(visible: false), reduced: true),
        _row(_show(visible: true), reduced: true),
      );
      await tester.pump();
      expect(_size(tester), const Size(100, 40));

      await tester.pump(const Duration(milliseconds: 60));
      expect(_opacity(tester), inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 65));
      expect(_opacity(tester), 1.0);
    });

    testWidgets('us15/fr04: fade runs unchanged', (tester) async {
      await _toggle(
        tester,
        _row(
          _show(visible: false, transition: StratumShowTransition.fade),
          reduced: true,
        ),
        _row(
          _show(visible: true, transition: StratumShowTransition.fade),
          reduced: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 60));

      expect(_size(tester), const Size(100, 40));
      expect(_opacity(tester), inExclusiveRange(0, 1));
    });

    testWidgets('us15/fr04/e02: slide hides in place, fades out, then takes '
        'no space', (tester) async {
      await _toggle(
        tester,
        _row(
          _show(visible: true, transition: StratumShowTransition.slide),
          reduced: true,
        ),
        _row(
          _show(visible: false, transition: StratumShowTransition.slide),
          reduced: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 40));
      expect(
        tester.getTopLeft(find.byKey(_content)),
        tester.getTopLeft(find.byType(StratumShow)),
      );
      expect(_opacity(tester), inExclusiveRange(0, 1));

      await tester.pump(const Duration(milliseconds: 40));
      // One more tick past the 80 ms hide: AnimationController reports
      // dismissed a tick after its value reaches 0 (isDone is strict `>`).
      await tester.pump(const Duration(milliseconds: 1));
      expect(_size(tester), Size.zero);
    });

    testWidgets('us15/fr04/e03, us15/s8: size shows and hides at once', (
      tester,
    ) async {
      await _toggle(
        tester,
        _row(
          _show(visible: false, transition: StratumShowTransition.size),
          reduced: true,
        ),
        _row(
          _show(visible: true, transition: StratumShowTransition.size),
          reduced: true,
        ),
      );
      expect(_size(tester), const Size(100, 40));
      expect(_opacity(tester), 1.0);

      await tester.pumpWidget(
        _row(
          _show(visible: false, transition: StratumShowTransition.size),
          reduced: true,
        ),
      );
      expect(_size(tester), Size.zero);
      expect(find.byKey(_content, skipOffstage: false), findsNothing);
    });

    testWidgets('us15/fr04/e04: a caller duration sets the fade', (
      tester,
    ) async {
      const slow = Duration(milliseconds: 400);
      await _toggle(
        tester,
        _row(_show(visible: false, duration: slow), reduced: true),
        _row(_show(visible: true, duration: slow), reduced: true),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(_opacity(tester), lessThan(1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_opacity(tester), 1.0);
    });

    testWidgets('nfr-u03: the platform reduce-motion flag holds the same', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _toggle(
        tester,
        _row(_show(visible: false)),
        _row(_show(visible: true)),
      );
      await tester.pump();

      expect(_size(tester), const Size(100, 40));
    });
  });
}
