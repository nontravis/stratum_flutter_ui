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
// _Huffman.build's code checks and _dynamic's checks are translated
// from zlib's puff.c (puff.h), which carries this notice:
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
// _Huffman.build's two-level tables and _symbol's lookups are translated
// from zlib's inftrees.c (inflate_table) and inflate.c, with the table
// bounds of inftrees.h, which carry this notice:
//
// inftrees.c -- Copyright (C) 1995-2024 Mark Adler
// inflate.c -- Copyright (C) 1995-2022 Mark Adler
// inftrees.h -- Copyright (C) 1995-2005, 2010 Mark Adler
// For conditions of distribution and use, see copyright notice in zlib.h
//
// zlib.h's notice:
//
// Copyright (C) 1995-2024 Jean-loup Gailly and Mark Adler
//
// This software is provided 'as-is', without any express or implied
// warranty.  In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would be
//    appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not
//    be misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source
//    distribution.
//
// Jean-loup Gailly        Mark Adler
// jloup@gzip.org          madler@alumni.caltech.edu
//
// This is an altered version: translated to Dart, with zlib's two-level
// tables in place of puff's bit-at-a-time decode, one Huffman-block budget
// per zip, and the return codes replaced by stratum_ui's InflateFailure
// and InflateLimitReached.

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

/// The Huffman blocks the deflate streams of one zip may start, shared by
/// every [inflateRaw] call of one read (design Z5, RZ13): 16, plus one per
/// stream, plus one per 512 bytes the streams have written, counted
/// across the zip, so neither many streams nor many blocks in one stream
/// cost more than the zip's entries and output pay for.
final class HuffmanBlockBudget {
  /// The Huffman blocks, dynamic or fixed, the zip's streams have started.
  var _blocks = 0;

  /// The streams that have started, each paying for one block.
  var _streams = 0;

  /// The bytes the zip's finished streams wrote.
  var _output = 0;
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
/// before the final block; and a byte after the final block. Beyond zlib,
/// refuses a Huffman block, dynamic or fixed, past [budget], the zip's
/// [_freeHuffmanBlocks] plus one per stream plus one per
/// [_outputPerHuffmanBlock] bytes of output (design Z5, RZ13). Decodes
/// through zlib's two-level tables, so each Huffman table costs at most a
/// fixed number of entries and each symbol one or two lookups: the zip's
/// streams cost time in proportion to their entries and output, plus a
/// few nanoseconds per input byte of their stored blocks, whatever codes
/// they hold.
///
/// Writes into a buffer of [sizeHint] bytes, at most [limit], grown up to
/// [limit]; throws [InflateLimitReached] before a write that would take
/// the output past [limit].
Uint8List inflateRaw(
  Uint8List input, {
  required int sizeHint,
  required int limit,
  required HuffmanBlockBudget budget,
}) => _Inflater(input, sizeHint, limit, budget).run();

/// The index bits of a literal and length table's root, zlib's `lenbits`.
const _lengthRootBits = 9;

/// The index bits of a distance table's root, zlib's `distbits`.
const _distanceRootBits = 6;

/// The index bits of the code-length code's table: its longest code, 7
/// bits, so it has no second level, as zlib builds it.
const _codeLengthRootBits = 7;

/// The most entries a literal and length table takes, its root and its
/// second-level tables, for any code zlib accepts: zlib's `ENOUGH_LENS`,
/// which its `enough 286 9 15` found by exhaustive search (inftrees.h).
const _lengthTableSize = 852;

/// The same for a distance table: zlib's `ENOUGH_DISTS`, from
/// `enough 30 6 15` (inftrees.h).
const _distanceTableSize = 592;

/// A table entry that points at a second-level table: the table's offset
/// in the low 16 bits and its index bits in bits 16 to 23.
const int _link = 1 << 24;

/// A table entry for no code, which only an incomplete single 1-bit code
/// or a code with no lengths leaves; it needs 1 bit to be known.
const int _undefined = 1 << 25 | 1 << 16;

/// The Huffman blocks, dynamic or fixed, a zip's streams may start beyond
/// one per stream before their output pays for more (design Z5, RZ13).
const int _freeHuffmanBlocks = 16;

/// The output bytes that pay for one more Huffman block (design Z5, RZ13):
/// the zip tools measured write one per 21,845 bytes or more, and a zlib
/// stream flushed every 4 KiB one per 3,855, so 512 leaves that stream 8
/// times the room it needs.
const int _outputPerHuffmanBlock = 512;

/// One Huffman code as zlib's inflate decodes it (inftrees.c
/// `inflate_table`): a root table of [rootBits] index bits, then a
/// second-level table for each run of codes longer than [rootBits] that
/// share their first [rootBits] bits.
final class _Huffman {
  new(this.rootBits, int size)
    : rootMask = (1 << rootBits) - 1,
      table = Int32List(size);

