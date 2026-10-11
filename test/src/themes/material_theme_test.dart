import 'package:animations/animations.dart'
    show FadeThroughTransition, SharedAxisTransition;
import 'package:flutter/cupertino.dart' show CupertinoPageTransition;
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/animations/stratum_page_transitions_builder.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/typography/google_fonts_lookup.dart';

import '../components/common/fakes/fake_stratum_theme.dart';
import 'config/theme_fixtures.dart' show layer;

ThemeData _material(
  StratumThemeData data, {
  Locale locale = const Locale('en'),
  WindowSize windowSize = WindowSize.mobile,
}) => data.toThemeData(
  locale: locale,
  windowSize: windowSize,
  textScaler: TextScaler.noScaling,
);

/// The fields a Material slot takes from its Stratum recipe.
List<Object?> _fields(TextStyle? style) => [
  style?.fontFamily,
  style?.fontSize,
  style?.fontWeight,
  style?.height,
  style?.letterSpacing,
  style?.color,
];

/// The weights of the six title and label slots of [theme].
List<FontWeight?> _titlesAndLabels(TextTheme theme) => [
  theme.titleLarge?.fontWeight,
  theme.titleMedium?.fontWeight,
  theme.titleSmall?.fontWeight,
  theme.labelLarge?.fontWeight,
  theme.labelMedium?.fontWeight,
  theme.labelSmall?.fontWeight,
];

