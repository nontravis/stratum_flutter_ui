// Derived from archive 4.3.0 (https://pub.dev/packages/archive),
// lib/src/codecs/zlib/inflate.dart and _huffman_table.dart, which carry
// this notice:
//
// The MIT License
//
// Copyright (c) 2013-2021 Brendan Duncan.
// All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
// CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
// TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// archive's inflate is in turn derived from zlib.js
// (https://github.com/imaya/zlib.js), The MIT License, Copyright (c)
// 2012 imaya, under the same permission notice.
//
// _Huffman.build, _symbol's slow path, and _dynamic's checks are
// translated from zlib's puff.c (puff.h), which carries this notice:
//
// puff.h
// Copyright (C) 2002-2013 Mark Adler, all rights reserved
// version 2.3, 21 Jan 2013
//
// This software is provided 'as-is', without any express or implied
// warranty.  In no event will the author be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must
//    not claim that you wrote the original software. If you use this
//    software in a product, an acknowledgment in the product
//    documentation would be appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must
//    not be misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source
//    distribution.
//
// Mark Adler    madler@alumni.caltech.edu
//
// This is an altered version: translated to Dart, with a 9-bit root
// lookup table ahead of puff's bit-at-a-time decode, and puff's return
// codes replaced by stratum_ui's InflateFailure and InflateLimitReached.

import 'dart:typed_data';

/// Thrown by [inflateRaw] before a write that would take its output past
/// its limit.
final class InflateLimitReached implements Exception {
  const new(this.measured);

  /// The output length the refused write would have reached.
  final int measured;
}

/// Thrown by [inflateRaw] on input that is not one well-formed raw
/// deflate stream ending at the input's last byte.
final class InflateFailure implements Exception {
  const new(this.reason);

  /// What is wrong, worded to follow an entry's label in a message.
  final String reason;
}

/// Inflates [input], one raw deflate stream (RFC 1951), and returns its
/// output (FO-04 US-01 FR-02 E07, E10; design Z5, RZ11).
///
/// Refuses, with [InflateFailure], every stream zlib refuses: a stored
/// block whose NLEN is not the complement of its LEN, a LEN of 0
/// included; a block of the reserved type; a dynamic block header with
/// more than 286 length or 30 distance codes, a code-length repeat with no
/// length before it or past the code count, or no end-of-block code; an
/// over-subscribed Huffman code, and an incomplete one but a single code
/// of length 1; a symbol or a distance out of range; input that ends
/// before the final block; and a byte after the final block. Builds each
/// Huffman table in time linear in its symbol count plus a fixed 512-entry
/// lookup, so a stream costs time linear in its bytes and its output,
/// whatever codes it holds.
///
/// Writes into a buffer of [sizeHint] bytes, at most [limit], grown up to
/// [limit]; throws [InflateLimitReached] before a write that would take
/// the output past [limit].
Uint8List inflateRaw(
  Uint8List input, {
  required int sizeHint,
  required int limit,
}) => _Inflater(input, sizeHint, limit).run();

/// The bits of the root lookup of a [_Huffman] table.
const _rootBits = 9;

/// One Huffman code in canonical form (`count`, `symbol`, as zlib's puff
/// keeps it) with a root lookup of [_rootBits] bits for its short codes.
final class _Huffman {
  /// Builds the code of [lengths], refusing an over-subscribed code, and an
  /// incomplete one unless [incompleteAllowed] and it is a single code of
  /// length 1, as zlib's `inflate_table` does.
  factory build(List<int> lengths, {bool incompleteAllowed = true}) {
    final count = Uint16List(16);
    for (final length in lengths) {
      count[length]++;
    }
    var max = 15;
    while (max > 0 && count[max] == 0) {
      max--;
    }
    final symbol = Uint16List(lengths.length);
    final root = Int32List(1 << _rootBits);
    if (max == 0) return _Huffman._(count, symbol, root);
    var left = 1;
    for (var length = 1; length <= 15; length++) {
      left = (left << 1) - count[length];
      if (left < 0) {
        throw const InflateFailure('has an over-subscribed Huffman code');
      }
    }
    if (left > 0 && (!incompleteAllowed || max != 1)) {
      throw const InflateFailure('has an incomplete Huffman code');
    }
    final offsets = Uint16List(17);
    for (var length = 1; length < 16; length++) {
      offsets[length + 1] = offsets[length] + count[length];
    }
    for (var i = 0; i < lengths.length; i++) {
      if (lengths[i] != 0) symbol[offsets[lengths[i]]++] = i;
    }
    var code = 0;
    var index = 0;
    for (var length = 1; length <= _rootBits; length++) {
      for (var k = 0; k < count[length]; k++) {
        var reversed = 0;
        for (var bit = 0; bit < length; bit++) {
          reversed |= ((code >> bit) & 1) << (length - 1 - bit);
        }
        final entry = (length << 16) | symbol[index++];
        for (var j = reversed; j < root.length; j += 1 << length) {
          root[j] = entry;
        }
        code++;
      }
      code <<= 1;
    }
    return _Huffman._(count, symbol, root);
  }

