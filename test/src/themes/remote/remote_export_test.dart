import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';

void main() {
  test('d1: the package exports the remote theme API', () {
    final theme = StratumRemoteTheme(
      id: 'brand',
      bytes: Uint8List(0),
      checksum: 'sha256:x',
    );

    expect(theme.maxEntries, StratumRemoteTheme.defaultMaxEntries);
    expect(StratumRemoteThemeErrorCode.invalidId.key, 'invalid_id');
    expect(StratumRemoteThemeException, isNotNull);
  });
}
