import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/config/escape_text.dart';

/// Printable ASCII but `"` and `\`, or a whole `\uXXXX` escape.
final _whole = RegExp(r'^(?:[\x20\x21\x23-\x5b\x5d-\x7e]|\\u[0-9a-f]{4})*$');

/// The marker that ends a cut text: `\[cut N chars, id H]`.
final _marker = RegExp(r'\\\[cut (\d+) chars, id ([0-9a-f]{32})\]$');

void main() {
  group('us01/fr02/e12, fo01 us02/fr01/e05, minor7: escapeZipText', () {
    test('escapes each unit outside printable ASCII, each quote, and each '
        'backslash', () {
      expect(
        escapeZipText('a"\\\n\u{e9}\u{1F600}'),
        r'a\u0022\u005c\u000a\u00e9\ud83d\ude00',
      );
    });

    test('keeps a text of 200 characters whole', () {
      expect(escapeZipText('a' * 200), 'a' * 200);
    });

    test('rz4: cuts a longer text at 200 characters and ends it with the '
        'marker of its length and id', () {
      expect(
        escapeZipText('a' * 201),
        '${'a' * 200}\\[cut 201 chars, id e9bd4c0ef334a7a492ef7a98202f0e69]',
      );
    });

    test('never splits an escape at the cut', () {
      expect(
        escapeZipText('${'a' * 197}${'é' * 5}'),
        startsWith('${'a' * 197}\\[cut 202 chars, id '),
      );
      expect(
        escapeZipText('${'a' * 194}${'é' * 5}'),
        startsWith('${'a' * 194}\\u00e9\\[cut 199 chars, id '),
      );
    });

    test('every cut keeps whole escapes within 200 characters, then the '
        'marker with the whole text length', () {
      for (var prefix = 190; prefix <= 200; prefix++) {
        final text = '${'a' * prefix}${'\u0007' * 10}';
        final cut = escapeZipText(text);
        final marker = _marker.firstMatch(cut);

        expect(marker, isNotNull, reason: '$prefix');
        final kept = cut.substring(0, marker!.start);
        expect(kept, matches(_whole), reason: '$prefix');
        expect(kept.length, lessThanOrEqualTo(200), reason: '$prefix');
        expect(marker.group(1), '${text.length}', reason: '$prefix');
      }
    });

    test('rz4, r19 (t28): two names that share their first 200 escaped '
        'characters print distinct ids', () {
      expect(
        escapeZipText('${'b' * 200}.html'),
        '${'b' * 200}\\[cut 205 chars, id f866e1e88ad77944367513ab1d5ccbf1]',
      );
      expect(
        escapeZipText('${'b' * 200}.exe'),
        '${'b' * 200}\\[cut 204 chars, id 8c7ec01dccafb8f22aa393f9cd527ca3]',
      );
    });

    test('rz4, r19 (t28): a 200-character text ending in ... prints whole, '
        'and one that ends in a letter the cut drops carries the marker', () {
      expect(escapeZipText('${'a' * 197}...'), '${'a' * 197}...');
      expect(
        escapeZipText('${'a' * 197}é'),
        '${'a' * 197}\\[cut 198 chars, id f6a65ddf2fffa8f36aa3d7f6242810ee]',
      );
    });

    test('rz4: the id is exact for a lone surrogate', () {
      expect(
        escapeZipText('${'a' * 300}${String.fromCharCode(0xD800)}'),
        '${'a' * 200}\\[cut 301 chars, id 02f3479ecaf4534dfa1c7d9710e4c779]',
      );
    });

    test('rz4: a text cannot forge the marker, since its backslash '
        'escapes', () {
      final forged = '${'a' * 10}\\[cut 5 chars, id ${'0' * 32}]';

      expect(
        escapeZipText(forged),
        '${'a' * 10}\\u005c[cut 5 chars, id ${'0' * 32}]',
      );
    });
  });
}
