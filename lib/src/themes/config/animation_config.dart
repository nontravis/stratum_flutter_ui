import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/animation_config.freezed.dart';

/// The merged `animation` group of a theme (spec section 8.1).
@valueModel
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

    /// `animation.transition`: window size name to page transition type
    /// name, one for each of `watch`, `mobile`, `tablet`, `desktop`, and
    /// `bigDesktop`. A config built by hand that sets none names
    /// `platform` for all five, as the package default does.
    @Default(<String, String>{
      'watch': 'platform',
      'mobile': 'platform',
      'tablet': 'platform',
      'desktop': 'platform',
      'bigDesktop': 'platform',
    })
    Map<String, String> transitions,
  }) = _StratumAnimationConfig;
}

/// A curve as `theme.yaml` writes it: a `Curves` name or
/// `cubic(a, b, c, d)` (spec G15). `StratumCurveConvert` gives its Flutter
/// `Curve`.
@immutable
sealed class StratumCurve {
  const new();

  /// A name of [StratumNamedCurve.names], or `cubic(a, b, c, d)` with a
  /// and c within 0 and 1; null for anything else.
  static StratumCurve? tryParse(String value) {
    if (StratumNamedCurve.names.contains(value)) {
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
@valueModel
final class StratumNamedCurve extends StratumCurve with _$StratumNamedCurve {
  const new(this.name);

  /// The curve names `theme.yaml` accepts, case-sensitive (spec section
  /// 8.2), in the order of `animation/curves.dart`. A test pins them to
  /// the keys of `StratumCurveConvert.byName`.
  static const names = <String>{
    'linear',
    'decelerate',
    'fastLinearToSlowEaseIn',
    'fastEaseInToSlowEaseOut',
    'ease',
    'easeIn',
    'easeInToLinear',
    'easeInSine',
    'easeInQuad',
    'easeInCubic',
    'easeInQuart',
    'easeInQuint',
    'easeInExpo',
    'easeInCirc',
    'easeInBack',
    'easeOut',
    'linearToEaseOut',
    'easeOutSine',
    'easeOutQuad',
    'easeOutCubic',
    'easeOutQuart',
    'easeOutQuint',
    'easeOutExpo',
    'easeOutCirc',
    'easeOutBack',
    'easeInOut',
    'easeInOutSine',
    'easeInOutQuad',
    'easeInOutCubic',
    'easeInOutCubicEmphasized',
    'easeInOutQuart',
    'easeInOutQuint',
    'easeInOutExpo',
    'easeInOutCirc',
    'easeInOutBack',
    'fastOutSlowIn',
    'slowMiddle',
    'bounceIn',
    'bounceOut',
    'bounceInOut',
    'elasticIn',
    'elasticOut',
    'elasticInOut',
  };

  /// A member of [names].
  final String name;

  @override
  String toString() => 'StratumNamedCurve($name)';
}

/// `cubic(a, b, c, d)`, as Figma and CSS `cubic-bezier` write it.
@valueModel
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
