import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// The merged `animation` group of a theme (spec section 8.1).
@immutable
class StratumAnimationConfig {
  const new({
    required this.durations,
    required this.defaultLevel,
    required this.reverseRatio,
    required this.curves,
  });

  /// Level name to forward duration: the levels of `animation.duration`
  /// other than `default`.
  final Map<String, Duration> durations;

  /// `animation.duration.default`, a key of [durations].
  final String defaultLevel;

  /// `animation.reverseDuration` as a ratio: 0.64 for `64%`.
  final double reverseRatio;

  /// `animation.curve`: `standard`, `enter`, `exit`.
  final Map<String, StratumCurve> curves;

  @override
  bool operator ==(Object other) =>
      other is StratumAnimationConfig &&
      mapEquals(other.durations, durations) &&
      other.defaultLevel == defaultLevel &&
      other.reverseRatio == reverseRatio &&
      mapEquals(other.curves, curves);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(
      durations.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    defaultLevel,
    reverseRatio,
    Object.hashAllUnordered(
      curves.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
  );
}

/// A curve as `theme.yaml` writes it: a `Curves` name or
/// `cubic(a, b, c, d)` (spec G15).
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

  /// The curve to animate with.
  Curve get curve;
}

/// One of the 43 `static const` curves of Flutter's `Curves` class.
final class StratumNamedCurve extends StratumCurve {
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
  Curve get curve => byName[name]!;

  @override
  bool operator ==(Object other) =>
      other is StratumNamedCurve && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'StratumNamedCurve($name)';
}

/// `cubic(a, b, c, d)`, as Figma and CSS `cubic-bezier` write it.
final class StratumCubicCurve extends StratumCurve {
  new(this.a, this.b, this.c, this.d);

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

  /// One [Cubic] per instance: Flutter's `Cubic` defines no `==`, so the
  /// same instance keeps `AnimationStyle` equality stable.
  @override
  late final Curve curve = Cubic(a, b, c, d);

  @override
  bool operator ==(Object other) =>
      other is StratumCubicCurve &&
      other.a == a &&
      other.b == b &&
      other.c == c &&
      other.d == d;

  @override
  int get hashCode => Object.hash(a, b, c, d);

  @override
  String toString() => 'StratumCubicCurve($a, $b, $c, $d)';
}
