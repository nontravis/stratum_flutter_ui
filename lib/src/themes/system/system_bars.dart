import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:stratum_ui/src/themes/system/system_style.dart';
import 'package:stratum_ui/src/themes/system/system_style_region.dart';

/// What the resolver applies to the platform for one frame (FO-03 US-14
/// FR-02 to FR-04). Internal: not exported.
@immutable
final class SystemBars {
  const new({
    required this.overlay,
    required this.barMode,
    required this.orientations,
    required this.appSwitcherLabel,
    required this.appSwitcherColor,
    required this.statusBarColor,
    required this.navigationBarColor,
    required this.navigationBarDividerColor,
  });

  /// The status bar fields, and the navigation bar fields when the
  /// navigation bar's point was read; every bar color in it is
  /// transparent, since the root paints the bar colors itself (themes s03
  /// invariant 45).
  final SystemUiOverlayStyle overlay;

  /// `edgeToEdge` when no layer sets one.
  final SystemBarMode barMode;

  /// Empty, no lock, when no layer sets them.
  final List<DeviceOrientation> orientations;

  /// Null when no layer sets one.
  final String? appSwitcherLabel;

  /// The merged `appSwitcherColor`.
  final Color? appSwitcherColor;

  /// The merged `statusBarColor`, which the root paints under the status
  /// bar.
  final Color? statusBarColor;

  /// The merged `navigationBarColor`, which the root paints under the
  /// navigation bar; null when its point was not read.
  final Color? navigationBarColor;

  /// The merged `navigationBarDividerColor`, which the root paints as the
  /// navigation bar's edge line; null when its point was not read.
  final Color? navigationBarDividerColor;

  @override
  bool operator ==(Object other) =>
      other is SystemBars &&
      other.overlay == overlay &&
      other.barMode == barMode &&
      listEquals(other.orientations, orientations) &&
      other.appSwitcherLabel == appSwitcherLabel &&
      other.appSwitcherColor == appSwitcherColor &&
      other.statusBarColor == statusBarColor &&
      other.navigationBarColor == navigationBarColor &&
      other.navigationBarDividerColor == navigationBarDividerColor;

  @override
  int get hashCode => Object.hash(
    overlay,
    barMode,
    Object.hashAll(orientations),
    appSwitcherLabel,
    appSwitcherColor,
    statusBarColor,
    navigationBarColor,
    navigationBarDividerColor,
  );
}

/// The bars of one frame from [status], every annotation at the status
/// bar's point, front to back, and [navigation], those at the navigation
/// bar's point, null where the platform has no navigation bar to style.
/// Null when [status] holds no `SystemStyleBaseRegion`, so no Stratum
/// theme lies under the bar.
///
/// Each point merges its style layers from the bottom up (themes s03
/// invariant 38) and blends its fills from the bottom up over the theme's
/// page background (invariant 40); a `SystemUiOverlayStyle` that is no
/// Stratum layer, such as a Material `AppBar`'s, is one fill (invariant
/// 41). The merged bar color, which the root paints over every page,
/// blends last, the topmost fill, and the overlay sends the platform
/// transparent bar colors (invariant 45). The status point gives the
/// status bar fields, the behavior, and the app switcher entry; the
/// navigation point gives the navigation bar fields.
SystemBars? resolveSystemBars(
  List<SystemUiOverlayStyle> status, {
  List<SystemUiOverlayStyle>? navigation,
}) {
  final top = _Point.read(status);
  if (top == null) return null;
  final bottom = navigation == null ? null : _Point.read(navigation);
  final style = top.style;
  final statusLight = _lightIcons(
    style.statusBarIcons,
    () => top.blend(_statusFill, strip: style.statusBarColor),
  );
  final navigationLight = switch (bottom) {
    final point? => _lightIcons(
      point.style.navigationBarIcons,
      () => point.blend(_navigationFill, strip: point.style.navigationBarColor),
    ),
    null => null,
  };
  final navigationColor = bottom == null ? null : _transparent;
  return SystemBars(
    overlay: SystemUiOverlayStyle(
      statusBarColor: _transparent,
      statusBarIconBrightness: _iconBrightness(statusLight),
      statusBarBrightness: statusLight ? Brightness.dark : Brightness.light,
      systemStatusBarContrastEnforced: style.statusBarContrast,
      systemNavigationBarColor: navigationColor,
      systemNavigationBarDividerColor: navigationColor,
      systemNavigationBarIconBrightness: navigationLight == null
          ? null
          : _iconBrightness(navigationLight),
      systemNavigationBarContrastEnforced: bottom?.style.navigationBarContrast,
    ),
    barMode: style.barMode ?? SystemBarMode.edgeToEdge,
    orientations: style.orientations ?? const [],
    appSwitcherLabel: style.appSwitcherLabel,
    appSwitcherColor: style.appSwitcherColor,
    statusBarColor: style.statusBarColor,
    navigationBarColor: bottom?.style.navigationBarColor,
    navigationBarDividerColor: bottom?.style.navigationBarDividerColor,
  );
}

