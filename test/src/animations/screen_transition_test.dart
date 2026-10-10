import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/animations/screen_transition.dart';
import 'package:stratum_ui/src/src.dart';

import '../components/common/fakes/fake_stratum_theme.dart';

/// Every type a switch in place takes: each type but the two that hand
/// their motion to a Flutter page transition (FO-03 US-12 FR-04 E01).
final List<ScreenTransitionType> _inPlaceTypes = [
  for (final type in ScreenTransitionType.values)
    if (flutterTransitionsBuilder(type, TargetPlatform.android) == null) type,
];

const Key _page = ValueKey('page');

/// The whole test view, where a page ends.
const _screen = Rect.fromLTWH(0, 0, 800, 600);

/// [type]'s transition of a full-size page with no route, coming in by
/// [animation], under app reduced motion when [reduced].
Widget _inPlace(
  ScreenTransitionType type,
  Animation<double> animation, {
  bool reduced = false,
}) => MediaQuery(
  data: MediaQueryData(size: const Size(800, 600), disableAnimations: reduced),
  child: themedHost(
    Builder(
      builder: (context) => buildScreenTransition<void>(
        type,
        context: context,
        animation: animation,
        secondaryAnimation: kAlwaysDismissedAnimation,
        child: const SizedBox.expand(key: _page),
        standard: Curves.easeInOutSine,
        alignment: Alignment.center,
        joinOnSecondary: true,
      ),
    ),
  ),
);

/// The rect a person sees the page take: its layout rect, moved, scaled,
/// and turned by every transition above it.
Rect _seen(WidgetTester tester) {
  final box = tester.renderObject<RenderBox>(find.byKey(_page));
  return MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
}

void main() {
  group('fo03/us12/fr04: a switch in place, with no route', () {
    test('takes every type but platform and cupertino', () {
      expect(_inPlaceTypes, hasLength(ScreenTransitionType.values.length - 2));
      expect(
        _inPlaceTypes,
        isNot(
          anyOf(
            contains(ScreenTransitionType.platform),
            contains(ScreenTransitionType.cupertino),
          ),
        ),
      );
    });

    for (final type in _inPlaceTypes) {
      testWidgets('us12/fr04/e03, nfr-u03: under reduced motion $type halfway '
          'in shows the page where it ends, unscaled', (tester) async {
        await tester.pumpWidget(
          _inPlace(type, const AlwaysStoppedAnimation(0.5), reduced: true),
        );

        expect(_seen(tester), _screen);
      });
    }

    for (final type in [
      ScreenTransitionType.rightToLeft,
      ScreenTransitionType.scale,
      ScreenTransitionType.fadeThrough,
      ScreenTransitionType.sharedAxisHorizontal,
    ]) {
      testWidgets('us12/fr04: with full motion $type a quarter in moves or '
          'scales the page', (tester) async {
        await tester.pumpWidget(
          _inPlace(type, const AlwaysStoppedAnimation(0.25)),
        );

        expect(_seen(tester), isNot(_screen));
      });
    }

    testWidgets('us12/fr04/e02: none shows the page at once', (tester) async {
      await tester.pumpWidget(
        _inPlace(ScreenTransitionType.none, kAlwaysDismissedAnimation),
      );

      expect(_seen(tester), _screen);
    });

    for (final type in [
      ScreenTransitionType.platform,
      ScreenTransitionType.cupertino,
    ]) {
      testWidgets('us12/fr04/e01: $type asserts a route', (tester) async {
        await tester.pumpWidget(
          _inPlace(type, const AlwaysStoppedAnimation(0.5)),
        );

        expect(
          tester.takeException(),
          isA<AssertionError>().having(
            (error) => error.message,
            'message',
            contains('needs the page route'),
          ),
        );
      });
    }
  });
}
