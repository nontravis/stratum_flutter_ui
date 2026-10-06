import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/config/escape_text.dart';

/// Printable ASCII but `"` and `\`, or a whole `\uXXXX` escape.
final _whole = RegExp(r'^(?:[\x20\x21\x23-\x5b\x5d-\x7e]|\\u[0-9a-f]{4})*$');

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

    test('cuts a longer text at 200 characters and ends it with ...', () {
      expect(escapeZipText('a' * 201), '${'a' * 200}...');
    });

    test('never splits an escape at the cut', () {
      expect(escapeZipText('${'a' * 197}${'é' * 5}'), '${'a' * 197}...');
      expect(escapeZipText('${'a' * 194}${'é' * 5}'), '${'a' * 194}\\u00e9...');
    });

    test('every cut keeps whole escapes within 200 characters', () {
      for (var prefix = 190; prefix <= 200; prefix++) {
        final cut = escapeZipText('${'a' * prefix}${'\u0007' * 10}');
        final kept = cut.substring(0, cut.length - 3);

        expect(cut, endsWith('...'), reason: '$prefix');
        expect(kept, matches(_whole), reason: '$prefix');
        expect(kept.length, lessThanOrEqualTo(200), reason: '$prefix');
      }
    });
  });
}
