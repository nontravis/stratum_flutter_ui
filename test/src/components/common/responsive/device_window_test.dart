import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/responsive/device_window.dart';
import 'package:stratum_ui/src/components/common/responsive/keyboard_visibility_scope.dart';
import 'package:stratum_ui/src/components/common/responsive/window_size_scope.dart';
import 'package:stratum_ui/src/themes/constant/window_size.dart';

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

    expect(windowSize, WindowSize.tablet);
  });

  testWidgets('keeps a rotated phone mobile and reports it as landscape', (
    tester,
  ) async {
    setWindowSize(tester, const Size(393, 852));
    addTearDown(tester.view.reset);
    late WindowSize windowSize;
    late bool isLandscape;

    await tester.pumpWidget(
      WindowSizeScope(
        child: capture((window) {
          windowSize = window.windowSize;
          isLandscape = window.isLandscape;
        }),
      ),
    );
    setWindowSize(tester, const Size(852, 393));
    await tester.pump();

    expect(windowSize, WindowSize.mobile);
    expect(isLandscape, isTrue);
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
      KeyboardVisibilityScope(
        child: capture((window) {
          keyboardHeight = window.keyboardHeight;
          isKeyboardVisible = window.isKeyboardVisible;
        }),
      ),
    );

    expect(keyboardHeight, 300);
    expect(isKeyboardVisible, isTrue);
  });

  testWidgets('inside a Scaffold body, the keyboard reads as open but its '
      'height as already consumed', (tester) async {
    setWindowSize(tester, const Size(400, 800));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    late double keyboardHeight;
    late bool isKeyboardVisible;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => KeyboardVisibilityScope(child: child!),
        home: Scaffold(
          body: capture((window) {
            keyboardHeight = window.keyboardHeight;
            isKeyboardVisible = window.isKeyboardVisible;
          }),
        ),
      ),
    );

    expect(isKeyboardVisible, isTrue);
    expect(keyboardHeight, 0);
  });

  testWidgets('reports no keyboard while the keyboard is closed', (
    tester,
  ) async {
    setWindowSize(tester, const Size(400, 800));
    addTearDown(tester.view.reset);
    late double keyboardHeight;
    late bool isKeyboardVisible;

    await tester.pumpWidget(
      KeyboardVisibilityScope(
        child: capture((window) {
          keyboardHeight = window.keyboardHeight;
          isKeyboardVisible = window.isKeyboardVisible;
        }),
      ),
    );

    expect(keyboardHeight, 0);
    expect(isKeyboardVisible, isFalse);
  });

  testWidgets('reports portrait when the window is taller than wide', (
    tester,
  ) async {
    setWindowSize(tester, const Size(400, 800));
    addTearDown(tester.view.reset);
    late bool isPortrait;
    late bool isLandscape;

    await tester.pumpWidget(
      capture((window) {
        isPortrait = window.isPortrait;
        isLandscape = window.isLandscape;
      }),
    );

    expect(isPortrait, isTrue);
    expect(isLandscape, isFalse);
  });

  testWidgets('reports landscape when the window is wider than tall', (
    tester,
  ) async {
    setWindowSize(tester, const Size(800, 400));
    addTearDown(tester.view.reset);
    late bool isPortrait;
    late bool isLandscape;

    await tester.pumpWidget(
      capture((window) {
        isPortrait = window.isPortrait;
        isLandscape = window.isLandscape;
      }),
    );

    expect(isPortrait, isFalse);
    expect(isLandscape, isTrue);
  });

  testWidgets('widthPercent and heightPercent take a 0 to 100 percentage', (
    tester,
  ) async {
    setWindowSize(tester, const Size(400, 800));
    addTearDown(tester.view.reset);
    late double quarterWidth;
    late double halfHeight;

    await tester.pumpWidget(
      capture((window) {
        quarterWidth = window.widthPercent(25);
        halfHeight = window.heightPercent(50);
      }),
    );

    expect(quarterWidth, 100);
    expect(halfHeight, 400);
  });

  testWidgets('safeWidthPercent and safeHeightPercent exclude the safe area', (
    tester,
  ) async {
    setWindowSize(tester, const Size(400, 800));
    tester.view.padding = const FakeViewPadding(
      left: 20,
      top: 47,
      right: 20,
      bottom: 33,
    );
    addTearDown(tester.view.reset);
    late double halfSafeWidth;
    late double halfSafeHeight;

    await tester.pumpWidget(
      capture((window) {
        halfSafeWidth = window.safeWidthPercent(50);
        halfSafeHeight = window.safeHeightPercent(50);
      }),
    );

    expect(halfSafeWidth, (400 - 20 - 20) / 2);
    expect(halfSafeHeight, (800 - 47 - 33) / 2);
  });

  testWidgets('reports the dark platform brightness of the OS', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    late Brightness platformBrightness;
    late bool isPlatformDarkMode;
    late bool isPlatformLightMode;

    await tester.pumpWidget(
      capture((window) {
        platformBrightness = window.platformBrightness;
        isPlatformDarkMode = window.isPlatformDarkMode;
        isPlatformLightMode = window.isPlatformLightMode;
      }),
    );

    expect(platformBrightness, Brightness.dark);
    expect(isPlatformDarkMode, isTrue);
    expect(isPlatformLightMode, isFalse);
  });

  testWidgets('reports the light platform brightness of the OS', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    late bool isPlatformDarkMode;
    late bool isPlatformLightMode;

    await tester.pumpWidget(
      capture((window) {
        isPlatformDarkMode = window.isPlatformDarkMode;
        isPlatformLightMode = window.isPlatformLightMode;
      }),
    );

    expect(isPlatformDarkMode, isFalse);
    expect(isPlatformLightMode, isTrue);
  });

  testWidgets('reads a right-to-left textDirection from Directionality', (
    tester,
  ) async {
    late TextDirection textDirection;
    late bool isLTR;
    late bool isRTL;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: capture((window) {
          textDirection = window.textDirection;
          isLTR = window.isLTR;
          isRTL = window.isRTL;
        }),
      ),
    );

    expect(textDirection, TextDirection.rtl);
    expect(isLTR, isFalse);
    expect(isRTL, isTrue);
  });

  testWidgets('reads a left-to-right textDirection from Directionality', (
    tester,
  ) async {
    late bool isLTR;
    late bool isRTL;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: capture((window) {
          isLTR = window.isLTR;
          isRTL = window.isRTL;
        }),
      ),
    );

    expect(isLTR, isTrue);
    expect(isRTL, isFalse);
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
