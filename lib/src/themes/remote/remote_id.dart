import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';

final _remoteId = RegExp(r'^[a-z0-9_-]+$');

/// Checks the remote id rule (FO-04 US-01 FR-01): only `a-z`, `0-9`, `-`,
/// and `_`, so never `/`, the font family separator, and never `@`, the
/// install generation separator; never `default`, the merge base of every
/// theme. Throws `RemoteThemeFailure` `invalidId` naming the id.
void checkRemoteThemeId(String id) {
  if (id == 'default') {
    throw RemoteThemeFailure(
      StratumRemoteThemeErrorCode.invalidId,
      'theme id "${escapeZipText(id)}" is the default theme, which a zip never '
      'replaces',
    );
  }
  if (!_remoteId.hasMatch(id)) {
    throw RemoteThemeFailure(
      StratumRemoteThemeErrorCode.invalidId,
      'theme id "${escapeZipText(id)}" may hold only a-z, 0-9, "-", and "_"',
    );
  }
}
