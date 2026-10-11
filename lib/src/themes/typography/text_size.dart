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
/// scale is [ownScale]'s entry at [window], the type's own; else
/// [themeScale]'s entry at [window], at the nearest smaller window size it
/// names, or at the smallest one it names (`windowSizeEntryIndex`); else
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
  if (window == null) return null;
  if (ownScale?[window] case final value?) {
    return (name: window, own: true, value: value);
  }
  if (themeScale == null) return null;
  final index = windowSizeEntryIndex(
    windowSizeNames.indexOf(window),
    (index) => themeScale.containsKey(windowSizeNames[index]),
  );
  if (index == null) return null;
  final name = windowSizeNames[index];
  return (name: name, own: false, value: themeScale[name]!);
}

double _unscaled(double size) => size;
