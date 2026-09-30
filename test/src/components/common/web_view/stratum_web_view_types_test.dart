import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

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
  });

  test('messages compare by data and origin', () {
    final origin = Uri.parse('https://app.example.com');
    expect(
      StratumWebViewMessage(data: 'hi', origin: origin),
      StratumWebViewMessage(data: 'hi', origin: origin),
    );
    expect(
      const StratumWebViewMessage(data: 'hi'),
      isNot(StratumWebViewMessage(data: 'hi', origin: origin)),
    );
  });

  test('errors compare by every field', () {
    final url = Uri.parse('https://app.example.com');
    expect(
      StratumWebViewError(
        type: StratumWebViewErrorType.http,
        description: 'HTTP error 500',
        code: 500,
        url: url,
      ),
      StratumWebViewError(
        type: StratumWebViewErrorType.http,
        description: 'HTTP error 500',
        code: 500,
        url: url,
      ),
    );
  });

  test('errors differ when any single field differs', () {
    final base = StratumWebViewError(
      type: StratumWebViewErrorType.http,
      description: 'HTTP error 500',
      code: 500,
      url: Uri.parse('https://app.example.com'),
    );
    final variants = [
      StratumWebViewError(
        type: StratumWebViewErrorType.network,
        description: base.description,
        code: base.code,
        url: base.url,
      ),
      StratumWebViewError(
        type: base.type,
        description: 'other',
        code: base.code,
        url: base.url,
      ),
      StratumWebViewError(
        type: base.type,
        description: base.description,
        code: 404,
        url: base.url,
      ),
      StratumWebViewError(
        type: base.type,
        description: base.description,
        code: base.code,
        url: Uri.parse('https://example.net'),
      ),
    ];
    for (final variant in variants) {
      expect(variant, isNot(base), reason: '$variant');
    }
  });
}
