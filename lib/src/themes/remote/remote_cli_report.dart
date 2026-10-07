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
/// code (FR-03 E03).
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

/// The warnings of a zip that passed the check, each starting with
/// `warning:` and never failing the run (FR-03 E05, E06): every file,
/// `theme.yaml` aside, that the theme file names neither as a font file nor
/// as an asset slot, in name order, then every pair of twin names.
List<String> cliWarnings(RemoteInstallCheck check) {
  final names = check.entries.keys.toList()..sort();
  return [
    for (final name in names)
      if (name != 'theme.yaml' && !check.namedFiles.contains(name))
        _unnamedWarning(name),
    for (final (first, second) in twinNames(names)) _twinWarning(first, second),
  ];
}

/// Every pair of [names] that are equal when letter case is ignored (s03
/// Twin names; plan D-h, case only), each pair once, in the order of
/// [names]. Groups by the lower-case name, so a zip of many entries costs
/// no pairwise compare.
List<(String, String)> twinNames(List<String> names) {
  final groups = <String, List<String>>{};
  for (final name in names) {
    (groups[name.toLowerCase()] ??= []).add(name);
  }
  return [
    for (final group in groups.values)
      for (var i = 0; i < group.length; i++)
        for (var j = i + 1; j < group.length; j++) (group[i], group[j]),
  ];
}
