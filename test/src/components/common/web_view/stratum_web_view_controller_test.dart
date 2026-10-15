import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/model/web_view/web_view_configuration.dart';
import 'package:stratum_ui/src/components/common/model/web_view/web_view_error.dart';
import 'package:stratum_ui/src/components/common/model/web_view/web_view_message.dart';
import 'package:stratum_ui/src/components/common/model/web_view/web_view_navigation_decision.dart';
import 'package:stratum_ui/src/components/common/model/web_view/web_view_source.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_controller.dart';

import 'fakes/fake_platform_stratum_web_view.dart';

void main() {
  final appOrigin = Uri.parse('https://app.example.com');
  final partner = Uri.parse('https://partner.example.net');
  late List<FakePlatformStratumWebView> platforms;
  late StratumWebViewController controller;

  FakePlatformStratumWebView platform() => platforms.single;

  setUp(() {
    platforms = installFakePlatform();
    controller = StratumWebViewController();
  });

  test('loadUrl and loadHtml forward the source', () async {
    await controller.loadUrl(appOrigin);
    await controller.loadHtml('<p>Hi</p>');
    expect(platform().loads, [
      StratumWebViewSource.url(appOrigin),
      const StratumWebViewSource.html('<p>Hi</p>'),
    ]);
  });

  test('loadUrl rejects a scheme other than http or https', () async {
    await expectLater(
      controller.loadUrl(Uri.parse('javascript:alert(1)')),
      throwsArgumentError,
    );
    await expectLater(
      controller.loadUrl(Uri.parse('file:///etc/passwd')),
      throwsArgumentError,
    );
    await expectLater(
      controller.loadUrl(Uri.parse('app.example.com/a')),
      throwsArgumentError,
    );
    expect(platform().loads, isEmpty);
  });

  test('navigation methods forward to the platform', () async {
    platform()
      ..canGoBackValue = true
      ..canGoForwardValue = true
      ..currentUrlValue = Uri.parse('https://app.example.com/a');
    await controller.reload();
    await controller.goBack();
    await controller.goForward();
    expect(await controller.canGoBack(), isTrue);
    expect(await controller.canGoForward(), isTrue);
    expect(
      await controller.currentUrl(),
      Uri.parse('https://app.example.com/a'),
    );
    expect(
      [platform().reloadCount, platform().backCount, platform().forwardCount],
      [1, 1, 1],
    );
  });

  test('postMessage throws while allowedOrigins is empty', () async {
    await expectLater(controller.postMessage('x'), throwsStateError);
    expect(platform().sentMessages, isEmpty);
  });

  test('postMessage forwards once an origin is allowed', () async {
    controller.configure(
      StratumWebViewConfiguration(allowedOrigins: {appOrigin}),
    );
    await controller.postMessage('x');
    expect(platform().sentMessages, ['x']);
    expect(platform().sentTargets, [null]);
  });

  test('co01_02/us03/fr02/e14: a named target is compared as an origin and passed on '
      'as one', () async {
    controller.configure(
      StratumWebViewConfiguration(allowedOrigins: {appOrigin}),
    );
    await controller.postMessage(
      'x',
      targetOrigin: Uri.parse('https://APP.example.com:443/path?q=1#f'),
    );
    expect(platform().sentTargets, [Uri.parse('https://app.example.com')]);
    expect(platform().sentMessages, ['x']);
  });

  test('co01_02/us03/fr02/e15, nf01/NFR-Sec02: a named send whose target matches no '
      'allowed entry, a host-less one included, throws before the platform '
      'runs', () async {
    controller.configure(
      StratumWebViewConfiguration(allowedOrigins: {appOrigin}),
    );
    await expectLater(
      controller.postMessage('x', targetOrigin: partner),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(
            startsWith('targetOrigin '),
            endsWith(' is not an allowed message destination.'),
          ),
        ),
      ),
    );
    await expectLater(
      controller.postMessage('x', targetOrigin: Uri.parse('about:blank')),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(
            startsWith('targetOrigin '),
            endsWith(' is not an allowed message destination.'),
          ),
        ),
      ),
    );
    expect(platform().sentMessages, isEmpty);
  });

  test('postMessage surfaces platform refusals', () async {
    controller.configure(
      StratumWebViewConfiguration(allowedOrigins: {appOrigin}),
    );
    platform().postMessageError = StateError('blocked');
    await expectLater(controller.postMessage('x'), throwsStateError);
  });

  test('co01_02/us02/s2, co01_02/us02/fr02: postMessage throws while '
      'javaScriptEnabled is false', () async {
    controller.configure(
      StratumWebViewConfiguration(
        allowedOrigins: {appOrigin},
        javaScriptEnabled: false,
      ),
    );
    await expectLater(controller.postMessage('x'), throwsStateError);
    expect(platform().sentMessages, isEmpty);
  });

  group('reply', () {
    test('co01_02/us03/fr05/e01: reply throws ArgumentError for a message this '
        'controller did not deliver', () async {
      controller.configure(
        StratumWebViewConfiguration(
          allowedOrigins: {appOrigin},
          onMessage: (_) {},
        ),
      );
      platforms.first.listener.onMessage(
        StratumWebViewMessage(data: 'ready', origin: appOrigin),
        PlatformUrlPageSender(appOrigin),
      );

      final other = StratumWebViewController();
      addTearDown(other.dispose);
      other.configure(
        StratumWebViewConfiguration(
          allowedOrigins: {appOrigin},
          onMessage: (_) {},
        ),
      );
      final otherMessage = StratumWebViewMessage(
        data: 'ready',
        origin: appOrigin,
      );
      platforms.last.listener.onMessage(
        otherMessage,
        PlatformUrlPageSender(appOrigin),
      );

      await expectLater(
        controller.reply(
          StratumWebViewMessage(data: 'ready', origin: appOrigin),
          'x',
        ),
        throwsA(
          isA<ArgumentError>()
              .having(
                (e) => e.message,
                'message',
                'The message was not delivered by this controller.',
              )
              .having((e) => e.name, 'name', 'message'),
        ),
      );
      await expectLater(
        controller.reply(otherMessage, 'x'),
        throwsA(
          isA<ArgumentError>()
              .having(
                (e) => e.message,
                'message',
                'The message was not delivered by this controller.',
              )
              .having((e) => e.name, 'name', 'message'),
        ),
      );
      expect(platforms.first.sentMessages, isEmpty);
      expect(platforms.first.documentReplies, isEmpty);
      expect(platforms.last.sentMessages, isEmpty);
      expect(platforms.last.documentReplies, isEmpty);
    });

    test('co01_02/us03/fr05/e01: reply(delivered.copyWith()) finds no '
        'sender and fails closed', () async {
      controller.configure(
        StratumWebViewConfiguration(
          allowedOrigins: {appOrigin},
          onMessage: (_) {},
        ),
      );
      final message = StratumWebViewMessage(data: 'ready', origin: appOrigin);
      platform().listener.onMessage(message, PlatformUrlPageSender(appOrigin));

      // copyWith builds a new _StratumWebViewMessage, value-equal to the
      // delivered message but with no Expando entry (P3): this guards
      // against a future freezed version ever returning `this` unchanged.
      await expectLater(
        controller.reply(message.copyWith(), 'x'),
        throwsA(
          isA<ArgumentError>()
              .having(
                (e) => e.message,
                'message',
                'The message was not delivered by this controller.',
              )
              .having((e) => e.name, 'name', 'message'),
        ),
      );
      expect(platform().sentMessages, isEmpty);
      expect(platform().documentReplies, isEmpty);
    });

    test('co01_02/us03/fr05/e02: reply checks dispose first, then the message, then '
        'the bridge gate', () async {
      final disposed = StratumWebViewController()..dispose();
      await expectLater(
        disposed.reply(
          StratumWebViewMessage(data: 'ready', origin: appOrigin),
          'x',
        ),
        throwsStateError,
      );

      final noAllowlist = StratumWebViewController();
      addTearDown(noAllowlist.dispose);
      await expectLater(
        noAllowlist.reply(
          StratumWebViewMessage(data: 'ready', origin: appOrigin),
          'x',
        ),
        throwsArgumentError,
      );

      final emptied = StratumWebViewController();
      addTearDown(emptied.dispose);
      emptied.configure(
        StratumWebViewConfiguration(
          allowedOrigins: {appOrigin},
          onMessage: (_) {},
        ),
      );
      final emptiedMessage = StratumWebViewMessage(
        data: 'ready',
        origin: appOrigin,
      );
      platforms.last.listener.onMessage(
        emptiedMessage,
        PlatformUrlPageSender(appOrigin),
      );
      emptied.configure(const StratumWebViewConfiguration());
      await expectLater(
        emptied.reply(emptiedMessage, 'x'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'The bridge is disabled because allowedOrigins is empty.',
          ),
        ),
      );

      final jsOff = StratumWebViewController();
      addTearDown(jsOff.dispose);
      jsOff.configure(
        StratumWebViewConfiguration(
          allowedOrigins: {appOrigin},
          onMessage: (_) {},
        ),
      );
      final jsOffMessage = StratumWebViewMessage(
        data: 'ready',
        origin: appOrigin,
      );
      platforms.last.listener.onMessage(
        jsOffMessage,
        PlatformUrlPageSender(appOrigin),
      );
      jsOff.configure(
        StratumWebViewConfiguration(
          allowedOrigins: {appOrigin},
          javaScriptEnabled: false,
        ),
      );
      await expectLater(
        jsOff.reply(jsOffMessage, 'x'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'The bridge is disabled because javaScriptEnabled is false.',
          ),
        ),
      );
    });

    test('co01_02/us03/fr05/e03, co01_02/us03/fr05/e04, co01_02/us03/s8: a reply to a URL page is a '
        "send naming the message's origin, and the platform's refusal "
        'surfaces', () async {
      controller.configure(
        StratumWebViewConfiguration(
          allowedOrigins: {appOrigin, partner},
          onMessage: (_) {},
        ),
      );
      final message = StratumWebViewMessage(data: 'ready', origin: appOrigin);
      platform().listener.onMessage(message, PlatformUrlPageSender(appOrigin));

      await controller.reply(message, 'pong');
      expect(platform().sentMessages, ['pong']);
      expect(platform().sentTargets, [appOrigin]);

      platform().postMessageError = StateError('moved');
      await expectLater(
        controller.reply(message, 'pong'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'moved')),
      );
    });

    test('co01_02/us03/fr05/e05: a reply to a URL page whose origin left the allowlist '
        'throws before the platform runs', () async {
      controller.configure(
        StratumWebViewConfiguration(
          allowedOrigins: {appOrigin, partner},
          onMessage: (_) {},
        ),
      );
      final message = StratumWebViewMessage(data: 'ready', origin: appOrigin);
      platform().listener.onMessage(message, PlatformUrlPageSender(appOrigin));

      controller.configure(
        StratumWebViewConfiguration(
          allowedOrigins: {partner},
          onMessage: (_) {},
        ),
      );

      await expectLater(
        controller.reply(message, 'pong'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              startsWith('targetOrigin '),
              endsWith(' is not an allowed message destination.'),
            ),
          ),
        ),
      );
      expect(platform().sentMessages, isEmpty);
    });

    test('co01_02/us03/fr05/e06, co01_02/us03/fr05/e08: a reply to own HTML goes to the '
        'platform with the document that sent the message', () async {
      controller.configure(
        StratumWebViewConfiguration(
          allowedOrigins: {appOrigin},
          onMessage: (_) {},
        ),
      );
      final text = 'ready:${appOrigin.host}';
      final message = StratumWebViewMessage(data: text);
      platform().listener.onMessage(message, const FakeHtmlDocumentSender());

      await controller.reply(message, 'pong');
      expect(platform().documentReplies, [
        (const FakeHtmlDocumentSender(), 'pong'),
      ]);
      expect(platform().sentMessages, isEmpty);

      platform().replyError = StateError('gone');
      await expectLater(
        controller.reply(message, 'pong'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'gone')),
      );
    });

    test(
      'co01_02/us03/fr05: a reply from inside onMessage reaches its sender',
      () async {
        controller.configure(
          StratumWebViewConfiguration(
            allowedOrigins: {appOrigin},
            onMessage: (m) => unawaited(controller.reply(m, 'ack')),
          ),
        );
        final message = StratumWebViewMessage(data: 'ready', origin: appOrigin);
        platform().listener.onMessage(
          message,
          PlatformUrlPageSender(appOrigin),
        );
        await pumpEventQueue();
        expect(platform().sentMessages, ['ack']);
      },
    );

    test(
      'G4 co01_02/us03/fr05: two replies to the same still-valid sender both '
      'land',
      () async {
        controller.configure(
          StratumWebViewConfiguration(
            allowedOrigins: {appOrigin},
            onMessage: (_) {},
          ),
        );
        final message = StratumWebViewMessage(data: 'ready:${appOrigin.host}');
        platform().listener.onMessage(message, const FakeHtmlDocumentSender());

        await controller.reply(message, 'first');
        await controller.reply(message, 'second');
        expect(platform().documentReplies, [
          (const FakeHtmlDocumentSender(), 'first'),
          (const FakeHtmlDocumentSender(), 'second'),
        ]);
      },
    );

    test('co01_02/us03/fr05: a reply to one of two HTML messages uses that '
        "message's own sender, never the other's", () async {
      controller.configure(
        StratumWebViewConfiguration(
          allowedOrigins: {appOrigin},
          onMessage: (_) {},
        ),
      );
      final first = StratumWebViewMessage(data: 'ready:${appOrigin.host}');
      final second = StratumWebViewMessage(data: 'ready:${appOrigin.host}');
      // Not const: a const instance would canonicalize both senders to the
      // same object, defeating the identity check this test makes (F3).
      // ignore: prefer_const_constructors
      final firstSender = FakeHtmlDocumentSender();
      // Not const, for the same reason as firstSender above.
      // ignore: prefer_const_constructors
      final secondSender = FakeHtmlDocumentSender();
      platform().listener.onMessage(first, firstSender);
      platform().listener.onMessage(second, secondSender);

      await controller.reply(first, 'x');
      expect(platform().documentReplies, [(firstSender, 'x')]);
      expect(
        identical(platform().documentReplies.single.$1, firstSender),
        isTrue,
      );
      expect(
        identical(platform().documentReplies.single.$1, secondSender),
        isFalse,
      );
    });

    test(
      'G5 co01_02/us03/fr05: an empty-string reply reaches the sender whole',
      () async {
        controller.configure(
          StratumWebViewConfiguration(
            allowedOrigins: {appOrigin},
            onMessage: (_) {},
          ),
        );
        final message = StratumWebViewMessage(data: 'ready:${appOrigin.host}');
        platform().listener.onMessage(message, const FakeHtmlDocumentSender());

        await controller.reply(message, '');
        expect(platform().documentReplies, [
          (const FakeHtmlDocumentSender(), ''),
        ]);
      },
    );
  });

  test('configure forwards JavaScript only when it changes', () {
    controller
      ..configure(const StratumWebViewConfiguration())
      ..configure(const StratumWebViewConfiguration(javaScriptEnabled: false))
      ..configure(const StratumWebViewConfiguration(javaScriptEnabled: false));
    expect(platform().javaScriptChanges, [false]);
  });

  test('dispose releases the platform once and blocks later use', () async {
    controller
      ..dispose()
      ..dispose();
    expect(platform().disposed, isTrue);
    await expectLater(controller.loadUrl(appOrigin), throwsStateError);
    expect(
      () => controller.configure(const StratumWebViewConfiguration()),
      throwsStateError,
    );
  });

  group('allowedOrigins validation (debug)', () {
    test('rejects an entry without a scheme', () {
      expect(
        () => controller.configure(
          StratumWebViewConfiguration(
            allowedOrigins: {Uri.parse('app.example.com')},
          ),
        ),
        throwsAssertionError,
      );
    });

    test('rejects a non-http scheme', () {
      expect(
        () => controller.configure(
          StratumWebViewConfiguration(
            allowedOrigins: {Uri.parse('ftp://app.example.com')},
          ),
        ),
        throwsAssertionError,
      );
    });

    test('rejects a Unicode host that is not punycode', () {
      expect(
        () => controller.configure(
          StratumWebViewConfiguration(
            allowedOrigins: {Uri.parse('https://bücher.de')},
          ),
        ),
        throwsAssertionError,
      );
    });

    test('accepts http and https origins, with or without a path', () {
      expect(
        () => controller.configure(
          StratumWebViewConfiguration(
            allowedOrigins: {
              Uri.parse('https://xn--bcher-kva.de'),
              Uri.parse('http://localhost:8080/app/'),
            },
          ),
        ),
        returnsNormally,
      );
    });
  });

  test('detach drops callbacks but keeps the JavaScript setting', () {
    controller
      ..configure(
        StratumWebViewConfiguration(
          allowedOrigins: {appOrigin},
          javaScriptEnabled: false,
          onMessage: (_) {},
        ),
      )
      ..detach();
    final configuration = controller.debugConfiguration;
    expect(configuration.allowedOrigins, isEmpty);
    expect(configuration.onMessage, isNull);
    expect(configuration.javaScriptEnabled, isFalse);
    expect(platform().javaScriptChanges, [false]);
  });

  test('detach after dispose does nothing', () {
    controller.dispose();
    expect(controller.detach, returnsNormally);
  });

  test('dispose resets the configuration to release consumer callbacks', () {
    controller
      ..configure(
        StratumWebViewConfiguration(
          allowedOrigins: {appOrigin},
          onMessage: (_) {},
          onNavigationRequest: (_) => StratumNavigationDecision.navigate,
          onPageStarted: (_) {},
          onPageFinished: (_) {},
          onError: (_) {},
        ),
      )
      ..dispose();
    final configuration = controller.debugConfiguration;
    expect(configuration.allowedOrigins, isEmpty);
    expect(configuration.onMessage, isNull);
    expect(configuration.onNavigationRequest, isNull);
    expect(configuration.onPageStarted, isNull);
    expect(configuration.onPageFinished, isNull);
    expect(configuration.onError, isNull);
  });

  group('listener', () {
    late List<StratumWebViewMessage> messages;

    setUp(() => messages = []);

    test('drops messages while allowedOrigins is empty', () {
      controller.configure(
        StratumWebViewConfiguration(onMessage: messages.add),
      );
      platform().listener.onMessage(
        const StratumWebViewMessage(data: 'x'),
        const FakeHtmlDocumentSender(),
      );
      expect(messages, isEmpty);
    });

    test('delivers messages when an origin is allowed', () {
      controller.configure(
        StratumWebViewConfiguration(
          allowedOrigins: {appOrigin},
          onMessage: messages.add,
        ),
      );
      platform().listener.onMessage(
        const StratumWebViewMessage(data: 'x'),
        const FakeHtmlDocumentSender(),
      );
      expect(messages, [const StratumWebViewMessage(data: 'x')]);
    });

    test('drops messages while javaScriptEnabled is false', () {
      controller.configure(
        StratumWebViewConfiguration(
          allowedOrigins: {appOrigin},
          javaScriptEnabled: false,
          onMessage: messages.add,
        ),
      );
      platform().listener.onMessage(
        const StratumWebViewMessage(data: 'x'),
        const FakeHtmlDocumentSender(),
      );
      expect(messages, isEmpty);
    });

    test(
      'co01_02/us04/fr03: reports a throwing callback without rethrowing',
      () {
        final reported = <FlutterErrorDetails>[];
        final previous = FlutterError.onError;
        FlutterError.onError = reported.add;
        addTearDown(() => FlutterError.onError = previous);
        controller.configure(
          StratumWebViewConfiguration(
            allowedOrigins: {appOrigin},
            onMessage: (_) => throw StateError('boom'),
          ),
        );
        platform().listener.onMessage(
          const StratumWebViewMessage(data: 'x'),
          const FakeHtmlDocumentSender(),
        );
        expect(reported.single.exception, isStateError);
      },
    );

    test('co01_02/us04/s4, co01_02/us04/fr02: navigation defaults to navigate '
        'and fails closed on errors', () {
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);
      final listener = platform().listener;
      expect(
        listener.onNavigationRequest(appOrigin),
        StratumNavigationDecision.navigate,
      );
      controller.configure(
        StratumWebViewConfiguration(
          onNavigationRequest: (_) => throw StateError('boom'),
        ),
      );
      expect(
        listener.onNavigationRequest(appOrigin),
        StratumNavigationDecision.prevent,
      );
      expect(reported, hasLength(1));
    });

    test('forwards page and error events', () {
      final started = <Uri?>[];
      final finished = <Uri?>[];
      final errors = <StratumWebViewError>[];
      controller.configure(
        StratumWebViewConfiguration(
          onPageStarted: started.add,
          onPageFinished: finished.add,
          onError: errors.add,
        ),
      );
      const error = StratumWebViewError(
        type: StratumWebViewErrorType.network,
        description: 'offline',
      );
      platform().listener
        ..onPageStarted(appOrigin)
        ..onPageFinished(appOrigin)
        ..onError(error);
      expect(started, [appOrigin]);
      expect(finished, [appOrigin]);
      expect(errors, [error]);
    });

    test('ignores events after dispose', () {
      final started = <Uri?>[];
      controller
        ..configure(
          StratumWebViewConfiguration(
            allowedOrigins: {appOrigin},
            onMessage: messages.add,
            onPageStarted: started.add,
          ),
        )
        ..dispose();
      platform().listener
        ..onMessage(
          const StratumWebViewMessage(data: 'x'),
          const FakeHtmlDocumentSender(),
        )
        ..onPageStarted(appOrigin);
      expect(messages, isEmpty);
      expect(started, isEmpty);
    });
  });
}
