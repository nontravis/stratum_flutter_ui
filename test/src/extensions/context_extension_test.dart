import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/responsive/window_size_scope.dart';
import 'package:stratum_ui/src/extensions/context_extension.dart';
import 'package:stratum_ui/src/themes/constant/widget_size.dart';
import 'package:stratum_ui/src/themes/constant/window_size.dart';
import 'package:stratum_ui/src/themes/theme_application.dart';
import 'package:stratum_ui/src/themes/theme_set.dart';

import '../components/common/fakes/fake_stratum_theme.dart';

void main() {
  group('context.reducesMotion', () {
    void useFeatures(WidgetTester tester, FakeAccessibilityFeatures features) {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          features;
      addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }

    /// The result of `context.reducesMotion` below [data], or below no
    /// [MediaQuery] of the test's own when [data] is null.
    Future<bool> read(WidgetTester tester, {MediaQueryData? data}) async {
      late bool result;
      Widget probe = Builder(
        builder: (context) {
          result = context.reducesMotion;
          return const SizedBox();
        },
      );
      if (data != null) probe = MediaQuery(data: data, child: probe);
      await tester.pumpWidget(probe);
      return result;
    }

    testWidgets('is false when neither the app nor the platform asks', (
      tester,
    ) async {
      expect(await read(tester, data: const MediaQueryData()), isFalse);
    });

    testWidgets('is false without a flag and no MediaQuery of its own', (
      tester,
    ) async {
      expect(await read(tester), isFalse);
    });

    testWidgets("is true for the app's MediaQuery disableAnimations", (
      tester,
    ) async {
      expect(
        await read(tester, data: const MediaQueryData(disableAnimations: true)),
        isTrue,
      );
    });

    testWidgets('is true for the platform reduceMotion', (tester) async {
      useFeatures(tester, const FakeAccessibilityFeatures(reduceMotion: true));

      expect(await read(tester, data: const MediaQueryData()), isTrue);
    });

    testWidgets("lets the app's MediaQuery override the platform "
        'disableAnimations', (tester) async {
      useFeatures(
        tester,
        const FakeAccessibilityFeatures(disableAnimations: true),
      );

      expect(await read(tester, data: const MediaQueryData()), isFalse);
    });
  });

  final light = fakeTheme.copyWith(defaultWidgetSize: WidgetSize.small);
  final dark = fakeTheme.copyWith(defaultWidgetSize: WidgetSize.large);

  /// What [read] returns while a probe builds under a theme application
  /// of [light] and [dark] in [mode], or under no application at all.
  Future<T> readAt<T>(
    WidgetTester tester,
    T Function(BuildContext context) read, {
    ThemeMode mode = ThemeMode.light,
    bool themed = true,
  }) async {
    late T result;
    final probe = Builder(
      builder: (context) {
        result = read(context);
        return const SizedBox();
      },
    );
    await tester.pumpWidget(
      themed
          ? StratumThemeApplication(
              themes: StratumThemeSet(light: light, dark: dark),
              themeMode: mode,
              child: probe,
            )
          : probe,
    );
    return result;
  }

  group('context.themeData', () {
    testWidgets('fo03/us10/fr06: reads the data of the app mode', (
      tester,
    ) async {
      final data = await readAt(tester, (c) => c.themeData());
      expect(data, same(light));
    });

    testWidgets('fo03/us10/fr06/e03: reads the data of a given mode', (
      tester,
    ) async {
      final data = await readAt(tester, (c) => c.themeData(ThemeMode.dark));
      expect(data, same(dark));
    });

    testWidgets(
      'fo03/us10/fr06/e01: throws a FlutterError naming the application '
      'with no theme above',
      (tester) async {
        await readAt(tester, (c) => c, themed: false).then((context) {
          expect(
            () => context.themeData(),
            throwsA(
              isA<FlutterError>().having(
                (e) => e.message,
                'message',
                contains('StratumThemeApplication'),
              ),
            ),
          );
        });
      },
    );
  });

  group('context.defaultWidgetSize', () {
    testWidgets('fo03/us10/s6: reads the default widget size of the app mode', (
      tester,
    ) async {
      expect(
        await readAt(tester, (c) => c.defaultWidgetSize()),
        WidgetSize.small,
      );
    });

    testWidgets(
      'fo03/us10/fr06/e03: reads the dark data size for the dark mode',
      (tester) async {
        expect(
          await readAt(tester, (c) => c.defaultWidgetSize(ThemeMode.dark)),
          WidgetSize.large,
        );
      },
    );
  });

  group('context.windowSize', () {
    testWidgets(
      'fo03/us10/s7: reads tablet from the nearest window size scope',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(800, 1000);
        addTearDown(tester.view.reset);
        late WindowSize size;
        await tester.pumpWidget(
          WindowSizeScope(
            child: Builder(
              builder: (context) {
                size = context.windowSize;
                return const SizedBox();
              },
            ),
          ),
        );
        expect(size, WindowSize.tablet);
      },
    );

    testWidgets(
      'fo03/us10/fr06/e02: throws the scope error with no scope above',
      (tester) async {
        final context = await readAt(tester, (c) => c, themed: false);
        expect(() => context.windowSize, throwsA(isA<FlutterError>()));
      },
    );
  });
}
