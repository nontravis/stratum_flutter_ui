import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/config/pipeline/load_yaml_text.dart';
import 'package:yaml/yaml.dart' show loadYamlNode;

YamlTextFailure _gateFailure(String text) {
  try {
    checkYamlGate(text);
  } on YamlTextFailure catch (error) {
    return error;
  }
  fail('checkYamlGate passed');
}

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
    ]) {
      test('"${text.replaceAll('\n', r'\n')}" uses no collection as a key '
          'and loads', () {
        expect(() => loadYamlText(text), returnsNormally);
      });
    }

    test('rz7 (rca-s5): one key chain 16 mappings deep, 92 bytes, which '
        'package:yaml 3.1.4 hashes in time exponential in its depth, is '
        'refused fast at its innermost key', () {
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
              .having((f) => f.at, 'at', (line: 1, column: 16)),
        ),
      );
      expect(watch.elapsedMilliseconds, lessThan(1000));
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
}
