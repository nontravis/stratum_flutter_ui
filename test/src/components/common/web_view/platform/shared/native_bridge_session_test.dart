import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/html_bridge_bootstrap.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/message_script.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/native_bridge_session.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

import '../../fakes/native_bridge_envelope.dart';

const String tag = nativeBridgeEnvelopeTag;

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
    test('us03/fr04: a message with the current nonce reaches the app with '
        'no origin and without its envelope', () {
      final nonce = nonceIn(session.willLoadHtml('<p>Hi</p>'));
      session.didStartPage('about:blank');
      expect(
        session.acceptMessage(envelope(nonce, 'message', 'hi:there')),
        const StratumWebViewMessage(data: 'hi:there'),
      );
    });

    test('us03/fr04/e01: page starts, finishes, and URL changes in any '
        'order neither grant nor end trust', () {
      final nonce = nonceIn(session.willLoadHtml('<p>Hi</p>'));
      // A message that beats the HTML's own page start (F1's order).
      expect(session.acceptMessage(envelope(nonce, 'message', 'a')), isNotNull);
      session
        ..didStartPage('https://evil.example.net/')
        ..didStartPage('about:blank')
        ..didChangeUrl(null);
      expect(session.didFinishPage(), isTrue);
      expect(session.acceptMessage(envelope(nonce, 'message', 'b')), isNotNull);
      // The page the HTML replaced cannot know the nonce.
      expect(session.acceptMessage('untagged'), isNull);
    });

    test('us03/fr04/e02: a null, empty, unparsable, or blob: page URL never '
        'passes an untagged message as own HTML', () {
      session.willLoadHtml('<p>Hi</p>');
      for (final url in [
        'about:blank',
        '',
        'http://[::1',
        'blob:https://evil.example.net/0b5c',
      ]) {
        session.didStartPage(url);
        expect(session.acceptMessage('hi'), isNull, reason: url);
      }
      session.didChangeUrl(null);
      expect(session.acceptMessage('hi'), isNull);
    });

    test('us03/fr04/e03: back or forward to the current HTML entry passes; '
        'an older loadHtml stays off', () {
      final older = nonceIn(session.willLoadHtml('<p>One</p>'));
      final current = nonceIn(session.willLoadHtml('<p>Two</p>'));
      session
        ..didStartPage('about:blank')
        // A link away, then the controller's goBack.
        ..didStartPage('https://app.example.com/linked')
        ..willNavigate()
        ..didStartPage('about:blank');
      expect(session.acceptMessage(envelope(older, 'message', 'x')), isNull);
      expect(
        session.acceptMessage(envelope(current, 'message', 'x')),
        const StratumWebViewMessage(data: 'x'),
      );
    });

    test('us03/fr04/e04: a reload keeps the nonce and the proof', () {
      final html = session.willLoadHtml('<p>Hi</p>');
      session
        ..acceptMessage(envelope(nonceIn(html), 'hello'))
        ..willReload()
        ..didStartPage('about:blank');
      expect(
        session.acceptMessage(envelope(nonceIn(html), 'message', 'x')),
        isNotNull,
      );
      expect(session.scriptForMessage('ping'), contains(tokenIn(html)));
    });

    test('us03/fr04/e05: a malformed envelope, an unknown kind, a missing '
        'field, or a stale or forged nonce is dropped with no side '
        'effect', () {
      final nonce = nonceIn(session.willLoadHtml('<p>Hi</p>'));
      for (final bad in [
        tag,
        '$tag$nonce',
        '$tag$nonce:',
        '$tag$nonce:message',
        '${tag}x$nonce:message:hi',
        '$tag$nonce:ping:hi',
        '$tag$nonce:hello:x',
        '$tag${nonce.toUpperCase()}:hello:',
        '$tag${'0' * 32}:hello:',
        '$tag${nonce.substring(1)}:hello:',
      ]) {
        expect(session.acceptMessage(bad), isNull, reason: bad);
      }
      expect(
        () => session.scriptForMessage('ping'),
        throwsA(isA<StateError>()),
        reason: 'no envelope above may prove the nonce',
      );
    });

    test('us03/fr04/e06, us03/fr01/e12: a tagged message is judged only by '
        'its nonce, so an allowed page that sends one is dropped', () {
      session
        ..willLoadUrl()
        ..didStartPage('https://app.example.com/home');
      expect(session.acceptMessage(envelope('a' * 32, 'message', 'x')), isNull);
      expect(session.acceptMessage('untagged'), isNotNull);
    });

    test('us03/fr04/e08: a hello before the HTML page start, a later page '
        'start, and a URL change keep the proof', () {
      final html = session.willLoadHtml('<p>Hi</p>');
      session
        ..acceptMessage(envelope(nonceIn(html), 'hello'))
        ..didStartPage('about:blank')
        ..didStartPage('https://app.example.com/next')
        ..didChangeUrl(null);
      expect(session.scriptForMessage('ping'), contains(tokenIn(html)));
    });

    test('us03/fr04: loadUrl and dispose revoke the nonce and the token', () {
      for (final revoke in <void Function()>[
        session.willLoadUrl,
        session.willDispose,
      ]) {
        final html = session.willLoadHtml('<p>Hi</p>');
        session
          ..acceptMessage(envelope(nonceIn(html), 'hello'))
          ..didStartPage('about:blank');
        revoke();
        expect(
          session.acceptMessage(envelope(nonceIn(html), 'message', 'x')),
          isNull,
        );
        expect(session.scriptForMessage('ping'), isNot(contains('t===')));
      }
    });

    test('nf01/NFR-Sec03: every loadHtml of every session mints a fresh '
        'inbound nonce and an independent outbound token', () {
      final other = NativeBridgeSession(allowedOrigins: () => allowed);
      final secrets = [
        for (final html in [
          session.willLoadHtml('<p>1</p>'),
          session.willLoadHtml('<p>2</p>'),
          other.willLoadHtml('<p>1</p>'),
        ]) ...[nonceIn(html), tokenIn(html)],
      ];
      expect(secrets.toSet(), hasLength(6));
      for (final secret in secrets) {
        expect(secret, matches(RegExp(r'^[0-9a-f]{32}$')));
      }
    });

    test('nf01/NFR-Sec03: no secret reaches a delivered message or an error '
        'text', () {
      final html = session.willLoadHtml('<p>Hi</p>');
      final secrets = [nonceIn(html), tokenIn(html)];
      final message = session.acceptMessage(
        envelope(nonceIn(html), 'message', 'x'),
      )!;
      for (final secret in secrets) {
        expect(message.data, isNot(contains(secret)));
        expect('$message', isNot(contains(secret)));
        expect(
          () => session.scriptForMessage('ping'),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              isNot(contains(secret)),
            ),
          ),
        );
      }
    });

    test('Q9-OQ-A3: a message has no size limit', () {
      final nonce = nonceIn(session.willLoadHtml('<p>Hi</p>'));
      final big = 'x' * (1 << 20);
      expect(session.acceptMessage(envelope(nonce, 'message', big))?.data, big);
    });
  });

  group('scriptForMessage', () {
    test('us03/fr02/e04: an HTML load not yet proven throws, whatever page '
        'shows', () {
      session
        ..willLoadUrl()
        ..didStartPage('https://app.example.com/home')
        ..willLoadHtml('<p>Hi</p>');
      final unproven = throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'The HTML page has not connected the bridge yet.',
        ),
      );
      expect(() => session.scriptForMessage('ping'), unproven);
      session.didStartPage('https://app.example.com/home');
      expect(() => session.scriptForMessage('ping'), unproven);
    });

    test('us03/fr02/e03: after the proof the script carries the outbound '
        'token and never the inbound nonce', () {
      final html = session.willLoadHtml('<p>Hi</p>');
      session.acceptMessage(envelope(nonceIn(html), 'hello'));
      final script = session.scriptForMessage('ping');
      expect(script, contains("t==='${tokenIn(html)}'"));
      expect(script, isNot(contains(nonceIn(html))));
    });

    test('us03/fr02/e10: with no current nonce the script checks the '
        'allowed origins only, read at send time', () {
      session
        ..willLoadUrl()
        ..didStartPage('https://app.example.com/');
      allowed = {appOrigin, Uri.parse('https://other.example.net')};
      expect(
        session.scriptForMessage('ping'),
        buildMessageDispatchScript(
          'ping',
          token: null,
          allowedOrigins: allowed,
        ),
      );
    });

    test('us03/fr02/e10: before any page the script still runs, and the '
        'page decides', () {
      expect(session.scriptForMessage('ping'), isNotEmpty);
    });

    test('us03/fr02/e03: confirmDelivery accepts true and throws a '
        'StateError naming no origin for anything else', () {
      session.confirmDelivery(true);
      for (final result in <Object?>[false, 'true', 1, null, '']) {
        expect(
          () => session.confirmDelivery(result),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'The current page is not an allowed message destination.',
            ),
          ),
          reason: '$result',
        );
      }
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

    test('us01/fr02: an HTTP error before its page starts is held as the '
        'candidate of its URL and released right after that page starts', () {
      final page = Uri.parse('https://app.example.com/missing');
      expect(session.httpError(statusCode: 404, requestUrl: page), isNull);
      expect(
        session.didStartPage('https://app.example.com/missing#top'),
        StratumWebViewError(
          type: StratumWebViewErrorType.http,
          description: 'HTTP error 404',
          code: 404,
          url: page,
        ),
      );
      expect(session.didFinishPage(), isTrue);
    });

    test('us01/fr02/e02: a page start discards every candidate of another '
        'URL', () {
      final missing = Uri.parse('https://app.example.com/missing');
      session
        ..httpError(statusCode: 404, requestUrl: missing)
        ..httpError(
          statusCode: 404,
          requestUrl: Uri.parse('https://app.example.com/favicon.ico'),
        );
      expect(session.didStartPage('https://app.example.com/home'), isNull);
      expect(session.didFinishPage(), isTrue);
      expect(session.didStartPage(missing.toString()), isNull);
    });

    test('us01/fr02: the newest HTTP error of a URL replaces its candidate, '
        'so one failure reaches the app once', () {
      final page = Uri.parse('https://app.example.com/missing');
      session
        ..httpError(statusCode: 404, requestUrl: page)
        ..httpError(statusCode: 410, requestUrl: page);
      expect(session.didStartPage(page.toString())?.code, 410);
    });

    test('us01/fr02: at most 16 candidates are held, the oldest dropped '
        'first', () {
      Uri pageOf(int index) => Uri.parse('https://app.example.com/p$index');
      void hold() {
        for (var index = 0; index < 16; index++) {
          session.httpError(statusCode: 404, requestUrl: pageOf(index));
        }
        // p0 fails again and becomes the newest; the 17th URL then drops the
        // oldest, p1.
        session
          ..httpError(statusCode: 410, requestUrl: pageOf(0))
          ..httpError(statusCode: 404, requestUrl: pageOf(16));
      }

      hold();
      expect(session.didStartPage(pageOf(1).toString()), isNull);
      expect(session.didFinishPage(), isTrue);
      hold();
      expect(session.didStartPage(pageOf(0).toString())?.code, 410);
      expect(session.didFinishPage(), isTrue);
      hold();
      expect(session.didStartPage(pageOf(16).toString())?.code, 404);
    });

    test('us01/fr02: every navigation begin and dispose discard every '
        'candidate', () {
      final page = Uri.parse('https://app.example.com/missing');
      for (final begin in <void Function()>[
        session.willLoadUrl,
        () => session.willLoadHtml('<p>Hi</p>'),
        session.willReload,
        session.willNavigate,
        session.didAllowNavigation,
        session.willDispose,
      ]) {
        expect(session.httpError(statusCode: 404, requestUrl: page), isNull);
        begin();
        expect(session.didStartPage(page.toString()), isNull);
        expect(session.didFinishPage(), isTrue);
      }
    });

    test('us01/fr02/e08: an HTTP error on the page itself is held while its '
        'start is closed, so a reload reports start, error, finish', () {
      final page = Uri.parse('https://app.example.com/flip');
      session.didStartPage(page.toString());
      expect(session.didFinishPage(), isTrue);
      // A reload by the controller.
      session.willReload();
      expect(session.httpError(statusCode: 404, requestUrl: page), isNull);
      expect(session.didStartPage(page.toString())?.code, 404);
      expect(session.didFinishPage(), isTrue);
      // A reload by the page's own script: no navigation begin is seen.
      expect(session.httpError(statusCode: 404, requestUrl: page), isNull);
      expect(session.didStartPage(page.toString())?.code, 404);
    });

    test('us01/fr02/e08: a history move the page script starts releases the '
        'candidate of the page it lands on', () {
      final flip = Uri.parse('https://app.example.com/flip');
      session.didStartPage('https://app.example.com/b');
      expect(session.didFinishPage(), isTrue);
      // history.back() in page script: no navigation begin reaches the
      // session, and Android reports the error before the page starts.
      expect(session.httpError(statusCode: 404, requestUrl: flip), isNull);
      expect(session.didStartPage(flip.toString())?.url, flip);
    });

    test('us01/fr02/e09: a sub-resource 404 on the URL a later page-script '
        'history move lands on reaches onError as that page error', () {
      final image = Uri.parse('https://app.example.com/y');
      session.didStartPage('https://app.example.com/x');
      // <img src="/y"> on /x answers 404 while /x loads.
      expect(session.httpError(statusCode: 404, requestUrl: image), isNull);
      expect(session.didFinishPage(), isTrue);
      // history.back() to /y, which now answers 200: with no navigation
      // begin between, arrival before the page start decides.
      expect(session.didStartPage(image.toString())?.url, image);
    });

    test('us01/fr01/e05: a page finish with no open start is dropped and '
        'releases no candidate', () {
      final target = Uri.parse('https://app.example.com/gone');
      // Android after a 302: a finish names the target before it starts.
      expect(session.didFinishPage(), isFalse);
      expect(session.httpError(statusCode: 404, requestUrl: target), isNull);
      expect(session.didFinishPage(), isFalse);
      expect(session.didStartPage(target.toString())?.url, target);
      expect(session.didFinishPage(), isTrue);
      expect(session.didFinishPage(), isFalse);
    });

    test('us04/fr01/e05: a controller goBack with no new start keeps the '
        'open finish', () {
      // R14: a controller action ends only at-once eligibility, never the
      // finish pairing. A goBack with no history entry starts no document.
      session
        ..didStartPage('https://app.example.com/a')
        ..willNavigate();
      expect(session.didFinishPage(), isTrue);
    });

    test('us01/fr01/e05: after a reload whose page never restarts, the old '
        'finish still reports', () {
      // R14: the reload ends only at-once eligibility, so the load it
      // replaces keeps its finish.
      session
        ..didStartPage('https://app.example.com/flip')
        ..willReload();
      expect(session.didFinishPage(), isTrue);
    });

    test('us01/fr02/e08: a tracked-page HTTP error after a controller action '
        'is a candidate, not at once', () {
      // R8 and R9, kept by R14: the controller action ends at-once
      // eligibility, so the error waits for the page it belongs to.
      final page = Uri.parse('https://app.example.com/flip');
      session
        ..didStartPage(page.toString())
        ..willNavigate();
      expect(session.httpError(statusCode: 404, requestUrl: page), isNull);
      expect(session.didStartPage(page.toString())?.code, 404);
    });

    test('us01/fr02/e08: a controller action ends the at-once error '
        'eligibility, so the error of a reload while the page still loads '
        'waits for its start', () {
      // R8, R9, and R14: every controller action ends the at-once
      // eligibility only.
      final page = Uri.parse('https://app.example.com/flip');
      for (final begin in <void Function()>[
        session.willLoadUrl,
        () => session.willLoadHtml('<p>Hi</p>'),
        session.willReload,
        session.willNavigate,
      ]) {
        session.didStartPage(page.toString());
        begin();
        expect(session.httpError(statusCode: 404, requestUrl: page), isNull);
        expect(session.didStartPage(page.toString())?.code, 404);
        expect(session.didFinishPage(), isTrue);
      }
    });

    test('us01/fr01/e05: the late finish of a load that a controller action '
        'replaced pairs with its own start and reaches the app', () {
      // R14: the reload ends only the at-once error eligibility, so the
      // replaced load's finish still pairs with the start it left open.
      const page = 'https://app.example.com/flip';
      session
        ..didStartPage(page)
        ..willReload();
      expect(session.didFinishPage(), isTrue);
      session.didStartPage(page);
      expect(session.didFinishPage(), isTrue);
    });

    test('us01/fr01/e05: an allowed navigation request keeps the open start, '
        'so a WebKit redirect keeps its finish', () {
      // R10: WebKit asks for the redirect target after the page start.
      final target = Uri.parse('https://app.example.com/gone');
      session
        ..didStartPage('https://app.example.com/redirect')
        ..didAllowNavigation()
        ..didChangeUrl(target.toString());
      expect(session.httpError(statusCode: 404, requestUrl: null)?.url, target);
      expect(session.didFinishPage(), isTrue);
    });

    test('us01/fr02/e10: a navigation the page starts to itself while it '
        'loads reports its early HTTP error at once', () {
      // R10 residue: only a controller action ends the open start.
      final page = Uri.parse('https://app.example.com/flip');
      session
        ..didStartPage(page.toString())
        ..didAllowNavigation();
      expect(session.httpError(statusCode: 404, requestUrl: page)?.url, page);
    });

    test('us01/fr02: an empty path matches its canonical slash, fragment '
        'ignored', () {
      expect(
        session.httpError(
          statusCode: 404,
          requestUrl: Uri.parse('https://app.example.com#top'),
        ),
        isNull,
      );
      expect(
        session.didStartPage('https://app.example.com/')?.url,
        Uri.parse('https://app.example.com#top'),
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

    test('us01/fr02/e02: holds an HTTP error that arrives before any page as '
        'a candidate', () {
      expect(
        session.httpError(
          statusCode: 500,
          requestUrl: Uri.parse('https://app.example.com/'),
        ),
        isNull,
      );
      expect(session.didStartPage('https://app.example.com/other'), isNull);
    });

    test('us01/fr02/e03: treats a null request URL as the current page', () {
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
