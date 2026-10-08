import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart' show Deflate;
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/remote/remote_inflate.dart';

/// A deflate bit writer, low bit first, as RFC 1951 packs a stream.
final class _Bits {
  final _out = <int>[];
  var _acc = 0;
  var _count = 0;

  /// Writes the low [count] bits of [value], low bit first.
  void put(int value, int count) {
    for (var i = 0; i < count; i++) {
      _acc |= ((value >> i) & 1) << _count;
      if (++_count == 8) {
        _out.add(_acc);
        _acc = 0;
        _count = 0;
      }
    }
  }

  /// Writes a Huffman [code] of [length] bits, high bit first.
  void code(int code, int length) {
    for (var i = length - 1; i >= 0; i--) {
      put((code >> i) & 1, 1);
    }
  }

  /// Writes a stored block of [data] at the current bit position.
  void stored(List<int> data, {required bool last}) {
    put(last ? 1 : 0, 1);
    put(0, 2);
    if (_count > 0) put(0, 8 - _count);
    _out.addAll([
      data.length & 0xFF,
      data.length >> 8,
      (data.length & 0xFF) ^ 0xFF,
      (data.length >> 8) ^ 0xFF,
      ...data,
    ]);
  }

  Uint8List done() {
    if (_count > 0) put(0, 8 - _count);
    return Uint8List.fromList(_out);
  }
}

/// The canonical codes of [lengths], as RFC 1951 section 3.2.2 assigns
/// them.
List<int> _canonical(List<int> lengths) {
  final codes = List.filled(lengths.length, 0);
  var code = 0;
  for (var length = 1; length <= 15; length++) {
    for (var i = 0; i < lengths.length; i++) {
      if (lengths[i] == length) codes[i] = code++;
    }
    code <<= 1;
  }
  return codes;
}

const _order = [
  16,
  17,
  18,
  0,
  8,
  7,
  9,
  6,
  10,
  5,
  11,
  4,
  12,
  3,
  13,
  2,
  14,
  1,
  15,
];

/// Writes a dynamic block header declaring [lengthCount] length codes and
/// [distanceCount] distance codes, their code lengths sent as the
/// code-length [symbols], each a (symbol, extra bit count, extra value);
/// the code-length code is complete, symbols 0 to 14 at 4 bits and 15 to
/// 18 at 6.
void _dynamicHeader(
  _Bits bits, {
  required bool last,
  required int lengthCount,
  required int distanceCount,
  required List<(int, int, int)> symbols,
}) {
  final codeLengths = [...List.filled(15, 4), 6, 6, 6, 6];
  bits
    ..put(last ? 1 : 0, 1)
    ..put(2, 2)
    ..put(lengthCount - 257, 5)
    ..put(distanceCount - 1, 5)
    ..put(15, 4);
  for (final symbol in _order) {
    bits.put(codeLengths[symbol], 3);
  }
  final codes = _canonical(codeLengths);
  for (final (symbol, extraBits, extra) in symbols) {
    bits
      ..code(codes[symbol], codeLengths[symbol])
      ..put(extra, extraBits);
  }
}

/// [lengths] as literal code-length symbols.
List<(int, int, int)> _literal(List<int> lengths) => [
  for (final length in lengths) (length, 0, 0),
];

/// [count] zero code lengths as runs of symbols 18 and 17.
List<(int, int, int)> _zeros(int count) {
  final out = <(int, int, int)>[];
  var left = count;
  while (left >= 11) {
    final run = left > 138 ? 138 : left;
    out.add((18, 7, run - 11));
    left -= run;
  }
  if (left >= 3) {
    out.add((17, 3, left - 3));
  } else {
    out.addAll(_literal(List.filled(left, 0)));
  }
  return out;
}

/// One empty dynamic block, 22 bytes, whose codes zlib accepts and whose
/// length code reaches 15 bits: symbols 0 to 13 at lengths 1 to 14,
/// symbol 14 and the end code at 15, and one distance code of length 1.
void _completeEmptyBlock(_Bits bits, {required bool last}) {
  final lengths = [for (var i = 1; i <= 15; i++) i, ...List.filled(241, 0), 15];
  _dynamicHeader(
    bits,
    last: last,
    lengthCount: 257,
    distanceCount: 1,
    symbols: [
      ..._literal(lengths.sublist(0, 15)),
      ..._zeros(241),
      (15, 0, 0),
      (1, 0, 0),
    ],
  );
  bits.code(_canonical(lengths)[256], 15);
}

