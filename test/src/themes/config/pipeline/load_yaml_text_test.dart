import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/config/pipeline/load_yaml_text.dart';
import 'package:yaml/yaml.dart' show YamlMap, loadYamlNode;

YamlTextFailure _gateFailure(String text) {
  try {
    checkYamlGate(text);
  } on YamlTextFailure catch (error) {
    return error;
  }
  fail('checkYamlGate passed');
}

/// [n] keys in one block mapping, one a line.
String _blockKeys(int n) => [for (var k = 0; k < n; k++) 'k$k: 1'].join('\n');

/// [n] keys in one flow mapping on one line.
String _flowKeys(int n) =>
    '{${[for (var k = 0; k < n; k++) 'k$k: 1'].join(', ')}}';

/// [maps] root keys, each holding a block mapping of [n] keys, whose key
/// [key] writes; [maps] * ([n] + 1) keys in all.
String _nestedKeys(int maps, int n, [Object Function(int)? key]) => [
  for (var m = 0; m < maps; m++) ...[
    'm$m:',
    for (var k = 0; k < n; k++) '  ${key?.call(m * n + k + 1) ?? 'k$k'}: 1',
  ],
].join('\n');

/// [n] nested block mappings, one key a line, each one column deeper.
String _blockMappings(int n) =>
    [for (var d = 0; d < n; d++) '${' ' * d}k$d:${d == n - 1 ? ' x' : ''}']
        .join('\n');

/// [n] nested block sequences, one `-` a line, each two columns deeper.
String _blockSequences(int n) =>
    [for (var d = 0; d < n; d++) '${'  ' * d}-${d == n - 1 ? ' x' : ''}']
        .join('\n');

/// [n] - 1 nested block mappings, the last holding an indentless
/// sequence at its own column.
String _indentless(int n) => [
  for (var d = 0; d < n - 1; d++) '${' ' * d}k$d:',
  '${' ' * (n - 2)}- x',
].join('\n');

/// 32 nested block mappings, the last holding [n] - 32 nested flow
/// sequences.
String _blockThenFlow(int n) => [
  for (var d = 0; d < 31; d++) '${' ' * d}k$d:',
  '${' ' * 31}k31: ${'[' * (n - 32)}x${']' * (n - 32)}',
].join('\n');

/// [n] nested flow mappings, each opened on its own line behind a
/// byte-order mark except the first (design G4; security review round 2
/// C1): package:yaml allows a byte-order mark to start any line, a
/// construct the depth and anchor rules do not refuse.
String _bomChain(int n) => '{${'\n\u{FEFF}{' * (n - 1)}a${'}' * n}';

