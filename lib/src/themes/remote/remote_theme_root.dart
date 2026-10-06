import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';

/// Whether the zip reader skips [name]: an entry under `__MACOSX/` or one
/// whose base name is `.DS_Store`.
bool isIgnoredEntry(String name) =>
    name.startsWith('__MACOSX/') ||
    name == '.DS_Store' ||
    name.endsWith('/.DS_Store');

/// The theme root of a zip with the entry [names] (FO-04 US-01 FR-02 E03,
/// E05): `''` when the zip root holds `theme.yaml`; else `'<folder>/'`
/// when the zip holds exactly one top folder, ignored entries and loose
/// top files aside, and that folder holds `theme.yaml`. Throws
/// `RemoteThemeFailure` `missingThemeFile` whose message names the cause,
/// the zip's folder names escaped.
String findThemeRoot(Iterable<String> names) {
  final files = [
    for (final name in names)
      if (!name.endsWith('/') && !isIgnoredEntry(name)) name,
  ];
  if (files.contains('theme.yaml')) return '';
  final folders = <String>{
    for (final file in files)
      if (file.contains('/')) file.split('/').first,
  };
  if (folders.length >= 2) {
    throw RemoteThemeFailure(
      StratumRemoteThemeErrorCode.missingThemeFile,
      'the zip root holds no theme.yaml and holds two or more top '
      'folders: ${escapeZipText((folders.toList()..sort()).join(', '))}',
    );
  }
  if (folders.length == 1) {
    final folder = '${folders.single}/';
    if (files.contains('${folder}theme.yaml')) return folder;
  }
  final deep = files.where((file) => file.endsWith('/theme.yaml')).toList();
  if (deep.isNotEmpty) {
    throw RemoteThemeFailure(
      StratumRemoteThemeErrorCode.missingThemeFile,
      'theme.yaml sits two or more folders deep: ${escapeZipText(deep.first)}',
    );
  }
  throw const RemoteThemeFailure(
    StratumRemoteThemeErrorCode.missingThemeFile,
    'the zip holds no theme.yaml',
  );
}
