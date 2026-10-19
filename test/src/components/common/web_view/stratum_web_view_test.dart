import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/model/web_view/web_view_message.dart';
import 'package:stratum_ui/src/components/common/model/web_view/web_view_source.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_controller.dart';

import 'fakes/fake_platform_stratum_web_view.dart';

void main() {
  final appOrigin = Uri.parse('https://app.example.com');
  final urlA = StratumWebViewSource.url(Uri.parse('https://app.example.com/a'));
  final urlB = StratumWebViewSource.url(Uri.parse('https://app.example.com/b'));
  late List<FakePlatformStratumWebView> platforms;

  setUp(() => platforms = installFakePlatform());

  testWidgets(
    'co01_02/us01/s1: creates a controller, loads the source, shows the view',
    (tester) async {
      await tester.pumpWidget(StratumWebView(source: urlA));
      expect(platforms.single.loads, [urlA]);
      expect(find.byKey(fakePlatformViewKey), findsOneWidget);
    },
  );

  testWidgets('co01_02/us01/fr03: disposes the controller it created', (
    tester,
  ) async {
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
    platforms.single.listener.onMessage(
      const StratumWebViewMessage(data: 'x'),
      const FakeHtmlDocumentSender(),
    );
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
    firstPlatform.listener.onMessage(
      const StratumWebViewMessage(data: 'x'),
      const FakeHtmlDocumentSender(),
    );
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

  testWidgets(
    'co01_02/us01/fr01/e01: never reaches the javascript url a hostile '
    'source returns on a later read',
    (tester) async {
      final hostile = _HostileUrlSource(
        Uri.parse('https://safe.example'),
        Uri.parse('javascript:alert(1)'),
      );
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      // `StratumWebView._load` destructures `url` through its pattern
      // match exactly once per load; a rebuild with the same source skips
      // `_load` entirely because `oldWidget.source != widget.source` is
      // `false` by identity, so the widget never performs the second read
      // that would return the hostile scheme (F2's residual risk).
      await tester.pumpWidget(StratumWebView(source: hostile));
      await tester.pumpWidget(StratumWebView(source: hostile));
      await tester.pump();

      expect(platforms.single.loads, [
        StratumWebViewSource.url(Uri.parse('https://safe.example')),
      ]);
      expect(reported, isEmpty);
    },
  );
}

/// A `StratumWebViewUrlSource` subclass that returns [_first] on the first
/// read of [url] and [_second] on every later read, to prove
/// `StratumWebView` trusts no source's url getter past a single read
/// (F2, F3).
class _HostileUrlSource extends StratumWebViewUrlSource {
  new(this._first, this._second) : super(_first);

  final Uri _first;
  final Uri _second;
  var _reads = 0;

  @override
  Uri get url => _reads++ == 0 ? _first : _second;
}
