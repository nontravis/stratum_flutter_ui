import 'dart:io';

/// Prefix of every public top-level name that a frozen file declares.
const baselinePrefix = 'Baseline';

/// Folder of the frozen files, relative to `example/`.
const baselineDirectory = 'integration_test/baseline';

/// The barrel that exports every frozen file; each frozen file imports it.
const baselineBarrel = 'baseline.dart';

final _declaration = RegExp(
  r'^(?:(?:abstract|base|final|sealed|interface|mixin)\s+)*'
  r'(?:class|mixin|enum|extension\s+type|extension|typedef)\s+([A-Z]\w*)',
  multiLine: true,
);

final _directive = RegExp(r'^(?:library|part)\b', multiLine: true);

/// Freezes baseline classes for the in-process benchmark (spec section 9.3).
///
/// Usage, from `example/`:
/// `dart run tool/perf_freeze.dart <commit> <path>...`
///
/// Each path is relative to the repository root. Replaces the content of
/// `integration_test/baseline/` with one frozen file per path and a barrel
/// that exports them. Run `flutter analyze` on the folder afterwards: an
/// error there means the copy set misses a file.
Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('usage: dart run tool/perf_freeze.dart <commit> <path>...');
    exitCode = 64;
    return;
  }
  final commit = await _resolve(args.first);
  final sources = {
    for (final path in args.skip(1)) path: await _show(commit, path),
  };
  final files = freeze(commit: commit, sources: sources);
  final directory = Directory(baselineDirectory);
  if (directory.existsSync()) directory.deleteSync(recursive: true);
  directory.createSync(recursive: true);
  for (final MapEntry(key: name, value: content) in files.entries) {
    File('${directory.path}/$name').writeAsStringSync(content);
  }
  final names = declaredNames(sources.values).toList()..sort();
  stdout.writeln(
    'froze ${sources.length} files from $commit; renamed ${names.join(', ')}',
  );
}

/// Public top-level names declared in [sources].
Set<String> declaredNames(Iterable<String> sources) {
  return {
    for (final source in sources)
      for (final match in _declaration.allMatches(source)) match[1]!,
  };
}

/// [source] with [baselinePrefix] before every whole identifier in [names].
String renameAll(String source, Set<String> names) {
  if (names.isEmpty) return source;
  final pattern = RegExp('\\b(${names.join('|')})\\b');
  return source.replaceAllMapped(
    pattern,
    (match) => '$baselinePrefix${match[1]}',
  );
}

/// File name to content for each frozen source and for the barrel.
///
/// [sources] maps a repository path to its content at [commit]. Throws an
/// [ArgumentError] when two paths share a file name, a path is named like
/// the barrel, or a source has a library or part directive.
Map<String, String> freeze({
  required String commit,
  required Map<String, String> sources,
}) {
  final names = declaredNames(sources.values);
  final files = <String, String>{};
  for (final MapEntry(key: path, value: source) in sources.entries) {
    final name = path.split('/').last;
    if (name == baselineBarrel || files.containsKey(name)) {
      throw ArgumentError.value(path, 'sources', 'duplicate file name $name');
    }
    if (_directive.hasMatch(source)) {
      throw ArgumentError.value(path, 'sources', 'library or part directive');
    }
    files[name] =
        '${_header('$commit:$path')}'
        '// ignore_for_file: type=lint, unused_import\n'
        "import '$baselineBarrel';\n"
        '\n'
        '${renameAll(source, names)}';
  }
  files[baselineBarrel] =
      '${_header(commit)}\n'
      '${[for (final name in files.keys) "export '$name';\n"].join()}';
  return files;
}

String _header(String origin) {
  return '// Frozen by tool/perf_freeze.dart from $origin. Do not edit; run\n'
      '// the tool again. Verbatim except this header, the baseline import,\n'
      '// and the $baselinePrefix prefix on the names the frozen files '
      'declare.\n';
}

Future<String> _resolve(String commit) async {
  return (await _git(['rev-parse', '--short', commit])).trim();
}

Future<String> _show(String commit, String path) {
  return _git(['show', '$commit:$path']);
}

Future<String> _git(List<String> args) async {
  final result = await Process.run('git', args);
  if (result.exitCode != 0) {
    throw ProcessException('git', args, '${result.stderr}', result.exitCode);
  }
  return result.stdout as String;
}
