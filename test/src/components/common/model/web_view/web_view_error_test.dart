import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/model/web_view/web_view_error.dart';

void main() {
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

  test('5.3: copyWith changes one field and keeps the rest', () {
    final error = StratumWebViewError(
      type: StratumWebViewErrorType.http,
      description: 'Not Found',
      code: 404,
      url: Uri.parse('https://a.example'),
    );
    final copy = error.copyWith(code: 500);

    expect(copy.code, 500);
    expect(copy.type, StratumWebViewErrorType.http);
    expect(copy, isNot(error));
  });

  test('5.3: copyWith(url: null) clears url and keeps the rest', () {
    final error = StratumWebViewError(
      type: StratumWebViewErrorType.network,
      description: 'DNS lookup failed',
      code: -2,
      url: Uri.parse('https://a.example'),
    );
    final copy = error.copyWith(url: null);

    expect(copy.url, isNull);
    expect(
      copy,
      StratumWebViewError(
        type: StratumWebViewErrorType.network,
        description: 'DNS lookup failed',
        code: -2,
      ),
    );
  });

  test('R4 Q2: its own toString stays', () {
    expect(
      StratumWebViewError(
        type: StratumWebViewErrorType.http,
        description: 'Not Found',
        code: 404,
        url: Uri.parse('https://a.example'),
      ).toString(),
      'StratumWebViewError(http, 404, Not Found, https://a.example)',
    );
  });
}
