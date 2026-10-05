import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/message_script.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/native_bridge_session.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

void main() {
  final appOrigin = Uri.parse('https://app.example.com');
  late Set<Uri> allowed;
  late NativeBridgeSession session;

  setUp(() {
    allowed = {appOrigin};
    session = NativeBridgeSession(allowedOrigins: () => allowed);
  });

  group('messages from URL pages', () {
    test('accepts an allowed page and reports its origin', () {
      session
        ..willLoadUrl()
        ..didStartPage('https://app.example.com/home');
      expect(
        session.acceptMessage('hi'),
        StratumWebViewMessage(data: 'hi', origin: appOrigin),
      );
    });

    test('drops a page outside the allowlist', () {
      session
        ..willLoadUrl()
        ..didStartPage('https://evil.example.net/');
      expect(session.acceptMessage('hi'), isNull);
    });

    test('follows URL changes without a page load', () {
      session
        ..willLoadUrl()
        ..didStartPage('https://app.example.com/home')
        ..didChangeUrl('https://evil.example.net/');
      expect(session.acceptMessage('hi'), isNull);
    });

    test('reads the allowlist at message time', () {
      session
        ..willLoadUrl()
        ..didStartPage('https://app.example.com/home');
      allowed = {Uri.parse('https://other.example.net')};
      expect(session.acceptMessage('hi'), isNull);
    });

    test('a null URL change clears the tracked page', () {
      session
        ..willLoadUrl()
        ..didStartPage('https://app.example.com/home')
        ..didChangeUrl(null);
      expect(session.acceptMessage('hi'), isNull);
    });
  });

  group('messages from loaded HTML', () {
    test('accepts messages without an origin', () {
      session
        ..willLoadHtml()
        ..didStartPage('about:blank');
      expect(
        session.acceptMessage('hi'),
        const StratumWebViewMessage(data: 'hi'),
      );
    });

    test('drops messages after the page navigates away', () {
      session
        ..willLoadHtml()
        ..didStartPage('about:blank')
        ..didStartPage('https://evil.example.net/');
      expect(session.acceptMessage('hi'), isNull);
    });

    test('reload keeps the HTML trusted', () {
      session
        ..willLoadHtml()
        ..didStartPage('about:blank')
        ..willReload()
        ..didStartPage('about:blank');
      expect(session.acceptMessage('hi'), isNotNull);
    });

    test('switching from HTML to a URL ends HTML trust at once', () {
      session
        ..willLoadHtml()
        ..didStartPage('about:blank')
        ..willLoadUrl();
      expect(session.acceptMessage('hi'), isNull);
      expect(() => session.scriptForMessage('hi'), throwsStateError);
    });

    test('reload after navigating away does not restore trust', () {
      session
        ..willLoadHtml()
        ..didStartPage('about:blank')
        ..didStartPage('https://evil.example.net/')
        ..willReload()
        ..didStartPage('https://evil.example.net/');
      expect(session.acceptMessage('hi'), isNull);
    });

    test('does not trust a foreign page still shown during an html switch', () {
      session
        ..willLoadUrl()
        ..didStartPage('https://evil.example.net/')
        ..willLoadHtml();
      expect(session.acceptMessage('hi'), isNull);
      expect(() => session.scriptForMessage('hi'), throwsStateError);
      session.didStartPage('about:blank');
      expect(
        session.acceptMessage('hi'),
        const StratumWebViewMessage(data: 'hi'),
      );
    });

    test('a late report of a foreign page after reload is not our html', () {
      session
        ..willLoadHtml()
        ..didStartPage('about:blank')
        ..willReload()
        ..didStartPage('https://evil.example.net/');
      expect(session.acceptMessage('hi'), isNull);
    });

    test('a late start of a superseded URL does not take the html slot', () {
      session
        ..willLoadUrl()
        ..willLoadHtml()
        ..didStartPage('https://app.example.com/a')
        ..didStartPage('about:blank');
      expect(
        session.acceptMessage('hi'),
        const StratumWebViewMessage(data: 'hi'),
      );
    });

    test(
      'an unknown URL during an html switch does not trust the old page',
      () {
        session
          ..willLoadUrl()
          ..didStartPage('https://evil.example.net/')
          ..willLoadHtml()
          ..didChangeUrl(null);
        expect(session.acceptMessage('hi'), isNull);
        expect(() => session.scriptForMessage('hi'), throwsStateError);
        session.didStartPage('about:blank');
        expect(
          session.acceptMessage('hi'),
          const StratumWebViewMessage(data: 'hi'),
        );
      },
    );
  });

  group('scriptForMessage', () {
    test('builds the dispatch script for an allowed page', () {
      session
        ..willLoadUrl()
        ..didStartPage('https://app.example.com/');
      expect(
        session.scriptForMessage('ping'),
        buildMessageDispatchScript('ping'),
      );
    });

    test('refuses a page outside the allowlist', () {
      session
        ..willLoadUrl()
        ..didStartPage('https://evil.example.net/');
      expect(() => session.scriptForMessage('ping'), throwsStateError);
    });

    test('refusal error names the origin, not the full URL', () {
      session
        ..willLoadUrl()
        ..didStartPage('https://evil.example.net/path?x=secret#tok');
      expect(
        () => session.scriptForMessage('ping'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'The current page (https://evil.example.net) is not an '
                'allowed message destination.',
          ),
        ),
      );
    });

    test('refuses to build a script before any page', () {
      expect(() => session.scriptForMessage('ping'), throwsStateError);
    });

    test('allows loaded HTML', () {
      session
        ..willLoadHtml()
        ..didStartPage('about:blank');
      expect(session.scriptForMessage('ping'), isNotEmpty);
    });
  });

  group('errors', () {
    test('maps main-frame network errors, treating null as main frame', () {
      const expected = StratumWebViewError(
        type: StratumWebViewErrorType.network,
        description: 'offline',
        code: -2,
      );
      expect(
        session.networkError(
          code: -2,
          description: 'offline',
          isForMainFrame: true,
          url: null,
        ),
        expected,
      );
      expect(
        session.networkError(
          code: -2,
          description: 'offline',
          isForMainFrame: null,
          url: null,
        ),
        expected,
      );
    });

    test('maps the failing URL of a network error', () {
      expect(
        session
            .networkError(
              code: -6,
              description: 'refused',
              isForMainFrame: true,
              url: 'https://app.example.com/x',
            )
            ?.url,
        Uri.parse('https://app.example.com/x'),
      );
    });

    test('describes an HTTP error without a status code', () {
      session.didStartPage('https://app.example.com/home');
      final error = session.httpError(
        statusCode: null,
        requestUrl: Uri.parse('https://app.example.com/home'),
      );
      expect(error?.description, 'HTTP error');
      expect(error?.code, isNull);
    });

    test('drops sub-frame network errors', () {
      expect(
        session.networkError(
          code: -2,
          description: 'offline',
          isForMainFrame: false,
          url: 'https://ads.example.net/',
        ),
        isNull,
      );
    });

    test('maps HTTP errors for the current page only', () {
      session.didStartPage('https://app.example.com/home');
      expect(
        session.httpError(
          statusCode: 404,
          requestUrl: Uri.parse('https://app.example.com/logo.png'),
        ),
        isNull,
      );
      expect(
        session.httpError(
          statusCode: 500,
          requestUrl: Uri.parse('https://app.example.com/home#top'),
        ),
        StratumWebViewError(
          type: StratumWebViewErrorType.http,
          description: 'HTTP error 500',
          code: 500,
          url: Uri.parse('https://app.example.com/home#top'),
        ),
      );
    });

    test('us01/fr02: an HTTP error on the navigation target before its page '
        'starts is held until that page starts', () {
      final target = Uri.parse('https://app.example.com/missing');
      session.willNavigate(target);
      expect(session.httpError(statusCode: 404, requestUrl: target), isNull);
      expect(
        session.didStartPage('https://app.example.com/missing#top'),
        StratumWebViewError(
          type: StratumWebViewErrorType.http,
          description: 'HTTP error 404',
          code: 404,
          url: target,
        ),
      );
      expect(session.didFinishPage(), isNull);
    });

    test('us01/fr02: a held HTTP error whose page never starts is released '
        'by the next page finish', () {
      final target = Uri.parse('https://app.example.com/missing');
      session.willNavigate(target);
      expect(session.httpError(statusCode: 404, requestUrl: target), isNull);
      expect(session.didStartPage('https://app.example.com/home'), isNull);
      expect(session.didFinishPage()?.url, target);
      expect(session.didFinishPage(), isNull);
    });

    test('us01/fr02: a URL load, an HTML load, or dispose discards a held '
        'HTTP error', () {
      final target = Uri.parse('https://app.example.com/missing');
      void hold() {
        session.willNavigate(target);
        expect(session.httpError(statusCode: 404, requestUrl: target), isNull);
      }

      hold();
      session.willLoadUrl();
      expect(session.didFinishPage(), isNull);
      hold();
      session.willLoadHtml();
      expect(session.didFinishPage(), isNull);
      hold();
      session.willDispose();
      expect(session.didFinishPage(), isNull);
    });

    test('us01/fr02: an empty path matches its canonical slash, fragment '
        'ignored', () {
      session.willNavigate(Uri.parse('https://app.example.com'));
      expect(
        session.httpError(
          statusCode: 404,
          requestUrl: Uri.parse('https://app.example.com/#top'),
        ),
        isNull,
      );
      expect(
        session.didStartPage('https://app.example.com/')?.url,
        Uri.parse('https://app.example.com/#top'),
      );
      expect(
        session
            .httpError(
              statusCode: 500,
              requestUrl: Uri.parse('https://app.example.com'),
            )
            ?.url,
        Uri.parse('https://app.example.com'),
      );
    });

    test('us01/fr02/e02: only the start of the target page, or an HTML load, '
        'ends the navigation target', () {
      final target = Uri.parse('https://app.example.com/missing');
      session
        ..willNavigate(target)
        ..didStartPage('https://app.example.com/home');
      expect(session.httpError(statusCode: 404, requestUrl: target), isNull);
      expect(session.didStartPage(target.toString())?.url, target);
      // The target page has started: its errors now pass at once.
      expect(session.httpError(statusCode: 500, requestUrl: target)?.code, 500);
      // An HTML load ends the target too.
      final next = Uri.parse('https://app.example.com/next');
      session
        ..willNavigate(next)
        ..willLoadHtml();
      expect(session.httpError(statusCode: 404, requestUrl: next), isNull);
      expect(session.didFinishPage(), isNull);
    });

    test('drops HTTP errors before any page', () {
      expect(
        session.httpError(
          statusCode: 500,
          requestUrl: Uri.parse('https://app.example.com/'),
        ),
        isNull,
      );
    });

    test('treats a null request URL as the current page', () {
      session.didStartPage('https://app.example.com/home');
      expect(
        session.httpError(statusCode: 500, requestUrl: null),
        StratumWebViewError(
          type: StratumWebViewErrorType.http,
          description: 'HTTP error 500',
          code: 500,
          url: Uri.parse('https://app.example.com/home'),
        ),
      );
    });

    test('us01/fr02/e07: WebKit order, a null request URL after a redirect '
        'names the target', () {
      session
        ..didStartPage('https://app.example.com/start')
        ..didChangeUrl('https://app.example.com/gone');
      expect(
        session.httpError(statusCode: 404, requestUrl: null),
        StratumWebViewError(
          type: StratumWebViewErrorType.http,
          description: 'HTTP error 404',
          code: 404,
          url: Uri.parse('https://app.example.com/gone'),
        ),
      );
    });

    test('treats a null request URL as the page before any page', () {
      expect(
        session.httpError(statusCode: 500, requestUrl: null),
        const StratumWebViewError(
          type: StratumWebViewErrorType.http,
          description: 'HTTP error 500',
          code: 500,
        ),
      );
    });
  });
}