/// One empty dynamic block whose length code is over-subscribed: length
/// symbols 0 to 255 at length 1 and the end code at 15, its code the one
/// archive 4.3.0 assigns past the over-subscribed run, so archive read the
/// block whole and filled 2^14 table slots for each of the 256.
void _overSubscribedEmptyBlock(_Bits bits, {required bool last}) {
  _dynamicHeader(
    bits,
    last: last,
    lengthCount: 257,
    distanceCount: 1,
    symbols: _literal([...List.filled(256, 1), 15, 1]),
  );
  bits.code(_canonical([...List.filled(256, 1), 15])[256] & 0x7FFF, 15);
}

/// The cheapest valid dynamic block that fills three full 512-entry root
/// tables (the code-length, length, and distance codes): 92 bits, 11.5
/// bytes (review m3-t7c security, worst per byte). One literal length
/// code (symbol 0) and the end-of-block code (symbol 256) at length 1,
/// both distance codes at length 1, each pair filling its table; then
/// [literals] literal zero bytes, one bit each, and the end-of-block code.
void _maxFillBlock(_Bits bits, {required bool last, int literals = 0}) {
  bits
    ..put(last ? 1 : 0, 1)
    ..put(2, 2)
    ..put(0, 5) // HLIT 257
    ..put(1, 5) // HDIST 2
    ..put(14, 4); // HCLEN 18
  final codeLengths = List.filled(19, 0)
    ..[1] = 1
    ..[18] = 1;
  for (var i = 0; i < 18; i++) {
    bits.put(codeLengths[_order[i]], 3);
  }
  bits
    ..code(0, 1) // length code 0 = 1
    ..code(1, 1) // repeat zero (code 18)
    ..put(138 - 11, 7) // code lengths 1 to 138 zero
    ..code(1, 1) // repeat zero (code 18)
    ..put(117 - 11, 7) // code lengths 139 to 255 zero
    ..code(0, 1) // length code 256 (end-of-block) = 1
    ..code(0, 1) // distance code 0 = 1
    ..code(0, 1); // distance code 1 = 1
  for (var i = 0; i < literals; i++) {
    bits.code(0, 1); // literal 0
  }
  bits.code(1, 1); // the end-of-block code
}

Matcher _refused(String reason) => throwsA(
  isA<InflateFailure>().having((f) => f.reason, 'reason', contains(reason)),
);

Uint8List _inflate(List<int> stream, {int sizeHint = 0, int limit = 1 << 24}) =>
    inflateRaw(Uint8List.fromList(stream), sizeHint: sizeHint, limit: limit);

