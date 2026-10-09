import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;

/// The longest escaped text a message holds before the cut marker.
const _maxEscapedText = 200;

/// Returns [text], which a zip or a theme file supplied, fit for a message
/// (FO-04 S-06, FO-01 S-06): each UTF-16 code unit outside U+0020 to
/// U+007E, and each `"` and `\`, as `\u` and four lower-case hex digits.
/// An escaped text of at most 200 characters returns whole; a longer one
/// keeps the longest run of whole characters and escapes that fits in
/// 200, never splitting an escape, then the marker `\[cut N chars, id H]`
/// (FO-04 US-01 FR-02 E12): N is [text]'s length in UTF-16 code units,
/// and H the first 32 lower-case hex digits of the SHA-256 over those code
/// units, each as two bytes big-endian. Every `\` of [text] is escaped, so
/// `\[` never comes from it and the marker is out of band.
String escapeZipText(String text) {
  final out = StringBuffer();
  for (final unit in text.codeUnits) {
    final piece = unit < 0x20 || unit > 0x7E || unit == 0x22 || unit == 0x5C
        ? '\\u${unit.toRadixString(16).padLeft(4, '0')}'
        : String.fromCharCode(unit);
    if (out.length + piece.length > _maxEscapedText) {
      return '$out${_cutMarker(text)}';
    }
    out.write(piece);
  }
  return out.toString();
}

/// The marker that follows a cut [text]: its length in UTF-16 code units
/// and the first 32 hex digits of the SHA-256 over those code units, each
/// as two bytes big-endian, exact for a lone surrogate too.
String _cutMarker(String text) {
  final bytes = Uint8List(text.length * 2);
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    bytes[2 * i] = unit >> 8;
    bytes[2 * i + 1] = unit & 0xFF;
  }
  final id = sha256.convert(bytes).toString().substring(0, 32);
  return '\\[cut ${text.length} chars, id $id]';
}
