import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_controller.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

import 'fakes/fake_platform_stratum_web_view.dart';

void main() {
  final appOrigin = Uri.parse('https://app.example.com');
  final urlA = StratumWebViewSource.url(Uri.parse('https://app.example.com/a'));
  final urlB = StratumWebViewSource.url(Uri.parse('https://app.example.com/b'));
  late List<FakePlatformStratumWebView> platforms;

  setUp(() => platforms = installFakePlatform());

  testWidgets('creates a controller, loads the source, shows the view', (
    tester,
  ) async {
    await tester.pumpWidget(StratumWebView(source: urlA));
    expect(platforms.single.loads, [urlA]);
    expect(find.byKey(fakePlatformViewKey), findsOneWidget);
  });

  testWidgets('disposes the controller it created', (tester) async {
    await tester.pumpWidget(StratumWebView(source: urlA));
    await tester.pumpWidget(const SizedBox());
    expect(platforms.single.disposed, isTrue);
  });

  testWidgets('leaves an external controller undisposed', (tester) async {
    final controller = StratumWebViewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      StratumWebView(controller: controller, source: urlA),
    );
    await tester.pumpWidget(const SizedBox());
    expect(platforms.single.disposed, isFalse);
  });

  testWidgets('loads again only when the source changes', (tester) async {
    await tester.pumpWidget(StratumWebView(source: urlA));
    await tester.pumpWidget(
      StratumWebView(
        source: StratumWebViewSource.url(
          Uri.parse('https://app.example.com/a'),
        ),
      ),
    );
    expect(platforms.single.loads, [urlA]);
    await tester.pumpWidget(StratumWebView(source: urlB));
    expect(platforms.single.loads, [urlA, urlB]);
  });

  testWidgets('keeps the latest source when it changes twice', (tester) async {
    const html = StratumWebViewSource.html('<p>C</p>');
    await tester.pumpWidget(StratumWebView(source: urlA));
    await tester.pumpWidget(StratumWebView(source: urlB));
    await tester.pumpWidget(const StratumWebView(source: html));
    expect(platforms.single.loads, [urlA, urlB, html]);
  });

  testWidgets('forwards the latest callbacks', (tester) async {
    final first = <StratumWebViewMessage>[];
    final second = <StratumWebViewMessage>[];
    await tester.pumpWidget(
      StratumWebView(
        source: urlA,
        allowedOrigins: {appOrigin},
        onMessage: first.add,
      ),
    );
    await tester.pumpWidget(
      StratumWebView(
        source: urlA,
        allowedOrigins: {appOrigin},
        onMessage: second.add,
      ),
    );
    platforms.single.listener.onMessage(const StratumWebViewMessage(data: 'x'));
    expect(first, isEmpty);
    expect(second, [const StratumWebViewMessage(data: 'x')]);
  });

  testWidgets('applies javaScriptEnabled changes', (tester) async {
    await tester.pumpWidget(StratumWebView(source: urlA));
    await tester.pumpWidget(
      StratumWebView(source: urlA, javaScriptEnabled: false),
    );
    expect(platforms.single.javaScriptChanges, [false]);
  });

  testWidgets(
    'reports a load error instead of throwing for a rejected scheme',
    (tester) async {
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);
      await tester.pumpWidget(
        StratumWebView(
          source: StratumWebViewSource.url(Uri.parse('javascript:0')),
        ),
      );
      await tester.pump();
      expect(reported, hasLength(1));
      expect(reported.single.exception, isArgumentError);
      expect(platforms.single.loads, isEmpty);
    },
  );

  testWidgets('switching to an external controller disposes the owned one', (
    tester,
  ) async {
    await tester.pumpWidget(StratumWebView(source: urlA));
    final owned = platforms.single;
    final controller = StratumWebViewController();
    addTearDown(controller.dispose);
    final external = platforms.last;
    await tester.pumpWidget(
      StratumWebView(controller: controller, source: urlA),
    );
    expect(owned.disposed, isTrue);
    expect(external.loads, [urlA]);
  });

  testWidgets('a replaced external controller stops reaching the callbacks', (
    tester,
  ) async {
    final received = <StratumWebViewMessage>[];
    final first = StratumWebViewController();
    final second = StratumWebViewController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final firstPlatform = platforms.first;
    await tester.pumpWidget(
      StratumWebView(
        controller: first,
        source: urlA,
        allowedOrigins: {appOrigin},
        onMessage: received.add,
      ),
    );
    await tester.pumpWidget(
      StratumWebView(
        controller: second,
        source: urlA,
        allowedOrigins: {appOrigin},
        onMessage: received.add,
      ),
    );
    firstPlatform.listener.onMessage(const StratumWebViewMessage(data: 'x'));
    expect(received, isEmpty);
  });

  testWidgets('replacing an already disposed external controller is safe', (
    tester,
  ) async {
    final first = StratumWebViewController();
    final second = StratumWebViewController();
    addTearDown(second.dispose);
    await tester.pumpWidget(StratumWebView(controller: first, source: urlA));
    first.dispose();
    await tester.pumpWidget(StratumWebView(controller: second, source: urlA));
    expect(tester.takeException(), isNull);
    expect(platforms.last.loads, [urlA]);
  });
}
