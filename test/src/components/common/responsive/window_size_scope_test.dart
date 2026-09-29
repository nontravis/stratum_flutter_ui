import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/responsive/window_size_scope.dart';
import 'package:stratum_ui/src/themes/model/window_size.dart';

void main() {
  void setWindowWidth(WidgetTester tester, double width) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 800);
  }

  testWidgets('of returns the window size class of the window width', (
    tester,
  ) async {
    setWindowWidth(tester, 900);
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

    expect(windowSize, WindowSize.expanded);
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

  testWidgets('rebuilds dependents only when the width crosses a breakpoint', (
    tester,
  ) async {
    setWindowWidth(tester, 400);
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
      setWindowWidth(tester, width);
      await tester.pump();
    }

    // Crosses 600, 840, and 1200.
    expect(dependentBuilds, 3);
    expect(independentBuilds, 0);
  });
}
