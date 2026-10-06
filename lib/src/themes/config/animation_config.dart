import 'package:flutter/animation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/config/theme_model.dart';

part 'generated/animation_config.freezed.dart';

/// The merged `animation` group of a theme (spec section 8.1).
@themeModel
abstract class StratumAnimationConfig with _$StratumAnimationConfig {
  const factory({
    /// Level name to forward duration: the levels of `animation.duration`
    /// other than `default`.
    required Map<String, Duration> durations,

    /// `animation.duration.default`, a key of [durations].
    required String defaultLevel,

    /// `animation.reverseDuration` as a ratio: 0.64 for `64%`.
    required double reverseRatio,

    /// `animation.curve`: `standard`, `enter`, `exit`.
    required Map<String, StratumCurve> curves,
  }) = _StratumAnimationConfig;
}

/// A curve as `theme.yaml` writes it: a `Curves` name or
/// `cubic(a, b, c, d)` (spec G15). `StratumCurveConvert` gives its Flutter
/// `Curve`.
@immutable
sealed class StratumCurve {
  const new();

  /// A name of [StratumNamedCurve.byName], or `cubic(a, b, c, d)` with a
  /// and c within 0 and 1; null for anything else.
  static StratumCurve? tryParse(String value) {
    if (StratumNamedCurve.byName.containsKey(value)) {
      return StratumNamedCurve(value);
    }
    final match = StratumCubicCurve.pattern.firstMatch(value);
    if (match == null) return null;
    final [a, b, c, d] = [
      for (var group = 1; group <= 4; group++) double.parse(match[group]!),
    ];
    if (a < 0 || a > 1 || c < 0 || c > 1) return null;
    return StratumCubicCurve(a, b, c, d);
  }
}

/// One of the 43 `static const` curves of Flutter's `Curves` class.
@themeModel
final class StratumNamedCurve extends StratumCurve with _$StratumNamedCurve {
  const new(this.name);

  /// The curve names `theme.yaml` accepts, case-sensitive (spec section
  /// 8.2), in the order of `animation/curves.dart`.
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

  /// A key of [byName].
  final String name;

  @override
  String toString() => 'StratumNamedCurve($name)';
}

/// `cubic(a, b, c, d)`, as Figma and CSS `cubic-bezier` write it.
@themeModel
final class StratumCubicCurve extends StratumCurve with _$StratumCubicCurve {
  const new(this.a, this.b, this.c, this.d);

  /// `cubic(a, b, c, d)` with each value a decimal number such as `0.37`,
  /// `-0.28`, or `.5`, spaces allowed around each.
  static final pattern = RegExp(
    r'^cubic\(\s*(-?(?:\d+(?:\.\d+)?|\.\d+))\s*,'
    r'\s*(-?(?:\d+(?:\.\d+)?|\.\d+))\s*,'
    r'\s*(-?(?:\d+(?:\.\d+)?|\.\d+))\s*,'
    r'\s*(-?(?:\d+(?:\.\d+)?|\.\d+))\s*\)$',
  );

  final double a;
  final double b;
  final double c;
  final double d;

  @override
  String toString() => 'StratumCubicCurve($a, $b, $c, $d)';
}
