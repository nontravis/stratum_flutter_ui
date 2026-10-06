/// The longest escaped text a message holds before `...` cuts it.
const _maxEscapedText = 200;

/// Returns [text], which a zip or a theme file supplied, fit for a message
/// (FO-04 S-06, FO-01 S-06): each UTF-16 code unit outside U+0020 to
/// U+007E, and each `"` and `\`, as `\u` and four lower-case hex digits.
/// Past 200 characters it keeps the longest run of whole characters and
/// escapes that fits in 200, never splitting an escape, then `...`.
String escapeZipText(String text) {
  final out = StringBuffer();
  for (final unit in text.codeUnits) {
    final piece = unit < 0x20 || unit > 0x7E || unit == 0x22 || unit == 0x5C
        ? '\\u${unit.toRadixString(16).padLeft(4, '0')}'
        : String.fromCharCode(unit);
    if (out.length + piece.length > _maxEscapedText) return '$out...';
    out.write(piece);
  }
  return out.toString();
}
