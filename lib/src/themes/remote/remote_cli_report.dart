import 'package:stratum_ui/src/themes/config/escape_text.dart';
import 'package:stratum_ui/src/themes/remote/remote_install_check.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';

// The standard error lines of the `stratum_theme` CLI (FO-04 US-02 FR-03;
// s05 CLI output). Only `bin/stratum_theme.dart` imports this file.

/// The first standard error line of a run that reaches the check: the
/// default theme files the theme file was read over, the package default
/// first (FR-03 E07).
String cliDefaultsLine({required String packageDefault, String? appDefault}) =>
    appDefault == null
    ? 'defaults: $packageDefault (package)'
    : 'defaults: $packageDefault (package), $appDefault (app)';

/// One line per problem of [error]: its catalog code and its message, whose
/// zip and theme text is already escaped (FR-03 E02); a `theme_format`
/// failure gives one line per problem of its FO-01 report, with the
/// source, the position, the escaped yaml path, the message, and the FO-01
/// code (FR-03 E03). Relies on every FO-01 path, message, and source
/// reaching `toString()` holding no line break: `escapeZipText` escapes
/// them first (preflight D4).
List<String> cliProblemLines(StratumRemoteThemeException error) {
  final report = error.formatException;
  if (report == null) return ['${error.code.key}: ${error.message}'];
  return [
    for (final line in report.toString().split('\n').skip(1))
      '${error.code.key}: ${line.trim()}',
  ];
}

/// Warns that [name] is in the zip, but the theme file does not name it
/// (FR-03 E05, E06).
String _unnamedWarning(String name) =>
    'warning: "${escapeZipText(name)}" is in the zip, but the theme file '
    'does not name it';

/// Warns that [first] and [second] differ only in letter case (s03 Twin
/// names; plan D-h, case only).
String _twinWarning(String first, String second) =>
    'warning: "${escapeZipText(first)}" and "${escapeZipText(second)}" '
    'differ only in letter case';

/// Warns that [name], a zip path, is in the zip, but the install never
/// reads it (FR-03 E13).
String _unreadWarning(String name) =>
    'warning: "${escapeZipText(name)}" is in the zip, but the app install '
    'never reads it';

/// The warnings of a zip that passed the check, each starting with
/// `warning:` and never failing the run (FR-03 E05, E06, E13): every file,
/// `theme.yaml` aside, that the theme file names neither as a font file nor
/// as an asset slot, in name order; then every entry the install never
/// reads, by its zip path, in name order; then every two twin names next
/// to each other.
List<String> cliWarnings(RemoteInstallCheck check) {
  final names = check.entries.keys.toList()..sort();
  final unread = [...check.unreadEntries]..sort();
  return [
    for (final name in names)
      if (name != 'theme.yaml' && !check.namedFiles.contains(name))
        _unnamedWarning(name),
    for (final name in unread) _unreadWarning(name),
    for (final (first, second) in twinNames(names)) _twinWarning(first, second),
  ];
}

/// Every two [names] next to each other in a group of names equal when
/// letter case is ignored (s03 Twin names; plan D-h, case only), each
/// group in the order of [names], so a group of n names gives n - 1 pairs
/// and the output grows linearly (FR-03 E06). Groups by
/// `name.toUpperCase().toLowerCase()`, which also catches `ſ`/`s`, `µ`/`μ`,
/// `ς`/`σ`, and `ı`/`I` as twins, and over-warns on `ß`/`ss`, which is
/// harmless for a warning — still case only, no NFC (D-h).
List<(String, String)> twinNames(List<String> names) {
  final groups = <String, List<String>>{};
  for (final name in names) {
    (groups[name.toUpperCase().toLowerCase()] ??= []).add(name);
  }
  return [
    for (final group in groups.values)
      for (var i = 1; i < group.length; i++) (group[i - 1], group[i]),
  ];
}
