@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

/// [child] in a 400 by 300 box; [reduced] asks for `disableAnimations`.
Widget _host(Widget child, {bool reduced = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduced),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: SizedBox(width: 400, height: 300, child: child)),
  ),
);

Finder get _viewer => find.byType(InteractiveViewer);

Matrix4 _transform(WidgetTester tester) => tester
    .widget<Transform>(
      find.descendant(of: _viewer, matching: find.byType(Transform)).first,
    )
    .transform;

double _scale(WidgetTester tester) => _transform(tester).getMaxScaleOnAxis();

/// The point of the app under the center of the 400 by 300 viewport.
Offset _sceneCenter(WidgetTester tester) => MatrixUtils.transformPoint(
  Matrix4.inverted(_transform(tester)),
  const Offset(200, 150),
);

/// Two fingers that start 80 px apart and end [factor] times as far.
Future<void> _pinch(WidgetTester tester, double factor) async {
  final center = tester.getCenter(find.byType(StratumWebZoom));
  const half = 40.0;
  final a = await tester.startGesture(
    center - const Offset(half, 0),
    pointer: 1,
  );
  final b = await tester.startGesture(
    center + const Offset(half, 0),
    pointer: 2,
  );
  await tester.pump();
  for (var step = 1; step <= 10; step++) {
    final spread = half * (1 + (factor - 1) * step / 10);
    await a.moveTo(center - Offset(spread, 0));
    await b.moveTo(center + Offset(spread, 0));
    await tester.pump();
  }
  await a.up();
  await b.up();
  await tester.pumpAndSettle();
}

