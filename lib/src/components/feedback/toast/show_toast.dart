import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/feedback/toast/toast_host.dart';
import 'package:stratum_ui/src/components/feedback/toast/toast_placement.dart';
import 'package:stratum_ui/src/extensions/context_extension.dart';
import 'package:stratum_ui/src/themes/constant/feedback_state.dart';

extension StratumToastContextExtension on BuildContext {
  /// Shows one notice on the nearest `StratumToastHost` above this
  /// context: [message], an optional action, a [kind] that defaults to
  /// `info`, and a [placement] that defaults by window size (US-01
  /// FR-01).
  ///
  /// Throws the host's `FlutterError` when none is above.
  void showToast({
    required String message,
    StratumToastAction? action,
    FeedbackState kind = FeedbackState.info,
    StratumToastPlacement? placement,
  }) {
    StratumToastHost.of(this).show(
      StratumToastRequest(
        message: message,
        kind: kind,
        placement: placement ?? defaultToastPlacement(windowSize),
        action: action,
      ),
    );
  }
}
