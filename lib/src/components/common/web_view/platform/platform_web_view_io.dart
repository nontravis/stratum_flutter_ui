import 'package:flutter/foundation.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/adapters/webview_all_adapter.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/adapters/webview_flutter_adapter.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';

/// Picks the native adapter for the running platform.
///
/// Conditional imports only separate web from native, so native platforms
/// are told apart here, at runtime.
PlatformStratumWebView createPlatformStratumWebView(
  PlatformStratumWebViewListener listener,
) {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS => WebviewFlutterAdapter(listener),
    TargetPlatform.windows ||
    TargetPlatform.linux => WebviewAllAdapter(listener),
    TargetPlatform.fuchsia => throw UnsupportedError(
      'StratumWebView is not supported on fuchsia.',
    ),
  };
}
