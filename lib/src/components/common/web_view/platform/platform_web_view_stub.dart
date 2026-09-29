import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';

/// Fallback when neither `dart:io` nor `dart:js_interop` is available.
PlatformStratumWebView createPlatformStratumWebView(
  PlatformStratumWebViewListener listener,
) {
  throw UnsupportedError('StratumWebView is not supported on this platform.');
}
