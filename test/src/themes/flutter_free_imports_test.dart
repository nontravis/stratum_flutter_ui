@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// One `import` or `export` directive in either quote style: its URI, and
/// the rest of the directive up to its `;`.
final _directive = RegExp(
  r'''^\s*(?:import|export)\s+(['"])([^'"]+)\1([^;]*);''',
  multiLine: true,
);

/// The `if (...)` of a conditional import.
final _condition = RegExp(r'\bif\s*\(');

/// The URI of every directive of [source], in order.
List<String> _uris(String source) => [
  for (final match in _directive.allMatches(source)) match[2]!,
];

/// Every edge `(file, uri)` of the import graph of [entry], a path from
/// the package root: `stratum_ui` files are followed, and every other URI
/// is a leaf. A conditional import fails the walk: the Dart VM would take
/// its default branch, which this walk does not judge.
List<(String, String)> _edges(String entry) {
  final edges = <(String, String)>[];
  final seen = <String>{};
  final queue = [entry];
  while (queue.isNotEmpty) {
    final file = queue.removeLast();
    if (!seen.add(file)) continue;
    final source = File(file).readAsStringSync();
    for (final match in _directive.allMatches(source)) {
      final uri = match[2]!;
      expect(match[3], isNot(matches(_condition)), reason: '$file: $uri');
      edges.add((file, uri));
      final String target;
      if (uri.startsWith('package:stratum_ui/')) {
        target = p.join('lib', uri.substring('package:stratum_ui/'.length));
      } else if (uri.contains(':')) {
        continue;
      } else {
        target = p.normalize(p.join(p.dirname(file), uri));
      }
      queue.add(target);
    }
  }
  return edges;
}

/// The edges of [entry]'s graph that reach Flutter, `dart:ui`, or the
/// `src.dart` barrel, and `dart:io` too when [refuseIo] is set.
List<String> _refused(String entry, {required bool refuseIo}) => [
  for (final (file, uri) in _edges(entry))
    if (uri.startsWith('package:flutter/') ||
        uri == 'dart:ui' ||
        uri == 'package:stratum_ui/src/src.dart' ||
        p.normalize(p.join(p.dirname(file), uri)) ==
            p.join('lib', 'src', 'src.dart') ||
        (refuseIo && uri == 'dart:io'))
      '$file imports $uri',
];

void main() {
  test('minor5: the directive reader reads both quote styles', () {
    expect(
      _uris(
        "import \"dart:io\";\nimport 'dart:ui' show Color;\n"
        "export 'a.dart';",
      ),
      ['dart:io', 'dart:ui', 'a.dart'],
    );
  });

  for (final entry in [
    'lib/src/themes/remote/remote_install_check.dart',
    'lib/src/themes/config/pipeline/parse_values.dart',
  ]) {
    test('s2, s03/inv13: $entry, a part of the install check, reaches no '
        'Flutter, dart:ui, src.dart barrel, or dart:io', () {
      expect(_refused(entry, refuseIo: true), isEmpty);
    });
  }

  test('s2, s03/inv13: bin/stratum_theme.dart reaches no Flutter, dart:ui, '
      'or src.dart barrel', () {
    expect(_refused('bin/stratum_theme.dart', refuseIo: false), isEmpty);
  });

  test('us10/fr01/e04, s03/inv33: tool/gen_theme_tokens.dart reaches no '
      'Flutter, dart:ui, or src.dart barrel, so dart run regenerates the '
      'tokens', () {
    expect(_refused('tool/gen_theme_tokens.dart', refuseIo: false), isEmpty);
  });

  test('minor5, us01/fr02/e04, s03/inv13: no file under '
      'lib/src/themes/remote/ imports dart:io, in either quote style', () {
    final files = Directory('lib/src/themes/remote')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();

    expect(files, isNotEmpty);
    for (final file in files) {
      expect(
        _uris(file.readAsStringSync()),
        isNot(contains('dart:io')),
        reason: file.path,
      );
    }
  });
}
