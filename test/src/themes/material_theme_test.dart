import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/typography/google_fonts_lookup.dart';

import '../components/common/fakes/fake_stratum_theme.dart';

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

void main() {
  for (final (name, data) in [
    ('light', defaultThemeSet.light),
    ('dark', defaultThemeSet.dark!),
  ]) {
    group('fr01: the $name ColorScheme', () {
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

  test('fr01: the section 10.3 fields', () {
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
    expect(material.appBarTheme.systemOverlayStyle, AppSystemUI.light);
  });

  group('fr01/e02: the text theme of spec section 10.4', () {
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
      'titleLarge': (
        (theme) => theme.titleLarge,
        StratumTextStyle.body.s18.medium,
      ),
      'titleMedium': (
        (theme) => theme.titleMedium,
        StratumTextStyle.body.s16.medium,
      ),
      'titleSmall': (
        (theme) => theme.titleSmall,
        StratumTextStyle.body.s14.medium,
      ),
      'bodyLarge': ((theme) => theme.bodyLarge, StratumTextStyle.body.s16),
      'bodyMedium': ((theme) => theme.bodyMedium, StratumTextStyle.body.s14),
      'bodySmall': ((theme) => theme.bodySmall, StratumTextStyle.body.s12),
      'labelLarge': (
        (theme) => theme.labelLarge,
        StratumTextStyle.body.s14.medium,
      ),
      'labelMedium': (
        (theme) => theme.labelMedium,
        StratumTextStyle.body.s12.medium,
      ),
      'labelSmall': (
        (theme) => theme.labelSmall,
        StratumTextStyle.body.s10.medium,
      ),
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
    testWidgets('fr01: Theme.of below it follows the active data', (
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
}
