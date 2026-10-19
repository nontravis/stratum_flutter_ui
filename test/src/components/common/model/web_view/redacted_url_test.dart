import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/model/web_view/redacted_url.dart';

void main() {
  group('redactedUrl (co01_02/us03/nf01: NFR-Sec06)', () {
    test('a null url prints null', () {
      expect(redactedUrl(null), isNull);
    });

    test('a hostile url keeps only its origin, plus /… for the cut rest', () {
      expect(
        redactedUrl(
          Uri.parse('https://user:pw@idp.example/reset/9f3a2c?code=X#t=Y'),
        ),
        'https://idp.example/…',
      );
    });

    test('an empty path with the default port prints the bare origin', () {
      expect(
        redactedUrl(Uri.parse('HTTPS://A.Example:443/')),
        'https://a.example',
      );
    });

    test('no path at all prints the bare origin, the same as a bare '
        'slash', () {
      expect(redactedUrl(Uri.parse('https://a.example')), 'https://a.example');
    });

    test('a present but empty query still cuts the rest', () {
      expect(
        redactedUrl(Uri.parse('https://a.example?')),
        'https://a.example/…',
      );
    });

    test('a present but empty fragment still cuts the rest', () {
      expect(
        redactedUrl(Uri.parse('https://a.example#')),
        'https://a.example/…',
      );
    });

    test('a data url prints only its scheme, never the payload', () {
      expect(
        redactedUrl(Uri.parse('data:text/plain;base64,c2VjcmV0')),
        'data:…',
      );
    });

    test('a protocol-relative url keeps its host and cuts the path', () {
      expect(
        redactedUrl(Uri.parse('//attacker.example/x')),
        '//attacker.example/…',
      );
    });

    test('an IPv6 host with a non-default port and a path keeps the port '
        'and cuts the path', () {
      expect(
        redactedUrl(Uri.parse('http://[::1]:8080/p')),
        'http://[::1]:8080/…',
      );
    });

    test('a scheme with no host prints only the scheme', () {
      expect(redactedUrl(Uri.parse('javascript:alert(1)')), 'javascript:…');
    });

    test('a triple-slash scheme with an empty host prints only the scheme', () {
      expect(redactedUrl(Uri.parse('file:///etc/x')), 'file:…');
    });

    test('no scheme and no host prints the ellipsis alone', () {
      expect(redactedUrl(Uri.parse('app.example.com/a')), '…');
    });
  });
}
