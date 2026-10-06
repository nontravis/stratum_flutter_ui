import 'package:flutter/animation.dart';
import 'package:stratum_ui/src/themes/config/animation_config.dart';

/// The Flutter [Curve] of a [StratumCurve] (design S2): kept out of the
/// model so the model compiles in the Dart VM, and exported through the
/// barrel so `stratumCurve.curve` reads as before.
extension StratumCurveConvert on StratumCurve {
  /// One [Cubic] per [StratumCubicCurve] instance: Flutter's `Cubic`
  /// defines no `==`, so the same instance keeps `AnimationStyle` equality
  /// stable.
  static final _cubics = Expando<Curve>();

  /// The curve to animate with.
  Curve get curve => switch (this) {
    StratumNamedCurve(:final name) => StratumNamedCurve.byName[name]!,
    final StratumCubicCurve cubic => _cubics[cubic] ??= Cubic(
      cubic.a,
      cubic.b,
      cubic.c,
      cubic.d,
    ),
  };
}