void main() {
  final random = Random(20261008);
  final small = Uint8List.fromList([
    for (var i = 0; i < 3000; i++) (i * 7) % 251,
  ]);
  final noise = Uint8List.fromList([
    for (var i = 0; i < 100000; i++) random.nextInt(256),
  ]);
  final text = Uint8List.fromList(
    List.generate(50000, (i) => 'theme: brand\n'.codeUnitAt(i % 13)),
  );

  group('us01/fr02/e10, rz11: well-formed streams inflate', () {
    for (final (label, data) in [
      ('nothing', Uint8List(0)),
      ('one byte', Uint8List.fromList([7])),
      ('3,000 patterned bytes', small),
      ('100,000 random bytes', noise),
      ('50,000 bytes of repeated text', text),
    ]) {
      test("archive's Deflate of $label round-trips", () {
        expect(_inflate(Deflate(data).getBytes()), data);
      });
    }

    for (final (label, stream) in [
      ('03 00, the empty fixed block', [0x03, 0x00]),
      ('01 00 00 ff ff, the empty final stored block', [1, 0, 0, 0xFF, 0xFF]),
    ]) {
      test('$label inflates to nothing', () {
        expect(_inflate(stream), isEmpty);
      });
    }

    test('a complete empty dynamic block with 15-bit codes and one 1-bit '
        'distance code, then a final stored block, inflates', () {
      final bits = _Bits();
      _completeEmptyBlock(bits, last: false);
      bits.stored(small, last: true);

      expect(_inflate(bits.done()), small);
    });
  });

  group('us01/fr02/e10, rz11 (m3-t7 security W1 to W6, P2 v10, v11, v14): '
      'malformed streams are refused', () {
    final b3 = _Bits()
      ..stored(small, last: false)
      ..put(1, 1)
      ..put(1, 2)
      ..code(0xC6, 8);
    final b4 = _Bits()
      ..stored(small, last: false)
      ..put(1, 1)
      ..put(1, 2)
      ..code(0x01, 7)
      ..code(29, 5)
      ..put(0x1FFF, 13);
    final b5 = _Bits()..stored(small, last: false);
    _overSubscribedEmptyBlock(b5, last: true);
    final b6 = _Bits();
    _overSubscribedEmptyBlock(b6, last: false);
    b6.stored(small, last: true);
    final distance30 = _Bits()
      ..stored(small, last: false)
      ..put(1, 1)
      ..put(1, 2)
      ..code(0x01, 7)
      ..code(30, 5);
    final noEnd = _Bits();
    _dynamicHeader(
      noEnd,
      last: true,
      lengthCount: 257,
      distanceCount: 1,
      symbols: [
        ..._literal([1, 1]),
        ..._zeros(255),
        (1, 0, 0),
      ],
    );
    final incomplete = _Bits();
    _dynamicHeader(
      incomplete,
      last: true,
      lengthCount: 257,
      distanceCount: 1,
      symbols: [
        ..._literal([2]),
        ..._zeros(255),
        (2, 0, 0),
        (1, 0, 0),
      ],
    );
    final tooMany = _Bits();
    _dynamicHeader(
      tooMany,
      last: true,
      lengthCount: 287,
      distanceCount: 1,
      symbols: const [],
    );
    final repeatPast = _Bits();
    _dynamicHeader(
      repeatPast,
      last: true,
      lengthCount: 257,
      distanceCount: 1,
      symbols: const [(18, 7, 127), (18, 7, 127)],
    );
    final repeatFirst = _Bits();
    _dynamicHeader(
      repeatFirst,
      last: true,
      lengthCount: 257,
      distanceCount: 1,
      symbols: const [(16, 2, 0)],
    );
    final stream = Deflate(small).getBytes();

    for (final (label, bytes, reason) in [
      (
        'W1: an empty stored block with NLEN 0x4241 before the data',
        [0x00, 0x00, 0x00, 0x41, 0x42, ...stream],
        'NLEN is not the complement of its LEN',
      ),
      (
        'W2: 1,000 empty stored blocks carrying 2,000 chosen bytes, then '
            '03 00',
        [
          for (var i = 0; i < 1000; i++) ...[0, 0, 0, 0x48, 0x49],
          0x03,
          0x00,
        ],
        'NLEN is not the complement of its LEN',
      ),
      (
        'W3: after the output, a final fixed block whose first symbol is 286',
        b3.done(),
        'uses a length symbol past 285',
      ),
      (
        'W4: after the output, a match 32,768 back',
        b4.done(),
        'reaches back past the start of its output',
      ),
      (
        'W5: after the output, an over-subscribed final dynamic block',
        b5.done(),
        'has an over-subscribed Huffman code',
      ),
      (
        'W6: an over-subscribed empty dynamic block before the data',
        b6.done(),
        'has an over-subscribed Huffman code',
      ),
      (
        'v10: after the output, a block of the reserved type',
        [...(_Bits()..stored(small, last: false)).done(), 0x07],
        'has a deflate block of the reserved type',
      ),
      (
        'v11: after the output, a stored LEN and NLEN that disagree',
        [
          ...(_Bits()..stored(small, last: false)).done(),
          0x01,
          0x05,
          0x00,
          0x34,
          0x12,
        ],
        'NLEN is not the complement of its LEN',
      ),
      (
        'v14: an empty final stored block with a wrong NLEN',
        [1, 0, 0, 0x12, 0x34],
        'NLEN is not the complement of its LEN',
      ),
      (
        'a fixed block whose match uses distance symbol 30',
        distance30.done(),
        'uses a distance symbol past 29',
      ),
      (
        'a dynamic block with no end-of-block code',
        noEnd.done(),
        'has no end-of-block code',
      ),
      (
        'a dynamic block whose length code is incomplete',
        incomplete.done(),
        'has an incomplete Huffman code',
      ),
      (
        'a dynamic block header with 287 length codes',
        tooMany.done(),
        'more than 286 length or 30 distance codes',
      ),
      (
        'a code-length repeat past the code count',
        repeatPast.done(),
        'repeats a code length past its code count',
      ),
      (
        'a code-length repeat with no length before it',
        repeatFirst.done(),
        'repeats a code length with no length before it',
      ),
      (
        'a stream with no final block',
        [0x00, 0x00, 0x00, 0xFF, 0xFF],
        'ends before its final deflate block',
      ),
      (
        'a byte after the final block',
        [0x03, 0x00, 0x00],
        'holds bytes after its final deflate block',
      ),
      ('no byte at all', const <int>[], 'ends before its final deflate block'),
    ]) {
      test('$label is refused', () {
        expect(() => _inflate(bytes), _refused(reason));
      });
    }
  });

  group('us01/fr02/e07, rz11: the output limit and its buffer', () {
    final stored = (_Bits()..stored(Uint8List(100), last: true)).done();

    test('an output of exactly the limit inflates, and one byte past it '
        'stops at that byte', () {
      expect(_inflate(stored, limit: 100), hasLength(100));
      expect(
        () => _inflate(stored, limit: 99),
        throwsA(
          isA<InflateLimitReached>().having((r) => r.measured, 'measured', 100),
        ),
      );
    });

    test('a deflate output past the limit stops before it is written', () {
      expect(
        () => _inflate(Deflate(Uint8List(1 << 20)).getBytes(), limit: 4096),
        throwsA(
          isA<InflateLimitReached>().having(
            (r) => r.measured,
            'measured',
            greaterThan(4096),
          ),
        ),
      );
    });

    test('the buffer is sized to the declared size, so an exact output is '
        'returned without a copy', () {
      final out = _inflate(Deflate(small).getBytes(), sizeHint: small.length);

      expect(out, small);
      expect(out.buffer.lengthInBytes, small.length);
    });

    test('a declared size past the limit sizes the buffer to the limit, '
        'not the declared size', () {
      final out = _inflate(
        Deflate([1, 2, 3]).getBytes(),
        sizeHint: 1 << 40,
        limit: 64,
      );

      expect(out, [1, 2, 3]);
      expect(out.buffer.lengthInBytes, 64);
    });

    test('a declared size short of the output grows the buffer', () {
      expect(_inflate(Deflate(noise).getBytes(), sizeHint: 10), noise);
    });
  });

  group('rz11, rz13 (m3-t7 security I2, m3-t7c security Important 1): the '
      'cost stays in proportion to the output', () {
    test('1,000 over-subscribed empty dynamic blocks, which archive 4.3.0 '
        'read for about 5 s, are refused in under 1 s', () {
      final bits = _Bits();
      for (var i = 0; i < 1000; i++) {
        _overSubscribedEmptyBlock(bits, last: false);
      }
      bits.stored(small, last: true);
      final stream = bits.done();
      final clock = Stopwatch()..start();

      expect(() => _inflate(stream), _refused('over-subscribed'));
      expect(clock.elapsedMilliseconds, lessThan(1000));
    });

    test('100,000 max-fill dynamic blocks, each three full 512-entry root '
        'tables and no output, which took about 0.4 s a megabyte, are '
        'refused at the 17th block in under 50 ms', () {
      final bits = _Bits();
      for (var i = 0; i < 100000; i++) {
        _maxFillBlock(bits, last: false);
      }
      bits.stored(small, last: true);
      final stream = bits.done();
      final clock = Stopwatch()..start();

      expect(
        () => _inflate(stream),
        _refused('starts more than 16 Huffman blocks'),
      );
      expect(clock.elapsedMilliseconds, lessThan(50));
    });

    // VM only: flutter test runs Chrome through the debug compiler, whose
    // speed is no measure of the web build's. Max-fill blocks that each pay
    // for themselves with 520 literal bytes are the costliest stream per
    // output byte the bound admits (amend-rz12 measure: 273 to 289 ms AOT);
    // the budget stays generous for a loaded machine.
    test('40,000 max-fill dynamic blocks, each paying with 520 output '
        'bytes, 20.8 MB, inflate in under 3 s', () {
      final bits = _Bits();
      for (var i = 0; i < 40000; i++) {
        _maxFillBlock(bits, last: false, literals: 520);
      }
      bits.stored(const [], last: true);
      final stream = bits.done();
      final clock = Stopwatch()..start();

      expect(_inflate(stream, limit: 1 << 25), hasLength(40000 * 520));
      expect(clock.elapsedMilliseconds, lessThan(3000));
    }, testOn: 'vm');
  });

  group('us01/fr02/e10, rz13: at most 16 Huffman blocks plus one per 512 '
      'output bytes', () {
    Uint8List emptyFixed(int count, {List<int> before = const []}) {
      final bits = _Bits();
      if (before.isNotEmpty) bits.stored(before, last: false);
      for (var i = 0; i < count; i++) {
        bits
          ..put(i == count - 1 ? 1 : 0, 1)
          ..put(1, 2)
          ..code(0, 7);
      }
      return bits.done();
    }

    test('16 empty Huffman blocks inflate, and the 17th is refused before '
        'its header is read', () {
      expect(_inflate(emptyFixed(16)), isEmpty);
      expect(
        () => _inflate(emptyFixed(17)),
        _refused('starts more than 16 Huffman blocks plus one per 512 bytes'),
      );
    });

    test('512 bytes of output pay for a 17th block, and the 18th is '
        'refused; 511 bytes pay for none', () {
      final paid = Uint8List(512);
      expect(_inflate(emptyFixed(17, before: paid)), paid);
      expect(
        () => _inflate(emptyFixed(18, before: paid)),
        _refused('starts more than 16 Huffman blocks'),
      );
      expect(
        () => _inflate(emptyFixed(17, before: Uint8List(511))),
        _refused('starts more than 16 Huffman blocks'),
      );
    });

    test('dynamic and fixed blocks count alike; stored blocks do not', () {
      Uint8List mixed({required bool extra}) {
        final bits = _Bits();
        for (var i = 0; i < 8; i++) {
          _completeEmptyBlock(bits, last: false);
          bits
            ..put(0, 1)
            ..put(1, 2)
            ..code(0, 7);
          for (var k = 0; k < 10; k++) {
            bits.stored(const [], last: false);
          }
        }
        if (extra) {
          bits
            ..put(0, 1)
            ..put(1, 2)
            ..code(0, 7);
        }
        bits.stored(const [], last: true);
        return bits.done();
      }

      expect(_inflate(mixed(extra: false)), isEmpty);
      expect(
        () => _inflate(mixed(extra: true)),
        _refused('starts more than 16 Huffman blocks'),
      );
    });

    for (final level in [1, 6, 9]) {
      test("archive's Deflate at level $level of 1 MiB of text, which "
          'zip tools write one Huffman block per 21,845 bytes or more, '
          'round-trips', () {
        final data = Uint8List.fromList([
          for (var i = 0; i < 1 << 20; i++) text[i % text.length],
        ]);
        expect(_inflate(Deflate(data, level: level).getBytes()), data);
      });
    }

    test('a stream flushed every 4 KiB, one Huffman block and one empty '
        'stored block per 4,096 bytes as zlib writes it, inflates', () {
      final bits = _Bits();
      for (var at = 0; at < noise.length; at += 4096) {
        final end = at + 4096 < noise.length ? at + 4096 : noise.length;
        final chunk = noise.sublist(at, end);
        bits
          ..put(0, 1)
          ..put(1, 2);
        for (final byte in chunk) {
          if (byte < 144) {
            bits.code(0x30 + byte, 8);
          } else {
            bits.code(0x190 + byte - 144, 9);
          }
        }
        bits
          ..code(0, 7)
          ..stored(const [], last: false);
      }
      bits.stored(const [], last: true);

      expect(_inflate(bits.done()), noise);
    });
  });
}
