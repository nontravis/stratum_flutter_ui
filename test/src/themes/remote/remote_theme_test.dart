import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';

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