  new _(this.count, this.symbol, this.root);

  /// How many codes have each length, 0 to 15.
  final Uint16List count;

  /// The symbols in canonical order.
  final Uint16List symbol;

  /// For each [_rootBits]-bit input, `length << 16 | symbol` of the code
  /// it starts with, or 0 when that code is longer or undefined.
  final Int32List root;
}

/// The fixed codes of RFC 1951 section 3.2.6: 288 length symbols and 32
/// distance symbols, both complete; symbols 286, 287, 30, and 31 are
/// refused where they are read.
final _fixedLengths = _Huffman.build([
  for (var i = 0; i < 144; i++) 8,
  for (var i = 144; i < 256; i++) 9,
  for (var i = 256; i < 280; i++) 7,
  for (var i = 280; i < 288; i++) 8,
]);
final _fixedDistances = _Huffman.build(List.filled(32, 5));

/// The order the code-length code lengths arrive in.
const _order = [
  16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15, //
];

const _lengthBase = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, //
  59, 67, 83, 99, 115, 131, 163, 195, 227, 258,
];
const _lengthExtra = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, //
  4, 5, 5, 5, 5, 0,
];
const _distanceBase = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, //
  513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
];
const _distanceExtra = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, //
  10, 11, 11, 12, 12, 13, 13,
];

/// One run of [inflateRaw] over its input.
final class _Inflater {
  new(this._input, int sizeHint, this._limit)
    : _output = Uint8List(sizeHint < _limit ? sizeHint : _limit);

  final Uint8List _input;
  final int _limit;

  /// The buffer size past which [_room] stops doubling and jumps straight
  /// to [_limit].
  static const int _bigGrowth = 1 << 20;

  Uint8List _output;
  var _length = 0;
  var _at = 0;
  var _bits = 0;
  var _bitCount = 0;

  Uint8List run() {
    var last = false;
    while (!last) {
      last = _take(1) == 1;
      switch (_take(2)) {
        case 0:
          _stored();
        case 1:
          _codes(_fixedLengths, _fixedDistances);
        case 2:
          _dynamic();
        default:
          throw const InflateFailure(
            'has a deflate block of the reserved type',
          );
      }
    }
    _at -= _bitCount >> 3;
    if (_at < _input.length) {
      throw const InflateFailure('holds bytes after its final deflate block');
    }
    return _length == _output.length
        ? _output
        : Uint8List.sublistView(_output, 0, _length);
  }

  /// The next [count] bits, at most 16, low bit first.
  int _take(int count) {
    while (_bitCount < count) {
      if (_at >= _input.length) {
        throw const InflateFailure('ends before its final deflate block');
      }
      _bits |= _input[_at++] << _bitCount;
      _bitCount += 8;
    }
    final value = _bits & ((1 << count) - 1);
    _bits >>= count;
    _bitCount -= count;
    return value;
  }

  /// The next symbol of [code]: through its root lookup when
  /// [_rootBits] bits are at hand and the code is that short, else one bit
  /// at a time over its canonical counts, as zlib's puff decodes.
  int _symbol(_Huffman code) {
    while (_bitCount < _rootBits && _at < _input.length) {
      _bits |= _input[_at++] << _bitCount;
      _bitCount += 8;
    }
    if (_bitCount >= _rootBits) {
      final entry = code.root[_bits & ((1 << _rootBits) - 1)];
      if (entry != 0) {
        final length = entry >> 16;
        _bits >>= length;
        _bitCount -= length;
        return entry & 0xFFFF;
      }
    }
    var value = 0;
    var first = 0;
    var index = 0;
    for (var length = 1; length <= 15; length++) {
      value |= _take(1);
      final count = code.count[length];
      if (value - count < first) return code.symbol[index + value - first];
      index += count;
      first = (first + count) << 1;
      value <<= 1;
    }
    throw const InflateFailure('uses a code its block does not define');
  }

