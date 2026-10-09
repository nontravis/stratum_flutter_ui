@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/utility/web_zoom.dart';
import 'package:stratum_ui/src/src.dart';

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: SizedBox(width: 400, height: 300, child: child)),
);

Finder get _viewer => find.byType(InteractiveViewer);

Matrix4 _transform(WidgetTester tester) => tester
    .widget<Transform>(
      find.descendant(of: _viewer, matching: find.byType(Transform)).first,
    )
    .transform;

double _scale(WidgetTester tester) => _transform(tester).getMaxScaleOnAxis();

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

void main() {
  testWidgets('co01-04/us01/fr01: the web branch is one pinch zoom with the '
      'limits, clipped to its bounds (us01/s7)', (tester) async {
    await tester.pumpWidget(
      _host(const StratumWebZoom(child: SizedBox.expand())),
    );

    final viewer = tester.widget<InteractiveViewer>(_viewer);
    expect(viewer.minScale, 1.0);
    expect(viewer.maxScale, 2.5);
    expect(viewer.clipBehavior, Clip.hardEdge);
  });

  testWidgets('us01/s1, us01/fr01/e02: a pinch out zooms in up to 2.5', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const StratumWebZoom(child: SizedBox.expand())),
    );

    await _pinch(tester, 5);
    expect(_scale(tester), closeTo(2.5, 0.01));

    await _pinch(tester, 2);
    expect(_scale(tester), closeTo(2.5, 0.01));
  });

  testWidgets('us01/s6: a maximum of 4 zooms in up to 4', (tester) async {
    await tester.pumpWidget(
      _host(const StratumWebZoom(maxScale: 4, child: SizedBox.expand())),
    );

    await _pinch(tester, 6);

    expect(_scale(tester), closeTo(4, 0.01));
  });

  testWidgets('us01/fr01/e01, us01/s3: a pinch in at the default minimum '
      'keeps the app at its own size', (tester) async {
    await tester.pumpWidget(
      _host(const StratumWebZoom(child: SizedBox.expand())),
    );

    await _pinch(tester, 0.5);

    expect(_scale(tester), 1.0);
  });

  testWidgets('us01/s2: a pan moves the view across the zoomed app', (
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

  testWidgets('us01/fr01/e03, us01/s4: a browser trackpad pinch zooms in', (
    tester,
  ) async {
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
  });

  test('R8, us01/s9: a maximum below the minimum asserts on the web too', () {
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

    testWidgets('co01-04/us01/fr03, us01/fr03/e01, us01/s5: the wheel '
        'scrolls a list and the scale stays', (tester) async {
      final controller = ScrollController(initialScrollOffset: 100);
      addTearDown(controller.dispose);
      await tester.pumpWidget(list(controller));

      await wheel(tester, const Offset(0, -20));

      expect(_scale(tester), 1.0);
      expect(controller.offset, lessThan(100));
    });

    testWidgets('us01/fr03/e02: the wheel over content that does not scroll '
        'leaves the scale', (tester) async {
      await tester.pumpWidget(
        _host(const StratumWebZoom(child: SizedBox.expand())),
      );

      await wheel(tester, const Offset(0, -20));

      expect(_scale(tester), 1.0);
    });

    testWidgets('us01/fr03/e03: zoomed in, the wheel scrolls the list and '
        'the scale stays', (tester) async {
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
    });

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
