import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../components/common/fakes/fake_stratum_theme.dart';

final StratumThemeData _light = fakeTheme;
final StratumThemeData _dark = fakeTheme.copyWith(themeMode: ThemeMode.dark);
final StratumThemeData _contrastLight = fakeTheme.copyWith();
final StratumThemeData _contrastDark = _dark.copyWith();
final StratumThemeSet _set = StratumThemeSet(
  light: _light,
  dark: _dark,
  highContrastLight: _contrastLight,
  highContrastDark: _contrastDark,
);

/// A dark platform with high contrast on, then the application, then a
/// reader that stores what [StratumThemeApplication.maybeOf] gives.
Widget _host(
  void Function(StratumThemeData? data) found, {
  ThemeMode themeMode = ThemeMode.light,
  HighContrastMode highContrast = HighContrastMode.system,
  StratumThemeSet? themes,
  MediaQueryData media = const MediaQueryData(
    platformBrightness: Brightness.dark,
    highContrast: true,
  ),
}) => MediaQuery(
  data: media,
  child: StratumThemeApplication(
    themes: themes ?? _set,
    themeMode: themeMode,
    highContrast: highContrast,
    child: Builder(
      builder: (context) {
        found(StratumThemeApplication.maybeOf(context));
        return const SizedBox();
      },
    ),
  ),
);

