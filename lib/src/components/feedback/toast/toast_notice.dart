import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/components/feedback/toast/toast_placement.dart';
import 'package:stratum_ui/src/themes/constant/feedback_state.dart';

/// Builds the look of one notice, replacing the plain look only: placement,
/// queue, timers, close paths, and the announcement stay the host's
/// (US-01 FR-06 E04, s03 invariant 13).
typedef StratumToastBuilder = Widget Function(
  BuildContext context,
  StratumToastNotice notice,
);

/// One notice as the plain look and an app `builder` read it: its message,
/// kind, action, placement, the edge inset its solid edge pads by, and the
/// page `snack` style layer the host resolved, plus the [close] call that
/// closes it (US-01 FR-06 E04; s03 invariants 4, 16).
class StratumToastNotice {
  const new({
    required this.message,
    required this.kind,
    required this.placement,
    required this.insets,
    required this.pageSnack,
    required this.customStyle,
    required this.close,
    required this.closeLabel,
    required this.kindLabel,
    this.action,
  });

  final String message;
  final FeedbackState kind;
  final StratumToastPlacement placement;

  /// The edge inset a solid notice pads its content by; zero on a float
  /// (s03 invariant 4).
  final EdgeInsets insets;

  /// The registered page's `PageLayoutStyle.snack` layer, null with no
  /// registered page (s03 invariant 16).
  final WidgetStyle? pageSnack;

  /// The per-call style layer, last in the style order (s03 invariant 16).
  final WidgetStyle? customStyle;

  final StratumToastAction? action;

  /// Closes this notice now, any close path's equal (US-01 FR-04).
  final VoidCallback close;

  /// The close button's accessible name: `StratumToastHost.closeButtonLabel`
  /// when the app set one, else FO-09's built-in label (s03 invariant 11).
  final String closeLabel;

  /// The kind's accessible name: `StratumToastHost.kindLabels[kind]` when
  /// the app set one, else FO-09's built-in name — the same name the host
  /// announces on show (FO-09 FR-01 E08; s03 invariant 11).
  final String kindLabel;
}
