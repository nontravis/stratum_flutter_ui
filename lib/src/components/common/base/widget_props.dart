import 'package:flutter/material.dart';
import 'package:flutter_falmodel/flutter_falmodel.dart' show FullWidgetState;
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/components/common/responsive/device_window.dart';
import 'package:stratum_ui/src/themes/constant/color.dart';
import 'package:stratum_ui/src/themes/constant/feedback_state.dart';
import 'package:stratum_ui/src/themes/constant/widget_size.dart';
import 'package:stratum_ui/src/themes/constant/window_size.dart';
import 'package:stratum_ui/src/themes/theme_application.dart';
import 'package:stratum_ui/src/themes/theme_data.dart';

/// The props every Stratum component takes, and how they resolve.
///
/// Call the `resolve*` methods inside `build` only: they register
/// dependencies on the nearest [StratumThemeApplication] and
/// `WindowSizeScope`.
mixin StratumWidgetProps {
  /// Null resolves to the theme's `defaultWidgetSize`.
  WidgetSize? get size;

  /// Feedback colors go to [feedbackState] instead.
  ColorEnum? get color;

  /// Null uses the app's theme mode.
  ThemeMode? get themeMode;

  /// Null resolves from the nearest `WindowSizeScope`.
  WindowSize? get windowSize;

  /// Forces a visual state for previews and golden tests. When it is
  /// `normal`, the widget derives hovered, pressed, and focused at runtime.
  FullWidgetState get state;

  FeedbackState? get feedbackState;

  bool get disabled;

  bool get loading;

  /// Forwarded to `ContainerLayout.debug`.
  bool get debug;

  /// Merged over the component's default style; see [resolveStyle].
  WidgetStyle? get customStyle;

  StratumThemeData resolveTheme(BuildContext context) =>
      StratumThemeApplication.of(context, themeMode: themeMode);

  WidgetSize resolveSize(BuildContext context) =>
      size ?? resolveTheme(context).defaultWidgetSize;

  WindowSize resolveWindowSize(BuildContext context) =>
      windowSize ?? context.deviceWindow.windowSize;

  /// Returns [defaults] with every non-null field of [customStyle] applied.
  WidgetStyle resolveStyle(WidgetStyle defaults) =>
      defaults.merge(customStyle);
}
