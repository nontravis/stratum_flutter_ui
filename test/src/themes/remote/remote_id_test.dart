import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/remote/remote_id.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';

void main() {
  for (final id in ['brand', 'songkran-2026', 'a_b', '0', 'x-_9']) {
    test('fo04/us01/fr01: "$id" passes the id rule', () {
      expect(() => checkRemoteThemeId(id), returnsNormally);
    });
  }

  for (final id in [
    'default',
    '',
    'Brand',
    'brand/x',
    'brand@2',
    'brand.zip',
    'ก',
    ' brand',
    '../brand',
  ]) {
    test('fo04/us01/fr01/e02: "$id" is invalid_id naming the id', () {
      expect(
        () => checkRemoteThemeId(id),
        throwsA(
          isA<RemoteThemeFailure>()
              .having(
                (f) => f.code,
                'code',
                StratumRemoteThemeErrorCode.invalidId,
              )
              .having(
                (f) => f.message,
                'message',
                contains('"${escapeZipText(id)}"'),
              ),
        ),
      );
    });
  }

  test('d-m, oq-f, fo04/us01/fr01/e02: an off-rule id reaches the invalid_id '
      'message escaped', () {
    final id = 'brand${String.fromCharCode(0x0e44)}${String.fromCharCode(7)}';

    expect(
      () => checkRemoteThemeId(id),
      throwsA(
        isA<RemoteThemeFailure>().having(
          (f) => f.message,
          'message',
          r'theme id "brand\u0e44\u0007" may hold only a-z, 0-9, "-", '
              'and "_"',
        ),
      ),
    );
  });

  test('d-m, oq-f, fo04/us01/fr01/e02: the default-id message keeps its text, '
      'escaped by the same rule', () {
    expect(
      () => checkRemoteThemeId('default'),
      throwsA(
        isA<RemoteThemeFailure>().having(
          (f) => f.message,
          'message',
          'theme id "default" is the default theme, which a zip never '
              'replaces',
        ),
      ),
    );
  });
}
