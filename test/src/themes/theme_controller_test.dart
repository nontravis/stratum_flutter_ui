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

    test('a file a theme lists twice registers once', () async {
      final loads = recordFontLoads();
      final (controller, _) = await startController(
        FakeThemeBundle(
          themes: {'brand': duplicateFontTheme()},
          fonts: {fontKey('brand')},
        ),
        initialThemeId: 'brand',
      );

      expect(controller.activeId, 'brand');
      expect(loads, [('brand/DB Heavent', 1)]);
    });

    test('R8 (owner ruling): a registration that fails, then succeeds once '
        'the theme is needed again, loads and registers it', () async {
      var attempt = 0;
      ThemeFontLoader.load = (family, files) async {
        attempt++;
        if (attempt == 1) throw StateError('bad font bytes');
      };
      final logs = captureDebugPrint();
      final bundle = FakeThemeBundle(
        themes: {'brand': fontTheme()},
        fonts: {fontKey('brand')},
      );
      final (controller, _) = await startController(
        bundle,
        initialThemeId: 'brand',
      );

      expect(controller.activeId, 'brand');
      expect(attempt, 1);
      expect(logs.where((line) => line.contains('failed')), hasLength(1));

      await controller.switchTo('default');
      await controller.switchTo('brand');

      expect(attempt, 2);
      expect(
        controller.themes.light.typography.fonts['brand']!.family,
        'brand/DB Heavent',
      );
    });

    test('R8 (owner ruling): a registration that keeps failing logs a '
        'warning each time the theme is needed again', () async {
      ThemeFontLoader.load = (family, files) async =>
          throw StateError('bad font bytes');
      final logs = captureDebugPrint();
      final bundle = FakeThemeBundle(
        themes: {'brand': fontTheme()},
        fonts: {fontKey('brand')},
      );
      final (controller, _) = await startController(
        bundle,
        initialThemeId: 'brand',
      );
      await controller.switchTo('default');
      await controller.switchTo('brand');

      expect(controller.activeId, 'brand');
      expect(logs.where((line) => line.contains('failed')), hasLength(2));
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

    test('us05/fr02: a tag that names only its body font still waits for '
        "it at another type's weight, since the resolver draws every "
        "tag's body font as a fallback there", () async {
      final calls = recordGoogleFonts();
      await startController(
        FakeThemeBundle(
          themes: {
            'brand': appTheme('''
typography:
  fonts:
    xx-body: { family: "Google/Lato" }
  families:
    xx: { body: xx-body }'''),
          },
        ),
        initialThemeId: 'brand',
      );

      // Nothing else in this theme names "Lato" directly for any type, so
      // only the resolver's body-font fallback (resolver.dart `_fallback`)
      // can ask for it at header's weight.
      expect(calls, contains(('Lato', FontWeight.w600, FontStyle.normal)));
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

  group('us02/fr01: switchTo', () {
    test('us02/s1, us03/s2, us03/fr02: a switch makes the theme active in '
        'one step and reports it once, after it is active', () async {
      final seen = <String>[];
      var notified = 0;
      late final StratumThemeController controller;
      controller = await StratumThemeController.preload(
        onThemeChanged: (id) => seen.add('$id ${controller.activeId}'),
        bundle: FakeThemeBundle(themes: {'brand': markTheme('brand-mark')}),
      );
      controller.addListener(() => notified++);

      await controller.switchTo('brand');

      expect(controller.activeId, 'brand');
      expect(
        controller.themes.light.typography.fonts.keys,
        contains('brand-mark'),
      );
      expect(notified, 1);
      expect(seen, ['brand brand']);
    });

    test('us02/fr01/e01: an unknown id throws theme_not_found with the '
        'registered ids, and nothing changes', () async {
      final (controller, changes) = await startController(
        FakeThemeBundle(themes: {'brand': appTheme()}),
      );
      var notified = 0;
      controller.addListener(() => notified++);

      await expectLater(
        controller.switchTo('nope'),
        throwsA(
          isA<StratumThemeNotFoundException>()
              .having((error) => error.id, 'id', 'nope')
              .having((error) => error.registeredIds, 'registeredIds', [
                'default',
                'brand',
              ]),
        ),
      );
      expect(controller.activeId, 'default');
      expect(changes, isEmpty);
      expect(notified, 0);
    });

    test('us02/s3, us02/fr01/e02, us03/fr02/e01: a theme that fails to '
        'parse throws theme_format, and the active theme stays', () async {
      final (controller, changes) = await startController(
        FakeThemeBundle(themes: {'brand': brokenTheme()}),
      );
      final before = controller.themes;
      var notified = 0;
      controller.addListener(() => notified++);

      await expectLater(
        controller.switchTo('brand'),
        throwsA(isA<StratumThemeFormatException>()),
      );
      expect(controller.activeId, 'default');
      expect(controller.themes, same(before));
      expect(changes, isEmpty);
      expect(notified, 0);
    });

    test('us02/fr01/e04, us03/fr02/e06: a switch to the active id reads '
        'nothing and reports nothing', () async {
      final bundle = FakeThemeBundle(themes: {'brand': appTheme()});
      final (controller, changes) = await startController(
        bundle,
        initialThemeId: 'brand',
      );
      final reads = Map.of(bundle.reads);
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.switchTo('brand');

      expect(bundle.reads, reads);
      expect(changes, isEmpty);
      expect(notified, 0);
    });

    test('us02/fr01/e05, us03/fr02/e06: the latest of two overlapping '
        'switches wins; the first completes with no error and no '
        'callback', () async {
      final bundle = FakeThemeBundle(
        themes: {'brand': appTheme(), 'night': appTheme()},
      );
      final (controller, changes) = await startController(bundle);
      var notified = 0;
      controller.addListener(() => notified++);
      final release = bundle.hold[themeKey('brand')] = Completer<void>();

      final first = controller.switchTo('brand');
      await controller.switchTo('night');
      release.complete();
      await first;

      expect(controller.activeId, 'night');
      expect(changes, ['night']);
      expect(notified, 1);
    });

    test('a switch to the active id overtakes a switch in flight', () async {
      final bundle = FakeThemeBundle(themes: {'brand': appTheme()});
      final (controller, changes) = await startController(bundle);
      var notified = 0;
      controller.addListener(() => notified++);
      final release = bundle.hold[themeKey('brand')] = Completer<void>();

      final first = controller.switchTo('brand');
      await controller.switchTo('default');
      release.complete();
      await first;

      expect(controller.activeId, 'default');
      expect(changes, isEmpty);
      expect(notified, 0);
    });

    test('two switches to the same new id report it once', () async {
      final bundle = FakeThemeBundle(themes: {'brand': appTheme()});
      final (controller, changes) = await startController(bundle);
      var notified = 0;
      controller.addListener(() => notified++);
      final release = bundle.hold[themeKey('brand')] = Completer<void>();

      final first = controller.switchTo('brand');
      final second = controller.switchTo('brand');
      release.complete();
      await Future.wait([first, second]);

      expect(controller.activeId, 'brand');
      expect(changes, ['brand']);
      expect(notified, 1);
    });

    test('a switch that ends after dispose notifies no one', () async {
      final bundle = FakeThemeBundle(themes: {'brand': appTheme()});
      final (controller, changes) = await startController(bundle);
      final release = bundle.hold[themeKey('brand')] = Completer<void>();

      final pending = controller.switchTo('brand');
      controller.dispose();
      release.complete();
      await pending;

      expect(changes, isEmpty);
    });

    test('us02/fr01/e05: a switch overtaken while its own theme fails to '
        'parse completes with no error', () async {
      final bundle = FakeThemeBundle(
        themes: {'brand': brokenTheme(), 'night': appTheme()},
      );
      final (controller, changes) = await startController(bundle);
      final gate = Completer<void>();
      final saved = ThemeParse.run;
      ThemeParse.run = (base, layers) async {
        if (layers.any((layer) => layer.id == 'brand')) await gate.future;
        return saved(base, layers);
      };
      addTearDown(() => ThemeParse.run = saved);

      final first = controller.switchTo('brand');
      await pumpEventQueue();
      await controller.switchTo('night');
      gate.complete();

      await expectLater(first, completes);
      expect(controller.activeId, 'night');
      expect(changes, ['night']);
    });

    test('us02/fr01/e05: a switch that ends after dispose, whose theme '
        'fails to parse, completes with no error', () async {
      final bundle = FakeThemeBundle(themes: {'brand': brokenTheme()});
      final (controller, changes) = await startController(bundle);
      final gate = Completer<void>();
      final saved = ThemeParse.run;
      ThemeParse.run = (base, layers) async {
        await gate.future;
        return saved(base, layers);
      };
      addTearDown(() => ThemeParse.run = saved);

      final pending = controller.switchTo('brand');
      await pumpEventQueue();
      controller.dispose();
      gate.complete();

      await expectLater(pending, completes);
      expect(changes, isEmpty);
    });

    test('us02/fr01/e05: three rapid switches, only the latest wins', () async {
      final bundle = FakeThemeBundle(
        themes: {'brand': appTheme(), 'night': appTheme(), 'ocean': appTheme()},
      );
      final (controller, changes) = await startController(bundle);
      final releaseBrand = bundle.hold[themeKey('brand')] = Completer<void>();
      final releaseNight = bundle.hold[themeKey('night')] = Completer<void>();

      final first = controller.switchTo('brand');
      final second = controller.switchTo('night');
      final third = controller.switchTo('ocean');
      releaseBrand.complete();
      releaseNight.complete();
      await Future.wait([first, second, third]);

      expect(controller.activeId, 'ocean');
      expect(changes, ['ocean']);
    });

    test('us02/fr01: switchTo called again after dispose, with no switch '
        'already in flight, does no work and throws nothing', () async {
      final bundle = FakeThemeBundle(themes: {'brand': appTheme()});
      final (controller, changes) = await startController(bundle);
      controller.dispose();

      await controller.switchTo('brand');

      expect(changes, isEmpty);
    });

    test('us02/fr01/e01 x e05: an unknown-id switch thrown while a '
        'different switch is in flight does not affect that in-flight '
        'switch', () async {
      final bundle = FakeThemeBundle(
        themes: {'brand': appTheme(), 'night': appTheme()},
      );
      final (controller, changes) = await startController(bundle);
      final release = bundle.hold[themeKey('brand')] = Completer<void>();

      final inFlight = controller.switchTo('brand');
      await expectLater(
        controller.switchTo('nope'),
        throwsA(isA<StratumThemeNotFoundException>()),
      );
      release.complete();
      await inFlight;

      expect(controller.activeId, 'brand');
      expect(changes, ['brand']);
    });

    test('us03/fr02/e02: switchTo with no onThemeChanged still '
        'completes', () async {
      final controller = await StratumThemeController.preload(
        bundle: FakeThemeBundle(themes: {'brand': appTheme()}),
      );

      await controller.switchTo('brand');

      expect(controller.activeId, 'brand');
    });

    test('us02/fr01/e06, us05/fr01/e06: a switch back reads the file again '
        'and registers no font twice', () async {
      final loads = recordFontLoads();
      final bundle = FakeThemeBundle(
        themes: {'brand': fontTheme()},
        fonts: {fontKey('brand')},
      );
      final (controller, changes) = await startController(bundle);

      await controller.switchTo('brand');
      await controller.switchTo('default');
      await controller.switchTo('brand');

      expect(bundle.reads[themeKey('brand')], 2);
      expect(bundle.reads[fontKey('brand')], 1);
      expect(loads, [('brand/DB Heavent', 1)]);
      expect(changes, ['brand', 'default', 'brand']);
    });

    test('us05/s4: each theme that ships the same family name draws its own '
        'file after a switch', () async {
      final loads = recordFontLoads();
      final (controller, _) = await startController(
        FakeThemeBundle(
          themes: {'brand': fontTheme(), 'night': fontTheme()},
          fonts: {fontKey('brand'), fontKey('night')},
        ),
        initialThemeId: 'brand',
      );

      await controller.switchTo('night');

      expect(loads, [('brand/DB Heavent', 1), ('night/DB Heavent', 1)]);
      expect(
        controller.themes.light.typography.fonts['brand']!.family,
        'night/DB Heavent',
      );
    });

    test('us02/s2, us05/fr02/e06: a switch waits for its Google fonts up to '
        'the limit while the current theme stays', () {
      fakeAsync((async) {
        StratumThemeController? controller;
        unawaited(
          StratumThemeController.preload(
            bundle: FakeThemeBundle(themes: {'brand': appTheme()}),
          ).then((value) => controller = value),
        );
        async.flushMicrotasks();
        recordGoogleFonts(pending: () => Completer<void>().future);
        var done = false;
        unawaited(controller!.switchTo('brand').then((_) => done = true));

        async.elapse(const Duration(milliseconds: 2999));
        expect(controller!.activeId, 'default');
        expect(done, isFalse);
        async.elapse(const Duration(milliseconds: 1));
        expect(controller!.activeId, 'brand');
        expect(done, isTrue);
      });
    });
  });
}
