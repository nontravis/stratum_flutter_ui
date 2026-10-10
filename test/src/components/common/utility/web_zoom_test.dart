@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/base/disabled.dart';
import 'package:stratum_ui/src/src.dart';

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: SizedBox(width: 400, height: 300, child: child)),
);

void main() {
  for (final (name, zoom) in [
    ('no limits', const StratumWebZoom(child: SizedBox.expand())),
    (
      'valid limits',
      const StratumWebZoom(
        minScale: 0.5,
        maxScale: 4,
        child: SizedBox.expand(),
      ),
    ),
  ]) {
    testWidgets('co01-04/us01/fr02, us01/fr02/e02: with $name it builds its '
        'child alone off the web', (tester) async {
      await tester.pumpWidget(_host(zoom));

      Widget? built;
      tester
          .element(find.byType(StratumWebZoom))
          .visitChildElements((element) => built = element.widget);
      expect(built, same(zoom.child));
      expect(find.byType(InteractiveViewer), findsNothing);
      expect(find.byType(StratumDisabled), findsNothing);
    });
  }

  testWidgets(
    'co01-04/us01/fr02/e01, us01/s8: a pinch on Android reaches the child '
    'as it would with no web zoom',
    variant: TargetPlatformVariant.only(TargetPlatform.android),
    (tester) async {
      var scale = 1.0;
      await tester.pumpWidget(
        _host(
          StratumWebZoom(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleUpdate: (details) => scale = details.scale,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      final center = tester.getCenter(find.byType(StratumWebZoom));
      final a = await tester.startGesture(
        center - const Offset(50, 0),
        pointer: 1,
      );
      final b = await tester.startGesture(
        center + const Offset(50, 0),
        pointer: 2,
      );
      await tester.pump();
      for (var step = 1; step <= 10; step++) {
        await a.moveTo(center - Offset(50.0 + 10 * step, 0));
        await b.moveTo(center + Offset(50.0 + 10 * step, 0));
        await tester.pump();
      }
      await a.up();
      await b.up();
      await tester.pump();

      expect(scale, greaterThan(1.5));
    },
  );

  group('R8: the scale limits assert on every platform', () {
    for (final (name, min, max) in [
      ('a maximum below the minimum', 2.0, 1.0),
      ('a minimum of 0', 0.0, 2.5),
      ('a negative minimum', -1.0, 2.5),
    ]) {
      test('co01-04/us01/fr01/e04, us01/fr02/e02, us01/s9: $name stops the '
          'build with a message about the scale limits', () {
        expect(
          () => StratumWebZoom(
            minScale: min,
            maxScale: max,
            child: const SizedBox(),
          ),
          throwsA(
            isA<AssertionError>().having(
              (error) => '${error.message}',
              'message',
              contains('Scale'),
            ),
          ),
        );
      });
    }

    test('a maximum equal to the minimum is valid', () {
      expect(
        const StratumWebZoom(
          minScale: 2,
          maxScale: 2,
          child: SizedBox(),
        ).maxScale,
        2,
      );
    });
  });
}
