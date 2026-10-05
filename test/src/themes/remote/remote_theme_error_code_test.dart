import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';

void main() {
  test('every code keys as its s05 catalog row', () {
    expect(StratumRemoteThemeErrorCode.values.map((code) => code.key), [
      'invalid_id',
      'invalid_checksum',
      'checksum_mismatch',
      'invalid_archive',
      'archive_too_large',
      'unsafe_entry_path',
      'missing_theme_file',
      'theme_format',
      'missing_entry',
    ]);
  });

  test('a failure keeps its code, message, path, and measured value', () {
    const failure = RemoteThemeFailure(
      StratumRemoteThemeErrorCode.archiveTooLarge,
      'too big',
      path: 'fonts/a.ttf',
      measured: 42,
    );

    expect(failure.code, StratumRemoteThemeErrorCode.archiveTooLarge);
    expect(failure.message, 'too big');
    expect(failure.path, 'fonts/a.ttf');
    expect(failure.measured, 42);
  });
}
