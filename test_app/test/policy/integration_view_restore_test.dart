import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// One kind of view or platform override and the call that undoes it.
///
/// [setter] finds a set; the closures read that match to name the override,
/// build the one restore that undoes it, and print the fix.
class _Override {
  const _Override({
    required this.setter,
    required this.nameFor,
    required this.restoreFor,
    required this.fixFor,
  });

  final RegExp setter;
  final String Function(Match set) nameFor;
  final RegExp Function(Match set) restoreFor;
  final String Function(Match set) fixFor;
}

String _capitalize(String word) =>
    '${word[0].toUpperCase()}${word.substring(1)}';

// The round's entry runs several files in one app, so an override that a
// file leaves behind changes the layout of every file that runs after it.
final _overrides = <_Override>[
  _Override(
    setter: RegExp(r'setSurfaceSize\(\s*(?!null\b)[^)\s]'),
    nameFor: (_) => 'binding.setSurfaceSize',
    restoreFor: (_) =>
        RegExp(r'addTearDown\([^;]*setSurfaceSize\(\s*null\s*,?\s*\)'),
    fixFor: (_) => 'addTearDown(() => binding.setSurfaceSize(null))',
  ),
  _Override(
    setter: RegExp(
      r'\bview\.(physicalSize|devicePixelRatio|padding|viewPadding'
      r'|viewInsets|systemGestureInsets|displayFeatures|gestureSettings)'
      r'\s*=(?!=)',
    ),
    nameFor: (set) => 'tester.view.${set[1]}',
    restoreFor: (set) => RegExp(
      'addTearDown\\([^;]*\\bview\\.(reset|reset${_capitalize(set[1]!)})\\b',
    ),
    fixFor: (_) => 'addTearDown(tester.view.reset)',
  ),
  _Override(
    setter: RegExp(r'\bplatformDispatcher\.(\w+)TestValue\s*=(?!=)'),
    nameFor: (set) => 'platformDispatcher.${set[1]}TestValue',
    restoreFor: (set) => RegExp(
      'addTearDown\\([^;]*\\bplatformDispatcher\\.'
      '(clearAllTestValues|clear${_capitalize(set[1]!)}TestValue)\\b',
    ),
    fixFor: (set) =>
        'addTearDown(tester.platformDispatcher.clear${_capitalize(set[1]!)}'
        'TestValue)',
  ),
];

// Opens a body that owns its own `addTearDown` calls.
final _bodyStart = RegExp(r'(?<![\w.])(testWidgets|test|setUp|setUpAll)\(');

// A `//` at a line start or after whitespace; keeps `https://` in strings.
final _lineComment = RegExp(r'(^|\s)//.*$', multiLine: true);

/// Returns one `path:line` message per override in [source] with no restore.
///
/// A set counts as restored only by the `addTearDown` call that undoes that
/// same override in the same `testWidgets`, `test`, or `setUp` body. Comments
/// count as neither a set nor a restore.
List<String> findUnrestoredOverrides(String path, String source) {
  final code = source.replaceAllMapped(_lineComment, (m) => m[1]!);
  final starts = [
    0,
    for (final start in _bodyStart.allMatches(code)) start.start,
  ];
  final findings = <String>[];
  for (var i = 0; i < starts.length; i++) {
    final from = starts[i];
    final to = i + 1 < starts.length ? starts[i + 1] : code.length;
    final body = code.substring(from, to);
    for (final override in _overrides) {
      for (final set in override.setter.allMatches(body)) {
        if (override.restoreFor(set).hasMatch(body)) continue;
        final line = '\n'.allMatches(code.substring(0, from + set.start));
        findings.add(
          '$path:${line.length + 1}: ${override.nameFor(set)} is set and '
          'never restored in its test body; add `${override.fixFor(set)}`',
        );
      }
    }
  }
  return findings;
}

