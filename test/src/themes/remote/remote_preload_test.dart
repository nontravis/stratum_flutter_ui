import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import 'remote_fakes.dart';
import 'remote_test_zip.dart';

String _mark(String mark) =>
    'typography:\n  fonts:\n    $mark: { family: $mark }';

/// [theme] with its checksum replaced, as a kept zip damaged on disk.
StratumRemoteTheme _damaged(StratumRemoteTheme theme) => StratumRemoteTheme(
  id: theme.id,
  bytes: theme.bytes,
  checksum: checksumOf([0]),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> logs;
  late List<String> changes;
  late List<(String, StratumRemoteThemeErrorCode)> errors;
  setUp(() {
    useSyncParse();
    recordRemoteFontLoads();
    recordRemoteGoogleFonts();
    logs = captureRemoteLogs();
    changes = [];
    errors = [];
  });

  Future<StratumThemeController> start(
    List<StratumRemoteTheme> remoteThemes, {
    String? initialThemeId,
    Map<String, String> bundled = const {},
    bool withCallback = true,
  }) async {
    final controller = await StratumThemeController.preload(
      bundle: RemoteFakeBundle(themes: bundled),
      initialThemeId: initialThemeId,
      onThemeChanged: changes.add,
      remoteThemes: remoteThemes,
      onRemoteThemeError: withCallback
          ? (id, error) => errors.add((id, error.code))
          : null,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  Iterable<String> fontKeys(StratumThemeController c) =>
      c.themes.light.typography.fonts.keys;

  test('us01/s3, us01/fr04, us01/fr03/e02: a kept zip installs again at the '
      'next start, before the start theme is picked', () async {
    final controller = await start([
      remoteTheme('brand', body: _mark('zip-mark')),
    ], initialThemeId: 'brand');

    expect(controller.themeIds, ['default', 'brand']);
    expect(controller.activeId, 'brand');
    expect(fontKeys(controller), contains('zip-mark'));
    expect(changes, isEmpty);
  });

  test('us01/s14, us01/fr04/e01, us01/fr04/e02, fo03 us03/fr01/e03, fo03 '
      'us01/fr03/e04: a damaged kept zip of an unbundled id is skipped, '
      'reported, and the start falls back to default', () async {
    final controller = await start([
      _damaged(remoteTheme('songkran')),
      remoteTheme('brand'),
    ], initialThemeId: 'songkran');

    expect(controller.themeIds, ['default', 'brand']);
    expect(controller.activeId, 'default');
    expect(changes, ['default']);
    expect(errors, [
      ('songkran', StratumRemoteThemeErrorCode.checksumMismatch),
    ]);
    expect(
      logs,
      contains(
        'Stratum theme: kept zip "songkran" failed to install '
        '(checksum_mismatch); skipped',
      ),
    );
    expect(
      logs,
      contains(
        'Stratum theme: initialThemeId "songkran" names no registered '
        'theme; starting on default',
      ),
    );
  });

  test('us01/fr04/e01, rz6 (3): a kept zip that breaks a new rule, a name '
      'outside printable ASCII, is skipped at preload and reported', () async {
    final controller = await start([
      remoteTheme(
        'songkran',
        files: {
          'imagés/a.svg': [1],
        },
      ),
    ], initialThemeId: 'songkran');

    expect(controller.themeIds, ['default']);
    expect(controller.activeId, 'default');
    expect(errors, [('songkran', StratumRemoteThemeErrorCode.unsafeEntryPath)]);
  });

  test('us01/fr04/e03: of two kept zips with one id, the later wins', () async {
    final controller = await start([
      remoteTheme('brand', body: _mark('first')),
      remoteTheme('brand', body: _mark('second')),
    ], initialThemeId: 'brand');

    expect(fontKeys(controller), contains('second'));
    expect(fontKeys(controller), isNot(contains('first')));
    expect(controller.remoteBundle.holds('stratum-remote/brand/1'), isFalse);
  });

  test(
    'us01/fr04/e04: a kept zip over a bundled id starts with the zip',
    () async {
      final controller = await start(
        [remoteTheme('brand', body: _mark('zip-mark'))],
        initialThemeId: 'brand',
        bundled: {'brand': '$remoteSchemaLine\n${_mark('bundled-mark')}'},
      );

      expect(fontKeys(controller), contains('zip-mark'));
      expect(fontKeys(controller), isNot(contains('bundled-mark')));
    },
  );

  test('us01/fr04/e07, r10/oq1: a failed kept zip of a bundled id leaves the '
      'bundled theme, and the start lands on it', () async {
    final controller = await start(
      [_damaged(remoteTheme('brand', body: _mark('zip-mark')))],
      initialThemeId: 'brand',
      bundled: {'brand': '$remoteSchemaLine\n${_mark('bundled-mark')}'},
    );

    expect(controller.activeId, 'brand');
    expect(fontKeys(controller), contains('bundled-mark'));
    expect(changes, isEmpty);
    expect(errors, [('brand', StratumRemoteThemeErrorCode.checksumMismatch)]);
  });

  test('us01/fr04/e05: with no callback, a failed kept zip still skips and '
      'logs, and preload throws nothing', () async {
    final controller = await start([
      _damaged(remoteTheme('songkran')),
    ], withCallback: false);

    expect(controller.activeId, 'default');
    expect(
      logs,
      contains(
        'Stratum theme: kept zip "songkran" failed to install '
        '(checksum_mismatch); skipped',
      ),
    );
  });

  test('us01/fr04, r12: a kept zip whose theme file is not UTF-8 is skipped '
      'as theme_format, and the start falls back to default', () async {
    final controller = await start([
      latin1Theme('brand'),
    ], initialThemeId: 'brand');

    expect(controller.themeIds, ['default']);
    expect(controller.activeId, 'default');
    expect(changes, ['default']);
    expect(errors, [('brand', StratumRemoteThemeErrorCode.themeFormat)]);
  });

  test('us01/fr04/e06: no kept zip runs preload as FO-03 states', () async {
    final controller = await start(
      const [],
      bundled: {'brand': '$remoteSchemaLine\nname: brand'},
    );

    expect(controller.themeIds, ['default', 'brand']);
    expect(controller.activeId, 'default');
    expect(errors, isEmpty);
  });
}
