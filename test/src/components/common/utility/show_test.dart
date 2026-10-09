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

/// A [StratumShow] around a [_Box] keyed [_content].
StratumShow _show({
  required bool visible,
  StratumShowTransition transition = StratumShowTransition.sizeAndFade,
  Duration? duration,
  Duration? reverseDuration,
}) => StratumShow(
  visible: visible,
  transition: transition,
  duration: duration,
  reverseDuration: reverseDuration,
  child: const KeyedSubtree(key: _content, child: _Box()),
);

/// [show] between two texts, in a themed row sized to its children, so a
/// row that takes no space still reports [Size.zero].
Widget _row(
  Widget show, {
  StratumThemeData? theme,
  TextDirection direction = TextDirection.ltr,
}) => themedHost(
  Row(
    mainAxisSize: MainAxisSize.min,
    children: [const Text('A'), show, const Text('B')],
  ),
  theme: theme,
  textDirection: direction,
);

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
}