  /// The index bits of the root table.
  final int rootBits;

  /// The low [rootBits] bits set.
  final int rootMask;

  /// The root table, then the second-level tables: each entry
  /// `length << 16 | symbol` with the code's whole length, a [_link], or
  /// [_undefined].
  final Int32List table;

  /// Builds the code of [lengths] into [table], refusing an
  /// over-subscribed code, and an incomplete one unless
  /// [incompleteAllowed] and it is a single code of length 1, as zlib's
  /// `inflate_table` does.
  void build(List<int> lengths, {bool incompleteAllowed = true}) {
    final count = Uint16List(16);
    for (final length in lengths) {
      count[length]++;
    }
    var max = 15;
    while (max > 0 && count[max] == 0) {
      max--;
    }
    final rootSize = 1 << rootBits;
    if (max == 0) {
      table.fillRange(0, rootSize, _undefined);
      return;
    }
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
    final offsets = Uint16List(16);
    for (var length = 1; length < 15; length++) {
      offsets[length + 1] = offsets[length] + count[length];
    }
    final symbols = Uint16List(lengths.length);
    for (var i = 0; i < lengths.length; i++) {
      if (lengths[i] != 0) symbols[offsets[lengths[i]]++] = i;
    }
    var length = 1;
    while (count[length] == 0) {
      length++;
    }
    // zlib's loop: [code] is the current code bit-reversed, so its low
    // [rootBits] bits index the root; [next] is the table being filled,
    // [bits] its index bits, [drop] the code bits that led to it.
    var code = 0;
    var symbol = 0;
    var next = 0;
    var bits = rootBits;
    var drop = 0;
    var low = -1;
    final mask = rootSize - 1;
    while (true) {
      final entry = length << 16 | symbols[symbol];
      final step = 1 << (length - drop);
      for (var fill = (1 << bits) - step; fill >= 0; fill -= step) {
        table[next + (code >> drop) + fill] = entry;
      }
      var increment = 1 << (length - 1);
      while (code & increment != 0) {
        increment >>= 1;
      }
      code = increment == 0 ? 0 : (code & (increment - 1)) + increment;
      symbol++;
      if (--count[length] == 0) {
        if (length == max) break;
        length = lengths[symbols[symbol]];
      }
      if (length > rootBits && code & mask != low) {
        if (drop == 0) drop = rootBits;
        next += 1 << bits;
        bits = length - drop;
        var room = 1 << bits;
        while (bits + drop < max) {
          room -= count[bits + drop];
          if (room <= 0) break;
          bits++;
          room <<= 1;
        }
        low = code & mask;
        table[low] = _link | bits << 16 | next;
      }
    }
    if (code != 0) {
      for (var i = code; i < rootSize; i += 2) {
        table[i] = _undefined;
      }
    }
  }
}

/// The fixed codes of RFC 1951 section 3.2.6: 288 length symbols and 32
/// distance symbols, both complete; symbols 286, 287, 30, and 31 are
/// refused where they are read.
final _fixedLengths = _Huffman(_lengthRootBits, 1 << _lengthRootBits)
  ..build([
    for (var i = 0; i < 144; i++) 8,
    for (var i = 144; i < 256; i++) 9,
    for (var i = 256; i < 280; i++) 7,
    for (var i = 280; i < 288; i++) 8,
  ]);
final _fixedDistances = _Huffman(_distanceRootBits, 1 << _distanceRootBits)
  ..build(List.filled(32, 5));

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
  new(this._input, int sizeHint, this._limit, this._budget)
    : _output = Uint8List(sizeHint < _limit ? sizeHint : _limit);

