import 'package:crypto/crypto.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';

final _checksumText = RegExp(r'^sha256:[0-9a-fA-F]{64}$');

/// Checks the checksum text (FO-04 US-01 FR-01 E03): `sha256:` and 64 hex
/// digits; throws `RemoteThemeFailure` `invalidChecksum` before any byte is
/// hashed.
void checkChecksumText(String checksum) {
  if (!_checksumText.hasMatch(checksum)) {
    throw const RemoteThemeFailure(
      StratumRemoteThemeErrorCode.invalidChecksum,
      'the checksum must be "sha256:" followed by 64 hex digits',
    );
  }
}

/// Compares the SHA-256 of [bytes] with [checksum], whose text
/// [checkChecksumText] passed (FO-04 US-01 FR-01 E01); throws
/// `RemoteThemeFailure` `checksumMismatch` before any entry is read.
void verifyChecksum(String checksum, List<int> bytes) {
  final expected = checksum.substring('sha256:'.length).toLowerCase();
  final actual = sha256.convert(bytes).toString();
  if (actual != expected) {
    throw RemoteThemeFailure(
      StratumRemoteThemeErrorCode.checksumMismatch,
      'the zip bytes hash to sha256:$actual, not the checksum the app passed',
    );
  }
}
