import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/components/feedback/toast/toast_host.dart';
import 'package:stratum_ui/src/components/feedback/toast/toast_placement.dart';
import 'package:stratum_ui/src/themes/constant/feedback_state.dart';

extension StratumToastContextExtension on BuildContext {
  /// Shows one notice on the nearest `StratumToastHost` above this
  /// context: [message], an optional action, a [kind] that defaults to
  /// `info`, a [placement] that defaults by window size, and a per-call
  /// [customStyle] that wins the notice's style order (US-01 FR-01,
  /// FR-06).
  ///
  /// The host shows and announces [message] as is, above every route;
  /// never pass a secret or personal data. The default placement is read
  /// from the host, so this call ties this context to no window size.
  ///
  /// Throws the host's `FlutterError` when none is above.
  void showToast({
    required String message,
    StratumToastAction? action,
    FeedbackState kind = FeedbackState.info,
    StratumToastPlacement? placement,
    WidgetStyle? customStyle,
  }) {
    StratumToastHost.of(this).show(
      StratumToastRequest(
        message: message,
        kind: kind,
        placement: placement,
        action: action,
        customStyle: customStyle,
      ),
    );
  }
}
