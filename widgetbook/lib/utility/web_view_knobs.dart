import 'package:stratum_ui/stratum_ui.dart';

import '../kit/preset.dart';

/// One field per `StratumWebView` constructor param, the `argsType` of its
/// stories (fo11/us04/fr01).
///
/// The callback fields are on/off switches; on reports the call under the
/// view (s03 INV-9).
class WebViewKnobs {
  const WebViewKnobs({
    required this.source,
    required this.controller,
    required this.allowedOrigins,
    this.javaScriptEnabled = true,
    this.onMessage = true,
    required this.onNavigationRequest,
    this.onPageStarted = true,
    this.onPageFinished = true,
    this.onError = true,
  });

  final RequiredPreset<StratumWebViewSource> source;
  final Preset<StratumWebViewController> controller;
  final RequiredPreset<Set<Uri>> allowedOrigins;
  final bool javaScriptEnabled;
  final bool onMessage;
  final Preset<StratumNavigationDecision Function(Uri url)> onNavigationRequest;
  final bool onPageStarted;
  final bool onPageFinished;
  final bool onError;
}
