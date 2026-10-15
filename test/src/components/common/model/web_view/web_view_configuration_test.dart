import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/model/web_view/web_view_configuration.dart';
import 'package:stratum_ui/src/components/common/model/web_view/web_view_message.dart';

void main() {
  group('D4: StratumWebViewConfiguration as a freezed value', () {
    void onMessage(StratumWebViewMessage message) {}

    test('D4: equal settings and the same callbacks are equal', () {
      // Built at run time from a parameter, so the checks read `==`.
      StratumWebViewConfiguration make({required bool javaScript}) =>
          StratumWebViewConfiguration(
            allowedOrigins: {Uri.parse('https://a.example')},
            javaScriptEnabled: javaScript,
            onMessage: onMessage,
          );

      expect(make(javaScript: true), make(javaScript: true));
      expect(make(javaScript: true).hashCode, make(javaScript: true).hashCode);
      expect(make(javaScript: true), isNot(make(javaScript: false)));
    });

    test('D4, R1: the callbacks compare by identity', () {
      expect(
        StratumWebViewConfiguration(onPageStarted: (_) {}),
        isNot(StratumWebViewConfiguration(onPageStarted: (_) {})),
      );
    });

    test('D4: copyWith changes one field and keeps the callbacks', () {
      final copy = StratumWebViewConfiguration(onMessage: onMessage)
          .copyWith(javaScriptEnabled: false);

      expect(copy.onMessage, onMessage);
      expect(copy.javaScriptEnabled, isFalse);
      expect(copy.allowedOrigins, isEmpty);
    });
  });
}
