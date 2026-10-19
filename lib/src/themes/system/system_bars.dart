import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/system/system_style.dart';
import 'package:stratum_ui/src/themes/system/system_style_region.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/system_bars.freezed.dart';

/// What the resolver applies to the platform for one frame (FO-03 US-14
/// FR-02 to FR-04). Internal: not exported.
@valueModel
abstract class SystemBars with _$SystemBars {
  const factory({
    /// The status bar fields, and the navigation bar fields when the
    /// navigation bar's point was read; every bar color in it is
    /// transparent, since the root paints the bar colors itself (themes s03
    /// invariant 45).
    required SystemUiOverlayStyle overlay,

    /// Null when no layer sets one this frame; the resolver falls back to
    /// `edgeToEdge` only once some layer has set it during its life, and
    /// before that leaves the platform's own bar mode untouched (R11).
    required SystemBarMode? barMode,

    /// Null when no layer sets one this frame; the resolver falls back to
    /// no lock only once some layer has set it during its life, and before
    /// that leaves the platform's own rotation lock untouched (R11).
    required List<DeviceOrientation>? orientations,

    /// Null when no layer sets one.
    required String? appSwitcherLabel,

    /// The merged `appSwitcherColor`.
    required Color? appSwitcherColor,

    /// The merged `statusBarColor`, which the root paints under the status
    /// bar.
    required Color? statusBarColor,

    /// The merged `navigationBarColor`, which the root paints under the
    /// navigation bar; null when its point was not read.
    required Color? navigationBarColor,

    /// The merged `navigationBarDividerColor`, which the root paints as the
    /// navigation bar's edge line; null when its point was not read.
    required Color? navigationBarDividerColor,
  }) = _SystemBars;
}

/// The bars of one frame from [status], every annotation at the status
/// bar's point, front to back, [navigation], those at the navigation
/// bar's point, null where the platform has no navigation bar to style,
/// and [painted], every Stratum region painted in the frame, front to
/// back, wherever it lies and whatever clips it. Null when [status] holds
/// no `SystemStyleBaseRegion`, so no Stratum theme lies under the bar.
///
/// Each point merges its style layers from the bottom up, every base
/// region, the outermost first, under every scope layer (themes s03
/// invariant 38), and blends its fills from the bottom up over the page
/// background of its topmost base (invariant 40); a `SystemUiOverlayStyle`
/// that is no Stratum layer, such as a Material `AppBar`'s, is one fill
/// (invariant 41). The merged bar color, which the root paints over every
/// page, blends last, the topmost fill, and the overlay sends the platform
/// transparent bar colors (invariant 45). The status point gives the
/// status bar fields and the app switcher color; the navigation point
/// gives the navigation bar fields; [painted], merged in the same order,
/// gives the bar mode, the rotation lock, and the app switcher label
/// (invariant 39).
SystemBars? resolveSystemBars(
  List<SystemUiOverlayStyle> status, {
  List<SystemUiOverlayStyle>? navigation,
  List<SystemStyleRegion> painted = const [],
}) {
  final top = _Point.read(status);
  if (top == null) return null;
  final bottom = navigation == null ? null : _Point.read(navigation);
  final style = top.style;
  final behavior = _merge(painted);
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
    barMode: behavior.barMode,
    orientations: behavior.orientations,
    appSwitcherLabel: behavior.appSwitcherLabel,
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

/// The Stratum style layers among [entries], front to back, merged from
/// the bottom up: every base region, the outermost first, then every
/// scope layer over them, so a theme application nested in a page stays
/// under that page's style (themes s03 invariant 38).
SystemStyle _merge(List<SystemUiOverlayStyle> entries) {
  var bases = const SystemStyle();
  var layers = const SystemStyle();
  for (final entry in entries.reversed) {
    if (entry is SystemStyleBaseRegion) bases = bases.merge(entry.style);
    if (entry is SystemStyleLayerRegion) layers = layers.merge(entry.style);
  }
  return bases.merge(layers);
}

/// The layers found at one bar's point.
final class _Point {
  new(this.style, this.background, this.fills);

  /// The annotations [entries], front to back, read from the bottom up;
  /// null with no base region among them. A fill found beneath a base that
  /// is itself beneath a more topmost base is dropped: the topmost base's
  /// own `background` occludes it (us14/fr01: the topmost base wins over
  /// an outer one, its page background included).
  static _Point? read(List<SystemUiOverlayStyle> entries) {
    Color? background;
    final fills = <SystemUiOverlayStyle>[];
    for (final entry in entries.reversed) {
      if (entry is SystemStyleBaseRegion) {
        background = entry.background;
        fills.clear();
      } else if (entry is! SystemStyleLayerRegion) {
        fills.add(entry);
      }
    }
    return background == null
        ? null
        : _Point(_merge(entries), background, fills);
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