  void _stored() {
    _at -= _bitCount >> 3;
    _bits = 0;
    _bitCount = 0;
    if (_at + 4 > _input.length) {
      throw const InflateFailure('ends before its final deflate block');
    }
    final length = _input[_at] | (_input[_at + 1] << 8);
    final complement = _input[_at + 2] | (_input[_at + 3] << 8);
    _at += 4;
    if (complement != (~length & 0xFFFF)) {
      throw const InflateFailure(
        'has a stored block whose NLEN is not the complement of its LEN',
      );
    }
    if (_at + length > _input.length) {
      throw const InflateFailure('ends before its final deflate block');
    }
    _room(length);
    _output.setRange(_length, _length + length, _input, _at);
    _length += length;
    _at += length;
  }

  void _dynamic() {
    final lengthCount = _take(5) + 257;
    final distanceCount = _take(5) + 1;
    final codeCount = _take(4) + 4;
    if (lengthCount > 286 || distanceCount > 30) {
      throw const InflateFailure(
        'has a dynamic block header with more than 286 length or 30 '
        'distance codes',
      );
    }
    final codeLengths = Uint8List(19);
    for (var i = 0; i < codeCount; i++) {
      codeLengths[_order[i]] = _take(3);
    }
    final lengthsCode = _Huffman.build(codeLengths, incompleteAllowed: false);
    final lengths = Uint8List(lengthCount + distanceCount);
    var i = 0;
    while (i < lengths.length) {
      final symbol = _symbol(lengthsCode);
      if (symbol < 16) {
        lengths[i++] = symbol;
        continue;
      }
      var value = 0;
      final int repeat;
      if (symbol == 16) {
        if (i == 0) {
          throw const InflateFailure(
            'repeats a code length with no length before it',
          );
        }
        value = lengths[i - 1];
        repeat = 3 + _take(2);
      } else if (symbol == 17) {
        repeat = 3 + _take(3);
      } else {
        repeat = 11 + _take(7);
      }
      if (i + repeat > lengths.length) {
        throw const InflateFailure('repeats a code length past its code count');
      }
      lengths.fillRange(i, i + repeat, value);
      i += repeat;
    }
    if (lengths[256] == 0) {
      throw const InflateFailure('has no end-of-block code');
    }
    _codes(
      _Huffman.build(Uint8List.sublistView(lengths, 0, lengthCount)),
      _Huffman.build(Uint8List.sublistView(lengths, lengthCount)),
    );
  }

  void _codes(_Huffman lengths, _Huffman distances) {
    while (true) {
      final symbol = _symbol(lengths);
      if (symbol < 256) {
        _room(1);
        _output[_length++] = symbol;
        continue;
      }
      if (symbol == 256) return;
      final index = symbol - 257;
      if (index >= 29) {
        throw const InflateFailure('uses a length symbol past 285');
      }
      final length = _lengthBase[index] + _take(_lengthExtra[index]);
      final code = _symbol(distances);
      if (code >= 30) {
        throw const InflateFailure('uses a distance symbol past 29');
      }
      final distance = _distanceBase[code] + _take(_distanceExtra[code]);
      if (distance > _length) {
        throw const InflateFailure('reaches back past the start of its output');
      }
      _room(length);
      for (var k = 0; k < length; k++) {
        _output[_length] = _output[_length - distance];
        _length++;
      }
    }
  }

  /// Makes room for [count] more output bytes, refusing to pass [_limit].
  ///
  /// Doubles while the buffer is small; past [_bigGrowth], one jump
  /// straight to [_limit] replaces the chain of doublings that would
  /// otherwise leave several stale buffers awaiting GC on the way there, so
  /// an entry whose declared size understates its real one by megabytes
  /// peaks near one buffer of [_limit], not several (review m3-t7c
  /// security, Minor 1).
  void _room(int count) {
    final needed = _length + count;
    if (needed > _limit) throw InflateLimitReached(needed);
    if (needed <= _output.length) return;
    if (_output.length >= _bigGrowth) {
      _output = Uint8List(_limit)..setRange(0, _length, _output);
      return;
    }
    var size = _output.length < 1024 ? 1024 : _output.length * 2;
    while (size < needed) {
      size *= 2;
    }
    if (size > _limit) size = _limit;
    _output = Uint8List(size)..setRange(0, _length, _output);
  }
}
