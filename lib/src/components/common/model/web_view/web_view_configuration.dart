import 'package:flutter/foundation.dart' show ValueChanged;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/components/common/model/web_view/web_view_error.dart';
import 'package:stratum_ui/src/components/common/model/web_view/web_view_message.dart';
import 'package:stratum_ui/src/components/common/model/web_view/web_view_navigation_decision.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/web_view_configuration.freezed.dart';

/// Settings and callbacks that `StratumWebView` hands to its controller.
///
/// `==` compares every field; the five callbacks compare by identity (D4,
/// R1).
@internal
@valueModel
abstract class StratumWebViewConfiguration with _$StratumWebViewConfiguration {
  const factory({
    @Default(<Uri>{}) Set<Uri> allowedOrigins,
    @Default(true) bool javaScriptEnabled,
    ValueChanged<StratumWebViewMessage>? onMessage,
    StratumNavigationDecision Function(Uri url)? onNavigationRequest,
    ValueChanged<Uri?>? onPageStarted,
    ValueChanged<Uri?>? onPageFinished,
    ValueChanged<StratumWebViewError>? onError,
  }) = _StratumWebViewConfiguration;
}
