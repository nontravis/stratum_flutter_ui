import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_controller.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

/// Key of the widget that [FakePlatformStratumWebView.buildView] returns.
const Key fakePlatformViewKey = ValueKey<String>('fake-platform-web-view');

/// Records every call that the controller makes.
final class FakePlatformStratumWebView implements PlatformStratumWebView {
  new(this.listener);

  final PlatformStratumWebViewListener listener;
  final List<StratumWebViewSource> loads = [];
  final List<bool> javaScriptChanges = [];
  final List<String> sentMessages = [];
  int reloadCount = 0;
  int backCount = 0;
  int forwardCount = 0;
  bool canGoBackValue = false;
  bool canGoForwardValue = false;
  Uri? currentUrlValue;
  StateError? postMessageError;
  bool disposed = false;

  @override
  Future<void> setJavaScriptEnabled(bool enabled) async =>
      javaScriptChanges.add(enabled);

  @override
  Future<void> load(StratumWebViewSource source) async => loads.add(source);

  @override
  Future<void> reload() async => reloadCount++;

  @override
  Future<void> goBack() async => backCount++;

  @override
  Future<void> goForward() async => forwardCount++;

  @override
  Future<bool> canGoBack() async => canGoBackValue;

  @override
  Future<bool> canGoForward() async => canGoForwardValue;

  @override
  Future<Uri?> currentUrl() async => currentUrlValue;

  @override
  Future<void> postMessage(String data) async {
    final error = postMessageError;
    if (error != null) throw error;
    sentMessages.add(data);
  }

  @override
  Widget buildView(BuildContext context) =>
      const SizedBox(key: fakePlatformViewKey);

  @override
  void dispose() => disposed = true;
}

/// Makes new controllers use fakes, and returns every fake they create.
///
/// Call from a test or `setUp`; the override is removed after the test.
List<FakePlatformStratumWebView> installFakePlatform() {
  final created = <FakePlatformStratumWebView>[];
  debugStratumWebViewPlatformFactory = (listener) {
    final fake = FakePlatformStratumWebView(listener);
    created.add(fake);
    return fake;
  };
  addTearDown(() => debugStratumWebViewPlatformFactory = null);
  return created;
}
