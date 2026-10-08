// The oracle reads package:yaml's own parser, which the package exports
// no public name for.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/config/pipeline/load_yaml_text.dart';
import 'package:yaml/src/event.dart';
import 'package:yaml/src/parser.dart';
import 'package:yaml/yaml.dart' show ScalarStyle, YamlException;

/// What package:yaml's own parser reads in [text]: whether any event is
/// an alias or carries an anchor or a tag, whether a collection starts in
/// a mapping's key position (design G9), the deepest nesting it opens,
/// stopping past 200, and the keys it reads, in all and in the fullest
/// mapping (design G10); null when it refuses the text. An error
/// other than [YamlException], such as the `ArgumentError` a malformed
/// tag throws, counts as a property read. package:yaml gives every quoted
/// or block scalar the non-specific tag `!` itself (`parser.dart:314`), so
/// such a tag counts only when the text writes it, where the event's span
/// then starts.
({bool properties, bool collectionKey, int depth, int keys, int mostKeys})?
_oracle(String text) {
  final parser = Parser(text);
  // Per open collection: whether it is a mapping, and how many nodes it
  // has started, so an even count in a mapping is a key position.
  final mappings = <bool>[];
  final nodes = <int>[];
  final mappingKeys = <int>[];
  var deepest = 0;
  var properties = false;
  var collectionKey = false;
  var keys = 0;
  var mostKeys = 0;
  try {
    while (!parser.isDone && deepest <= 200) {
      final event = parser.parse();
      final (anchor, tag) = switch (event) {
        ScalarEvent(:final anchor, :final tag) => (anchor, tag),
        SequenceStartEvent(:final anchor, :final tag) => (anchor, tag),
        MappingStartEvent(:final anchor, :final tag) => (anchor, tag),
        _ => (null, null),
      };
      final implicitTag =
          event is ScalarEvent &&
          tag == '!' &&
          event.style != ScalarStyle.PLAIN &&
          !event.span.text.startsWith('!');
      if (anchor != null || (tag != null && !implicitTag)) properties = true;
      final type = event.type;
      final collection =
          type == EventType.sequenceStart || type == EventType.mappingStart;
      if (nodes.isNotEmpty &&
          (collection || type == EventType.scalar || type == EventType.alias)) {
        if (collection && mappings.last && nodes.last.isEven) {
          collectionKey = true;
        }
        if (mappings.last && nodes.last.isEven) {
          keys++;
          if (++mappingKeys.last > mostKeys) mostKeys = mappingKeys.last;
        }
        nodes.last++;
      }
      switch (type) {
        case EventType.alias:
          properties = true;
        case EventType.sequenceStart || EventType.mappingStart:
          mappings.add(type == EventType.mappingStart);
          nodes.add(0);
          mappingKeys.add(0);
          if (mappings.length > deepest) deepest = mappings.length;
        case EventType.sequenceEnd || EventType.mappingEnd:
          mappings.removeLast();
          nodes.removeLast();
          mappingKeys.removeLast();
        case EventType.streamStart ||
            EventType.streamEnd ||
            EventType.documentStart ||
            EventType.documentEnd ||
            EventType.scalar:
      }
    }
  } on YamlException {
    return null;
  } on Object {
    return (
      properties: true,
      collectionKey: collectionKey,
      depth: deepest,
      keys: keys,
      mostKeys: mostKeys,
    );
  }
  return (
    properties: properties,
    collectionKey: collectionKey,
    depth: deepest,
    keys: keys,
    mostKeys: mostKeys,
  );
}

/// The keys the gate counted in [text], or null when it refuses [text].
({int keys, int mostKeys})? _passes(String text) {
  try {
    return checkYamlGate(text);
  } on YamlTextFailure {
    return null;
  }
}

/// Expects, once for every [text], refused ones included (ruling C-8), the
/// gate's verdict to be sound: the gate refuses [text], or package:yaml
/// refuses it too, or reads in it no property, no collection key, no
/// nesting past 64, and no more keys, in all or in its fullest mapping,
/// than the gate counted (design G10).
void _expectSound(String text) {
  final gate = _passes(text);
  final read = gate == null ? null : _oracle(text);
  expect(
    read == null ||
        (!read.properties &&
            !read.collectionKey &&
            read.depth <= 64 &&
            read.keys <= gate!.keys &&
            read.mostKeys <= gate.mostKeys),
    isTrue,
    reason:
        '${jsonEncode(text)} passes the gate counting $gate; package:yaml '
        'reads $read',
  );
}

const _fragments = <String>[
  '\n', '\n', '\n  ', '\n    ', '\r\n', '\r', ' ', '  ', '\t', //
  'a', 'bc', 'k:', 'k: ', ':', ': ', '- ', '-', '? ', ',', ', ',
  '[', ']', '{', '}', '"', "'", r'\"', "''", '#', ' #', '# c',
  '|', '>', '|-', '>+2', '&a', '*a', '!x', '!!str', '!<x>', '& ', '* ',
  '! ', '&', '*', '!', '---', '...', '%TAG ! x', '%YAML 1.2',
  '"{a}"', '"a #b"', "'q'", 'x "y', "y' z", '\u{FEFF}', '@', '`',
  // Flow-mapping entry positions (M1, C1): a whole entry with and
  // without ":", so random concatenation can land a collection right
  // after a flow mapping's "{" or ",", the shape the old gate missed.
  '{a}', '{a}, ', '{a:b}', '{a:b}, ', '[a]', '[a], ',
  // Key positions for the key count (G10): entries of a flow mapping with
  // and without ":", JSON-style values, and single-pair mappings in a flow
  // sequence.
  '{a, b}', '"k":1', '[k: 1]', 'k: v\n', '- k: v\n',
  // A byte-order mark starting a later line (C1 round 2): package:yaml
  // allows it there too, a shape plain '\n' and '\u{FEFF}' fragments
  // rarely land adjacent.
  '\n\u{FEFF}', '\r\n\u{FEFF}',
];

