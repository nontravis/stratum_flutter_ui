import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_controller.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

import 'fakes/fake_platform_stratum_web_view.dart';

void main() {
  final appOrigin = Uri.parse('https://app.example.com');
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
  });

  test('postMessage surfaces platform refusals', () async {
    controller.configure(
      StratumWebViewConfiguration(allowedOrigins: {appOrigin}),
    );
    platform().postMessageError = StateError('blocked');
    await expectLater(controller.postMessage('x'), throwsStateError);
  });

  test('postMessage throws while javaScriptEnabled is false', () async {
    controller.configure(
      StratumWebViewConfiguration(
        allowedOrigins: {appOrigin},
        javaScriptEnabled: false,
      ),
    );
    await expectLater(controller.postMessage('x'), throwsStateError);
    expect(platform().sentMessages, isEmpty);
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
      platform().listener.onMessage(const StratumWebViewMessage(data: 'x'));
      expect(messages, isEmpty);
    });

    test('delivers messages when an origin is allowed', () {
      controller.configure(
        StratumWebViewConfiguration(
          allowedOrigins: {appOrigin},
          onMessage: messages.add,
        ),
      );
      platform().listener.onMessage(const StratumWebViewMessage(data: 'x'));
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
      platform().listener.onMessage(const StratumWebViewMessage(data: 'x'));
      expect(messages, isEmpty);
    });

    test('reports a throwing callback without rethrowing', () {
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
      platform().listener.onMessage(const StratumWebViewMessage(data: 'x'));
      expect(reported.single.exception, isStateError);
    });

    test('navigation defaults to navigate and fails closed on errors', () {
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
        ..onMessage(const StratumWebViewMessage(data: 'x'))
        ..onPageStarted(appOrigin);
      expect(messages, isEmpty);
      expect(started, isEmpty);
    });
  });
}
