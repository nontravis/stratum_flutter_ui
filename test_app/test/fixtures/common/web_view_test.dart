import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
// The fixture's web view needs the platform seam the package keeps out of its
// barrel, so a widget test never opens a real platform view.
// ignore: implementation_imports
import 'package:stratum_ui/src/components/common/model/web_view/web_view_source.dart';
// ignore: implementation_imports
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
// ignore: implementation_imports
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_controller.dart';
import 'package:stratum_ui_test_app/fixture_app.dart';
import 'package:stratum_ui_test_app/fixtures/common/web_view.dart';

import '../one_actionable_node.dart';

const _fixtureId = 'common/web_view';

/// Records the sources a fixture web view loads and the messages it sends,
/// and draws an empty box.
final class _RecordingPlatform implements PlatformStratumWebView {
  _RecordingPlatform(this.loads, this.sent);

  final List<StratumWebViewSource> loads;
  final List<String> sent;

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
  Future<void> postMessage(String data, {Uri? targetOrigin}) async =>
      sent.add(data);

  @override
  Future<void> replyToDocument(
    PlatformHtmlDocumentSender document,
    String data,
  ) async {}

  @override
  Widget buildView(BuildContext context) => const SizedBox.expand();

  @override
  void dispose() {}
}

/// Makes every web view the fixture builds record into the returned lists.
({List<StratumWebViewSource> loads, List<String> sent}) _record() {
  final loads = <StratumWebViewSource>[];
  final sent = <String>[];
  debugStratumWebViewPlatformFactory = (listener) =>
      _RecordingPlatform(loads, sent);
  addTearDown(() => debugStratumWebViewPlatformFactory = null);
  return (loads: loads, sent: sent);
}

void main() {
  testWidgets(
    'the fixture opens on the URL tab and loads the default address',
    (tester) async {
      final loads = _record().loads;
      await tester.pumpWidget(const FixtureApp(fixtureId: _fixtureId));
      await tester.pumpAndSettle();

      expect(find.text('URL'), findsOneWidget);
      expect(find.text('HTML'), findsOneWidget);
      expect(find.text('Bridge'), findsOneWidget);
      expect(loads, [
        StratumWebViewSource.url(Uri.parse('https://flutter.dev')),
      ]);
    },
  );

  testWidgets('the URL tab loads the address the fixture is given', (
    tester,
  ) async {
    final loads = _record().loads;
    final address = Uri.parse('http://127.0.0.1:8080/ok');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WebViewFixture(urlAddress: address)),
      ),
    );
    await tester.pumpAndSettle();

    expect(loads, [StratumWebViewSource.url(address)]);
  });

  testWidgets('the HTML tab loads the document and the Bridge tab shows its '
      'send button as one node with a label, role, and tap', (tester) async {
    final handle = tester.ensureSemantics();
    final loads = _record().loads;
    await tester.pumpWidget(const FixtureApp(fixtureId: _fixtureId));
    await tester.pumpAndSettle();

    // A Material `Tab` reads `SemanticsRole.tab` with a tap and no button
    // flag, so the guard checks that role; it holds no identifier.
    for (final tab in ['URL', 'HTML', 'Bridge']) {
      expectOneActionableNode(
        tester,
        find.bySemanticsLabel(RegExp('^$tab')),
        label: tab,
        role: SemanticsRole.tab,
      );
    }

    await tester.tap(find.text('HTML'));
    await tester.pumpAndSettle();
    expect(
      loads.last,
      const StratumWebViewSource.html(
        '<h1 style="font-family: sans-serif">Terms</h1>'
        '<p style="font-family: sans-serif">Rendered from an HTML string.</p>',
      ),
    );

    await tester.tap(find.text('Bridge'));
    await tester.pumpAndSettle();
    expect(find.text('No messages yet'), findsOneWidget);
    expectOneActionableNode(
      tester,
      find.bySemanticsLabel('Send to page'),
      label: 'Send to page',
    );
    handle.dispose();
  });

  testWidgets('Send to page forwards a numbered message to the Bridge tab '
      'page', (tester) async {
    final sent = _record().sent;
    await tester.pumpWidget(const FixtureApp(fixtureId: _fixtureId));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bridge'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send to page'));
    await tester.pump();
    await tester.tap(find.text('Send to page'));
    await tester.pump();

    expect(sent, ['flutter message 1', 'flutter message 2']);
    expect(find.byType(SnackBar), findsNothing);
  });
}
