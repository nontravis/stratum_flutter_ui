import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/adapters/webview_all_adapter.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/adapters/webview_flutter_adapter.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_io.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart'
    as official;
import 'package:webview_platform_interface/webview_platform_interface.dart'
    as fork;

import '../fakes/fake_webview_all_platform.dart';
import '../fakes/fake_webview_flutter_platform.dart';
import '../fakes/recording_listener.dart';

void main() {
  setUp(() {
    official.WebViewPlatform.instance = FakeWebViewFlutterPlatform();
    fork.WebViewPlatform.instance = FakeWebviewAllPlatform();
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
  });

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    test('uses webview_flutter on ${platform.name}', () {
      debugDefaultTargetPlatformOverride = platform;
      expect(
        createPlatformStratumWebView(RecordingListener()),
        isA<WebviewFlutterAdapter>(),
      );
    });
  }

  for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
    test('uses webview_all on ${platform.name}', () {
      debugDefaultTargetPlatformOverride = platform;
      expect(
        createPlatformStratumWebView(RecordingListener()),
        isA<WebviewAllAdapter>(),
      );
    });
  }

  test('rejects fuchsia', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    expect(
      () => createPlatformStratumWebView(RecordingListener()),
      throwsUnsupportedError,
    );
  });
}
