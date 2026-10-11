import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/responsive/screen_radius_scope.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/theme_font_loader.dart';

import '../components/common/fakes/fake_stratum_theme.dart';
import 'theme_runtime_fakes.dart';

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

Map<Type, WidgetStyle> _defaults(StratumTheme theme) => const {};
Map<Type, Object> _parts(StratumTheme theme) => const {};

/// A dark platform with high contrast on, then the application, then a
/// reader that stores what [StratumThemeApplication.maybeOf] gives.
Widget _host(
  void Function(StratumThemeData? data) found, {
  ThemeMode themeMode = ThemeMode.light,
  StratumHighContrastMode highContrast = StratumHighContrastMode.system,
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
    final cases = <(ThemeMode, StratumHighContrastMode, StratumThemeData)>[
      (ThemeMode.light, StratumHighContrastMode.off, _light),
      (ThemeMode.light, StratumHighContrastMode.on, _contrastLight),
      (ThemeMode.light, StratumHighContrastMode.system, _contrastLight),
      (ThemeMode.dark, StratumHighContrastMode.off, _dark),
      (ThemeMode.dark, StratumHighContrastMode.on, _contrastDark),
      (ThemeMode.dark, StratumHighContrastMode.system, _contrastDark),
      (ThemeMode.system, StratumHighContrastMode.off, _dark),
      (ThemeMode.system, StratumHighContrastMode.on, _contrastDark),
      (ThemeMode.system, StratumHighContrastMode.system, _contrastDark),
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

    testWidgets('e2: a live platform brightness flip rebuilds a '
        'system-mode reader', (tester) async {
      var builds = 0;
      StratumThemeData? found;
      var brightness = Brightness.light;
      late StateSetter flip;
      final reader = StratumThemeApplication(
        themes: _set,
        themeMode: ThemeMode.system,
        child: Builder(
          builder: (context) {
            builds++;
            found = StratumThemeApplication.maybeOf(context);
            return const SizedBox();
          },
        ),
      );

      // [reader] keeps the same identity across both pumps, so only a real
      // MediaQuery dependency, not the setState rebuild, can grow [builds].
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            flip = setState;
            return MediaQuery(
              data: MediaQueryData(platformBrightness: brightness),
              child: reader,
            );
          },
        ),
      );
      expect(found, same(_light));
      final before = builds;

      flip(() => brightness = Brightness.dark);
      await tester.pump();

      expect(builds, greaterThan(before));
      expect(found, same(_dark));
    });

    testWidgets('e2: a live high-contrast flip rebuilds a system-mode '
        'reader', (tester) async {
      var builds = 0;
      StratumThemeData? found;
      var highContrast = false;
      late StateSetter flip;
      final reader = StratumThemeApplication(
        themes: _set,
        themeMode: ThemeMode.light,
        child: Builder(
          builder: (context) {
            builds++;
            found = StratumThemeApplication.maybeOf(context);
            return const SizedBox();
          },
        ),
      );

      // [reader] keeps the same identity across both pumps, so only a real
      // MediaQuery dependency, not the setState rebuild, can grow [builds].
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            flip = setState;
            return MediaQuery(
              data: MediaQueryData(highContrast: highContrast),
              child: reader,
            );
          },
        ),
      );
      expect(found, same(_light));
      final before = builds;

      flip(() => highContrast = true);
      await tester.pump();

      expect(builds, greaterThan(before));
      expect(found, same(_contrastLight));
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
            highContrast: StratumHighContrastMode.on,
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
    testWidgets('copies the theme set, both modes, and the component '
        'defaults', (tester) async {
      late Widget wrapped;
      const child = SizedBox();
      await tester.pumpWidget(
        StratumThemeApplication(
          themes: _set,
          themeMode: ThemeMode.dark,
          highContrast: StratumHighContrastMode.on,
          componentDefaults: _defaults,
          componentPartDefaults: _parts,
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
              StratumHighContrastMode.on,
            )
            .having(
              (app) => app.componentDefaults,
              'componentDefaults',
              same(_defaults),
            )
            .having(
              (app) => app.componentPartDefaults,
              'componentPartDefaults',
              same(_parts),
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
        highContrast: StratumHighContrastMode.off,
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

  group('us02/fr01: StratumThemeApplication.controlled', () {
    setUp(ThemeFontLoader.reset);

    testWidgets('us02/s1: a switch rebuilds each dependent once, with the '
        'new data', (tester) async {
      final controller = await StratumThemeController.preload(
        bundle: FakeThemeBundle(themes: {'brand': markTheme('brand-mark')}),
      );
      final marks = <bool>[];
      await tester.pumpWidget(
        StratumThemeApplication.controlled(
          controller: controller,
          themeMode: ThemeMode.light,
          child: Builder(
            builder: (context) {
              marks.add(
                StratumThemeApplication.of(context).typography.fonts
                    .containsKey('brand-mark'),
              );
              return const SizedBox();
            },
          ),
        ),
      );

      await controller.switchTo('brand');
      await tester.pump();

      expect(marks, [false, true]);
    });

    testWidgets('fr02: the same controller and modes rebuild nothing; a new '
        'controller rebuilds', (tester) async {
      final bundle = FakeThemeBundle();
      final first = await StratumThemeController.preload(bundle: bundle);
      final second = await StratumThemeController.preload(bundle: bundle);
      var builds = 0;
      final reader = Builder(
        builder: (context) {
          builds++;
          StratumThemeApplication.maybeOf(context);
          return const SizedBox();
        },
      );
      Widget host(StratumThemeController controller) =>
          StratumThemeApplication.controlled(
            controller: controller,
            themeMode: ThemeMode.light,
            child: reader,
          );

      await tester.pumpWidget(host(first));
      await tester.pumpWidget(host(first));
      expect(builds, 1);
      await tester.pumpWidget(host(second));
      expect(builds, 2);
    });

    testWidgets('StratumThemeController.of and maybeOf find the '
        'controller', (tester) async {
      final controller = await StratumThemeController.preload(
        bundle: FakeThemeBundle(),
      );
      StratumThemeController? found;
      StratumThemeController? maybe;
      await tester.pumpWidget(
        StratumThemeApplication.controlled(
          controller: controller,
          themeMode: ThemeMode.light,
          child: Builder(
            builder: (context) {
              found = StratumThemeController.of(context);
              maybe = StratumThemeController.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(found, same(controller));
      expect(maybe, same(controller));
    });

    testWidgets('under StratumThemeApplication(themes:), maybeOf is null and '
        'of throws a FlutterError naming the controlled constructor', (
      tester,
    ) async {
      StratumThemeController? maybe;
      await tester.pumpWidget(
        StratumThemeApplication(
          themes: _set,
          themeMode: ThemeMode.light,
          child: Builder(
            builder: (context) {
              maybe = StratumThemeController.maybeOf(context);
              StratumThemeController.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(maybe, isNull);
      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (error) => error.message,
          'message',
          contains('StratumThemeApplication.controlled'),
        ),
      );
    });

    testWidgets('a plain application nested below a controlled one still '
        'forwards the controller to of and maybeOf', (tester) async {
      final controller = await StratumThemeController.preload(
        bundle: FakeThemeBundle(),
      );
      StratumThemeController? found;
      StratumThemeController? maybe;
      await tester.pumpWidget(
        StratumThemeApplication.controlled(
          controller: controller,
          themeMode: ThemeMode.light,
          child: StratumThemeApplication(
            themes: _set,
            themeMode: ThemeMode.dark,
            child: Builder(
              builder: (context) {
                found = StratumThemeController.of(context);
                maybe = StratumThemeController.maybeOf(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(found, same(controller));
      expect(maybe, same(controller));
    });

    testWidgets('a reused reader under a plain application that becomes '
        '.controlled in place rebuilds and sees the controller', (
      tester,
    ) async {
      final controller = await StratumThemeController.preload(
        bundle: FakeThemeBundle(),
      );
      final found = <StratumThemeController?>[];
      final reader = Builder(
        builder: (context) {
          found.add(StratumThemeController.maybeOf(context));
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
      await tester.pumpWidget(
        StratumThemeApplication.controlled(
          controller: controller,
          themeMode: ThemeMode.light,
          child: reader,
        ),
      );

      expect(found, [null, same(controller)]);
    });

    testWidgets('us10/fr05: wrap keeps the controller and both modes', (
      tester,
    ) async {
      final controller = await StratumThemeController.preload(
        bundle: FakeThemeBundle(),
      );
      late Widget wrapped;
      await tester.pumpWidget(
        StratumThemeApplication.controlled(
          controller: controller,
          themeMode: ThemeMode.dark,
          highContrast: StratumHighContrastMode.on,
          componentDefaults: _defaults,
          componentPartDefaults: _parts,
          child: Builder(
            builder: (context) {
              wrapped = StratumThemeApplication.wrap(
                context,
                child: const SizedBox(),
              );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(
        wrapped,
        isA<StratumThemeApplication>()
            .having((app) => app.controller, 'controller', same(controller))
            .having((app) => app.themes, 'themes', same(controller.themes))
            .having((app) => app.themeMode, 'themeMode', ThemeMode.dark)
            .having(
              (app) => app.highContrast,
              'highContrast',
              StratumHighContrastMode.on,
            )
            .having(
              (app) => app.componentDefaults,
              'componentDefaults',
              same(_defaults),
            )
            .having(
              (app) => app.componentPartDefaults,
              'componentPartDefaults',
              same(_parts),
            ),
      );
    });
  });

  group('us05/fr02/e08: a theme with no wait', () {
    setUp(ThemeFontLoader.reset);

    testWidgets('StratumThemeApplication(themes:) draws the weights a '
        'preloaded StratumThemeApplication.controlled draws', (tester) async {
      final controller = await StratumThemeController.preload(
        bundle: FakeThemeBundle(),
      );
      final styles = <TextStyle>[];
      Widget probe() => Builder(
        builder: (context) {
          styles.add(StratumTextStyle.body.medium.build(context));
          return const SizedBox();
        },
      );

      await tester.pumpWidget(
        StratumThemeApplication.controlled(
          controller: controller,
          themeMode: ThemeMode.light,
          child: probe(),
        ),
      );
      final waited = styles.last;
      await tester.pumpWidget(
        StratumThemeApplication(
          themes: defaultThemeSet,
          themeMode: ThemeMode.light,
          child: probe(),
        ),
      );
      final unwaited = styles.last;

      expect(styles.length, greaterThanOrEqualTo(2));
      expect(unwaited.fontFamily, waited.fontFamily);
      expect(
        [waited.fontWeight, unwaited.fontWeight],
        [FontWeight.w600, FontWeight.w600],
      );
    });
  });

  group('us04/fr03: the screen radius scope', () {
    const channel = EventChannel('stratum_ui/screen_radius');
    BorderRadius all(double r) => BorderRadius.all(Radius.circular(r));
    Map<String, double> corners(double r) => {
      'topLeft': r,
      'topRight': r,
      'bottomLeft': r,
      'bottomRight': r,
    };

    late MockStreamHandlerEventSink sink;
    var listens = 0;

    /// Mocks the native probe: each listen counts and sends 46.
    void mockProbe(WidgetTester tester) {
      listens = 0;
      tester.binding.defaultBinaryMessenger.setMockStreamHandler(
        channel,
        MockStreamHandler.inline(
          onListen: (_, s) {
            listens++;
            sink = s..success(corners(46));
          },
        ),
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockStreamHandler(
          channel,
          null,
        ),
      );
    }

    Widget application(Widget child) => StratumThemeApplication(
      themes: _set,
      themeMode: ThemeMode.light,
      child: child,
    );

    testWidgets(
      'e07: with no application above the reader nothing publishes the '
      'probe radius; e03: under the application it does',
      (tester) async {
        mockProbe(tester);
        BorderRadius? radius = BorderRadius.zero;
        final reader = Builder(
          builder: (context) {
            radius = context.deviceWindow.radius;
            return const SizedBox();
          },
        );

        await tester.pumpWidget(reader);
        await tester.pump();
        final bare = radius;
        await tester.pumpWidget(application(reader));
        await tester.pump();

        expect(bare, isNull);
        expect(find.byType(ScreenRadiusScope), findsOneWidget);
        expect(radius, all(46));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'e06: nested applications keep one scope, and the radius follows '
      'every change event, after the inner application leaves too',
      (tester) async {
        mockProbe(tester);
        BorderRadius? radius;
        var radiusBuilds = 0;
        final reader = Builder(
          builder: (context) {
            radius = context.deviceWindow.radius;
            radiusBuilds++;
            return const SizedBox();
          },
        );
        await tester.pumpWidget(application(application(reader)));
        await tester.pump();
        expect(find.byType(ScreenRadiusScope), findsOneWidget);
        expect(radius, all(46));

        radiusBuilds = 0;
        sink.success(corners(12));
        await tester.pump();
        await tester.pump();
        final changed = radius;
        final changedBuilds = radiusBuilds;
        await tester.pumpWidget(application(reader));
        sink.success(corners(20));
        await tester.pump();
        await tester.pump();

        expect(changed, all(12));
        expect(changedBuilds, 1);
        expect(radius, all(20));
        expect(listens, 1);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'e06: an application remounted in one frame keeps following change '
      'events',
      (tester) async {
        mockProbe(tester);
        BorderRadius? radius;
        final reader = Builder(
          builder: (context) {
            radius = context.deviceWindow.radius;
            return const SizedBox();
          },
        );
        await tester.pumpWidget(application(reader));
        await tester.pump();

        await tester.pumpWidget(
          KeyedSubtree(key: UniqueKey(), child: application(reader)),
        );
        await tester.pump();
        sink.success(corners(20));
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(radius, all(20));
        expect(listens, 1);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'e06: when one of two sibling applications leaves, the other keeps '
      'following change events',
      (tester) async {
        mockProbe(tester);
        BorderRadius? first;
        BorderRadius? second;
        Widget reader(void Function(BorderRadius?) onRadius) => Builder(
          builder: (context) {
            onRadius(context.deviceWindow.radius);
            return const SizedBox();
          },
        );
        final firstApp = application(reader((r) => first = r));
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [firstApp, application(reader((r) => second = r))],
            ),
          ),
        );
        await tester.pump();
        expect([first, second], [all(46), all(46)]);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(children: [firstApp]),
          ),
        );
        sink.success(corners(20));
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(first, all(20));
        expect(listens, 1);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  });

  group('renames', () {
    testWidgets('renames: HighContrastMode.on still picks the high-contrast '
        'data', (tester) async {
      StratumThemeData? found;
      await tester.pumpWidget(
        _host(
          (data) => found = data,
          themeMode: ThemeMode.light,
          // Tests the deprecated alias and its replacement.
          // ignore: deprecated_member_use_from_same_package
          highContrast: HighContrastMode.on,
        ),
      );

      expect(found, same(_contrastLight));
    });
  });
}
