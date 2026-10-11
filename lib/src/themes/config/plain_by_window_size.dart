import 'package:stratum_ui/src/themes/typography/dimension.dart';

/// The window size names a `theme.yaml` per-window-size value may hold, in
/// `WindowSize` order. A test pins them to `WindowSize.values`, so stage 5
/// checks the names without `WindowSize`, whose `fromSize` needs `dart:ui`
/// (FO-04 s01 Install check; plan D-i).
const windowSizeNames = <String>[
  'watch',
  'mobile',
  'tablet',
  'desktop',
  'bigDesktop',
];

/// The index, in [windowSizeNames] order, of the entry a per-window-size
/// value reads at the window size of [index]: [index] itself when [has]
/// holds for it; else the nearest smaller index [has] holds for; else the
/// smallest one; null when [has] holds for none (OQ11).
/// `StratumByWindowSize.valueFor` and FO-02's shared size function both
/// read through it, so the app and the Flutter-free parse fill a window
/// size alike.
int? windowSizeEntryIndex(int index, bool Function(int index) has) {
  for (var at = index; at >= 0; at--) {
    if (has(at)) return at;
  }
  for (var at = index + 1; at < windowSizeNames.length; at++) {
    if (has(at)) return at;
  }
  return null;
}

/// A per-window-size value as stage 5 reads it: one value for every window
/// size, or the values of the window sizes a yaml map names, keyed by
/// name. `convertByWindowSize` turns it into `StratumByWindowSize`.
/// Internal: not exported.
final class PlainByWindowSize {
  /// The entries a yaml map wrote, by window size name; never empty.
  const new(Map<String, StratumDimension> this.sizes) : all = null;

  /// One value for every window size: a scalar token.
  const new all(StratumDimension this.all) : sizes = null;

  /// The value of every window size, or null when [sizes] holds them.
  final StratumDimension? all;

  /// The values by window size name, or null when [all] holds the value.
  final Map<String, StratumDimension>? sizes;
}
