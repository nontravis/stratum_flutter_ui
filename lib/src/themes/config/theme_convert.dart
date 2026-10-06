import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/config/plain_by_window_size.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';
import 'package:stratum_ui/src/themes/typography/typography_parser.dart';

// The convert of design S2: turns the plain values of stages 1 to 5 into
// the public theme types. It cannot fail, because the stages passed every
// value it reads: each weight is 100 to 900 in steps of 100, and each
// window size name is one of `windowSizeNames`. Internal: not exported.

/// [plain] as `StratumByWindowSize`.
StratumByWindowSize<StratumDimension> convertByWindowSize(
  PlainByWindowSize plain,
) {
  final sizes = plain.sizes;
  return sizes == null
      ? StratumByWindowSize.all(plain.all!)
      : StratumByWindowSize(_bySize(sizes));
}

/// [plain] as `StratumTypography`, each weight a [FontWeight].
StratumTypography convertTypography(PlainTypography plain) => StratumTypography(
  fonts: plain.fonts,
  families: plain.families,
  scaleByWindowSize: convertByWindowSize(plain.scaleByWindowSize),
  types: frozenMap({
    for (final MapEntry(key: type, value: style) in plain.types.entries)
      type: StratumTypeStyle(
        weight: FontWeight.values[style.weight ~/ 100 - 1],
        sizes: style.sizes,
        scaleByWindowSize: switch (style.scaleByWindowSize) {
          final scale? => _bySize(scale),
          null => null,
        },
      ),
  }),
);

Map<WindowSize, StratumDimension> _bySize(
  Map<String, StratumDimension> byName,
) => frozenMap({
  for (final MapEntry(:key, :value) in byName.entries)
    WindowSize.values.byName(key): value,
});
