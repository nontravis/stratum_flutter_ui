import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/responsive/window_size_scope.dart';
import 'package:stratum_ui/src/themes/constant/window_size.dart';

void main() {
  void setWindowSize(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
  }

  testWidgets('of returns the window size class of the window size', (
    tester,
  ) async {
    setWindowSize(tester, const Size(900, 800));
    addTearDown(tester.view.reset);
    late WindowSize windowSize;

    await tester.pumpWidget(
      WindowSizeScope(
        child: Builder(
          builder: (context) {
            windowSize = WindowSizeScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(windowSize, WindowSize.tablet);
  });

  testWidgets('of throws a FlutterError without a WindowSizeScope ancestor', (
    tester,
  ) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          WindowSizeScope.of(context);
          return const SizedBox();
        },
      ),
    );

    expect(
      tester.takeException(),
      isA<FlutterError>().having(
        (error) => error.message,
        'message',
        contains('No WindowSizeScope found'),
      ),
    );
  });

  testWidgets('rebuilds dependents only when the size crosses a breakpoint', (
    tester,
  ) async {
    setWindowSize(tester, const Size(400, 800));
    addTearDown(tester.view.reset);
    var dependentBuilds = 0;
    var independentBuilds = 0;

    await tester.pumpWidget(
      WindowSizeScope(
        child: Column(
          children: [
            Builder(
              builder: (context) {
                WindowSizeScope.of(context);
                dependentBuilds++;
                return const SizedBox();
              },
            ),
            Builder(
              builder: (context) {
                independentBuilds++;
                return const SizedBox();
              },
            ),
          ],
        ),
      ),
    );
    dependentBuilds = 0;
    independentBuilds = 0;

    for (var width = 401.0; width <= 1400; width++) {
      setWindowSize(tester, Size(width, 800));
      await tester.pump();
    }

    // Crosses 600 (shortest side) and 1200 (width).
    expect(dependentBuilds, 2);
    expect(independentBuilds, 0);
  });

  testWidgets('does not rebuild dependents when a phone rotates', (
    tester,
  ) async {
    setWindowSize(tester, const Size(393, 852));
    addTearDown(tester.view.reset);
    var dependentBuilds = 0;

    await tester.pumpWidget(
      WindowSizeScope(
        child: Builder(
          builder: (context) {
            WindowSizeScope.of(context);
            dependentBuilds++;
            return const SizedBox();
          },
        ),
      ),
    );
    dependentBuilds = 0;

    setWindowSize(tester, const Size(852, 393));
    await tester.pump();

    expect(dependentBuilds, 0);
  });
}
