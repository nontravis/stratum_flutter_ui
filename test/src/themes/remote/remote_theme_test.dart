import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  test('us01/fr02: the caps default to 20 MB and 200 entries', () {
    final theme = StratumRemoteTheme(
      id: 'brand',
      bytes: Uint8List(0),
      checksum: 'sha256:x',
    );

    expect(theme.maxBytes, 20 * 1024 * 1024);
    expect(theme.maxEntries, 200);
  });

  test('us01/fr02/e08: the app raises the caps for one theme', () {
    final theme = StratumRemoteTheme(
      id: 'brand',
      bytes: Uint8List(0),
      checksum: 'sha256:x',
      maxBytes: 64 * 1024 * 1024,
      maxEntries: 500,
    );

    expect(theme.maxBytes, 64 * 1024 * 1024);
    expect(theme.maxEntries, 500);
  });

  test('d1: the exception names its code and id', () {
    const error = StratumRemoteThemeException(
      code: StratumRemoteThemeErrorCode.missingEntry,
      id: 'brand',
      message: 'gone',
      path: 'fonts/a.ttf',
    );

    expect(error.path, 'fonts/a.ttf');
    expect(
      error.toString(),
      'StratumRemoteThemeException(missing_entry) "brand": gone',
    );
  });

  test('d1, s05: toString escapes the id, so a control character never '
      'reaches a log or crash sink raw', () {
    const error = StratumRemoteThemeException(
      code: StratumRemoteThemeErrorCode.invalidId,
      id: 'bra\u0007nd',
      message: 'gone',
    );

    expect(error.toString(), contains(r'bra\u0007nd'));
    expect(error.toString(), isNot(contains('\u0007')));
  });

  test('d1: theme_format wraps the FO-01 report', () {
    const report = StratumThemeFormatException([]);
    const error = StratumRemoteThemeException(
      code: StratumRemoteThemeErrorCode.themeFormat,
      id: 'brand',
      message: 'the theme file has problems',
      formatException: report,
    );

    expect(error.formatException, same(report));
  });
}
