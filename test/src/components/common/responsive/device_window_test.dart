import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/responsive/device_window.dart';
import 'package:stratum_ui/src/components/common/responsive/window_size_scope.dart';
import 'package:stratum_ui/src/themes/model/window_size.dart';

void main() {
  void setWindowSize(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
  }

  Widget capture(void Function(DeviceWindow window) onBuild) => Builder(
    builder: (context) {
      onBuild(context.deviceWindow);
      return const SizedBox();
    },
  );

  testWidgets('reads width, height, and orientation of the window', (
    tester,
  ) async {
    setWindowSize(tester, const Size(1000, 700));
    addTearDown(tester.view.reset);
    late double width;
    late double height;
    late Orientation orientation;

    await tester.pumpWidget(
      capture((window) {
        width = window.width;
        height = window.height;
        orientation = window.orientation;
      }),
    );

    expect(width, 1000);
    expect(height, 700);
    expect(orientation, Orientation.landscape);
  });

  testWidgets('reads windowSize from the nearest WindowSizeScope', (
    tester,
  ) async {
    setWindowSize(tester, const Size(1000, 700));
    addTearDown(tester.view.reset);
    late WindowSize windowSize;

    await tester.pumpWidget(
      WindowSizeScope(
        child: capture((window) => windowSize = window.windowSize),
      ),
    );

    expect(windowSize, WindowSize.expanded);
  });

  testWidgets('reads safeArea from the nearest MediaQuery, not the root', (
    tester,
  ) async {
    setWindowSize(tester, const Size(400, 800));
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);
    late EdgeInsets rootSafeArea;
    late EdgeInsets localSafeArea;

    await tester.pumpWidget(
      Column(
        children: [
          capture((window) => rootSafeArea = window.safeArea),
          Builder(
            builder: (context) => MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: capture((window) => localSafeArea = window.safeArea),
            ),
          ),
        ],
      ),
    );

    expect(rootSafeArea, const EdgeInsets.only(top: 47, bottom: 34));
    expect(localSafeArea, const EdgeInsets.only(bottom: 34));
  });

  testWidgets('safeHeight subtracts the top and bottom safe area insets', (
    tester,
  ) async {
    setWindowSize(tester, const Size(400, 800));
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);
    late double safeHeight;

    await tester.pumpWidget(
      capture((window) => safeHeight = window.safeHeight),
    );

    expect(safeHeight, 800 - 47 - 34);
  });

  testWidgets('safeWidth subtracts the left and right safe area insets', (
    tester,
  ) async {
    setWindowSize(tester, const Size(800, 400));
    tester.view.padding = const FakeViewPadding(left: 44, right: 44);
    addTearDown(tester.view.reset);
    late double safeWidth;

    await tester.pumpWidget(capture((window) => safeWidth = window.safeWidth));

    expect(safeWidth, 800 - 44 - 44);
  });

  testWidgets('reports the keyboard height while the keyboard is open', (
    tester,
  ) async {
    setWindowSize(tester, const Size(400, 800));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    late double keyboardHeight;
    late bool isKeyboardVisible;

    await tester.pumpWidget(
      capture((window) {
        keyboardHeight = window.keyboardHeight;
        isKeyboardVisible = window.isKeyboardVisible;
      }),
    );

    expect(keyboardHeight, 300);
    expect(isKeyboardVisible, isTrue);
  });

  testWidgets('reports no keyboard while the keyboard is closed', (
    tester,
  ) async {
    setWindowSize(tester, const Size(400, 800));
    addTearDown(tester.view.reset);
    late double keyboardHeight;
    late bool isKeyboardVisible;

    await tester.pumpWidget(
      capture((window) {
        keyboardHeight = window.keyboardHeight;
        isKeyboardVisible = window.isKeyboardVisible;
      }),
    );

    expect(keyboardHeight, 0);
    expect(isKeyboardVisible, isFalse);
  });

  testWidgets('a height reader does not rebuild when only the width changes', (
    tester,
  ) async {
    setWindowSize(tester, const Size(400, 800));
    addTearDown(tester.view.reset);
    var heightReaderBuilds = 0;

    await tester.pumpWidget(
      capture((window) {
        window.height;
        heightReaderBuilds++;
      }),
    );
    heightReaderBuilds = 0;

    for (var width = 401.0; width <= 500; width++) {
      setWindowSize(tester, Size(width, 800));
      await tester.pump();
    }

    expect(heightReaderBuilds, 0);
  });
}
