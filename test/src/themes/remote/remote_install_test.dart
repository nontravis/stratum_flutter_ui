import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';
import 'package:stratum_ui/src/themes/theme_font_loader.dart';
import 'package:stratum_ui/src/themes/theme_parse.dart';

import 'remote_fakes.dart';
import 'remote_test_zip.dart';

const _font = '''
typography:
  fonts:
    brand: { family: Prompt, files: [fonts/Prompt-Regular.ttf] }''';

String _mark(String mark) =>
    'typography:\n  fonts:\n    $mark: { family: $mark }';

StratumRemoteTheme _zip(String id, {String body = _font}) => remoteTheme(
  id,
  body: body,
  files: {
    'fonts/Prompt-Regular.ttf': [1, 2, 3],
  },
);

Future<(StratumThemeController, List<String>)> _start(
  RemoteFakeBundle bundle, {
  String? initialThemeId,
}) async {
  final changes = <String>[];
  final controller = await StratumThemeController.preload(
    initialThemeId: initialThemeId,
    onThemeChanged: changes.add,
    bundle: bundle,
  );
  addTearDown(controller.dispose);
  return (controller, changes);
}

Iterable<String> _fontKeys(StratumThemeController controller) =>
    controller.themes.light.typography.fonts.keys;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<(String, int)> loads;
  setUp(() {
    useSyncParse();
    loads = recordRemoteFontLoads();
    recordRemoteGoogleFonts();
  });

  test('us01/s1, us01/s2, us01/fr03/e06: an install of a new id registers '
      'with no repaint and no callback; a switch shows its fonts', () async {
    final (controller, changes) = await _start(RemoteFakeBundle());
    var notified = 0;
    controller.addListener(() => notified++);

    await controller.install(_zip('brand'));

    expect(controller.themeIds, ['default', 'brand']);
    expect(controller.activeId, 'default');
    expect(notified, 0);
    expect(changes, isEmpty);
    expect(loads, isEmpty);

    await controller.switchTo('brand');

    expect(changes, ['brand']);
    expect(loads, [('brand@1/Prompt', 1)]);
  });

  test('us01/s8, us01/fr03/e05: a re-install of the active id repaints once '
      'in one step, with no theme-change callback', () async {
    final (controller, changes) = await _start(RemoteFakeBundle());
    await controller.install(
      _zip('brand', body: '$_font\n    old-mark: { family: old-mark }'),
    );
    await controller.switchTo('brand');
    var notified = 0;
    controller.addListener(() => notified++);

    await controller.install(
      _zip('brand', body: '$_font\n    new-mark: { family: new-mark }'),
    );

    expect(notified, 1);
    expect(changes, ['brand']);
    expect(_fontKeys(controller), contains('new-mark'));
    expect(_fontKeys(controller), isNot(contains('old-mark')));
    expect(loads, [('brand@1/Prompt', 1), ('brand@2/Prompt', 1)]);
  });

  test('us01/fr03/e07, us01/fr01/e04: a failing install of the active id '
      'changes nothing', () async {
    final (controller, _) = await _start(RemoteFakeBundle());
    await controller.install(_zip('brand'));
    await controller.switchTo('brand');
    final before = controller.themes;
    var notified = 0;
    controller.addListener(() => notified++);
    final junk = Uint8List.fromList([1, 2, 3, 4]);

    await expectLater(
      controller.install(
        StratumRemoteTheme(
          id: 'brand',
          bytes: junk,
          checksum: checksumOf(junk),
        ),
      ),
      throwsA(
        isA<StratumRemoteThemeException>().having(
          (e) => e.code,
          'code',
          StratumRemoteThemeErrorCode.invalidArchive,
        ),
      ),
    );

    expect(controller.themes, same(before));
    expect(notified, 0);
    expect(controller.remoteBundle.holds('stratum-remote/brand/1'), isTrue);
  });

  test('us01/s4, us01/fr01/e01: a checksum mismatch adds no theme', () async {
    final (controller, _) = await _start(RemoteFakeBundle());
    final good = _zip('brand');

    await expectLater(
      controller.install(
        StratumRemoteTheme(
          id: 'brand',
          bytes: good.bytes,
          checksum: checksumOf([0]),
        ),
      ),
      throwsA(
        isA<StratumRemoteThemeException>().having(
          (e) => e.code,
          'code',
          StratumRemoteThemeErrorCode.checksumMismatch,
        ),
      ),
    );

    expect(controller.themeIds, ['default']);
  });

  test('us01/s11: a zip named default is refused and default stays', () async {
    final (controller, _) = await _start(RemoteFakeBundle());
    final before = controller.themes;

    await expectLater(
      controller.install(_zip('default')),
      throwsA(
        isA<StratumRemoteThemeException>().having(
          (e) => e.code,
          'code',
          StratumRemoteThemeErrorCode.invalidId,
        ),
      ),
    );

    expect(controller.themes, same(before));
    expect(controller.themeIds, ['default']);
  });

  test('us01/s9, us01/fr03/e04: a zip replaces a bundled id for the run, and '
      'the bundled theme comes back at a start with no zip', () async {
    final bundle = RemoteFakeBundle(
      themes: {'brand': '$remoteSchemaLine\n${_mark('bundled-mark')}'},
    );
    final (controller, _) = await _start(bundle);

    await controller.install(_zip('brand', body: _mark('zip-mark')));
    await controller.switchTo('brand');

    expect(controller.themeIds, ['default', 'brand']);
    expect(_fontKeys(controller), contains('zip-mark'));
    expect(_fontKeys(controller), isNot(contains('bundled-mark')));

    final (fresh, _) = await _start(bundle, initialThemeId: 'brand');
    expect(_fontKeys(fresh), contains('bundled-mark'));
  });

  test('us01/fr03/e08: a switch that starts before an install of the active '
      'id swaps drops the swap and keeps the registration', () async {
    final (controller, changes) = await _start(RemoteFakeBundle());
    await controller.install(_zip('brand'));
    await controller.switchTo('brand');
    final hold = Completer<void>();
    ThemeFontLoader.load = (family, files) =>
        family == 'brand@2/Prompt' ? hold.future : Future<void>.value();

    final installing = controller.install(
      _zip('brand', body: '$_font\n    new-mark: { family: new-mark }'),
    );
    await pumpEventQueue();
    await controller.switchTo('default');
    hold.complete();
    await installing;

    expect(controller.activeId, 'default');
    expect(changes, ['brand', 'default']);
    await controller.switchTo('brand');
    expect(_fontKeys(controller), contains('new-mark'));
  });

  test('r10/oq4: an earlier generation leaves memory once no theme on screen '
      "uses it, and stays through the new install's font load", () async {
    final (controller, _) = await _start(RemoteFakeBundle());
    final overlay = controller.remoteBundle;

    await controller.install(_zip('brand'));
    await controller.install(_zip('brand'));
    expect(overlay.holds('stratum-remote/brand/1'), isFalse);
    expect(overlay.holds('stratum-remote/brand/2'), isTrue);

    await controller.switchTo('brand');
    final hold = Completer<void>();
    ThemeFontLoader.load = (family, files) =>
        family == 'brand@3/Prompt' ? hold.future : Future<void>.value();
    final installing = controller.install(_zip('brand'));
    await pumpEventQueue();
    expect(overlay.holds('stratum-remote/brand/2'), isTrue);

    hold.complete();
    await installing;
    expect(overlay.holds('stratum-remote/brand/2'), isFalse);
    expect(overlay.holds('stratum-remote/brand/3'), isTrue);
  });

  test('us01/fr03/e11, ruling oq1: a switch to the active id while its '
      'install is in flight leaves the swap in place', () async {
    final (controller, changes) = await _start(RemoteFakeBundle());
    await controller.install(_zip('brand'));
    await controller.switchTo('brand');
    final hold = Completer<void>();
    ThemeFontLoader.load = (family, files) =>
        family == 'brand@2/Prompt' ? hold.future : Future<void>.value();

    final installing = controller.install(
      _zip('brand', body: '$_font\n    new-mark: { family: new-mark }'),
    );
    await pumpEventQueue();
    await controller.switchTo('brand');
    hold.complete();
    await installing;

    expect(_fontKeys(controller), contains('new-mark'));
    expect(changes, ['brand']);
  });

  test('us01/fr03/e12, ruling n4: a later call registered first, so the '
      'earlier call registers nothing and completes with no error', () async {
    final (controller, _) = await _start(RemoteFakeBundle());
    final holds = <Completer<void>>[];
    ThemeParse.run = (base, layers) async {
      final hold = Completer<void>();
      holds.add(hold);
      await hold.future;
      return StratumThemeConfig.parse(base: base, layers: layers);
    };

    final first = controller.install(_zip('brand', body: _mark('first')));
    final second = controller.install(_zip('brand', body: _mark('second')));
    await pumpEventQueue();
    holds[1].complete();
    await second;
    holds[0].complete();
    await expectLater(first, completes);
    useSyncParse();
    await controller.switchTo('brand');

    expect(_fontKeys(controller), contains('second'));
    expect(_fontKeys(controller), isNot(contains('first')));
    expect(controller.remoteBundle.holds('stratum-remote/brand/1'), isFalse);
    expect(controller.remoteBundle.holds('stratum-remote/brand/2'), isTrue);
  });

  test('us01/fr03/e12, ruling n4: a later install call that fails leaves '
      'an earlier call free to register', () async {
    final (controller, _) = await _start(RemoteFakeBundle());
    final hold = Completer<void>();
    ThemeParse.run = (base, layers) async {
      await hold.future;
      return StratumThemeConfig.parse(base: base, layers: layers);
    };

    final first = controller.install(_zip('brand', body: _mark('first')));
    final good = _zip('brand');
    await expectLater(
      controller.install(
        StratumRemoteTheme(
          id: 'brand',
          bytes: good.bytes,
          checksum: checksumOf([0]),
        ),
      ),
      throwsA(isA<StratumRemoteThemeException>()),
    );
    hold.complete();
    await first;
    useSyncParse();
    await controller.switchTo('brand');

    expect(_fontKeys(controller), contains('first'));
  });

  test('us01/fr03: themeIds list default, then bundled and installed ids '
      'together in alphabetical order', () async {
    final (controller, _) = await _start(
      RemoteFakeBundle(
        themes: {
          'night': '$remoteSchemaLine\nname: night',
          'apple': '$remoteSchemaLine\nname: apple',
        },
      ),
    );

    await controller.install(_zip('zeta'));
    await controller.install(_zip('brand'));

    expect(controller.themeIds, ['default', 'apple', 'brand', 'night', 'zeta']);
  });

  test('review focus 1, ruling fix-2: an install of X that finishes while a '
      'switch to X is in flight lands the newest generation in one step, '
      'with one theme-change callback', () async {
    final (controller, changes) = await _start(RemoteFakeBundle());
    final overlay = controller.remoteBundle;
    await controller.install(
      _zip('brand', body: '$_font\n    old-mark: { family: old-mark }'),
    );
    final hold = Completer<void>();
    ThemeFontLoader.load = (family, files) =>
        family == 'brand@1/Prompt' ? hold.future : Future<void>.value();
    var notified = 0;
    controller.addListener(() => notified++);

    final switching = controller.switchTo('brand');
    await pumpEventQueue();
    await controller.install(
      _zip('brand', body: '$_font\n    new-mark: { family: new-mark }'),
    );

    expect(controller.activeId, 'brand');
    expect(_fontKeys(controller), contains('new-mark'));
    expect(_fontKeys(controller), isNot(contains('old-mark')));
    expect(changes, ['brand']);
    expect(notified, 1);

    hold.complete();
    await switching;
    expect(changes, ['brand']);
    expect(notified, 1);
    expect(overlay.holds('stratum-remote/brand/1'), isFalse);
    expect(overlay.holds('stratum-remote/brand/2'), isTrue);
  });

  test('r10/oq4, us01/fr03/e08: the generation on screen stays in memory '
      'while a switch away loads, after the registry moved on', () async {
    final (controller, _) = await _start(RemoteFakeBundle());
    final overlay = controller.remoteBundle;
    await controller.install(_zip('brand'));
    await controller.switchTo('brand');
    final fontHold = Completer<void>();
    ThemeFontLoader.load = (family, files) =>
        family == 'brand@2/Prompt' ? fontHold.future : Future<void>.value();

    final installing = controller.install(_zip('brand'));
    await pumpEventQueue();
    final parseHold = Completer<void>();
    ThemeParse.run = (base, layers) async {
      await parseHold.future;
      return StratumThemeConfig.parse(base: base, layers: layers);
    };
    final switching = controller.switchTo('default');
    await pumpEventQueue();
    fontHold.complete();
    await installing;

    expect(controller.activeId, 'brand');
    expect(overlay.holds('stratum-remote/brand/1'), isTrue);
    expect(overlay.holds('stratum-remote/brand/2'), isTrue);

    parseHold.complete();
    await switching;
    expect(controller.activeId, 'default');
    expect(overlay.holds('stratum-remote/brand/1'), isFalse);
    expect(overlay.holds('stratum-remote/brand/2'), isTrue);
  });
}
