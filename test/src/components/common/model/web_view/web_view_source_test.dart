import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/model/web_view/web_view_source.dart';

void main() {
  group('StratumWebViewSource', () {
    test('url sources compare by URL', () {
      expect(
        StratumWebViewSource.url(Uri.parse('https://app.example.com')),
        StratumWebViewSource.url(Uri.parse('https://app.example.com')),
      );
      expect(
        StratumWebViewSource.url(Uri.parse('https://app.example.com')),
        isNot(StratumWebViewSource.url(Uri.parse('https://example.net'))),
      );
    });

    test('html sources compare by content', () {
      expect(
        const StratumWebViewSource.html('<p>A</p>'),
        const StratumWebViewSource.html('<p>A</p>'),
      );
      expect(
        const StratumWebViewSource.html('<p>A</p>'),
        isNot(const StratumWebViewSource.html('<p>B</p>')),
      );
    });

    test('factories create the matching subclass', () {
      expect(
        StratumWebViewSource.url(Uri.parse('https://app.example.com')),
        isA<StratumWebViewUrlSource>(),
      );
      expect(
        const StratumWebViewSource.html('<p>A</p>'),
        isA<StratumWebViewHtmlSource>(),
      );
    });

    test('fo05/us01/fr01/e03, Review Focus 5: two url sources built apart are '
        'equal, and a url source never equals an html one', () {
      // Built at run time from a parameter, so the checks read `==`.
      StratumWebViewSource make(String path) =>
          StratumWebViewSource.url(Uri.parse('https://example.com/$path'));

      expect(make('a'), make('a'));
      expect(make('a').hashCode, make('a').hashCode);
      expect(make('a'), isNot(make('b')));
      expect(
        make('a'),
        isNot(const StratumWebViewSource.html('https://example.com/a')),
      );
    });

    test('5.3: each case copies with copyWith', () {
      final url = StratumWebViewUrlSource(Uri.parse('https://a.example'));
      const html = StratumWebViewHtmlSource('<p>a</p>');

      expect(
        url.copyWith(url: Uri.parse('https://b.example')),
        StratumWebViewSource.url(Uri.parse('https://b.example')),
      );
      expect(
        html.copyWith(html: '<p>b</p>'),
        const StratumWebViewSource.html('<p>b</p>'),
      );
    });

    test('co01_02/us03/nf01: NFR-Sec06: its own toString stays, never '
        'printing the document', () {
      expect(
        StratumWebViewSource.url(Uri.parse('https://a.example')).toString(),
        'StratumWebViewSource.url(https://a.example)',
      );
      expect(
        const StratumWebViewSource.html('<p>secret</p>').toString(),
        'StratumWebViewSource.html(13 chars)',
      );
    });

    test('co01_02/us03/nf01: NFR-Sec06: a hostile url prints only its '
        'redacted origin', () {
      final text = StratumWebViewSource.url(
        Uri.parse('https://user:pw@idp.example/reset/9f3a2c?code=X#t=Y'),
      ).toString();

      expect(text, 'StratumWebViewSource.url(https://idp.example/…)');
      for (final leak in ['user', 'pw', 'reset', '9f3a2c', 'code=X', 't=Y']) {
        expect(text, isNot(contains(leak)));
      }
    });
  });
}
