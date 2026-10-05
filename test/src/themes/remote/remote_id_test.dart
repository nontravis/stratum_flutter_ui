import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/remote/remote_id.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';

void main() {
  for (final id in ['brand', 'songkran-2026', 'a_b', '0', 'x-_9']) {
    test('us01/fr01: "$id" passes the id rule', () {
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
    test('us01/fr01/e02: "$id" is invalid_id naming the id', () {
      expect(
        () => checkRemoteThemeId(id),
        throwsA(
          isA<RemoteThemeFailure>()
              .having(
                (f) => f.code,
                'code',
                StratumRemoteThemeErrorCode.invalidId,
              )
              .having((f) => f.message, 'message', contains('"$id"')),
        ),
      );
    });
  }
}