void main() {
  group('StratumThemeApplication.maybeOf', () {
    final cases = <(ThemeMode, HighContrastMode, StratumThemeData)>[
      (ThemeMode.light, HighContrastMode.off, _light),
      (ThemeMode.light, HighContrastMode.on, _contrastLight),
      (ThemeMode.light, HighContrastMode.system, _contrastLight),
      (ThemeMode.dark, HighContrastMode.off, _dark),
      (ThemeMode.dark, HighContrastMode.on, _contrastDark),
      (ThemeMode.dark, HighContrastMode.system, _contrastDark),
      (ThemeMode.system, HighContrastMode.off, _dark),
      (ThemeMode.system, HighContrastMode.on, _contrastDark),
      (ThemeMode.system, HighContrastMode.system, _contrastDark),
    ];
    for (final (themeMode, highContrast, expected) in cases) {
      testWidgets('fr01: ${themeMode.name} with high contrast '
          '${highContrast.name} picks its data', (tester) async {
        StratumThemeData? found;
        await tester.pumpWidget(
          _host(
            (data) => found = data,
            themeMode: themeMode,
            highContrast: highContrast,
          ),
        );

        expect(found, same(expected));
      });
    }

    testWidgets('fr01/e01: system and system on a default media query give '
        'light without high contrast', (tester) async {
      StratumThemeData? found;
      await tester.pumpWidget(
        _host(
          (data) => found = data,
          themeMode: ThemeMode.system,
          media: const MediaQueryData(),
        ),
      );

      expect(found, same(_light));
    });

    testWidgets('a themeMode argument overrides the application mode', (
      tester,
    ) async {
      StratumThemeData? found;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: StratumThemeApplication(
            themes: _set,
            themeMode: ThemeMode.light,
            child: Builder(
              builder: (context) {
                found = StratumThemeApplication.maybeOf(
                  context,
                  themeMode: ThemeMode.dark,
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(found, same(_dark));
    });

    testWidgets('returns null without an application', (tester) async {
      StratumThemeData? found = _light;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            found = StratumThemeApplication.maybeOf(context);
            return const SizedBox();
          },
        ),
      );

      expect(found, isNull);
    });
  });

  testWidgets('fr01/e03: of throws a FlutterError naming the application', (
    tester,
  ) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          StratumThemeApplication.of(context);
          return const SizedBox();
        },
      ),
    );

    expect(
      tester.takeException(),
      isA<FlutterError>().having(
        (error) => error.message,
        'message',
        contains('StratumThemeApplication.of() called'),
      ),
    );
  });

  group('fr02: StratumThemeApplication.updateShouldNotify', () {
    Future<int> rebuilds(
      WidgetTester tester,
      StratumThemeApplication Function(Widget child) second,
    ) async {
      var builds = 0;
      final reader = Builder(
        builder: (context) {
          builds++;
          StratumThemeApplication.maybeOf(context);
          return const SizedBox();
        },
      );
      await tester.pumpWidget(
        StratumThemeApplication(
          themes: _set,
          themeMode: ThemeMode.light,
          child: reader,
        ),
      );
      await tester.pumpWidget(second(reader));
      return builds - 1;
    }

    testWidgets('fr02/e03: the same set and modes rebuild nothing', (
      tester,
    ) async {
      expect(
        await rebuilds(
          tester,
          (child) => StratumThemeApplication(
            themes: StratumThemeSet(
              light: _light,
              dark: _dark,
              highContrastLight: _contrastLight,
              highContrastDark: _contrastDark,
            ),
            themeMode: ThemeMode.light,
            child: child,
          ),
        ),
        0,
      );
    });

    testWidgets('fr02/e01: a new theme mode rebuilds', (tester) async {
      expect(
        await rebuilds(
          tester,
          (child) => StratumThemeApplication(
            themes: _set,
            themeMode: ThemeMode.dark,
            child: child,
          ),
        ),
        1,
      );
    });

    testWidgets('a new high-contrast mode rebuilds', (tester) async {
      expect(
        await rebuilds(
          tester,
          (child) => StratumThemeApplication(
            themes: _set,
            themeMode: ThemeMode.light,
            highContrast: HighContrastMode.on,
            child: child,
          ),
        ),
        1,
      );
    });

    final members = <String, StratumThemeSet Function(StratumThemeData)>{
      'light': (data) => StratumThemeSet(
        light: data,
        dark: _dark,
        highContrastLight: _contrastLight,
        highContrastDark: _contrastDark,
      ),
      'dark': (data) => StratumThemeSet(
        light: _light,
        dark: data,
        highContrastLight: _contrastLight,
        highContrastDark: _contrastDark,
      ),
      'highContrastLight': (data) => StratumThemeSet(
        light: _light,
        dark: _dark,
        highContrastLight: data,
        highContrastDark: _contrastDark,
      ),
      'highContrastDark': (data) => StratumThemeSet(
        light: _light,
        dark: _dark,
        highContrastLight: _contrastLight,
        highContrastDark: data,
      ),
    };
    for (final MapEntry(key: name, value: build) in members.entries) {
      testWidgets('a new $name data rebuilds', (tester) async {
        expect(
          await rebuilds(
            tester,
            (child) => StratumThemeApplication(
              themes: build(fakeTheme.copyWith()),
              themeMode: ThemeMode.light,
              child: child,
            ),
          ),
          1,
        );
      });
    }
  });

  group('us10/fr05: StratumThemeApplication.wrap', () {
    testWidgets('copies the theme set and both modes', (tester) async {
      late Widget wrapped;
      const child = SizedBox();
      await tester.pumpWidget(
        StratumThemeApplication(
          themes: _set,
          themeMode: ThemeMode.dark,
          highContrast: HighContrastMode.on,
          child: Builder(
            builder: (context) {
              wrapped = StratumThemeApplication.wrap(context, child: child);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(
        wrapped,
        isA<StratumThemeApplication>()
            .having((app) => app.themes, 'themes', same(_set))
            .having((app) => app.themeMode, 'themeMode', ThemeMode.dark)
            .having(
              (app) => app.highContrast,
              'highContrast',
              HighContrastMode.on,
            ),
      );
    });

    testWidgets('fr05/e02: returns the child with no application above', (
      tester,
    ) async {
      late Widget wrapped;
      const child = SizedBox();
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            wrapped = StratumThemeApplication.wrap(context, child: child);
            return const SizedBox();
          },
        ),
      );

      expect(wrapped, same(child));
    });
  });

  testWidgets('ThemeMode.theme reads the data of that mode', (tester) async {
    StratumThemeData? found;
    await tester.pumpWidget(
      StratumThemeApplication(
        themes: _set,
        themeMode: ThemeMode.light,
        highContrast: HighContrastMode.off,
        child: Builder(
          builder: (context) {
            found = ThemeMode.dark.theme(context).data;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(found, same(_dark));
  });

  group('the body', () {
    Widget app(Widget child) => StratumThemeApplication(
      themes: _set,
      themeMode: ThemeMode.light,
      child: child,
    );

    testWidgets('us09/fr01/e02: inserts a WindowSizeScope when none is '
        'above', (tester) async {
      WindowSize? found;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) {
              found = WindowSizeScope.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(found, isNotNull);
      expect(find.byType(WindowSizeScope), findsOneWidget);
    });

    testWidgets('inserts none under a scope or a second application', (
      tester,
    ) async {
      await tester.pumpWidget(
        WindowSizeScope(child: app(app(const SizedBox()))),
      );

      expect(find.byType(WindowSizeScope), findsOneWidget);
    });
  });
}