void main() {
  for (final (name, data) in [
    ('light', defaultThemeSet.light),
    ('dark', defaultThemeSet.dark!),
  ]) {
    group('us08/fr01/e01: the $name ColorScheme', () {
      final scheme = _material(data).colorScheme;
      final color = data.color;

      test('sets the slots of spec section 10.2 from tokens', () {
        expect(
          scheme.brightness,
          name == 'light' ? Brightness.light : Brightness.dark,
        );
        expect(scheme.primary, color.brand.normal);
        expect(scheme.onPrimary, color.text.defaults.primaryOnColor);
        expect(scheme.primaryContainer, color.background.muted.brand);
        expect(scheme.onPrimaryContainer, color.text.color.brand);
        expect(scheme.secondary, color.brand.normal);
        expect(scheme.onSecondary, color.text.defaults.primaryOnColor);
        expect(scheme.error, color.background.color.negative);
        expect(scheme.onError, color.text.defaults.primaryOnColor);
        expect(scheme.errorContainer, color.background.muted.negative);
        expect(scheme.onErrorContainer, color.text.color.negative);
        expect(scheme.surface, color.background.defaults.normal);
        expect(scheme.onSurface, color.text.defaults.primary);
        expect(scheme.surfaceDim, color.background.defaults.surface);
        expect(scheme.onSurfaceVariant, color.text.defaults.secondary);
        expect(scheme.outline, color.border.color.gray);
        expect(scheme.outlineVariant, color.border.defaults.normal);
        expect(scheme.inverseSurface, color.background.defaults.normalInverse);
        expect(scheme.onInverseSurface, color.text.defaults.primaryInverse);
      });

      test('leaves the other slots to their ColorScheme fallbacks', () {
        expect(scheme.primaryFixed, scheme.primary);
        expect(scheme.onPrimaryFixed, scheme.onPrimary);
        expect(scheme.secondaryContainer, scheme.secondary);
        expect(scheme.tertiary, scheme.secondary);
        expect(scheme.onTertiary, scheme.onSecondary);
        expect(scheme.surfaceBright, scheme.surface);
        expect(scheme.surfaceContainerHighest, scheme.surface);
        expect(scheme.inversePrimary, scheme.onPrimary);
        expect(scheme.surfaceTint, scheme.primary);
        expect(scheme.shadow, const Color(0xff000000));
        expect(scheme.scrim, const Color(0xff000000));
      });
    });
  }

  test('us08/s1: the section 10.3 fields', () {
    final data = defaultThemeSet.light;
    final material = _material(data);
    final color = data.color;

    expect(material.splashFactory, same(NoSplash.splashFactory));
    expect(material.primaryColor, color.brand.normal);
    expect(material.primaryColorLight, color.brand.normal.lighten(10));
    expect(material.primaryColorDark, color.brand.normal.darken(10));
    expect(material.hoverColor, color.state.hover);
    expect(material.focusColor, color.state.hover);
    expect(material.splashColor, color.state.press);
    expect(material.highlightColor, color.brand.normal.withValues(alpha: 0.15));
    expect(material.canvasColor, color.background.defaults.normal);
    expect(material.scaffoldBackgroundColor, color.background.defaults.normal);
    expect(material.cardColor, color.background.control.popover);
    expect(
      material.textSelectionTheme.cursorColor,
      color.text.defaults.primary,
    );
    expect(
      material.textSelectionTheme.selectionHandleColor,
      color.brand.normal,
    );
    expect(material.dividerTheme.thickness, 1);
    expect(material.dividerTheme.color, color.border.defaults.normal);
  });

  test('us08/fr01/e05: the Material theme sets no system bar style for the '
      'app bar', () {
    for (final data in [defaultThemeSet.light, defaultThemeSet.dark!]) {
      expect(_material(data).appBarTheme.systemOverlayStyle, isNull);
    }
  });

  group('us08/s2, us08/fr01/e02: the text theme of themes s01 Material text '
      'theme', () {
    final slots = <String, (TextStyle? Function(TextTheme), StratumTextStyle)>{
      'displayLarge': (
        (theme) => theme.displayLarge,
        StratumTextStyle.header.s56,
      ),
      'displayMedium': (
        (theme) => theme.displayMedium,
        StratumTextStyle.header.s36,
      ),
      'displaySmall': (
        (theme) => theme.displaySmall,
        StratumTextStyle.header.s24,
      ),
      'headlineLarge': (
        (theme) => theme.headlineLarge,
        StratumTextStyle.header.s24,
      ),
      'headlineMedium': (
        (theme) => theme.headlineMedium,
        StratumTextStyle.header.s20,
      ),
      'headlineSmall': (
        (theme) => theme.headlineSmall,
        StratumTextStyle.header.s18,
      ),
      'titleLarge': ((theme) => theme.titleLarge, StratumTextStyle.body.s18),
      'titleMedium': ((theme) => theme.titleMedium, StratumTextStyle.body.s16),
      'titleSmall': ((theme) => theme.titleSmall, StratumTextStyle.body.s14),
      'bodyLarge': ((theme) => theme.bodyLarge, StratumTextStyle.body.s16),
      'bodyMedium': ((theme) => theme.bodyMedium, StratumTextStyle.body.s14),
      'bodySmall': ((theme) => theme.bodySmall, StratumTextStyle.body.s12),
      'labelLarge': ((theme) => theme.labelLarge, StratumTextStyle.body.s14),
      'labelMedium': ((theme) => theme.labelMedium, StratumTextStyle.body.s12),
      'labelSmall': ((theme) => theme.labelSmall, StratumTextStyle.body.s10),
    };
    for (final windowSize in const [WindowSize.mobile, WindowSize.desktop]) {
      for (final MapEntry(key: slot, value: (read, recipe)) in slots.entries) {
        test('$slot on ${windowSize.name}', () {
          final data = defaultThemeSet.light;
          final expected = TypographyResolver.resolve(
            recipe,
            theme: data,
            locale: const Locale('en'),
            windowSize: windowSize,
            textScaler: TextScaler.noScaling,
          );

          expect(
            _fields(read(_material(data, windowSize: windowSize).textTheme)),
            _fields(expected),
          );
        });
      }
    }

    test("us08/fr01/e02: the six title and label slots draw the body type's "
        'weight, 400 in the package default', () {
      expect(
        _titlesAndLabels(_material(defaultThemeSet.light).textTheme),
        everyElement(FontWeight.w400),
      );
    });

    test('us08/fr01/e03: a theme whose body declares another weight draws '
        'it in the six title and label slots', () {
      final data = StratumThemeSet.fromConfig(
        StratumThemeConfig.parse(
          base: const StratumThemeSource(
            id: 'stratum-default',
            folder: 'packages/stratum_ui/assets/themes/default',
            yaml: defaultThemeSource,
          ),
          layers: [
            StratumThemeSource(
              id: 'light-body',
              folder: 'assets/themes/light-body',
              yaml: layer(
                'typography:\n  types:\n    body:\n      weight: 300',
              ),
            ),
          ],
        ),
      ).light;

      // Inter now loads in 300 (body), 400, and 600, so 300 draws as is.
      expect(
        _titlesAndLabels(_material(data).textTheme),
        everyElement(FontWeight.w300),
      );
    });

    group('under th', () {
      final defaultFamily = GoogleFontsLookup.family;
      setUp(() {
        GoogleFontsLookup.family = (name, {required weight, required style}) =>
            'Google $name';
      });
      tearDown(() => GoogleFontsLookup.family = defaultFamily);

      test('bodyMedium takes Kanit', () {
        final material = _material(
          fakeTheme.copyWith(),
          locale: const Locale('th'),
        );

        expect(material.textTheme.bodyMedium?.fontFamily, 'Google Kanit');
      });
    });
  });

  group('the application inserts the Material theme', () {
    testWidgets('us08/fr01: Theme.of below it follows the active data', (
      tester,
    ) async {
      ColorScheme? scheme;
      await tester.pumpWidget(
        themedHost(
          Builder(
            builder: (context) {
              scheme = Theme.of(context).colorScheme;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(scheme?.primary, fakeTheme.color.brand.normal);
    });

    testWidgets('a window size change rebuilds the text theme', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.reset);
      final sizes = <double?>[];
      await tester.pumpWidget(
        themedHost(
          Builder(
            builder: (context) {
              sizes.add(Theme.of(context).textTheme.displayLarge?.fontSize);
              return const SizedBox();
            },
          ),
        ),
      );
      tester.view.physicalSize = const Size(1300, 800);
      await tester.pump();

      expect(sizes, [56, 57]);
    });

    testWidgets('G25: in MaterialApp.builder it reaches every route', (
      tester,
    ) async {
      ColorScheme? scheme;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorSchemeSeed: const Color(0xFFFF0000)),
          builder: (context, child) => StratumThemeApplication(
            themes: StratumThemeSet(light: fakeTheme),
            themeMode: ThemeMode.light,
            child: child!,
          ),
          home: Builder(
            builder: (context) {
              scheme = Theme.of(context).colorScheme;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(scheme?.primary, fakeTheme.color.brand.normal);
    });

    testWidgets("above MaterialApp, Material keeps the app's own theme", (
      tester,
    ) async {
      final appTheme = ThemeData(colorSchemeSeed: const Color(0xFFFF0000));
      ColorScheme? scheme;
      Color? stratum;
      await tester.pumpWidget(
        StratumThemeApplication(
          themes: StratumThemeSet(light: fakeTheme),
          themeMode: ThemeMode.light,
          child: MaterialApp(
            theme: appTheme,
            home: Builder(
              builder: (context) {
                scheme = Theme.of(context).colorScheme;
                stratum = StratumTheme.of(context).color.brand.normal;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(scheme?.primary, appTheme.colorScheme.primary);
      expect(stratum, fakeTheme.color.brand.normal);
    });
  });

  group('us08/fr01/e04: the page transitions', () {
    /// A [MaterialApp] whose builder places an application of [data]
    /// above the navigator.
    Widget app(GlobalKey<NavigatorState> navigator, StratumThemeData data) =>
        MaterialApp(
          navigatorKey: navigator,
          builder: (context, child) => StratumThemeApplication(
            themes: StratumThemeSet(light: data),
            themeMode: ThemeMode.light,
            child: child!,
          ),
          home: const SizedBox(),
        );

    Future<void> push(
      WidgetTester tester,
      GlobalKey<NavigatorState> navigator, [
      Route<void>? route,
    ]) async {
      navigator.currentState!
          .push(
            route ??
                MaterialPageRoute<void>(
                  builder: (_) => const SizedBox(key: ValueKey('page')),
                ),
          )
          .ignore();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    Finder above(Type type) => find.ancestor(
      of: find.byKey(const ValueKey('page')),
      matching: find.byType(type),
    );

    test('one Stratum builder of the theme for every platform', () {
      final builders = _material(fakeTheme).pageTransitionsTheme.builders;

      expect(builders.keys.toSet(), TargetPlatform.values.toSet());
      for (final MapEntry(key: platform, value: builder) in builders.entries) {
        expect(
          builder,
          isA<StratumPageTransitionsBuilder>()
              .having((b) => b.motion, 'motion', fakeTheme.animation)
              .having((b) => b.platform, 'platform', platform),
        );
      }
    });

    test('two calls give equal page transitions themes', () {
      expect(
        _material(fakeTheme).pageTransitionsTheme,
        _material(fakeTheme).pageTransitionsTheme,
      );
    });

    testWidgets('us05/s6: the default theme gives the iOS slide and its '
        'swipe-back', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(app(navigator, defaultThemeSet.light));
      await push(tester, navigator);

      expect(above(CupertinoPageTransition), findsOneWidget);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(const Offset(5, 300));
      await gesture.moveBy(const Offset(250, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(250, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page')), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('us08/s3: a plain Material page enters with the active '
        "theme's iOS slide and its swipe-back", (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(app(navigator, defaultThemeSet.light));
      await push(tester, navigator);

      expect(above(CupertinoPageTransition), findsOneWidget);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(const Offset(5, 300));
      await gesture.moveBy(const Offset(250, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(250, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page')), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    group('us05/fr04/e04, nfr-u03: under reduce motion the default theme', () {
      final page = find.byKey(const ValueKey('page'));

      void reduceMotion(WidgetTester tester) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
      }

      testWidgets('shows the page at once and keeps the iOS swipe-back, '
          'which tracks the finger', (tester) async {
        reduceMotion(tester);
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(app(navigator, defaultThemeSet.light));
        await push(tester, navigator);

        expect(tester.getTopLeft(page), Offset.zero);
        await tester.pumpAndSettle();
        final gesture = await tester.startGesture(const Offset(5, 300));
        await gesture.moveBy(const Offset(250, 0));
        await tester.pump();
        await gesture.moveBy(const Offset(250, 0));
        await tester.pump();
        expect(tester.getTopLeft(page).dx, greaterThan(0));

        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(page, findsOneWidget);
        await tester.pumpAndSettle();
        expect(page, findsNothing);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

      testWidgets('leaves a popped page gone one pump later', (tester) async {
        reduceMotion(tester);
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(app(navigator, defaultThemeSet.light));
        await push(tester, navigator);
        await tester.pumpAndSettle();

        navigator.currentState!.pop();
        await tester.pump();

        expect(page, findsNothing);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
    });

    testWidgets('us05/s7: a desktop window takes the desktop type '
        'through the application', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1300, 800);
      addTearDown(tester.view.reset);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        app(
          navigator,
          motionTheme(
            transitions: transitionsOf(
              ScreenTransitionType.platform,
              sizes: {
                WindowSize.mobile: ScreenTransitionType.fade,
                WindowSize.desktop: ScreenTransitionType.rightToLeft,
              },
            ),
          ),
        ),
      );
      await push(tester, navigator);

      expect(above(SlideTransition), findsOneWidget);
      expect(above(FadeTransition), findsNothing);
    });

    testWidgets('us05/s8: a PageTransition shows its own type over the '
        "theme's", (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        app(
          navigator,
          motionTheme(transitions: transitionsOf(ScreenTransitionType.fade)),
        ),
      );
      await push(
        tester,
        navigator,
        PageTransition<void>(
          type: ScreenTransitionType.rightToLeft,
          child: const SizedBox(key: ValueKey('page')),
        ),
      );

      expect(above(SlideTransition), findsOneWidget);
      expect(above(FadeTransition), findsNothing);
    });

    for (final type in [
      ScreenTransitionType.fadeThrough,
      ScreenTransitionType.sharedAxisHorizontal,
    ]) {
      testWidgets('us05/fr01: ${type.name} of a dark theme fills with its '
          "canvas color, not Flutter's fallback", (tester) async {
        final dark = defaultThemeSet.dark!;
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          app(
            navigator,
            motionTheme(theme: dark, transitions: transitionsOf(type)),
          ),
        );
        await push(tester, navigator);

        final fill = type == ScreenTransitionType.fadeThrough
            ? tester
                  .widget<FadeThroughTransition>(above(FadeThroughTransition))
                  .fillColor
            : tester
                  .widget<SharedAxisTransition>(above(SharedAxisTransition))
                  .fillColor;
        expect(fill, _material(dark).canvasColor);
        expect(fill, isNot(ThemeData.fallback().canvasColor));
      });
    }

    testWidgets("a theme switch gives the next page the new theme's type", (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        app(
          navigator,
          motionTheme(transitions: transitionsOf(ScreenTransitionType.fade)),
        ),
      );
      await tester.pumpWidget(
        app(
          navigator,
          motionTheme(
            transitions: transitionsOf(ScreenTransitionType.rightToLeft),
          ),
        ),
      );
      await push(tester, navigator);

      expect(above(SlideTransition), findsOneWidget);
      expect(above(FadeTransition), findsNothing);
    });
  });
}
