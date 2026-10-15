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

  test('R4 Q2: its own toString stays', () {
    expect(
      const StratumWebViewMessage(data: 'hi').toString(),
      'StratumWebViewMessage(data: hi, origin: null)',
    );
  });
}
