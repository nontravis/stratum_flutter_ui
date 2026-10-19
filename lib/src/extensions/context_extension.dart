import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/responsive/device_window.dart';
import 'package:stratum_ui/src/themes/constant/widget_size.dart';
import 'package:stratum_ui/src/themes/constant/window_size.dart';
import 'package:stratum_ui/src/themes/theme.dart';
import 'package:stratum_ui/src/themes/theme_application.dart';
import 'package:stratum_ui/src/themes/theme_data.dart';

extension StratumThemeContextExtension on BuildContext {
  /// `StratumTheme.of(this)`.
  StratumTheme get theme => StratumTheme.of(this);

  /// Whether the app or the platform asks for less motion at this context.
  ///
  /// `disableAnimations` comes from the nearest [MediaQuery], so an app or a
  /// test that sets it reaches every caller, else from the platform.
  /// `MediaQueryData` has no `reduceMotion` field, so that flag always comes
  /// from the view's dispatcher.
  bool get reducesMotion {
    final features = View.of(this).platformDispatcher.accessibilityFeatures;
    final disable =
        MediaQuery.maybeDisableAnimationsOf(this) ?? features.disableAnimations;
    return disable || features.reduceMotion;
  }

  /// `StratumTheme.of(this, themeMode: mode)`.
  StratumTheme getTheme([ThemeMode? mode]) =>
      StratumTheme.of(this, themeMode: mode);

  /// The theme data of [mode], else of the app's mode, from the nearest
  /// [StratumThemeApplication] (FO-03 US-10 FR-06).
  ///
  /// Throws a [FlutterError] that names [StratumThemeApplication] when
  /// none is above this context.
  StratumThemeData themeData([ThemeMode? mode]) =>
      StratumThemeApplication.of(this, themeMode: mode);

  /// The default widget size of [themeData] for [mode]; throws like
  /// [themeData].
  WidgetSize defaultWidgetSize([ThemeMode? mode]) =>
      themeData(mode).defaultWidgetSize;

  /// The window size class of the nearest `WindowSizeScope`; throws the
  /// scope's error, which says how to wrap the app, when none is above.
  WindowSize get windowSize => deviceWindow.windowSize;

  void clearFocus() => FocusScope.of(this).unfocus();

  void requestScopeFocus() => FocusScope.of(this).requestScopeFocus();

  void requestFocus([FocusNode? node]) =>
      FocusScope.of(this).requestFocus(node);
}
