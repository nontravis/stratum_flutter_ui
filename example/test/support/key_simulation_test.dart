import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/key_simulation.dart';

/// Matches a banned identifier as a whole token anywhere in a line's raw
/// text — comment or string included.
///
/// A prior version tried to tell code from comments and strings first and
/// only match inside code; that heuristic lexer missed a split-line call,
/// missed a tear-off, and (once comments were masked) mis-read a
/// double-quoted string holding an apostrophe before a `//`-shaped
/// substring as a comment, hiding a real call on the same line. Matching
/// raw text with no lexer removes every one of those escapes at once, at
/// the cost of also flagging a comment or string that merely names the
/// API; that trade favors a loud false positive over a silent miss.
final _bannedTokenPattern = RegExp(
  r'\b(sendKeyEvent|sendKeyDownEvent|sendKeyUpEvent|sendKeyRepeatEvent|'
  r'simulateKey\w*|enterText)\b',
);

/// The one file allowed to call the raw APIs `_bannedTokenPattern` names.
const _exemptPath = 'integration_test/support/key_simulation.dart';

/// The 1-based line and matched token for every banned identifier
/// `_bannedTokenPattern` finds in [source].
///
/// A device file must route the call through `support/key_simulation.dart`
/// instead; a comment should refer to "the key helper", never the API name.
List<MapEntry<int, String>> _bannedCallLines(String source) {
  final lines = source.split('\n');
  final hits = <MapEntry<int, String>>[];
  for (var i = 0; i < lines.length; i++) {
    final match = _bannedTokenPattern.firstMatch(lines[i]);
    if (match != null) {
      hits.add(MapEntry(i + 1, match.group(0)!));
    }
  }
  return hits;
}

void main() {
  group('physicalKeyFor', () {
    test('maps every key the device files send', () {
      expect(physicalKeyFor(LogicalKeyboardKey.tab), PhysicalKeyboardKey.tab);
      expect(
        physicalKeyFor(LogicalKeyboardKey.escape),
        PhysicalKeyboardKey.escape,
      );
      expect(physicalKeyFor(LogicalKeyboardKey.f8), PhysicalKeyboardKey.f8);
      expect(
        physicalKeyFor(LogicalKeyboardKey.altLeft),
        PhysicalKeyboardKey.altLeft,
      );
      expect(physicalKeyFor(LogicalKeyboardKey.keyT), PhysicalKeyboardKey.keyT);
    });

    test('throws, naming the key, when it has no physical key mapped', () {
      expect(
        () => physicalKeyFor(LogicalKeyboardKey.enter),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('0x${LogicalKeyboardKey.enter.keyId.toRadixString(16)}'),
          ),
        ),
      );
    });

    const handledKeys = [
      LogicalKeyboardKey.tab,
      LogicalKeyboardKey.escape,
      LogicalKeyboardKey.f8,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.keyT,
    ];

    test('every mapped physical key appears in every platform scan-code '
        'table `event_simulation.dart`\'s `_getScanCode` reads', () {
      final scanCodeTables = {
        'android': kAndroidToPhysicalKey,
        'fuchsia': kFuchsiaToPhysicalKey,
        'macos': kMacOsToPhysicalKey,
        'ios': kIosToPhysicalKey,
        'linux': kLinuxToPhysicalKey,
        'windows': kWindowsToPhysicalKey,
      };
      for (final logicalKey in handledKeys) {
        final physicalKey = physicalKeyFor(logicalKey);
        for (final table in scanCodeTables.entries) {
          expect(
            table.value.values,
            contains(physicalKey),
            reason: '${table.key} has no scan code for $physicalKey',
          );
        }
      }
    });

    test('every mapped logical key appears in every platform key-code table '
        "`event_simulation.dart`'s `_getKeyCode` reads (macOS, iOS, and web "
        'return early and read no table)', () {
      final keyCodeTables = {
        'android': kAndroidToLogicalKey,
        'fuchsia': kFuchsiaToLogicalKey,
        'linux (GLFW)': kGlfwToLogicalKey,
        'windows': kWindowsToLogicalKey,
      };
      for (final logicalKey in handledKeys) {
        for (final table in keyCodeTables.entries) {
          expect(
            table.value.values,
            contains(logicalKey),
            reason: '${table.key} has no key code for $logicalKey',
          );
        }
      }
    });
  });

  group('_bannedCallLines', () {
    test('flags a call split across lines, identifier apart from `(`', () {
      const source =
          'tester\n    .sendKeyEvent\n    (LogicalKeyboardKey.tab);\n';
      expect(_bannedCallLines(source), isNotEmpty);
    });

    test('flags a tear-off, with no `(` anywhere on its line', () {
      const source =
          'final send = tester.sendKeyEvent;\n'
          'await send(LogicalKeyboardKey.tab);\n';
      expect(_bannedCallLines(source), isNotEmpty);
    });

    test('flags a cascade call', () {
      const source = 'tester..sendKeyEvent(LogicalKeyboardKey.tab);\n';
      expect(_bannedCallLines(source), isNotEmpty);
    });

    test('flags a comment that names the API, not just a real call', () {
      const source =
          "// call enterText('hi') directly if you must bypass this.\n";
      expect(_bannedCallLines(source), isNotEmpty);
    });

    test('flags a real call beside an apostrophe-in-string URL (finding 4: '
        'the masking lexer this replaced mis-read this line as a comment)', () {
      const source =
          'final help = "it\'s at https://x"; '
          'tester.sendKeyEvent(LogicalKeyboardKey.tab);\n';
      expect(_bannedCallLines(source), isNotEmpty);
    });
  });

  test('every device file routes key and text simulation through '
      'support/key_simulation.dart', () {
    final root = Directory('integration_test');
    expect(
      root.existsSync(),
      isTrue,
      reason: 'run this test from the example/ package root',
    );
    final violations = <String>[];
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path == _exemptPath) continue;
      for (final hit in _bannedCallLines(entity.readAsStringSync())) {
        violations.add(
          '${entity.path}:${hit.key} names ${hit.value}: route the call '
          'through support/key_simulation.dart; in a comment, say "the '
          'key helper" instead of the API name.',
        );
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