void main() {
  group('findUnrestoredOverrides', () {
    test('flags a surface size set with no reset', () {
      final findings = findUnrestoredOverrides('a_test.dart', '''
void main() {
  testWidgets('x', (tester) async {
    await binding.setSurfaceSize(const Size(400, 800));
  });
}
''');
      expect(findings, hasLength(1));
      expect(findings.single, startsWith('a_test.dart:3:'));
    });

    test('accepts a surface size set with the addTearDown reset', () {
      final findings = findUnrestoredOverrides('a_test.dart', '''
    await binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => binding.setSurfaceSize(null));
''');
      expect(findings, isEmpty);
    });

    test('accepts a reset that dart format wraps over several lines', () {
      final findings = findUnrestoredOverrides('a_test.dart', '''
    await binding.setSurfaceSize(const Size(400, 800));
    addTearDown(
      () => binding.setSurfaceSize(
        null,
      ),
    );
''');
      expect(findings, isEmpty);
    });

    test('flags a set that dart format wraps, at the line of the call', () {
      final findings = findUnrestoredOverrides('a_test.dart', '''
void main() {
  testWidgets('x', (tester) async {
    await binding.setSurfaceSize(
      const Size(400, 800),
    );
  });
}
''');
      expect(findings, hasLength(1));
      expect(findings.single, startsWith('a_test.dart:3:'));
    });

    test('does not count a bare setSurfaceSize(null) as a set', () {
      expect(
        findUnrestoredOverrides('a_test.dart', 'await b.setSurfaceSize(null);'),
        isEmpty,
      );
    });

    test('flags a view override with no view.reset', () {
      final findings = findUnrestoredOverrides('a_test.dart', '''
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
''');
      expect(findings, hasLength(2));
      expect(findings.first, startsWith('a_test.dart:1:'));
      expect(findings.last, startsWith('a_test.dart:2:'));
    });

    test('accepts a view override with addTearDown(tester.view.reset)', () {
      final findings = findUnrestoredOverrides('a_test.dart', '''
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
''');
      expect(findings, isEmpty);
    });

    test('accepts a view override with its own reset<Prop> only', () {
      final findings = findUnrestoredOverrides('a_test.dart', '''
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.resetPhysicalSize);
''');
      expect(findings, isEmpty);
    });

    test('a reset of a different view property does not restore', () {
      final findings = findUnrestoredOverrides('a_test.dart', '''
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
''');
      expect(findings, hasLength(1));
      expect(findings.single, contains('tester.view.devicePixelRatio'));
    });

    test('does not count a view read or comparison as a set', () {
      final findings = findUnrestoredOverrides('a_test.dart', '''
    final before = tester.view.viewPadding;
    final open = tester.view.viewInsets.bottom == 0;
''');
      expect(findings, isEmpty);
    });

    test('flags a platform dispatcher test value with no clear', () {
      final findings = findUnrestoredOverrides('a_test.dart', '''
    tester.platformDispatcher.textScaleFactorTestValue = 2;
''');
      expect(findings, hasLength(1));
    });

    test(
      'accepts a platform dispatcher test value with clearAllTestValues',
      () {
        final findings = findUnrestoredOverrides('a_test.dart', '''
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
''');
        expect(findings, isEmpty);
      },
    );

    test('accepts a platform dispatcher test value with its own clear', () {
      final findings = findUnrestoredOverrides('a_test.dart', '''
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
''');
      expect(findings, isEmpty);
    });

    test('a clear of a different test value does not restore', () {
      final findings = findUnrestoredOverrides('a_test.dart', '''
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
''');
      expect(findings, hasLength(1));
      expect(findings.single, contains('textScaleFactorTestValue'));
    });

    test('a surface reset does not restore a view override', () {
      final findings = findUnrestoredOverrides('a_test.dart', '''
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(() => binding.setSurfaceSize(null));
''');
      expect(findings, hasLength(1));
    });

    test('flags a set in test A whose restore sits only in test B', () {
      final findings = findUnrestoredOverrides('a_test.dart', '''
void main() {
  testWidgets('a', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
  });

  testWidgets('b', (tester) async {
    addTearDown(tester.view.reset);
  });
}
''');
      expect(findings, hasLength(1));
      expect(findings.single, startsWith('a_test.dart:3:'));
    });

    test('accepts a set and its restore paired in each test body', () {
      final findings = findUnrestoredOverrides('a_test.dart', '''
void main() {
  testWidgets('a', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
  });

  testWidgets('b', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  });
}
''');
      expect(findings, isEmpty);
    });

    test('ignores a set or a reset that sits in a whole-line comment', () {
      final findings = findUnrestoredOverrides('a_test.dart', '''
    // addTearDown(() => binding.setSurfaceSize(null));
    await binding.setSurfaceSize(const Size(400, 800));
''');
      expect(findings, hasLength(1));
      expect(findings.single, startsWith('a_test.dart:2:'));
    });

    test('a restore in a trailing comment does not restore', () {
      final findings = findUnrestoredOverrides('a_test.dart', '''
    tester.view.physicalSize = const Size(1400, 900);
    pumpIt(); // addTearDown(tester.view.reset);
''');
      expect(findings, hasLength(1));
      expect(findings.single, startsWith('a_test.dart:1:'));
    });

    test('a set in a trailing comment is not a set', () {
      final findings = findUnrestoredOverrides('a_test.dart', '''
    pumpIt(); // await binding.setSurfaceSize(const Size(400, 800));
''');
      expect(findings, isEmpty);
    });

    test('keeps code that follows a url string on the same line', () {
      final findings = findUnrestoredOverrides('a_test.dart', '''
    final u = 'https://x.test'; tester.view.physicalSize = const Size(1, 1);
''');
      expect(findings, hasLength(1));
    });
  });

  group('integration_test files', () {
    test('restore every surface and view override they set', () {
      final files =
          Directory('integration_test')
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      expect(files, isNotEmpty, reason: 'integration_test/ holds no files');

      final findings = [
        for (final file in files)
          ...findUnrestoredOverrides(file.path, file.readAsStringSync()),
      ];

      expect(findings, isEmpty, reason: findings.join('\n'));
    });
  });
}