/// Two fingers that start 40 px apart, centered 20 px off the top-left
/// corner of the zoom, and end [factor] times as far.
Future<void> _cornerPinch(WidgetTester tester, double factor) async {
  final origin = tester.getTopLeft(find.byType(StratumWebZoom));
  final focal = origin + const Offset(40, 30);
  final a = await tester.startGesture(focal - const Offset(20, 0), pointer: 1);
  final b = await tester.startGesture(focal + const Offset(20, 0), pointer: 2);
  await tester.pump();
  for (var step = 1; step <= 10; step++) {
    final spread = 20.0 * (1 + (factor - 1) * step / 10);
    await a.moveTo(focal - Offset(spread, 0));
    await b.moveTo(focal + Offset(spread, 0));
    await tester.pump();
  }
  await a.up();
  await b.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('co01_04/us01/fr01: the web branch is one pinch zoom with the '
      'limits, clipped to its bounds (co01_04/us01/s7)', (tester) async {
    await tester.pumpWidget(
      _host(const StratumWebZoom(child: SizedBox.expand())),
    );

    final viewer = tester.widget<InteractiveViewer>(_viewer);
    expect(viewer.minScale, 1.0);
    expect(viewer.maxScale, 2.5);
    expect(viewer.clipBehavior, Clip.hardEdge);
  });

  testWidgets(
    'co01_04/us01/s1, co01_04/us01/fr01/e02: a pinch out zooms in up to 2.5',
    (tester) async {
      await tester.pumpWidget(
        _host(const StratumWebZoom(child: SizedBox.expand())),
      );

      await _pinch(tester, 5);
      expect(_scale(tester), closeTo(2.5, 0.01));

      await _pinch(tester, 2);
      expect(_scale(tester), closeTo(2.5, 0.01));
    },
  );

  testWidgets('co01_04/us01/s6: a maximum of 4 zooms in up to 4', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const StratumWebZoom(maxScale: 4, child: SizedBox.expand())),
    );

    await _pinch(tester, 6);

    expect(_scale(tester), closeTo(4, 0.01));
  });

  testWidgets(
    'co01_04/us01/fr01/e01, co01_04/us01/s3: a pinch in at the default minimum '
    'keeps the app at its own size',
    (tester) async {
      await tester.pumpWidget(
        _host(const StratumWebZoom(child: SizedBox.expand())),
      );

      await _pinch(tester, 0.5);

      expect(_scale(tester), 1.0);
    },
  );

  testWidgets('co01_04/us01/s2: a pan moves the view across the zoomed app', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const StratumWebZoom(child: SizedBox.expand())),
    );
    await _pinch(tester, 2);
    final before = _transform(tester).getTranslation();

    await tester.drag(find.byType(StratumWebZoom), const Offset(-60, -40));
    await tester.pumpAndSettle();

    expect(_transform(tester).getTranslation(), isNot(before));
  });

  testWidgets(
    'co01_04/us01/fr01/e03, co01_04/us01/s4: a browser trackpad pinch zooms in',
    (tester) async {
      await tester.pumpWidget(
        _host(const StratumWebZoom(child: SizedBox.expand())),
      );

      await tester.sendEventToBinding(
        PointerScaleEvent(
          position: tester.getCenter(find.byType(StratumWebZoom)),
          kind: PointerDeviceKind.trackpad,
          scale: 1.5,
        ),
      );
      await tester.pump();

      expect(_scale(tester), closeTo(1.5, 0.01));
    },
  );

  test(
    'R8, co01_04/us01/s9: a maximum below the minimum asserts on the web too',
    () {
      for (final (min, max) in [(2.0, 1.0)]) {
        expect(
          () => StratumWebZoom(
            minScale: min,
            maxScale: max,
            child: const SizedBox(),
          ),
          throwsAssertionError,
        );
      }
    },
  );

  group('new scale limits', () {
    Widget zoom({double minScale = 1, double maxScale = 2.5}) => StratumWebZoom(
      minScale: minScale,
      maxScale: maxScale,
      child: const SizedBox.expand(),
    );

    testWidgets('co01_04/us01/fr01/e05, co01_04/us01/s10: a maximum lowered below the zoom '
        'eases it back to the maximum, its center fixed', (tester) async {
      await tester.pumpWidget(_host(zoom()));
      await _pinch(tester, 2);
      final zoomed = _scale(tester);
      final center = _sceneCenter(tester);
      expect(zoomed, greaterThan(1.8));

      await tester.pumpWidget(_host(zoom(maxScale: 1.5)));
      await tester.pump(const Duration(milliseconds: 60));
      expect(_scale(tester), inExclusiveRange(1.5, zoomed));
      expect(_sceneCenter(tester), offsetMoreOrLessEquals(center));

      await tester.pumpAndSettle();
      expect(_scale(tester), 1.5);
      expect(_sceneCenter(tester), offsetMoreOrLessEquals(center));
    });

    testWidgets(
      'co01_04/us01/fr01/e05: a minimum raised above the zoom eases it up '
      'to the minimum, its center fixed',
      (tester) async {
        await tester.pumpWidget(_host(zoom()));
        final center = _sceneCenter(tester);

        await tester.pumpWidget(_host(zoom(minScale: 1.8)));
        await tester.pump(const Duration(milliseconds: 60));
        expect(_scale(tester), inExclusiveRange(1, 1.8));

        await tester.pumpAndSettle();
        expect(_scale(tester), 1.8);
        expect(_sceneCenter(tester), offsetMoreOrLessEquals(center));
      },
    );

    testWidgets(
      'co01_04/us01/fr01/e05: under reduced motion the zoom jumps to the '
      'new limit',
      (tester) async {
        await tester.pumpWidget(_host(zoom(), reduced: true));
        await _pinch(tester, 2);
        final center = _sceneCenter(tester);

        await tester.pumpWidget(_host(zoom(maxScale: 1.5), reduced: true));

        expect(tester.hasRunningAnimations, isFalse);
        expect(_scale(tester), 1.5);
        expect(_sceneCenter(tester), offsetMoreOrLessEquals(center));
      },
    );

    testWidgets(
      'co01_04/us01/fr01/e05: limits widened around the zoom leave it '
      'alone',
      (tester) async {
        await tester.pumpWidget(_host(zoom()));
        await _pinch(tester, 2);
        final zoomed = _scale(tester);

        await tester.pumpWidget(_host(zoom(minScale: 0.5, maxScale: 4)));

        expect(tester.hasRunningAnimations, isFalse);
        expect(_scale(tester), zoomed);
      },
    );

    testWidgets('R16: a maximum lowered past a corner zoom leaves no blank '
        'strip', (tester) async {
      await tester.pumpWidget(_host(zoom()));
      await _cornerPinch(tester, 2);

      await tester.pumpWidget(_host(zoom(maxScale: 1.5)));
      await tester.pumpAndSettle();

      final translation = _transform(tester).getTranslation();
      expect(_scale(tester), 1.5);
      expect(translation.x, inInclusiveRange(400 * (1 - 1.5), 0.0));
      expect(translation.y, inInclusiveRange(300 * (1 - 1.5), 0.0));
    });

    testWidgets('co01_04/us01/fr01/e05: a pinch mid-ease shows its own scale, '
        'not the stale eased one', (tester) async {
      await tester.pumpWidget(_host(zoom()));
      await _pinch(tester, 2);

      await tester.pumpWidget(_host(zoom(maxScale: 1.5)));
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.hasRunningAnimations, isTrue);
      final start = _scale(tester);

      final center = tester.getCenter(find.byType(StratumWebZoom));
      const half = 40.0;
      final a = await tester.startGesture(
        center - const Offset(half, 0),
        pointer: 1,
      );
      final b = await tester.startGesture(
        center + const Offset(half, 0),
        pointer: 2,
      );
      await tester.pump();
      await a.moveTo(center - const Offset(half * 1.2, 0));
      await b.moveTo(center + const Offset(half * 1.2, 0));
      await tester.pump();

      expect(tester.hasRunningAnimations, isFalse);
      expect(_scale(tester), closeTo(clampDouble(start * 1.2, 1, 1.5), 0.01));

      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      expect(_scale(tester), 1.5);
    });

    testWidgets(
      'co01_04/us01/fr01/e05: a rebuild with unchanged limits does not '
      'restart the ease',
      (tester) async {
        await tester.pumpWidget(_host(zoom()));
        await _pinch(tester, 2);

        await tester.pumpWidget(_host(zoom(maxScale: 1.5)));
        await tester.pump(const Duration(milliseconds: 30));
        final mid = _scale(tester);

        await tester.pumpWidget(_host(zoom(maxScale: 1.5)));
        await tester.pump(const Duration(milliseconds: 30));

        expect(_scale(tester), lessThan(mid));

        await tester.pumpAndSettle();
        expect(_scale(tester), 1.5);
      },
    );

    testWidgets(
      'co01_04/us01/fr01/e05: a dispose mid-ease leaves no ticker and no '
      'exception',
      (tester) async {
        await tester.pumpWidget(_host(zoom()));
        await _pinch(tester, 2);

        await tester.pumpWidget(_host(zoom(maxScale: 1.5)));
        await tester.pump(const Duration(milliseconds: 30));

        await tester.pumpWidget(const SizedBox());

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('co01_04/us01/fr01/e05: a wheel notch mid-ease leaves the ease '
        'running on schedule', (tester) async {
      await tester.pumpWidget(_host(zoom()));
      await _pinch(tester, 2);
      final zoomed = _scale(tester);

      await tester.pumpWidget(_host(zoom(maxScale: 1.5)));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        pointer.hover(tester.getCenter(find.byType(StratumWebZoom))),
      );
      for (var notch = 0; notch < 3; notch++) {
        await tester.sendEventToBinding(pointer.scroll(const Offset(0, -1)));
        await tester.pump(const Duration(milliseconds: 20));
      }

      // What an uninterrupted ease would show at the same 60 ms, so a
      // crawl (each notch restarting the curve at 0) reads far below it.
      final expected =
          zoomed + (1.5 - zoomed) * Curves.easeInOutSine.transform(60 / 125);
      expect(_scale(tester), closeTo(expected, 0.03));

      await tester.pumpAndSettle();
      expect(_scale(tester), 1.5);
    });
  });

  group('the mouse wheel', () {
    Future<void> wheel(
      WidgetTester tester,
      Offset delta, {
      PointerDeviceKind kind = PointerDeviceKind.mouse,
    }) async {
      final pointer = TestPointer(1, kind);
      await tester.sendEventToBinding(
        pointer.hover(tester.getCenter(find.byType(StratumWebZoom))),
      );
      await tester.sendEventToBinding(pointer.scroll(delta));
      await tester.pump();
    }

    Widget list(ScrollController controller) => _host(
      StratumWebZoom(
        child: ListView.builder(
          controller: controller,
          itemExtent: 50,
          itemCount: 100,
          itemBuilder: (_, index) => Text('$index'),
        ),
      ),
    );

    testWidgets(
      'co01_04/us01/fr03, co01_04/us01/fr03/e01, co01_04/us01/s5: the wheel '
      'scrolls a list and the scale stays',
      (tester) async {
        final controller = ScrollController(initialScrollOffset: 100);
        addTearDown(controller.dispose);
        await tester.pumpWidget(list(controller));

        await wheel(tester, const Offset(0, -20));

        expect(_scale(tester), 1.0);
        expect(controller.offset, lessThan(100));
      },
    );

    testWidgets(
      'co01_04/us01/fr03/e02: the wheel over content that does not scroll '
      'leaves the scale',
      (tester) async {
        await tester.pumpWidget(
          _host(const StratumWebZoom(child: SizedBox.expand())),
        );

        await wheel(tester, const Offset(0, -20));

        expect(_scale(tester), 1.0);
      },
    );

    testWidgets(
      'co01_04/us01/fr03/e03: zoomed in, the wheel scrolls the list and '
      'the scale stays',
      (tester) async {
        final controller = ScrollController(initialScrollOffset: 100);
        addTearDown(controller.dispose);
        await tester.pumpWidget(list(controller));
        await _pinch(tester, 2);
        final zoomed = _scale(tester);
        final offset = controller.offset;
        expect(zoomed, greaterThan(1.2));

        await wheel(tester, const Offset(0, 20));

        expect(_scale(tester), zoomed);
        expect(controller.offset, greaterThan(offset));
      },
    );

    testWidgets('a wheel over a list already at its end leaves the scale', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(list(controller));

      await wheel(tester, const Offset(0, -20));

      expect(_scale(tester), 1.0);
      expect(controller.offset, 0);
    });

    testWidgets('a trackpad two-finger scroll over a zoomed app leaves the '
        'scale', (tester) async {
      await tester.pumpWidget(
        _host(const StratumWebZoom(child: SizedBox.expand())),
      );
      await _pinch(tester, 2);
      final zoomed = _scale(tester);

      await wheel(
        tester,
        const Offset(0, 20),
        kind: PointerDeviceKind.trackpad,
      );

      expect(_scale(tester), zoomed);
    });
  });
}