const _noise = <String>[
  '',
  '"]]", ',
  "']}', ",
  '"a\n]]]\nb", ',
  ' # ]] "\n',
  ' # ]]\n',
  '\n',
  r'"\"]", ',
  "'it''s ]', ",
  'a, ',
];

/// 66 nested flow sequences with inert text around their brackets.
String _deepFlow(Random random) {
  final out = StringBuffer();
  for (var level = 0; level < 66; level++) {
    out
      ..write('[')
      ..write(_noise[random.nextInt(_noise.length)]);
  }
  out
    ..write('x')
    ..write(']' * 66);
  return out.toString();
}

/// 67 nested block mappings with inert siblings between them: quoted
/// closers, block scalars, comments, and two-line plain scalars.
String _deepBlock(Random random) {
  final lines = <String>[];
  for (var level = 0; level < 66; level++) {
    final indent = ' ' * level;
    switch (random.nextInt(5)) {
      case 0:
        lines.add('${indent}n$level: "]]]"');
      case 1:
        lines
          ..add('${indent}n$level: |')
          ..add('$indent  ]]] "');
      case 2:
        lines.add("$indent# ]] '");
      case 3:
        lines
          ..add('${indent}n$level: a [b')
          ..add('$indent  c]');
      default:
    }
    lines.add('${indent}k$level:');
  }
  lines.add('${' ' * 66}x: 1');
  return lines.join('\n');
}

void main() {
  group('fo01 us01/fr01/e07, g4, g9: no text the gate passes holds an '
      'anchor, alias, or tag, a collection key, or nests past 64, for '
      'package:yaml', () {
    test('hand-made attempts to hide a property, a collection key, or a '
        'level', () {
      [
        '[ "a #", &b c ]',
        'x "y: &a 1"',
        '- key: |\n  other: &a 1',
        '[ "a\n"b, &c d ]',
        "a: 'x\n  # a'' , &b c'",
        '${'[' * 40}"${']' * 40}", ${'[' * 30}1${']' * 70}',
        "${'[' * 40} # '${']' * 40}\n${'[' * 30}1${']' * 70}",
        '${'[' * 40}"\n${']' * 40}\n", ${'[' * 30}1${']' * 70}',
        'a: hello\n  "q: [[[[[["',
        '- hello\n  "q: [[[[[["',
        '[a\n"b, [c" ]',
        '[ "a]", b ]: c',
        '{a: [b, "c]: d"]}: e',
        '? # c\n  [a]\n: b',
        '[[a]\n# c\n: b]',
        'a: 1\n: b\n[c]: d',
        'a: 1\n: b\n? c\n: d',
        'a: 1\n...\n{[x]: y}: z',
        // C1: a flow-mapping entry with no ":" reads as a key with an
        // empty value (FLOW_MAPPING_EMPTY_VALUE), so a nested collection
        // right after "{" or "," is a collection key the old gate missed.
        '{{a}}',
        '{[a]}',
        '{a, [b]}',
        // C1 round 2: package:yaml allows a byte-order mark to start any
        // line (scanner.dart's _scanToNextToken), not just the text's
        // own first character, so one can hide a collection key the
        // same way.
        '{\n\u{FEFF}{a}}',
        // G10: keys the count must never miss, in block and flow
        // context, JSON style, in a flow sequence, and after the lock.
        'a: 1\nb: 2\nc:\n  d: 3\n  e: 4\nf: 5',
        '- a: 1\n  b: 2\n- c: 3',
        'k:\n- a: 1\n  b: 2\nm: 3',
        '{"a":1,"b":2,"c":{"d":3}}',
        '[a: 1, b: 2, "c":3, {d: 4}]',
        '{a, b, c: 1, ? d}',
        'a: 1\n...\nb: 2\nc: {d: 3, e: 4}\nf: 5',
        'x: 1\n: y\na: 1\nb: 2\nc: 3',
        'a: b\n  c\nd: e',
        '"a": 1\n\'b\': 2\nc d: 3',
      ].forEach(_expectSound);
    });

    test('20,000 texts of random fragments', () {
      final random = Random(20261007);
      for (var run = 0; run < 20000; run++) {
        final count = random.nextInt(40) + 1;
        _expectSound(
          [
            for (var i = 0; i < count; i++)
              _fragments[random.nextInt(_fragments.length)],
          ].join(),
        );
      }
    });

    test('300 flow and 300 block texts nested 66 deep among inert brackets '
        'are refused whenever package:yaml reads them past 64', () {
      final random = Random(7);
      for (var run = 0; run < 300; run++) {
        _expectSound(_deepFlow(random));
        _expectSound(_deepBlock(random));
      }
    });
  });
}