/// The bar color the platform receives, so only the root's strip shows.
const _transparent = Color(0x00000000);

/// Whether light icons hold a higher WCAG contrast ratio against [fill]
/// than dark icons (FO-03 US-14 FR-02; NFR-U07): white icons against
/// black, a tie taking dark.
bool pickLightIcons(Color fill) =>
    contrastRatio(const Color(0xFFFFFFFF), fill) >
    contrastRatio(const Color(0xFF000000), fill);

/// The WCAG contrast ratio of [a] against [b].
double contrastRatio(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return x > y ? (x + 0.05) / (y + 0.05) : (y + 0.05) / (x + 0.05);
}

/// Android's icon brightness of light icons when [light], else of dark.
Brightness _iconBrightness(bool light) =>
    light ? Brightness.light : Brightness.dark;

bool _lightIcons(SystemBarIcons? icons, Color Function() fill) =>
    switch (icons ?? SystemBarIcons.auto) {
      SystemBarIcons.light => true,
      SystemBarIcons.dark => false,
      SystemBarIcons.auto => pickLightIcons(fill()),
    };

/// The fill that [style], an annotation no Stratum layer placed, paints
/// under the status bar: its `statusBarColor` when opaque, else black for
/// light icons and white for dark icons, as a Material `AppBar` picks its
/// icons against its own background; null when it names no icons.
Color? _statusFill(SystemUiOverlayStyle style) {
  final color = style.statusBarColor;
  if (color != null && color.a == 1) return color;
  final light = switch (style.statusBarIconBrightness) {
    Brightness.light => true,
    Brightness.dark => false,
    null => switch (style.statusBarBrightness) {
      Brightness.dark => true,
      Brightness.light => false,
      null => null,
    },
  };
  return _fillFor(light);
}

/// [_statusFill] for the navigation bar.
Color? _navigationFill(SystemUiOverlayStyle style) {
  final color = style.systemNavigationBarColor;
  if (color != null && color.a == 1) return color;
  return _fillFor(switch (style.systemNavigationBarIconBrightness) {
    Brightness.light => true,
    Brightness.dark => false,
    null => null,
  });
}

Color? _fillFor(bool? lightIcons) => switch (lightIcons) {
  true => const Color(0xFF000000),
  false => const Color(0xFFFFFFFF),
  null => null,
};

/// The layers found at one bar's point.
final class _Point {
  new(this.style, this.background, this.fills);

  /// The annotations [entries], front to back, read from the bottom up;
  /// null with no base region among them. A fill found beneath a base that
  /// is itself beneath a more topmost base is dropped: the topmost base's
  /// own `background` occludes it (us14/fr01: the topmost base wins over
  /// an outer one, its page background included).
  static _Point? read(List<SystemUiOverlayStyle> entries) {
    var style = const SystemStyle();
    Color? background;
    final fills = <SystemUiOverlayStyle>[];
    for (final entry in entries.reversed) {
      switch (entry) {
        case SystemStyleBaseRegion():
          style = style.merge(entry.style);
          background = entry.background;
          fills.clear();
        case SystemStyleLayerRegion():
          style = style.merge(entry.style);
        default:
          fills.add(entry);
      }
    }
    return background == null ? null : _Point(style, background, fills);
  }

  /// The merged style, the lowest layer first.
  final SystemStyle style;

  /// The page background of the topmost base region.
  final Color background;

  /// Every fill, the lowest first.
  final List<SystemUiOverlayStyle> fills;

  /// [fills] blended from the bottom up over [background], each foreign
  /// annotation's fill given by [foreign], and [strip], the bar color the
  /// root paints over every page, blended last.
  Color blend(
    Color? Function(SystemUiOverlayStyle style) foreign, {
    required Color? strip,
  }) {
    var color = background;
    for (final fill in fills) {
      final over = switch (fill) {
        SystemBarFillRegion(color: final declared) => declared,
        _ => foreign(fill),
      };
      if (over != null) color = Color.alphaBlend(over, color);
    }
    return strip == null ? color : Color.alphaBlend(strip, color);
  }
}
