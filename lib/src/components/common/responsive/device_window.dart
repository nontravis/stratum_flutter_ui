import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/responsive/keyboard_visibility_scope.dart';
import 'package:stratum_ui/src/components/common/responsive/window_size_scope.dart';
import 'package:stratum_ui/src/themes/constant/window_size.dart';

/// Window metrics and ambient platform settings read lazily from the caller's
/// [BuildContext].
///
/// Each getter depends only on the aspect it reads, so a widget rebuilds only
/// when that value changes, and [safeArea] reflects the nearest [MediaQuery]
/// (for example, zero top inset under an app bar).
///
/// Read inside `build` only; never store it in a field.
extension type DeviceWindow._(BuildContext _context) {
  double get width => MediaQuery.widthOf(_context);

  double get height => MediaQuery.heightOf(_context);

  EdgeInsets get safeArea => MediaQuery.paddingOf(_context);

  /// [height] minus the top and bottom [safeArea] insets at this point in the
  /// tree. For the space a widget actually receives, use a `LayoutBuilder`.
  double get safeHeight => height - safeArea.vertical;

  /// [width] minus the left and right [safeArea] insets at this point in the
  /// tree.
  double get safeWidth => width - safeArea.horizontal;

  /// Keyboard height not yet consumed at this point in the tree; a `Scaffold`
  /// body sees zero because the `Scaffold` already resized it.
  ///
  /// Rebuilds on every frame of the keyboard animation; read it only where
  /// the layout must follow the keyboard.
  double get keyboardHeight => MediaQuery.viewInsetsOf(_context).bottom;

  /// Whether the keyboard is open anywhere in the window, from the nearest
  /// [KeyboardVisibilityScope]. Rebuilds only when the keyboard opens or
  /// closes.
  bool get isKeyboardVisible => KeyboardVisibilityScope.of(_context);

  Orientation get orientation => MediaQuery.orientationOf(_context);

  bool get isPortrait => orientation == Orientation.portrait;

  bool get isLandscape => orientation == Orientation.landscape;

  /// [percent] of [width], where `50` is half the window.
  double widthPercent(double percent) => width * percent / 100;

  /// [percent] of [height], where `50` is half the window.
  double heightPercent(double percent) => height * percent / 100;

  /// [percent] of [safeWidth], where `50` is half the width inside the safe
  /// area at this point in the tree.
  double safeWidthPercent(double percent) => safeWidth * percent / 100;

  /// [percent] of [safeHeight], where `50` is half the height inside the safe
  /// area at this point in the tree.
  double safeHeightPercent(double percent) => safeHeight * percent / 100;

  /// The OS light or dark setting. The app theme may override it; read the
  /// theme to learn what the screen actually shows.
  Brightness get platformBrightness =>
      MediaQuery.platformBrightnessOf(_context);

  bool get isPlatformDarkMode => platformBrightness == Brightness.dark;

  bool get isPlatformLightMode => platformBrightness == Brightness.light;

  TextDirection get textDirection => Directionality.of(_context);

  bool get isLTR => textDirection == TextDirection.ltr;

  bool get isRTL => textDirection == TextDirection.rtl;

  /// The form factor from the nearest [WindowSizeScope]; switch on
  /// `(windowSize, orientation)` to tell portrait from landscape.
  WindowSize get windowSize => WindowSizeScope.of(_context);
}

extension DeviceWindowContextExtension on BuildContext {
  DeviceWindow get deviceWindow => DeviceWindow._(this);
}
