import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/config/theme_model.dart';

part 'generated/system_style.freezed.dart';

/// The icon color of a system bar (FO-03 US-14 FR-01, FR-02).
enum SystemBarIcons {
  /// Light or dark, whichever holds the higher contrast against the fill
  /// under the bar; every bundled theme sets it.
  auto,

  /// Light icons: Android's icon brightness `Brightness.light`, iOS's
  /// status bar brightness `Brightness.dark`.
  light,

  /// Dark icons: Android's icon brightness `Brightness.dark`, iOS's status
  /// bar brightness `Brightness.light`.
  dark,
}

/// Which system bars show (FO-03 US-14 FR-03).
enum SystemBarMode {
  /// Both bars show over the app's content; the value when no layer sets
  /// one.
  edgeToEdge,

  /// `SystemUiMode.immersive`: both bars hide; an edge swipe shows them.
  immersive,

  /// `SystemUiMode.immersiveSticky`: both bars hide; an edge swipe shows
  /// them over the app for a moment.
  immersiveSticky,

  /// `SystemUiMode.leanBack`: both bars hide; a tap shows them.
  leanBack,

  /// The status bar only.
  topOnly,

  /// The navigation bar only.
  bottomOnly,
}

/// The style of the status bar, the navigation bar, and the app switcher
/// entry, merged field by field like `WidgetStyle`: a null field takes the
/// value of the layer below (FO-03 US-14 FR-01).
///
/// The theme file's `system` set gives the look fields, from
/// [statusBarIcons] to [appSwitcherColor]; [barMode], [orientations], and
/// [appSwitcherLabel] come from Dart only. Set it app-wide with
/// `StratumThemeApplication(systemStyle:)` and per page with
/// `SystemStyleScope`.
@themeModel
class SystemStyle with _$SystemStyle {
  const new({
    this.statusBarIcons,
    this.statusBarColor,
    this.statusBarContrast,
    this.navigationBarIcons,
    this.navigationBarColor,
    this.navigationBarDividerColor,
    this.navigationBarContrast,
    this.appSwitcherColor,
    this.barMode,
    this.orientations,
    this.appSwitcherLabel,
  });

  /// The status bar icons; `auto` picks against the fill under the bar.
  final SystemBarIcons? statusBarIcons;

  /// The status bar color; transparent paints the app edge to edge.
  final Color? statusBarColor;

  /// Whether Android 10 and later draws its own contrast scrim behind a
  /// transparent status bar.
  final bool? statusBarContrast;

  /// The navigation bar icons (Android only); `auto` picks against the
  /// fill under the bar.
  final SystemBarIcons? navigationBarIcons;

  /// The navigation bar color (Android only).
  final Color? navigationBarColor;

  /// The line between the navigation bar and the app (Android only).
  final Color? navigationBarDividerColor;

  /// Whether Android 10 and later draws its own contrast scrim behind a
  /// transparent navigation bar.
  final bool? navigationBarContrast;

  /// The color of the app switcher entry and, on the web, the browser
  /// theme color.
  final Color? appSwitcherColor;

  /// Which bars show; Dart only.
  final SystemBarMode? barMode;

  /// The rotations the app allows; empty means no lock. Dart only.
  final List<DeviceOrientation>? orientations;

  /// The label of the app switcher entry: the web tab title and the
  /// Android recent-apps label. Dart only, in the EndUser's language.
  final String? appSwitcherLabel;

  /// A copy where every non-null field of [other] replaces this one; a
  /// null field in [other] keeps this value, and a list replaces whole.
  SystemStyle merge(SystemStyle? other) {
    if (other == null) return this;
    return SystemStyle(
      statusBarIcons: other.statusBarIcons ?? statusBarIcons,
      statusBarColor: other.statusBarColor ?? statusBarColor,
      statusBarContrast: other.statusBarContrast ?? statusBarContrast,
      navigationBarIcons: other.navigationBarIcons ?? navigationBarIcons,
      navigationBarColor: other.navigationBarColor ?? navigationBarColor,
      navigationBarDividerColor:
          other.navigationBarDividerColor ?? navigationBarDividerColor,
      navigationBarContrast:
          other.navigationBarContrast ?? navigationBarContrast,
      appSwitcherColor: other.appSwitcherColor ?? appSwitcherColor,
      barMode: other.barMode ?? barMode,
      orientations: other.orientations ?? orientations,
      appSwitcherLabel: other.appSwitcherLabel ?? appSwitcherLabel,
    );
  }

  /// The look fields only, from [statusBarIcons] to [appSwitcherColor],
  /// the fields a theme file sets.
  SystemStyle get look => SystemStyle(
    statusBarIcons: statusBarIcons,
    statusBarColor: statusBarColor,
    statusBarContrast: statusBarContrast,
    navigationBarIcons: navigationBarIcons,
    navigationBarColor: navigationBarColor,
    navigationBarDividerColor: navigationBarDividerColor,
    navigationBarContrast: navigationBarContrast,
    appSwitcherColor: appSwitcherColor,
  );

  /// The behavior fields only, [barMode], [orientations], and
  /// [appSwitcherLabel], the fields only Dart sets.
  SystemStyle get behavior => SystemStyle(
    barMode: barMode,
    orientations: orientations,
    appSwitcherLabel: appSwitcherLabel,
  );
}
