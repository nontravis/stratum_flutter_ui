import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/responsive/window_size_scope.dart';
import 'package:stratum_ui/src/themes/model/window_size.dart';

/// Window metrics read lazily from the caller's [BuildContext].
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

  /// Rebuilds on every frame of the keyboard animation; read it only where
  /// the layout must follow the keyboard.
  double get keyboardHeight => MediaQuery.viewInsetsOf(_context).bottom;

  bool get isKeyboardVisible => keyboardHeight > 0;

  Orientation get orientation => MediaQuery.orientationOf(_context);

  WindowSize get windowSize => WindowSizeScope.of(_context);
}

extension DeviceWindowContextExtension on BuildContext {
  DeviceWindow get deviceWindow => DeviceWindow._(this);
}
