import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/remote/remote_checksum.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';

import 'remote_test_zip.dart';

const _abc =
    'sha256:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';

Matcher _fails(StratumRemoteThemeErrorCode code) =>
    throwsA(isA<RemoteThemeFailure>().having((f) => f.code, 'code', code));

void main() {
  test('fo04/us01/fr01: the FIPS 180-2 "abc" vector matches', () {
    expect(() => checkChecksumText(_abc), returnsNormally);
    expect(() => verifyChecksum(_abc, utf8.encode('abc')), returnsNormally);
    expect(checksumOf(utf8.encode('abc')), _abc);
  });

  test('fo04/us01/fr01: upper-case hex digits match too', () {
    final upper = 'sha256:${_abc.substring(7).toUpperCase()}';
    expect(() => checkChecksumText(upper), returnsNormally);
    expect(() => verifyChecksum(upper, utf8.encode('abc')), returnsNormally);
  });

  for (final text in [
    '',
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    'sha512:${'0' * 64}',
    'sha256:${'0' * 63}',
    'sha256:${'0' * 65}',
    'sha256:${'g' * 64}',
    'SHA256:${'0' * 64}',
    'sha256: ${'0' * 64}',
  ]) {
    test('fo04/us01/fr01/e03: "$text" is invalid_checksum', () {
      expect(
        () => checkChecksumText(text),
        _fails(StratumRemoteThemeErrorCode.invalidChecksum),
      );
    });
  }

  test('fo04/us01/fr01/e01: one changed byte is checksum_mismatch', () {
    expect(
      () => verifyChecksum(_abc, utf8.encode('abd')),
      _fails(StratumRemoteThemeErrorCode.checksumMismatch),
    );
  });
}
