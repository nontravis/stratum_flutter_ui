import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/model/web_view/web_view_message.dart';

void main() {
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

  test('5.3: copyWith changes one field and keeps the other', () {
    final message = StratumWebViewMessage(
      data: 'a',
      origin: Uri.parse('https://a.example'),
    );
    final copy = message.copyWith(data: 'b');

    expect(copy.data, 'b');
    expect(copy.origin, Uri.parse('https://a.example'));
    expect(copy, isNot(message));
  });

  test('co01_02/us03/nf01: NFR-Sec06: toString prints the data length, never '
      'the data', () {
    expect(
      const StratumWebViewMessage(data: 'hi').toString(),
      'StratumWebViewMessage(2 chars, origin: null)',
    );
  });

  test('co01_02/us03/nf01: NFR-Sec06: empty data prints 0 chars', () {
    expect(
      const StratumWebViewMessage(data: '').toString(),
      'StratumWebViewMessage(0 chars, origin: null)',
    );
  });

  test('co01_02/us03/nf01: NFR-Sec06: a multi-byte character counts as its '
      'UTF-16 code units, the same as String.length', () {
    expect(
      const StratumWebViewMessage(data: '😀').toString(),
      'StratumWebViewMessage(2 chars, origin: null)',
    );
  });

  test('co01_02/us03/nf01: NFR-Sec06: a hostile origin prints only its '
      'redacted origin, and the data never appears', () {
    const data = 'session-token-abc';
    final text = StratumWebViewMessage(
      data: data,
      origin: Uri.parse('https://user:pw@idp.example/reset/9f3a2c?code=X#t=Y'),
    ).toString();

    expect(
      text,
      'StratumWebViewMessage(${data.length} chars, origin: '
      'https://idp.example/…)',
    );
    const leaks = [data, 'user', 'pw', 'reset', '9f3a2c', 'code=X', 't=Y'];
    for (final leak in leaks) {
      expect(text, isNot(contains(leak)));
    }
  });
}
