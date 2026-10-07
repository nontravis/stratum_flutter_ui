import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
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
    session = NativeBridgeSession(
      allowedOrigins: () => allowed,
      platform: TargetPlatform.android,
    );
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

  group('messages with a sender the platform names', () {
    BridgeMessageSender from(String url, {bool isMainFrame = true}) =>
        BridgeMessageSender(origin: Uri.parse(url), isMainFrame: isMainFrame);

    test('us03/fr01/e10: the sender origin decides, before any page start '
        'and against the last one', () {
      expect(
        session.acceptMessage(
          'ready',
          sender: from('https://app.example.com/home'),
        ),
        StratumWebViewMessage(data: 'ready', origin: appOrigin),
      );
      session.didStartPage('https://app.example.com/home');
      expect(
        session.acceptMessage('x', sender: from('https://evil.example.net/')),
        isNull,
      );
    });

    test('us03/fr01/e06, us03/fr04/e09: a sub-frame message is dropped, a '
        'tagged one with the current nonce included', () {
      final nonce = nonceIn(session.willLoadHtml('<p>Hi</p>'));
      // M1-T2b ties a tagged message to a proven document: a main-frame
      // hello proves the nonce before this test judges a main-frame
      // message by it.
      session.acceptMessage(
        envelope(nonce, 'hello', documentA),
        sender: from('about:blank'),
      );
      expect(
        session.acceptMessage(
          'x',
          sender: from('https://app.example.com/', isMainFrame: false),
        ),
        isNull,
      );
      expect(
        session.acceptMessage(
          envelope(nonce, 'message', 'x'),
          sender: from('about:blank', isMainFrame: false),
        ),
        isNull,
      );
      expect(
        session.acceptMessage(
          envelope(nonce, 'message', 'x'),
          sender: from('about:blank'),
        ),
        const StratumWebViewMessage(data: 'x'),
      );
    });

    test('us03/fr01/e12: a tagged message from an allowed sender is judged '
        'only by its nonce', () {
      expect(
        session.acceptMessage(
          envelope('a' * 32, 'message', 'x'),
          sender: from('https://app.example.com/'),
        ),
        isNull,
      );
    });

    test('us03/fr01/e11, us03/fr02/e11: without the bridge features every '
        'message drops and every send throws naming the limit', () {
      final nonce = nonceIn(session.willLoadHtml('<p>Hi</p>'));
      session.markBridgeUnsupported();
      expect(
        session.acceptMessage('x', sender: from('https://app.example.com/')),
        isNull,
      );
      expect(session.acceptMessage(envelope(nonce, 'hello')), isNull);
      expect(
        () => session.scriptForMessage('ping'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'The bridge is disabled because the WebView lacks '
                'WEB_MESSAGE_LISTENER or JS_INJECTION_IN_FRAME_AND_WORLD '
                'support.',
          ),
        ),
      );
    });

    test('us03/fr01/e06, us03/fr01/e10: where the platform names senders, a '
        'message without one drops, never judged by the tracked page', () {
      final named = NativeBridgeSession(
        allowedOrigins: () => allowed,
        platform: TargetPlatform.android,
        namesSenders: true,
      );
      final nonce = nonceIn(named.willLoadHtml('<p>Hi</p>'));
      named.didStartPage('https://app.example.com/home');
      expect(named.acceptMessage('x'), isNull);
      named.acceptMessage(envelope(nonce, 'hello', documentA));
      expect(() => named.scriptForMessage('ping'), throwsA(isA<StateError>()));
      expect(
        named.acceptMessage('x', sender: from('https://app.example.com/home')),
        StratumWebViewMessage(data: 'x', origin: appOrigin),
      );
    });
  });

  group('messages from loaded HTML', () {
    test('us03/fr04: a message with the current nonce, once a hello proves '
        'it, reaches the app with no origin and without its envelope', () {
      final nonce = nonceIn(session.willLoadHtml('<p>Hi</p>'));
      session
        ..acceptMessage(envelope(nonce, 'hello', documentA))
        ..didStartPage('about:blank');
      expect(
        session.acceptMessage(envelope(nonce, 'message', 'hi:there')),
        const StratumWebViewMessage(data: 'hi:there'),
      );
    });

    test('us03/fr04/e01: page starts, finishes, and URL changes in any '
        'order neither grant nor end trust', () {
      final nonce = nonceIn(session.willLoadHtml('<p>Hi</p>'));
      session.didStartPage('about:blank');
      expect(session.acceptMessage(envelope(nonce, 'message', 'a')), isNull);
      // A hello and a message that beat the HTML's own page start.
      session.acceptMessage(envelope(nonce, 'hello', documentA));
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
        ..acceptMessage(envelope(current, 'hello', documentA))
        // A link away, then the controller's goBack to a parsed-again
        // document.
        ..acceptMessage(envelope(current, 'bye', documentA))
        ..didStartPage('https://app.example.com/linked')
        ..willNavigate()
        ..didStartPage('about:blank');
      expect(
        session.acceptMessage(envelope(older, 'hello', documentB)),
        isNull,
      );
      expect(session.acceptMessage(envelope(older, 'message', 'x')), isNull);
      session.acceptMessage(envelope(current, 'hello', documentB));
      expect(
        session.acceptMessage(envelope(current, 'message', 'x')),
        const StratumWebViewMessage(data: 'x'),
      );
    });

    test('us03/fr04/e03: a document restored from the back-forward cache '
        'proves the nonce again with the same document id', () {
      final html = session.willLoadHtml('<p>Hi</p>');
      final nonce = nonceIn(html);
      session
        ..acceptMessage(envelope(nonce, 'hello', documentA))
        ..acceptMessage(envelope(nonce, 'bye', documentA))
        ..acceptMessage(envelope(nonce, 'hello', documentA));
      expect(session.scriptForMessage('ping'), contains(tokenIn(html)));
      expect(session.acceptMessage(envelope(nonce, 'message', 'x')), isNotNull);
      session.acceptMessage(envelope(nonce, 'bye', documentA));
      expect(session.scriptForMessage('ping'), isNot(contains(tokenIn(html))));
    });

    test("us03/fr04/e04: a reload keeps the nonce; the old document's bye "
        "and the reloaded document's hello move the proof", () {
      final html = session.willLoadHtml('<p>Hi</p>');
      final nonce = nonceIn(html);
      session
        ..acceptMessage(envelope(nonce, 'hello', documentA))
        ..willReload()
        ..acceptMessage(envelope(nonce, 'bye', documentA))
        ..didStartPage('about:blank');
      // A send between that bye and that hello carries no token.
      expect(
        session.scriptForMessage('ping'),
        buildMessageDispatchScript(
          'ping',
          token: null,
          allowedOrigins: allowed,
        ),
      );
      expect(session.acceptMessage(envelope(nonce, 'message', 'x')), isNull);
      session.acceptMessage(envelope(nonce, 'hello', documentB));
      expect(session.acceptMessage(envelope(nonce, 'message', 'x')), isNotNull);
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
        '$tag$nonce:hello',
        '${tag}x$nonce:hello:$documentA',
        '$tag$nonce:ping:$documentA',
        '$tag$nonce:Hello:$documentA',
        '$tag${nonce.toUpperCase()}:hello:$documentA',
        '$tag${'0' * 32}:hello:$documentA',
        '$tag${nonce.substring(1)}:hello:$documentA',
      ]) {
        expect(session.acceptMessage(bad), isNull, reason: bad);
      }
      expect(
        () => session.scriptForMessage('ping'),
        throwsA(isA<StateError>()),
        reason: 'no envelope above may prove the nonce',
      );
    });

    test('us03/fr04: a hello or bye whose document id is not 32 lowercase '
        'hex characters is dropped', () {
      final html = session.willLoadHtml('<p>Hi</p>');
      final nonce = nonceIn(html);
      final badIds = [
        '',
        documentA.substring(1),
        '${documentA}0',
        documentA.toUpperCase(),
        '${documentA.substring(1)}g',
        '${documentA.substring(1)}\n',
        '$documentA\n',
        '$documentA:x',
      ];
      for (final id in badIds) {
        expect(session.acceptMessage(envelope(nonce, 'hello', id)), isNull);
        expect(
          () => session.scriptForMessage('ping'),
          throwsA(isA<StateError>()),
          reason: 'hello ${jsonEncode(id)}',
        );
      }
      session.acceptMessage(envelope(nonce, 'hello', documentA));
      for (final id in badIds) {
        expect(session.acceptMessage(envelope(nonce, 'bye', id)), isNull);
        expect(
          session.scriptForMessage('ping'),
          contains(tokenIn(html)),
          reason: 'bye ${jsonEncode(id)}',
        );
      }
    });

    test('us03/fr04: while minted, a message or a bye is dropped and only a '
        'hello proves the nonce', () {
      final nonce = nonceIn(session.willLoadHtml('<p>Hi</p>'));
      expect(session.acceptMessage(envelope(nonce, 'message', 'x')), isNull);
      expect(session.acceptMessage(envelope(nonce, 'bye', documentA)), isNull);
      expect(
        () => session.scriptForMessage('ping'),
        throwsA(isA<StateError>()),
      );
      session.acceptMessage(envelope(nonce, 'hello', documentA));
      expect(session.acceptMessage(envelope(nonce, 'message', 'x')), isNotNull);
    });

    test("us03/fr04/e10, us03/fr02/e04, us03/fr02/e10: the proving document's "
        'bye revokes the proof: the token is withheld, sends run the '
        'allowlist-only script, and messages drop', () {
      final nonce = nonceIn(session.willLoadHtml('<p>Hi</p>'));
      session
        ..acceptMessage(envelope(nonce, 'hello', documentA))
        ..acceptMessage(envelope(nonce, 'bye', documentA));
      expect(
        session.scriptForMessage('ping'),
        buildMessageDispatchScript(
          'ping',
          token: null,
          allowedOrigins: allowed,
        ),
      );
      expect(session.acceptMessage(envelope(nonce, 'message', 'x')), isNull);
    });

    test('us03/fr04/e10: a hello with another document id replaces the id, '
        "so an older document's late bye never ends the newer proof", () {
      final html = session.willLoadHtml('<p>Hi</p>');
      final nonce = nonceIn(html);
      session
        ..acceptMessage(envelope(nonce, 'hello', documentA))
        ..acceptMessage(envelope(nonce, 'hello', documentB))
        ..acceptMessage(envelope(nonce, 'bye', documentA));
      expect(session.scriptForMessage('ping'), contains(tokenIn(html)));
      expect(session.acceptMessage(envelope(nonce, 'message', 'x')), isNotNull);
      session.acceptMessage(envelope(nonce, 'bye', documentB));
      expect(session.scriptForMessage('ping'), isNot(contains(tokenIn(html))));
    });

    test('us03/fr04/e10: while revoked, any bye changes nothing and a hello '
        'with the current nonce proves it again', () {
      final html = session.willLoadHtml('<p>Hi</p>');
      final nonce = nonceIn(html);
      session
        ..acceptMessage(envelope(nonce, 'hello', documentA))
        ..acceptMessage(envelope(nonce, 'bye', documentA))
        ..acceptMessage(envelope(nonce, 'bye', documentA))
        ..acceptMessage(envelope(nonce, 'bye', documentB));
      expect(session.scriptForMessage('ping'), isNot(contains(tokenIn(html))));
      session.acceptMessage(envelope(nonce, 'hello', documentB));
      expect(session.scriptForMessage('ping'), contains(tokenIn(html)));
      expect(session.acceptMessage(envelope(nonce, 'message', 'x')), isNotNull);
    });

    test('us03/fr04/e10: a hello or a bye with the nonce of an older '
        'loadHtml moves nothing', () {
      final older = nonceIn(session.willLoadHtml('<p>One</p>'));
      final current = session.willLoadHtml('<p>Two</p>');
      session.acceptMessage(envelope(older, 'hello', documentA));
      expect(
        () => session.scriptForMessage('ping'),
        throwsA(isA<StateError>()),
      );
      session
        ..acceptMessage(envelope(nonceIn(current), 'hello', documentA))
        ..acceptMessage(envelope(older, 'bye', documentA));
      expect(session.scriptForMessage('ping'), contains(tokenIn(current)));
    });

    test('us03/fr04: a loadHtml from any proof state mints a new nonce, so '
        'sends throw until its own hello', () {
      for (final kinds in [
        <String>[],
        ['hello'],
        ['hello', 'bye'],
      ]) {
        final older = nonceIn(session.willLoadHtml('<p>One</p>'));
        for (final kind in kinds) {
          session.acceptMessage(envelope(older, kind, documentA));
        }
        session.willLoadHtml('<p>Two</p>');
        expect(
          () => session.scriptForMessage('ping'),
          throwsA(isA<StateError>()),
          reason: '$kinds',
        );
      }
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
        ..acceptMessage(envelope(nonceIn(html), 'hello', documentA))
        ..didStartPage('about:blank')
        ..didStartPage('https://app.example.com/next')
        ..didChangeUrl(null);
      expect(session.scriptForMessage('ping'), contains(tokenIn(html)));
    });

    test('us03/fr04: loadUrl and dispose revoke the nonce and the token from '
        'every proof state', () {
      for (final revoke in <void Function()>[
        session.willLoadUrl,
        session.willDispose,
      ]) {
        for (final kinds in [
          <String>[],
          ['hello'],
          ['hello', 'bye'],
        ]) {
          final html = session.willLoadHtml('<p>Hi</p>');
          final nonce = nonceIn(html);
          for (final kind in kinds) {
            session.acceptMessage(envelope(nonce, kind, documentA));
          }
          revoke();
          session.acceptMessage(envelope(nonce, 'hello', documentA));
          expect(
            session.acceptMessage(envelope(nonce, 'message', 'x')),
            isNull,
            reason: '$kinds',
          );
          expect(
            session.scriptForMessage('ping'),
            isNot(contains('t===')),
            reason: '$kinds',
          );
        }
      }
    });

    test('nf01/NFR-Sec03: every loadHtml of every session mints a fresh '
        'inbound nonce and an independent outbound token', () {
      final other = NativeBridgeSession(
        allowedOrigins: () => allowed,
        platform: TargetPlatform.android,
      );
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
      for (final secret in secrets) {
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
      session.acceptMessage(envelope(nonceIn(html), 'hello', documentA));
      final message = session.acceptMessage(
        envelope(nonceIn(html), 'message', 'x'),
      )!;
      for (final secret in secrets) {
        expect(message.data, isNot(contains(secret)));
        expect('$message', isNot(contains(secret)));
      }
    });

    test('Q9-OQ-A3: a message has no size limit', () {
      final nonce = nonceIn(session.willLoadHtml('<p>Hi</p>'));
      session.acceptMessage(envelope(nonce, 'hello', documentA));
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
      session.acceptMessage(envelope(nonceIn(html), 'hello', documentA));
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

  group('Android reply proxy', () {
    const proxyA = BridgeReplyProxy(1);
    const proxyB = BridgeReplyProxy(2);
    late NativeBridgeSession android;

    setUp(() {
      android = NativeBridgeSession(
        allowedOrigins: () => allowed,
        platform: TargetPlatform.android,
        namesSenders: true,
        bindsSendsToDocument: true,
      );
    });

    BridgeMessageSender sentBy(BridgeReplyProxy proxy) =>
        BridgeMessageSender(origin: null, isMainFrame: true, replyProxy: proxy);

    String allowlistOnly(String data) =>
        buildMessageDispatchScript(data, token: null, allowedOrigins: allowed);

    String tokenOnly(String data, String html) => buildMessageDispatchScript(
      data,
      token: tokenIn(html),
      allowedOrigins: const <Uri>[],
    );

    test('us03/fr02/e13, us03/fr04/e15: while proven, the page shown gets '
        'the allowlist-only script, and the token check runs through the '
        'reply proxy of the proving hello', () {
      final html = android.willLoadHtml('<p>Hi</p>');
      final nonce = nonceIn(html);
      android.acceptMessage(
        envelope(nonce, 'hello', documentA),
        sender: sentBy(proxyA),
      );
      expect(android.scriptForMessage('ping'), allowlistOnly('ping'));
      expect(android.replyProxyScriptForMessage('ping', loadNonce: nonce), (
        replyProxy: proxyA,
        script: tokenOnly('ping', html),
      ));
    });

    test('us03/fr04/e15: a hello with another document id replaces the '
        "reply proxy with the id, so an older document's late bye changes "
        'nothing', () {
      final html = android.willLoadHtml('<p>Hi</p>');
      final nonce = nonceIn(html);
      android
        ..acceptMessage(
          envelope(nonce, 'hello', documentA),
          sender: sentBy(proxyA),
        )
        ..acceptMessage(
          envelope(nonce, 'hello', documentB),
          sender: sentBy(proxyB),
        )
        ..acceptMessage(
          envelope(nonce, 'bye', documentA),
          sender: sentBy(proxyA),
        );
      expect(
        android
            .replyProxyScriptForMessage('ping', loadNonce: nonce)
            ?.replyProxy,
        proxyB,
      );
    });

    test('us03/fr04/e15: a message other than the accepted hello never '
        'records its reply proxy', () {
      final html = android.willLoadHtml('<p>Hi</p>');
      final nonce = nonceIn(html);
      android
        ..acceptMessage(
          envelope(nonce, 'hello', documentA),
          sender: sentBy(proxyA),
        )
        ..acceptMessage(envelope(nonce, 'message', 'x'), sender: sentBy(proxyB))
        ..acceptMessage('untagged', sender: sentBy(proxyB))
        ..acceptMessage(
          envelope('a' * 32, 'hello', documentB),
          sender: sentBy(proxyB),
        );
      expect(
        android
            .replyProxyScriptForMessage('ping', loadNonce: nonce)
            ?.replyProxy,
        proxyA,
      );
    });

    test('us03/fr04/e10, us03/fr02/e13: a bye that arrives revokes the '
        'proof, after which no send runs through the reply proxy', () {
      final html = android.willLoadHtml('<p>Hi</p>');
      final nonce = nonceIn(html);
      android
        ..acceptMessage(
          envelope(nonce, 'hello', documentA),
          sender: sentBy(proxyA),
        )
        ..acceptMessage(
          envelope(nonce, 'bye', documentA),
          sender: sentBy(proxyA),
        );
      expect(android.scriptForMessage('ping'), allowlistOnly('ping'));
      expect(
        android.replyProxyScriptForMessage('ping', loadNonce: nonce),
        isNull,
      );
    });

    test('us03/fr02/e13: nothing runs through a reply proxy with no current '
        'nonce, before the proof, or after loadUrl or dispose', () {
      expect(
        android.replyProxyScriptForMessage('ping', loadNonce: null),
        isNull,
      );
      for (final revoke in <void Function()>[
        android.willLoadUrl,
        android.willDispose,
      ]) {
        final nonce = nonceIn(android.willLoadHtml('<p>Hi</p>'));
        expect(
          android.replyProxyScriptForMessage('ping', loadNonce: nonce),
          isNull,
        );
        android.acceptMessage(
          envelope(nonce, 'hello', documentA),
          sender: sentBy(proxyA),
        );
        expect(
          android.replyProxyScriptForMessage('ping', loadNonce: nonce),
          isNotNull,
        );
        revoke();
        expect(
          android.replyProxyScriptForMessage('ping', loadNonce: nonce),
          isNull,
        );
      }
    });

    test('B1 us03/fr02/e13: a reply-proxy run binds to the load the send '
        'began under; a hello of a later loadHtml that proves while the '
        "first script is pending does not get the earlier load's send", () {
      final nonceA = nonceIn(android.willLoadHtml('<p>A</p>'));
      android.acceptMessage(
        envelope(nonceA, 'hello', documentA),
        sender: sentBy(proxyA),
      );
      // The first script runs late: a second loadHtml commits and proves
      // before the reply-proxy run is asked for.
      final nonceB = nonceIn(android.willLoadHtml('<p>B</p>'));
      android.acceptMessage(
        envelope(nonceB, 'hello', documentB),
        sender: sentBy(proxyB),
      );
      expect(
        android.replyProxyScriptForMessage('ping', loadNonce: nonceA),
        isNull,
      );
    });

    test('B2 us03/fr02/e04, us03/fr04/e15: a hello with no reply proxy '
        'proves nothing instead of being inferred as a non-Android sender, '
        'so a send still throws unproven', () {
      final html = android.willLoadHtml('<p>Hi</p>');
      android.acceptMessage(
        envelope(nonceIn(html), 'hello', documentA),
        sender: const BridgeMessageSender(origin: null, isMainFrame: true),
      );
      expect(
        () => android.scriptForMessage('ping'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('WebKit senders with no reply proxy', () {
    late NativeBridgeSession webKit;

    setUp(() {
      webKit = NativeBridgeSession(
        allowedOrigins: () => allowed,
        platform: TargetPlatform.iOS,
        namesSenders: true,
      );
    });

    test('us03/fr02/e03: iOS and macOS, whose senders hand no reply proxy, '
        'keep the token check on the page shown', () {
      final html = webKit.willLoadHtml('<p>Hi</p>');
      final nonce = nonceIn(html);
      webKit.acceptMessage(
        envelope(nonce, 'hello', documentA),
        sender: const BridgeMessageSender(origin: null, isMainFrame: true),
      );
      expect(webKit.scriptForMessage('ping'), contains(tokenIn(html)));
      expect(
        webKit.replyProxyScriptForMessage('ping', loadNonce: nonce),
        isNull,
      );
    });
  });

  group('dispatchScriptAnswer', () {
    test('us03/fr02/e03: passes the dispatch script answer through', () async {
      expect(await dispatchScriptAnswer(Future<Object>.value(true)), isTrue);
      expect(await dispatchScriptAnswer(Future<Object>.value(false)), isFalse);
    });

    test('us03/fr02/e12: no answer within 5 seconds counts as none', () {
      fakeAsync((async) {
        Object? answer = 'pending';
        unawaited(
          dispatchScriptAnswer(Completer<Object>().future)
              .then((value) => answer = value),
        );
        async.elapse(const Duration(milliseconds: 4999));
        expect(answer, 'pending');
        async.elapse(const Duration(milliseconds: 1));
        expect(answer, isNull);
      });
    });

    test('us03/fr02/e12: a platform error, or the null result a platform '
        'rejects, counts as none', () async {
      for (final error in <Object>[
        PlatformException(code: 'evaluateJavaScript'),
        ArgumentError('The JavaScript returned `null` or `undefined`.'),
      ]) {
        expect(
          await dispatchScriptAnswer(Future<Object>.error(error)),
          isNull,
          reason: '$error',
        );
      }
    });

    test('us03/fr02/e12: any other error propagates unchanged', () async {
      await expectLater(
        dispatchScriptAnswer(
          Future<Object>.error(MissingPluginException('no plugin')),
        ),
        throwsA(isA<MissingPluginException>()),
      );
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

    test('us01/fr02/e04: drops a cancelled navigation through the '
        'cancel-code table of its platform', () {
      for (final (platform, code, dropped) in [
        (TargetPlatform.iOS, -999, true),
        (TargetPlatform.macOS, -999, true),
        (TargetPlatform.windows, 14, true),
        (TargetPlatform.windows, -999, false),
        (TargetPlatform.linux, 14, false),
        (TargetPlatform.android, -999, false),
        (TargetPlatform.android, 14, false),
        (TargetPlatform.iOS, 14, false),
      ]) {
        final mapped =
            NativeBridgeSession(
              allowedOrigins: () => allowed,
              platform: platform,
            ).networkError(
              code: code,
              description: 'cancelled',
              isForMainFrame: true,
              url: 'https://app.example.com/',
            );
        expect(mapped == null, dropped, reason: '${platform.name} $code');
      }
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
