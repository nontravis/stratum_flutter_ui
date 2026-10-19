import 'package:stratum_ui/src/themes/config/plain_by_window_size.dart';
import 'package:stratum_ui/src/themes/constant/font_size.dart';
import 'package:stratum_ui/src/themes/typography/dimension.dart';

/// The window scale entry one text reads (FO-02 typography s03 step 4): the
/// window size `name` it is written at, whether the type's own map holds it
/// (`own`), and its `value`.
typedef WindowScaleEntry = ({String name, bool own, StratumDimension value});

/// One text's sizes in logical pixels (FO-02 typography s03 steps 4 to 6,
/// and step 8 for letter spacing).
///
/// `size` is the requested size plus the window scale. `fontSize` and
/// `lineBox` are what the theme asks for; `drawnFontSize`, `drawnLineBox`,
/// and `drawnSize` are what the text draws at, each falling back on `base`
/// when the theme's is not a finite number above 0 (steps 5, 6, and 8):
/// `drawnFontSize` drops the window scale and `adjustSize`, `drawnLineBox`
/// drops `spaceHeight` off the scaled `base`, and `drawnSize` — the basis
/// letter spacing scales — drops the window scale alone. `windowScale` is
/// the entry step 4 reads, or null when none adds to the size.
typedef TextSize = ({
  WindowScaleEntry? windowScale,
  double size,
  double fontSize,
  double lineBox,
  double drawnFontSize,
  double drawnLineBox,
  double drawnSize,
});

/// Whether [value] can size drawn text: a finite number above 0.
bool isDrawableSize(double value) => value.isFinite && value > 0;

/// The sizes of one text of the requested size [base] (FO-02 typography s03
/// steps 4 to 6, and step 8 for letter spacing's basis, with the fallback
/// of steps 5, 6, and 8).
///
/// [window] names the window size, or is null when none is known. The window
/// scale is the entry `windowScaleSource` picks over [ownScale] and
/// [themeScale], the type's own winning at the window size found; else
/// none. Both maps key by the names of `windowSizeNames`. [scale] is the
/// text scaler; the default is text scale 1.
///
/// Reaches no `dart:ui`, so `readTypography`'s draw-size check calls it
/// inside the Flutter-free parse as `TypographyResolver` does at draw time
/// (FO-02 typography s01 Shared size function).
TextSize textSizeOf({
  required double base,
  required String? window,
  required Map<String, StratumDimension>? ownScale,
  required Map<String, StratumDimension>? themeScale,
  required StratumDimension adjustSize,
  required StratumDimension spaceHeight,
  double Function(double size) scale = _unscaled,
}) {
  final entry = _windowScaleEntry(window, ownScale, themeScale);
  final size = base + (entry?.value.resolve(of: base) ?? 0);
  final fontSize = size + adjustSize.resolve(of: base);
  final scaledBase = scale(base);
  final lineBox = scaledBase + spaceHeight.resolve(of: scaledBase);
  return (
    windowScale: entry,
    size: size,
    fontSize: fontSize,
    lineBox: lineBox,
    drawnFontSize: isDrawableSize(fontSize) ? fontSize : base,
    drawnLineBox: isDrawableSize(lineBox) ? lineBox : scaledBase,
    drawnSize: isDrawableSize(size) ? size : base,
  );
}

/// The window size whose window scale a text reads at [window] (FO-02
/// US-04 FR-01 and FR-02): [window] itself when either map sets it, else
/// the nearest smaller window size either map sets, else the smallest one
/// either sets, in `windowSizeNames` order. `own` is whether the type's
/// own map sets the window size found, and wins there. Null when [window]
/// is null or neither map sets any window size.
///
/// [ownSets] and [themeSets] say whether the type's own and the theme-wide
/// `scaleByWindowSize` set a window size name, so `textSizeOf` asks the
/// parsed maps and `readTypography`'s draw-size check asks the keys the
/// raw yaml declares; both pick one entry (FO-02 typography s01 Shared
/// size function).
({String name, bool own})? windowScaleSource(
  String? window, {
  required bool Function(String name) ownSets,
  required bool Function(String name) themeSets,
}) {
  if (window == null) return null;
  final index = windowSizeEntryIndex(windowSizeNames.indexOf(window), (index) {
    final name = windowSizeNames[index];
    return ownSets(name) || themeSets(name);
  });
  if (index == null) return null;
  final name = windowSizeNames[index];
  return (name: name, own: ownSets(name));
}

/// The size of [defined] closest to [target], the smaller one on a tie
/// (FO-02 US-02 FR-02); null when [defined] is empty.
FontSize? nearestFontSize(Iterable<FontSize> defined, double target) {
  if (defined.isEmpty) return null;
  return defined.reduce((best, size) {
    final distance = (size.value - target).abs();
    final bestDistance = (best.value - target).abs();
    return distance < bestDistance ||
            (distance == bestDistance && size.value < best.value)
        ? size
        : best;
  });
}

WindowScaleEntry? _windowScaleEntry(
  String? window,
  Map<String, StratumDimension>? ownScale,
  Map<String, StratumDimension>? themeScale,
) {
  final source = windowScaleSource(
    window,
    ownSets: (name) => ownScale?.containsKey(name) ?? false,
    themeSets: (name) => themeScale?.containsKey(name) ?? false,
  );
  if (source == null) return null;
  final (:name, :own) = source;
  return (name: name, own: own, value: (own ? ownScale : themeScale)![name]!);
}

double _unscaled(double size) => size;
