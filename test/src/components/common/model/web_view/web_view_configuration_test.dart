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

    test('5.3: copyWith(onMessage: null) clears onMessage and keeps the '
        'rest', () {
      final configured = StratumWebViewConfiguration(
        onMessage: onMessage,
        javaScriptEnabled: false,
      );
      final copy = configured.copyWith(onMessage: null);

      expect(copy.onMessage, isNull);
      expect(copy.javaScriptEnabled, isFalse);
    });

    test('co01_02/us03/nf01: NFR-Sec06: toString prints allowedOrigins and '
        'javaScriptEnabled, never a callback', () {
      expect(
        StratumWebViewConfiguration(
          allowedOrigins: {Uri.parse('https://a.example')},
          javaScriptEnabled: false,
          onMessage: onMessage,
        ).toString(),
        'StratumWebViewConfiguration(allowedOrigins: '
        '{https://a.example}, javaScriptEnabled: false)',
      );
    });

    test('co01_02/us03/nf01: NFR-Sec06: a hostile allowed origin prints only '
        'its redacted origin', () {
      final text = StratumWebViewConfiguration(
        allowedOrigins: {
          Uri.parse('https://user:pw@idp.example/reset/9f3a2c?code=X#t=Y'),
        },
      ).toString();

      expect(
        text,
        'StratumWebViewConfiguration(allowedOrigins: '
        '{https://idp.example/…}, javaScriptEnabled: true)',
      );
      for (final leak in ['user', 'pw', 'reset', '9f3a2c', 'code=X', 't=Y']) {
        expect(text, isNot(contains(leak)));
      }
    });

    test('co01_02/us03/nf01: NFR-Sec06: an empty allowlist prints empty '
        'braces', () {
      expect(
        const StratumWebViewConfiguration().toString(),
        'StratumWebViewConfiguration(allowedOrigins: '
        '{}, javaScriptEnabled: true)',
      );
    });

    test('co01_02/us03/nf01: NFR-Sec06: a two-entry allowlist prints both '
        'redacted origins', () {
      expect(
        StratumWebViewConfiguration(
          allowedOrigins: {
            Uri.parse('https://a.example'),
            Uri.parse('https://b.example'),
          },
        ).toString(),
        'StratumWebViewConfiguration(allowedOrigins: '
        '{https://a.example, https://b.example}, javaScriptEnabled: true)',
      );
    });
  });
}
