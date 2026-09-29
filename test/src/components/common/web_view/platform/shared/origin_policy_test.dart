import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/origin_policy.dart';

void main() {
  group('originOf', () {
    test('drops path, query, and fragment', () {
      expect(
        originOf(Uri.parse('https://app.example.com/a/b?q=1#top')),
        Uri.parse('https://app.example.com'),
      );
    });

    test('lowercases scheme and host', () {
      expect(
        originOf(Uri.parse('HTTPS://App.Example.COM')),
        Uri.parse('https://app.example.com'),
      );
    });

    test('keeps a non-default port', () {
      expect(
        originOf(Uri.parse('https://app.example.com:8443/x')),
        Uri.parse('https://app.example.com:8443'),
      );
    });

    test('returns null without a host', () {
      expect(originOf(null), isNull);
      expect(originOf(Uri.parse('about:blank')), isNull);
      expect(originOf(Uri.parse('null')), isNull);
    });
  });

  group('isAllowedOrigin', () {
    final allowed = {Uri.parse('https://app.example.com')};

    test('matches the same origin with any path', () {
      expect(
        isAllowedOrigin(Uri.parse('https://app.example.com/page'), allowed),
        isTrue,
      );
    });

    test('treats an explicit default port as equal', () {
      expect(
        isAllowedOrigin(Uri.parse('https://app.example.com:443'), allowed),
        isTrue,
      );
    });

    test('compares hosts case-insensitively', () {
      expect(
        isAllowedOrigin(Uri.parse('https://APP.example.com'), allowed),
        isTrue,
      );
    });

    test('rejects another scheme', () {
      expect(
        isAllowedOrigin(Uri.parse('http://app.example.com'), allowed),
        isFalse,
      );
    });

    test('rejects another port', () {
      expect(
        isAllowedOrigin(Uri.parse('https://app.example.com:8443'), allowed),
        isFalse,
      );
    });

    test('rejects a subdomain and a lookalike suffix', () {
      expect(
        isAllowedOrigin(Uri.parse('https://evil.app.example.com'), allowed),
        isFalse,
      );
      expect(
        isAllowedOrigin(Uri.parse('https://app.example.com.evil.io'), allowed),
        isFalse,
      );
    });

    test('rejects null and host-less origins', () {
      expect(isAllowedOrigin(null, allowed), isFalse);
      expect(isAllowedOrigin(Uri.parse('null'), allowed), isFalse);
    });

    test('rejects everything when the allowlist is empty', () {
      expect(
        isAllowedOrigin(Uri.parse('https://app.example.com'), const {}),
        isFalse,
      );
    });

    test('allowlist entries with paths match by origin', () {
      expect(
        isAllowedOrigin(Uri.parse('https://app.example.com/other'), {
          Uri.parse('https://app.example.com/app/'),
        }),
        isTrue,
      );
    });
  });
}
