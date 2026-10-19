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

    test('judges by host, not by user info that looks like a host', () {
      expect(
        isAllowedOrigin(Uri.parse('https://app.example.com@evil.com'), allowed),
        isFalse,
      );
      expect(
        isAllowedOrigin(Uri.parse('https://evil.com@app.example.com'), allowed),
        isTrue,
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

  group('allowedOriginProblem (co01_02/us03/nf01: NFR-Sec06)', () {
    test('names a scheme-less entry by position and its redacted form', () {
      expect(
        allowedOriginProblem(2, Uri.parse('app.example.com')),
        'entry 2 (…) needs an http or https scheme',
      );
    });

    test('names a non-http(s) scheme entry by its redacted origin', () {
      expect(
        allowedOriginProblem(1, Uri.parse('ftp://app.example.com')),
        'entry 1 (ftp://app.example.com) needs an http or https scheme',
      );
    });

    test('names a host-less entry by its redacted scheme', () {
      expect(
        allowedOriginProblem(1, Uri(scheme: 'https')),
        'entry 1 (https:…) has no host',
      );
    });

    test('names a non-ASCII host entry by its redacted, lowercased origin', () {
      expect(
        allowedOriginProblem(3, Uri.parse('https://bücher.de')),
        'entry 3 (https://b%C3%BCcher.de) has a non-ASCII host; use its '
        'punycode form (xn--…)',
      );
    });

    test('a hostile entry never surfaces its user info, path, query, or '
        'fragment', () {
      final text = allowedOriginProblem(
        1,
        Uri.parse('ftp://user:pw@partner.example/x?token=abc#f'),
      );

      expect(
        text,
        'entry 1 (ftp://partner.example/…) needs an http or '
        'https scheme',
      );
      for (final leak in ['user', 'pw', '/x', 'token=abc', '#f']) {
        expect(text, isNot(contains(leak)));
      }
    });

    test('returns null for a working http or https entry', () {
      expect(
        allowedOriginProblem(1, Uri.parse('https://app.example.com')),
        isNull,
      );
    });
  });
}
