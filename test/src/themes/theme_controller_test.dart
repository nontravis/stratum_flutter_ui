import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/theme_font_loader.dart';
import 'package:stratum_ui/src/themes/theme_parse.dart';

import 'theme_runtime_fakes.dart';

const _fallbackLog =
    'Stratum theme: initialThemeId "gone" names no registered theme; '
    'starting on default';

const _missingFontLog =
    'Stratum theme: font file '
    '"assets/themes/brand/fonts/DBHeavent-Regular.ttf" is not in the asset '
    'bundle; add "- assets/themes/brand/fonts/" under flutter: assets: in '
    'pubspec.yaml';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(ThemeFontLoader.reset);
  tearDown(ThemeFontLoader.reset);

  group('us01/fr02: discovery', () {
    test('us01/fr02/e01: default first, then the bundled ids in '
        'alphabetical order', () async {
      final (controller, _) = await startController(
        FakeThemeBundle(themes: {'night': appTheme(), 'brand': appTheme()}),
      );

      expect(controller.themeIds, ['default', 'brand', 'night']);
    });

    test('us01/fr02/e03: registration reads no theme file', () async {
      final bundle = FakeThemeBundle(
        themes: {'night': appTheme(), 'brand': appTheme()},
      );
      await startController(bundle);

      expect(bundle.reads.keys, [packageDefaultKey]);
    });

    test("us01/fr02/e04, e05: only the app's own "
        'assets/themes/<id>/theme.yaml files register', () async {
      final (controller, _) = await startController(
        FakeThemeBundle(
          themes: {'brand': appTheme()},
          manifestOnly: {
            'packages/other_kit/assets/themes/kit/theme.yaml',
            'assets/themes/brand/fonts/Brand-Regular.ttf',
            'assets/themes/a/b/theme.yaml',
          },
        ),
      );

      expect(controller.themeIds, ['default', 'brand']);
    });

    test('us01/s3, us01/fr02/e02: the app default layers over the package '
        'default', () async {
      final (controller, _) = await startController(
        FakeThemeBundle(themes: {'default': markTheme('app-mark')}),
      );

      expect(controller.themeIds, ['default']);
      expect(controller.activeId, 'default');
      expect(
        controller.themes.light.typography.fonts.keys,
        containsAll(<String>['inter', 'app-mark']),
      );
    });
  });

  group('us01/fr03, us03/fr01: preload', () {
    test('us01/s1, us01/fr01/e01: an app with no theme starts on the '
        'package default', () async {
      final (controller, changes) = await startController(FakeThemeBundle());

      expect(controller.themeIds, ['default']);
      expect(controller.activeId, 'default');
      expect(controller.themes.light.typography.fonts.keys, [
        'inter',
        'geist',
        'geist-mono',
        'roboto-mono',
        'kanit',
      ]);
      expect(changes, isEmpty);
    });

    test('us03/s1, us03/fr02/e05: starts on the saved id over both '
        'defaults, with no callback', () async {
      final (controller, changes) = await startController(
        FakeThemeBundle(
          themes: {
            'default': markTheme('app-mark'),
            'brand': markTheme('brand-mark'),
          },
        ),
        initialThemeId: 'brand',
      );

      expect(controller.activeId, 'brand');
      expect(
        controller.themes.light.typography.fonts.keys,
        containsAll(<String>['inter', 'app-mark', 'brand-mark']),
      );
      expect(changes, isEmpty);
    });

    test('us03/fr01/e01: no initialThemeId starts on default', () async {
      final (controller, changes) = await startController(
        FakeThemeBundle(themes: {'brand': appTheme()}),
      );

      expect(controller.activeId, 'default');
      expect(changes, isEmpty);
    });

    test('us03/s3, us03/fr01/e02, us03/fr02/e04, us01/fr03/e02: a saved id '
        'that names no theme falls back to default, reports it, and logs '
        'the id', () async {
      final logs = captureDebugPrint();
      final (controller, changes) = await startController(
        FakeThemeBundle(themes: {'brand': appTheme()}),
        initialThemeId: 'gone',
      );

      expect(controller.activeId, 'default');
      expect(changes, ['default']);
      expect(logs, contains(_fallbackLog));
    });

    test('us03/fr01/e04, us01/s4, us01/fr03/e01: a start theme that fails '
        'to parse throws theme_format, with no fallback and no '
        'callback', () async {
      final changes = <String>[];

      await expectLater(
        StratumThemeController.preload(
          initialThemeId: 'brand',
          onThemeChanged: changes.add,
          bundle: FakeThemeBundle(themes: {'brand': brokenTheme()}),
        ),
        throwsA(isA<StratumThemeFormatException>()),
      );
      expect(changes, isEmpty);
    });

    test('us01/fr01/e02: a package default that fails to parse throws '
        'theme_format', () async {
      await expectLater(
        StratumThemeController.preload(
          bundle: FakeThemeBundle(packageDefault: 'name: ['),
        ),
        throwsA(isA<StratumThemeFormatException>()),
      );
    });
  });

  group('us05/fr01: theme font files', () {
    test('us05/s1: a theme registers its files under <id>/<family> before '
        'it is active', () async {
      final loads = recordFontLoads();
      final (controller, _) = await startController(
        FakeThemeBundle(
          themes: {'brand': fontTheme()},
          fonts: {fontKey('brand')},
        ),
        initialThemeId: 'brand',
      );

      expect(loads, [('brand/DB Heavent', 1)]);
      expect(
        controller.themes.light.typography.fonts['brand']!.family,
        'brand/DB Heavent',
      );
    });

    test('us05/fr01/e01: a theme with no files registers nothing', () async {
      final loads = recordFontLoads();
      await startController(FakeThemeBundle());

      expect(loads, isEmpty);
    });

    test('us05/fr01/e04: a file the bundle lacks logs the pubspec line, and '
        'the theme still starts', () async {
      final loads = recordFontLoads();
      final logs = captureDebugPrint();
      final (controller, _) = await startController(
        FakeThemeBundle(themes: {'brand': fontTheme()}),
        initialThemeId: 'brand',
      );

      expect(controller.activeId, 'brand');
      expect(loads, isEmpty);
      expect(logs, contains(_missingFontLog));
    });

    test('us05/fr01/e05: a theme that inherits a font uses its source '
        'registration, and no file registers twice', () async {
      final loads = recordFontLoads();
      final bundle = FakeThemeBundle(
        themes: {'default': fontTheme(), 'brand': appTheme()},
        fonts: {fontKey('default')},
      );
      await startController(bundle, initialThemeId: 'brand');
      await startController(bundle);

      expect(loads, [('default/DB Heavent', 1)]);
      expect(bundle.reads[fontKey('default')], 1);
    });

    test('us05/s4: two themes that ship the same family name register '
        'apart', () async {
      final loads = recordFontLoads();
      final bundle = FakeThemeBundle(
        themes: {'brand': fontTheme(), 'night': fontTheme()},
        fonts: {fontKey('brand'), fontKey('night')},
      );
      await startController(bundle, initialThemeId: 'brand');
      await startController(bundle, initialThemeId: 'night');

      expect(loads, [('brand/DB Heavent', 1), ('night/DB Heavent', 1)]);
    });

    test('a font registration that fails logs, and the theme still '
        'starts', () async {
      ThemeFontLoader.load = (family, files) async =>
          throw StateError('bad font bytes');
      final logs = captureDebugPrint();
      final (controller, _) = await startController(
        FakeThemeBundle(
          themes: {'brand': fontTheme()},
          fonts: {fontKey('brand')},
        ),
        initialThemeId: 'brand',
      );

      expect(controller.activeId, 'brand');
      expect(
        logs.where((line) => line.contains('"brand/DB Heavent" failed')),
        hasLength(1),
      );
    });
  });

  group('us05/fr02: Google fonts', () {
    test('us05/s2, us05/fr02: each Google font loads in each weight the '
        'yaml declares for the types that use it, in normal style', () async {
      final calls = recordGoogleFonts();
      await startController(FakeThemeBundle());

      expect(calls.where((call) => call.$3 == FontStyle.normal).toSet(), {
        ('Inter', FontWeight.w400, FontStyle.normal),
        ('Inter', FontWeight.w600, FontStyle.normal),
        ('Geist', FontWeight.w600, FontStyle.normal),
        ('Geist Mono', FontWeight.w600, FontStyle.normal),
        ('Roboto Mono', FontWeight.w400, FontStyle.normal),
        ('Roboto Mono', FontWeight.w600, FontStyle.normal),
        ('Kanit', FontWeight.w400, FontStyle.normal),
        ('Kanit', FontWeight.w600, FontStyle.normal),
      });
    });

    test('us05/s3, us05/fr02/e02: preload goes on when the 3 s limit '
        'passes', () {
      fakeAsync((async) {
        recordGoogleFonts(pending: () => Completer<void>().future);
        StratumThemeController? controller;
        unawaited(
          StratumThemeController.preload(bundle: FakeThemeBundle())
              .then((value) => controller = value),
        );

        async.elapse(const Duration(milliseconds: 2999));
        expect(controller, isNull);
        async.elapse(const Duration(milliseconds: 1));
        expect(controller?.activeId, 'default');
      });
    });

    test('us01/fr03: googleFontsTimeout sets another limit', () {
      fakeAsync((async) {
        recordGoogleFonts(pending: () => Completer<void>().future);
        StratumThemeController? controller;
        unawaited(
          StratumThemeController.preload(
            googleFontsTimeout: const Duration(seconds: 1),
            bundle: FakeThemeBundle(),
          ).then((value) => controller = value),
        );

        async.elapse(const Duration(milliseconds: 999));
        expect(controller, isNull);
        async.elapse(const Duration(milliseconds: 1));
        expect(controller, isNotNull);
      });
    });

    test('us05/fr02/e01: preload waits for Google fonts that finish in '
        'time', () {
      fakeAsync((async) {
        final fonts = Completer<void>();
        recordGoogleFonts(pending: () => fonts.future);
        StratumThemeController? controller;
        unawaited(
          StratumThemeController.preload(bundle: FakeThemeBundle())
              .then((value) => controller = value),
        );

        async.elapse(const Duration(milliseconds: 500));
        expect(controller, isNull);
        fonts.complete();
        async.flushMicrotasks();
        expect(controller, isNotNull);
      });
    });

    test('us05/fr02/e04: a Google font that fails lets preload go '
        'on', () async {
      recordGoogleFonts(
        pending: () => Future<void>.error(StateError('offline')),
      );
      final (controller, _) = await startController(FakeThemeBundle());

      expect(controller.activeId, 'default');
    });
  });

  group('S3 parse B: the background-isolate parse', () {
    test('preload parses off the main isolate, and a broken file still '
        'throws theme_format', () async {
      final saved = ThemeParse.run;
      ThemeParse.reset();
      addTearDown(() => ThemeParse.run = saved);

      final (controller, _) = await startController(
        FakeThemeBundle(themes: {'brand': markTheme('brand-mark')}),
        initialThemeId: 'brand',
      );
      expect(
        controller.themes.light.typography.fonts.keys,
        contains('brand-mark'),
      );
      await expectLater(
        StratumThemeController.preload(
          initialThemeId: 'brand',
          bundle: FakeThemeBundle(themes: {'brand': brokenTheme()}),
        ),
        throwsA(isA<StratumThemeFormatException>()),
      );
    });
  });
}
