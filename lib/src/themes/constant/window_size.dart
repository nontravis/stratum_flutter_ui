import 'dart:ui' show Size;

/// The form factor of the app window, ordered from smallest to largest.
///
/// Classifies the window's space, not the hardware: an iPad in narrow split
/// screen is [mobile]. Pair it with `DeviceWindow.orientation` to tell
/// portrait from landscape.
enum WindowSize {
  watch,
  mobile,
  tablet,
  desktop,
  bigDesktop;

  /// Classifies a window of [size] logical pixels, first match wins.
  ///
  /// - [bigDesktop]: width 1600 and up.
  /// - [desktop]: width 1200 and up, even when the window is very short.
  /// - [watch]: shortest side under 300 (Wear OS screens are 192-240+).
  /// - [tablet]: shortest side 600 and up, so a tablet keeps its class when
  ///   it rotates.
  /// - [mobile]: everything else, so a phone stays mobile in landscape.
  static WindowSize fromSize(Size size) => switch (size) {
    Size(width: >= 1600) => bigDesktop,
    Size(width: >= 1200) => desktop,
    Size(shortestSide: < 300) => watch,
    Size(shortestSide: >= 600) => tablet,
    _ => mobile,
  };

  bool get isWatch => this == watch;
  bool get isMobile => this == mobile;
  bool get isTablet => this == tablet;
  bool get isDesktop => this == desktop;
  bool get isBigDesktop => this == bigDesktop;

  bool operator <(WindowSize other) => index < other.index;

  bool operator <=(WindowSize other) => index <= other.index;

  bool operator >(WindowSize other) => index > other.index;

  bool operator >=(WindowSize other) => index >= other.index;
}
