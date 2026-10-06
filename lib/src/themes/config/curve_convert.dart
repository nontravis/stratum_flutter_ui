import 'package:flutter/animation.dart';
import 'package:stratum_ui/src/themes/config/animation_config.dart';

/// The Flutter [Curve] of a [StratumCurve] (design S2): kept out of the
/// model so the model compiles in the Dart VM, and exported through the
/// barrel so `stratumCurve.curve` reads as before.
extension StratumCurveConvert on StratumCurve {
  /// The `Curves` constant of each name of `StratumNamedCurve.names`, in
  /// the same order.
  static const byName = <String, Curve>{
    'linear': Curves.linear,
    'decelerate': Curves.decelerate,
    'fastLinearToSlowEaseIn': Curves.fastLinearToSlowEaseIn,
    'fastEaseInToSlowEaseOut': Curves.fastEaseInToSlowEaseOut,
    'ease': Curves.ease,
    'easeIn': Curves.easeIn,
    'easeInToLinear': Curves.easeInToLinear,
    'easeInSine': Curves.easeInSine,
    'easeInQuad': Curves.easeInQuad,
    'easeInCubic': Curves.easeInCubic,
    'easeInQuart': Curves.easeInQuart,
    'easeInQuint': Curves.easeInQuint,
    'easeInExpo': Curves.easeInExpo,
    'easeInCirc': Curves.easeInCirc,
    'easeInBack': Curves.easeInBack,
    'easeOut': Curves.easeOut,
    'linearToEaseOut': Curves.linearToEaseOut,
    'easeOutSine': Curves.easeOutSine,
    'easeOutQuad': Curves.easeOutQuad,
    'easeOutCubic': Curves.easeOutCubic,
    'easeOutQuart': Curves.easeOutQuart,
    'easeOutQuint': Curves.easeOutQuint,
    'easeOutExpo': Curves.easeOutExpo,
    'easeOutCirc': Curves.easeOutCirc,
    'easeOutBack': Curves.easeOutBack,
    'easeInOut': Curves.easeInOut,
    'easeInOutSine': Curves.easeInOutSine,
    'easeInOutQuad': Curves.easeInOutQuad,
    'easeInOutCubic': Curves.easeInOutCubic,
    'easeInOutCubicEmphasized': Curves.easeInOutCubicEmphasized,
    'easeInOutQuart': Curves.easeInOutQuart,
    'easeInOutQuint': Curves.easeInOutQuint,
    'easeInOutExpo': Curves.easeInOutExpo,
    'easeInOutCirc': Curves.easeInOutCirc,
    'easeInOutBack': Curves.easeInOutBack,
    'fastOutSlowIn': Curves.fastOutSlowIn,
    'slowMiddle': Curves.slowMiddle,
    'bounceIn': Curves.bounceIn,
    'bounceOut': Curves.bounceOut,
    'bounceInOut': Curves.bounceInOut,
    'elasticIn': Curves.elasticIn,
    'elasticOut': Curves.elasticOut,
    'elasticInOut': Curves.elasticInOut,
  };

  /// One [Cubic] per [StratumCubicCurve] instance: Flutter's `Cubic`
  /// defines no `==`, so the same instance keeps `AnimationStyle` equality
  /// stable.
  static final _cubics = Expando<Curve>();

  /// The curve to animate with.
  Curve get curve => switch (this) {
    StratumNamedCurve(:final name) => byName[name]!,
    final StratumCubicCurve cubic => _cubics[cubic] ??= Cubic(
      cubic.a,
      cubic.b,
      cubic.c,
      cubic.d,
    ),
  };
}