void main() {
  group('sec f1, us02/fr03/e09: loadYamlText turns every package:yaml '
      'failure into one escaped YamlTextFailure', () {
    test('a YamlException carries the 1-based line and column of its '
        'span', () {
      YamlTextFailure failure() {
        try {
          loadYamlText('x: [1, 2');
        } on YamlTextFailure catch (error) {
          return error;
        }
        fail('loadYamlText did not throw');
      }

      final error = failure();

      expect(error.message, contains('expected'));
      expect(error.at, (line: 1, column: 9));
    });
  });

  group('fo01 us01/fr01/e07, rz1, g1: the size cap', () {
    test('a text of exactly 1,048,576 code units passes', () {
      expect(
        () => checkYamlGate('a: ${'x' * (yamlTextMaxUnits - 3)}'),
        returnsNormally,
      );
    });

    test('one more code unit refuses at that unit', () {
      final failure = _gateFailure('a: ${'x' * (yamlTextMaxUnits - 2)}');

      expect(failure.message, yamlSizeMessage);
      expect(failure.at, (line: 1, column: yamlTextMaxUnits + 1));
    });

    test(r'review focus: the position counts \r\n as one break and a lone '
        r'\r as one', () {
      expect(_gateFailure('ab\r\n' * (yamlTextMaxUnits ~/ 4 + 1)).at, (
        line: yamlTextMaxUnits ~/ 4 + 1,
        column: 1,
      ));
      expect(_gateFailure('a\r' * (yamlTextMaxUnits ~/ 2 + 1)).at, (
        line: yamlTextMaxUnits ~/ 2 + 1,
        column: 1,
      ));
    });
  });

  group('fo01 us01/fr01/e07, rz1, g2: nesting', () {
    for (final (label, build, at) in [
      (
        'flow sequences',
        (int n) => '${'[' * n}${']' * n}',
        (line: 1, column: 65),
      ),
      (
        'flow mappings',
        (int n) => '${'{a: ' * n}1${'}' * n}',
        (line: 1, column: 257),
      ),
      ('block mappings', _blockMappings, (line: 65, column: 65)),
      ('block sequences', _blockSequences, (line: 65, column: 129)),
      (
        'compact block sequences',
        (int n) => '${'- ' * n}x',
        (line: 1, column: 129),
      ),
      ('an indentless sequence', _indentless, (line: 65, column: 64)),
      ('block mappings, then flow', _blockThenFlow, (line: 32, column: 69)),
    ]) {
      test('64 nested $label pass and 65 refuse at the character that '
          'opens the 65th', () {
        expect(() => loadYamlText(build(64)), returnsNormally);

        final failure = _gateFailure(build(65));

        expect(failure.message, yamlDepthMessage);
        expect(failure.at, at);
      });
    }

    test('r16 (t25): 2,500 to 20,000 nested flow sequences refuse at '
        'column 65', () {
      for (final n in [2500, 5000, 10000, 20000]) {
        expect(_gateFailure('[' * n).at, (line: 1, column: 65), reason: '$n');
      }
    });
  });

  group('fo01 us01/fr01/e07, rz1, rz6 (1), g3, g7: anchors, aliases, and '
      'tags', () {
    for (final (text, at) in [
      ('a: &x 1', (line: 1, column: 4)),
      ('a: *x', (line: 1, column: 4)),
      ('a: !x 1', (line: 1, column: 4)),
      ('a: !!str 1', (line: 1, column: 4)),
      ('a: !<tag:x> 1', (line: 1, column: 4)),
      ('a: ! 1', (line: 1, column: 4)),
      ('- &x 1', (line: 1, column: 3)),
      ('[&x 1]', (line: 1, column: 2)),
      ('{&x a: 1}', (line: 1, column: 2)),
      ('[a,*b]', (line: 1, column: 4)),
      ('{"a":*b}', (line: 1, column: 6)),
      ('&x a: 1', (line: 1, column: 1)),
      ('--- !x\na: 1', (line: 1, column: 5)),
      ('a: 1 # c\nb: &y 1', (line: 2, column: 4)),
      ('x: !<%ZZ> y', (line: 1, column: 4)),
      ('x: !<%FF> y', (line: 1, column: 4)),
      ('x: !!foo%1B%5D0%3Bpwned%07 y', (line: 1, column: 4)),
    ]) {
      test('"${text.replaceAll('\n', r'\n')}" is refused at its first '
          'property, never reaching package:yaml', () {
        final failure = _gateFailure(text);

        expect(failure.message, yamlPropertyMessage);
        expect(failure.at, at);
      });
    }

    for (final text in [
      'name: "Rock & Roll"',
      'note: 5 * 3',
      'url: "a?b=1&c=2"',
      'a: b&c',
      'a: 1 # see &x and *y and !z',
      '# &x *y !z',
      'a: "x" # &y',
    ]) {
      test('review focus: "$text" holds no anchor, alias, or tag and '
          'loads', () {
        expect(() => loadYamlText(text), returnsNormally);
      });
    }

    test('g4: a "!" after a blank inside quotes is refused, an over-refusal '
        'the gate allows', () {
      final failure = _gateFailure('name: "say !hi"');

      expect(failure.message, yamlPropertyMessage);
      expect(failure.at, (line: 1, column: 12));
    });

    for (final (text, at) in [
      ('name: "*.yaml"', (line: 1, column: 8)),
      ('note: *word*', (line: 1, column: 7)),
      ('x: &word', (line: 1, column: 4)),
    ]) {
      test('g4: "$text" refuses a "*" or "&" with no trailing blank, an '
          'over-refusal the gate allows (main: no gate change)', () {
        final failure = _gateFailure(text);

        expect(failure.message, yamlPropertyMessage);
        expect(failure.at, at);
      });
    }
  });

  group('fo01 us01/fr01/e07, rz7, g9: mapping keys that are collections', () {
    for (final (text, at) in [
      ('[a]: x', (line: 1, column: 1)),
      ('{a: 1}: x', (line: 1, column: 1)),
      ('k:\n  [a, b]: x', (line: 2, column: 3)),
      ('- {a: 1}: x', (line: 1, column: 3)),
      ('{[a]: x}', (line: 1, column: 2)),
      ('[{a: 1}: x]', (line: 1, column: 2)),
      ('{[a] : x}', (line: 1, column: 2)),
      ('{"k": {[a]:x}}', (line: 1, column: 8)),
      ('[[a,\n  b]\n  : x]', (line: 1, column: 2)),
      ('?\n  a: 1\n: x', (line: 1, column: 1)),
      ('? [a]\n: x', (line: 1, column: 1)),
      ('- ? a\n  : x', (line: 1, column: 3)),
      ('{? a : x}', (line: 1, column: 2)),
      ('[? a]', (line: 1, column: 2)),
      ('{{a}}', (line: 1, column: 2)),
      ('{[a]}', (line: 1, column: 2)),
      ('{a, [b]}', (line: 1, column: 5)),
      ('x: {{a}}', (line: 1, column: 5)),
      ('{a,\n [b]}', (line: 2, column: 2)),
    ]) {
      test('"${text.replaceAll('\n', r'\n')}" is refused at the first '
          'character of its key, never reaching package:yaml', () {
        final failure = _gateFailure(text);

        expect(failure.message, yamlKeyMessage);
        expect(failure.at, at);
      });
    }

    for (final text in [
      '"[a]": x',
      "'{a: 1}': x",
      'a: [b, c]',
      'a: {b: c}',
      '{"a": [1], "b": {"c": 2}}',
      '- [a, b]\n- {c: d}',
      'a: what?',
      'a: x ? y',
      '{a: [b]}',
      '{a: {b: c}}',
      '[{a: b}]',
      '[[a]]',
    ]) {
      test('"${text.replaceAll('\n', r'\n')}" uses no collection as a key '
          'and loads', () {
        expect(() => loadYamlText(text), returnsNormally);
      });
    }

    test('rz7 (rca-s5): one key chain 16 mappings deep, 92 bytes, which '
        'package:yaml 3.1.4 hashes in time exponential in its depth, is '
        'refused fast at the outermost key, the first collection key the '
        'linear scan reaches (c1 fix: no longer at the innermost "}:")', () {
      var key = '{a0: 1}';
      for (var d = 1; d < 16; d++) {
        key = '{$key: $d}';
      }
      final text = '$key: v\n';
      expect(text.length, 92);

      // A gate that let it through would hang here, as P1's s5 did.
      final watch = Stopwatch()..start();
      expect(
        () => loadYamlText(text),
        throwsA(
          isA<YamlTextFailure>()
              .having((f) => f.message, 'message', yamlKeyMessage)
              .having((f) => f.at, 'at', (line: 1, column: 2)),
        ),
      );
      expect(watch.elapsedMilliseconds, lessThan(1000));
    });

    test('c1 (critical): a flow mapping whose entry holds no ":", `{a}`, '
        'nests a collection key just as `{a: b}` does for package:yaml '
        '(parser.dart FLOW_MAPPING_EMPTY_VALUE); a chain of "{" 16 then 64 '
        'deep, "a", then as many "}" is refused fast at the second "{", '
        'never at a depth proportional to the chain', () {
      for (final n in [16, 64]) {
        final text = '${'{' * n}a${'}' * n}';

        final watch = Stopwatch()..start();
        final failure = _gateFailure(text);
        expect(watch.elapsedMilliseconds, lessThan(1000), reason: '$n');

        expect(failure.message, yamlKeyMessage, reason: '$n');
        expect(failure.at, (line: 1, column: 2), reason: '$n');
      }
    });
  });

  group('fo01 us01/fr01/e07, g4: a byte-order mark past the first '
      'character', () {
    test(r'"{\n﻿{a}}" is refused at the byte-order mark on its '
        'second line, which package:yaml would otherwise let start a '
        'mapping key just as a bare "{" does', () {
      final failure = _gateFailure('{\n\u{FEFF}{a}}');

      expect(failure.message, yamlBomMessage);
      expect(failure.at, (line: 2, column: 1));
    });

    test('review focus: a leading byte-order mark still loads', () {
      expect(
        () => checkYamlGate('\u{FEFF}a: 1\r\nb:\r\n  c: "{x}"\r\n'),
        returnsNormally,
      );
    });

    test('c1 round 2 (critical): package:yaml allows a byte-order mark '
        "to start any line, not just the text's own first character; a "
        'chain of mappings each opened behind one on a later line is '
        'refused fast at the first such mark, never at a depth '
        'proportional to the chain', () {
      for (final n in [16, 64]) {
        final text = _bomChain(n);

        final watch = Stopwatch()..start();
        final failure = _gateFailure(text);
        expect(watch.elapsedMilliseconds, lessThan(1000), reason: '$n');

        expect(failure.message, yamlBomMessage, reason: '$n');
        expect(failure.at, (line: 2, column: 1), reason: '$n');
      }
    });
  });

  group('fo01 us01/fr01/e07, g4: texts a theme file uses load', () {
    test('review focus: a block scalar, a folded scalar, a two-line quoted '
        'string, and a two-line plain scalar, then 200 quoted aliases', () {
      final text = [
        r'$schema: stratum-theme/v1.0.0',
        'name: brand',
        'extensions:',
        '  about: |',
        '    A theme [with] {brackets} and "quotes',
        '    over] two lines.',
        '  folded: >-',
        '    more [text',
        '  quoted: "a [b',
        '    c] d"',
        '  plain: one [two',
        '    three',
        'color:',
        '  light:',
        for (var i = 0; i < 200; i++) '    c$i: "{palette.brand.500}"',
      ].join('\n');

      expect(() => checkYamlGate(text), returnsNormally);
      expect(() => loadYamlNode(text), returnsNormally);
    });

    test(r'review focus: a leading BOM passes the gate, and \r\n line '
        'ends load', () {
      expect(
        () => checkYamlGate('\u{FEFF}a: 1\r\nb:\r\n  c: "{x}"\r\n'),
        returnsNormally,
      );
      expect(
        () => loadYamlText('a: 1\r\nb:\r\n  c: "{x}"\r\n'),
        returnsNormally,
      );
      expect(_gateFailure('a: 1\r\nb: 2\rc: &x 3').at, (line: 3, column: 4));
    });

    test('a directive and --- before the document load', () {
      expect(
        () => loadYamlText('%YAML 1.2\n---\na: [1, {b: "c"}]\n'),
        returnsNormally,
      );
    });
  });

  test('f1 (deferred minor 2), r9/fr03/e02: an unknown directive never prints '
      "package:yaml's raw source line, control character included", () {
    final prints = <String>[];

    runZoned(
      () => loadYamlText('%X \x1b]0;x\x07\n---\na: 1\n'),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => prints.add(line),
      ),
    );

    expect(prints, isEmpty);
  });

  group('fo01 us01/fr01/e07, rz10, g10: the key caps', () {
    test('256 keys in one block mapping pass, and the 257th is refused at '
        'its first character', () {
      expect(() => checkYamlGate(_blockKeys(256)), returnsNormally);
      final failure = _gateFailure(_blockKeys(257));

      expect(failure.message, yamlKeyCountMessage);
      expect(failure.at, (line: 257, column: 1));
    });

    test('256 keys in one flow mapping pass, and the 257th is refused at '
        'the "," before it', () {
      expect(() => checkYamlGate(_flowKeys(256)), returnsNormally);
      final text = _flowKeys(257);
      final failure = _gateFailure(text);

      expect(failure.message, yamlKeyCountMessage);
      expect(failure.at, (line: 1, column: text.indexOf(', k256') + 1));
    });

    test('2,048 keys in all pass, and the 2,049th is refused at its first '
        'character', () {
      expect(() => checkYamlGate(_nestedKeys(8, 255)), returnsNormally);
      final failure = _gateFailure('${_nestedKeys(8, 255)}\nlast: 1');

      expect(failure.message, yamlKeyCountMessage);
      expect(failure.at, (line: 2049, column: 1));
    });

    test('each key: value pair in a flow sequence counts as one key', () {
      final text = '[${[for (var k = 0; k < 2049; k++) 'k$k: 1'].join(', ')}]';
      final failure = _gateFailure(text);

      expect(failure.message, yamlKeyCountMessage);
      expect(failure.at, (line: 1, column: text.indexOf(': 1]') + 1));
    });

    test('after the lock, every ":", ",", and "{" counts into one bucket '
        'that starts at the fullest open mapping', () {
      // ": x" has no key on its line, which the model does not read, so
      // the pass locks there with 250 keys counted in the open mapping.
      String locked(int more) => [
        _blockKeys(250),
        ': x',
        for (var k = 0; k < more; k++) 'j$k: 1',
      ].join('\n');

      expect(() => checkYamlGate(locked(5)), returnsNormally);
      final failure = _gateFailure(locked(6));
      expect(failure.message, '$yamlLockedKeyCountMessage 251, column 1');
      expect(failure.at, (line: 257, column: 3));
    });

    test('rzf6 (t8b 2): a key cap under the locked count names the line '
        'and column where that count began, not the key, and no count', () {
      // "  : x" has no key on its line, so the pass locks at its ":", line
      // 3, column 3; the commas after it then count as keys.
      final commas = List.filled(300, 'x').join(', ');
      final failure = _gateFailure('a:\n  b: 1\n  : x\n  $commas\n');

      expect(failure.message, '$yamlLockedKeyCountMessage 3, column 3');
      expect(failure.message, isNot(contains('256')));
      expect(failure.message, isNot(contains('2,048')));
      expect(failure.at, (line: 4, column: 766));
    });

    test('rzf6: a refusal before the lock, and the walk, keep the key-cap '
        'message', () {
      expect(_gateFailure(_blockKeys(257)).message, yamlKeyCountMessage);
      expect(
        () => checkYamlTree(loadYamlNode(_blockKeys(257))),
        throwsA(
          isA<YamlTextFailure>().having(
            (f) => f.message,
            'message',
            yamlKeyCountMessage,
          ),
        ),
      );
    });

    test('rz10 (m4-t8 security C2): 2,040 integer keys that share one VM '
        'hash, 255 to a mapping under 8 root keys, pass the gate and load', () {
      int colliding(int k) => k * 4294967297;

      expect({
        for (var k = 1; k <= 2040; k++) colliding(k).hashCode,
      }, hasLength(1));
      expect(loadYamlText(_nestedKeys(8, 255, colliding)), isA<YamlMap>());
    }, testOn: 'vm');
  });

  group('fo01 us01/fr01/e07, rz5, g5: the walk after package:yaml', () {
    test('a node reached twice, which only an alias makes, is refused', () {
      expect(
        () => checkYamlTree(loadYamlNode('a: &x [1]\nb: *x')),
        throwsA(
          isA<YamlTextFailure>().having(
            (f) => f.message,
            'message',
            yamlPropertyMessage,
          ),
        ),
      );
    });

    test('64 nested collections pass, and 65 refuse at the 65th', () {
      expect(
        () => checkYamlTree(loadYamlNode('${'[' * 64}${']' * 64}')),
        returnsNormally,
      );
      expect(
        () => checkYamlTree(loadYamlNode('${'[' * 65}${']' * 65}')),
        throwsA(
          isA<YamlTextFailure>()
              .having((f) => f.message, 'message', yamlDepthMessage)
              .having((f) => f.at, 'at', (line: 1, column: 65)),
        ),
      );
    });

    test('g10, rz10: a mapping of 256 keys passes, the 257th key is '
        'refused, and so is a tree of 2,049 keys', () {
      expect(
        () => checkYamlTree(loadYamlNode(_blockKeys(256))),
        returnsNormally,
      );
      expect(
        () => checkYamlTree(loadYamlNode(_blockKeys(257))),
        throwsA(
          isA<YamlTextFailure>()
              .having((f) => f.message, 'message', yamlKeyCountMessage)
              .having((f) => f.at, 'at', (line: 257, column: 1)),
        ),
      );
      expect(
        () => checkYamlTree(loadYamlNode('${_nestedKeys(8, 255)}\nlast: 1')),
        throwsA(
          isA<YamlTextFailure>().having(
            (f) => f.message,
            'message',
            yamlKeyCountMessage,
          ),
        ),
      );
    });

    test('m4-t9 review: two null siblings and two "1" siblings, equal but '
        'distinct scalar nodes, do not read as a node reached twice', () {
      expect(
        () => checkYamlTree(loadYamlNode('a: null\nb: null\nc: 1\nd: 1')),
        returnsNormally,
      );
    });

    test('g9, rz7: a mapping whose key node is a collection is refused at '
        'the key', () {
      for (final (text, at) in [
        ('? [1]\n: v', (line: 1, column: 3)),
        ('{[1]: v}', (line: 1, column: 2)),
      ]) {
        expect(
          () => checkYamlTree(loadYamlNode(text)),
          throwsA(
            isA<YamlTextFailure>()
                .having((f) => f.message, 'message', yamlKeyMessage)
                .having((f) => f.at, 'at', at),
          ),
        );
      }
    });
  });
}
