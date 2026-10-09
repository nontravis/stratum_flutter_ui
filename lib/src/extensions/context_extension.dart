import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/themes/theme.dart';

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

  void clearFocus() => FocusScope.of(this).unfocus();

  void requestScopeFocus() => FocusScope.of(this).requestScopeFocus();

  void requestFocus([FocusNode? node]) =>
      FocusScope.of(this).requestFocus(node);
}