  final Uint8List _input;
  final int _limit;
  final HuffmanBlockBudget _budget;

  /// The buffer size past which [_room] stops doubling and jumps straight
  /// to [_limit].
  static const int _bigGrowth = 1 << 20;

  /// The tables of a dynamic block, built anew for each block.
  final _codeLengths = _Huffman(_codeLengthRootBits, 1 << _codeLengthRootBits);
  final _lengths = _Huffman(_lengthRootBits, _lengthTableSize);
  final _distances = _Huffman(_distanceRootBits, _distanceTableSize);

  Uint8List _output;
  var _length = 0;
  var _at = 0;
  var _bits = 0;
  var _bitCount = 0;

  Uint8List run() {
    _budget._streams++;
    var last = false;
    while (!last) {
      last = _take(1) == 1;
      switch (_take(2)) {
        case 0:
          _stored();
        case 1:
          _startHuffmanBlock();
          _codes(_fixedLengths, _fixedDistances);
        case 2:
          _startHuffmanBlock();
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
    _budget._output += _length;
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

  /// The next symbol of [code], read through its root table and, for a
  /// code longer than the root's index bits, the second-level table the
  /// root entry links to, as zlib's inflate decodes.
  int _symbol(_Huffman code) {
    if (_bitCount < 15) _fill();
    var entry = code.table[_bits & code.rootMask];
    if (entry >= _link) entry = _secondLevel(code, entry);
    final length = entry >> 16;
    if (length > _bitCount) {
      throw const InflateFailure('ends before its final deflate block');
    }
    _bits >>= length;
    _bitCount -= length;
    return entry & 0xFFFF;
  }

  /// Takes input bytes until 15 bits, the longest code, are at hand, or
  /// the input ends.
  void _fill() {
    while (_bitCount < 15 && _at < _input.length) {
      _bits |= _input[_at++] << _bitCount;
      _bitCount += 8;
    }
  }

  /// The entry [link] of [code]'s root points to, or a refusal when it
  /// is [_undefined].
  int _secondLevel(_Huffman code, int link) {
    if (link >= _undefined) {
      if (_bitCount == 0) {
        throw const InflateFailure('ends before its final deflate block');
      }
      throw const InflateFailure('uses a code its block does not define');
    }
    final bits = (link >> 16) & 0xFF;
    return code.table[(link & 0xFFFF) +
        ((_bits >> code.rootBits) & ((1 << bits) - 1))];
  }

  /// Counts one more Huffman block, dynamic or fixed, before its header is
  /// read, refusing it once the zip's streams have started
  /// [_freeHuffmanBlocks], plus one per stream, plus one per
  /// [_outputPerHuffmanBlock] bytes of their output so far (design Z5,
  /// RZ13), so streams that build tables and write little are refused
  /// before their cost outgrows the zip's entries and output.
  void _startHuffmanBlock() {
    final budget = _budget;
    if (budget._blocks >=
        _freeHuffmanBlocks +
            budget._streams +
            (budget._output + _length) ~/ _outputPerHuffmanBlock) {
      throw const InflateFailure(
        'starts more Huffman blocks than its zip allows: 16, plus one per '
        'deflate entry, plus one per 512 bytes of output',
      );
    }
    budget._blocks++;
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
    _codeLengths.build(codeLengths, incompleteAllowed: false);
    final lengths = Uint8List(lengthCount + distanceCount);
    var i = 0;
    while (i < lengths.length) {
      final symbol = _symbol(_codeLengths);
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
    _lengths.build(Uint8List.sublistView(lengths, 0, lengthCount));
    _distances.build(Uint8List.sublistView(lengths, lengthCount));
    _codes(_lengths, _distances);
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
