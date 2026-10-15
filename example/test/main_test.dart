import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// A widget test has no native web view, so the URL tab's controller needs a
// fake platform, the same way the package's own web_view tests do; main.dart
// already imports the web_view barrel this deeply for the same reason.
// ignore: implementation_imports
import 'package:stratum_ui/src/components/common/model/web_view/web_view_source.dart';
// ignore: implementation_imports
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
// ignore: implementation_imports
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_controller.dart';
import 'package:stratum_ui_example/main.dart';

void main() {
  late List<_FakePlatformWebView> created;

  setUp(() {
    created = [];
    debugStratumWebViewPlatformFactory = (listener) {
      final fake = _FakePlatformWebView(listener);
      created.add(fake);
      return fake;
    };
  });

  tearDown(() => debugStratumWebViewPlatformFactory = null);

  testWidgets(
    'f01/us01/fr01/e05: urlAddress unset, the URL tab loads https://flutter.dev',
    (tester) async {
      await tester.pumpWidget(const StratumWebViewExampleApp());

      expect(
        created.expand((fake) => fake.loads),
        contains(StratumWebViewSource.url(Uri.parse('https://flutter.dev'))),
      );
    },
  );

  testWidgets(
    'f01/us01/fr01/e05: urlAddress set, the URL tab loads it instead',
    (tester) async {
      final address = Uri.parse('http://127.0.0.1:9999/ok');

      await tester.pumpWidget(StratumWebViewExampleApp(urlAddress: address));

      final loads = created.expand((fake) => fake.loads);
      expect(loads, contains(StratumWebViewSource.url(address)));
      expect(
        loads,
        isNot(
          contains(StratumWebViewSource.url(Uri.parse('https://flutter.dev'))),
        ),
      );
    },
  );

  testWidgets(
    'f01/us02/s1, f01/us02/fr01: tapping the app bar button with the speed '
    'icon and tooltip "Performance overlay" flips showPerformanceOverlay '
    'from false to true',
    (tester) async {
      await tester.pumpWidget(const StratumWebViewExampleApp());

      MaterialApp app() => tester.widget(find.byType(MaterialApp));
      expect(app().showPerformanceOverlay, isFalse);

      await tester.tap(find.byTooltip('Performance overlay'));
      await tester.pump();

      expect(app().showPerformanceOverlay, isTrue);
    },
  );
}

/// Records every source a controller loads; `buildView` and the other calls
/// are never read by this test, so each one is an unreachable no-op.
final class _FakePlatformWebView implements PlatformStratumWebView {
  _FakePlatformWebView(this.listener);

  final PlatformStratumWebViewListener listener;
  final List<StratumWebViewSource> loads = [];

  @override
  Future<void> setJavaScriptEnabled(bool enabled) async {}

  @override
  Future<void> load(StratumWebViewSource source) async => loads.add(source);

  @override
  Future<void> reload() async {}

  @override
  Future<void> goBack() async {}

  @override
  Future<void> goForward() async {}

  @override
  Future<bool> canGoBack() async => false;

  @override
  Future<bool> canGoForward() async => false;

  @override
  Future<Uri?> currentUrl() async => null;

  @override
  Future<void> postMessage(String data, {Uri? targetOrigin}) async {}

  @override
  Future<void> replyToDocument(
    PlatformHtmlDocumentSender document,
    String data,
  ) async {}

  @override
  Widget buildView(BuildContext context) => const SizedBox();

  @override
  void dispose() {}
}
