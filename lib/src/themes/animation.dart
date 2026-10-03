import 'package:stratum_ui/src/src.dart';

/// The five duration levels of `animation.duration` (spec G5).
enum StratumMotionLevel { veryFast, fast, normal, slow, verySlow }

/// One animation style per [StratumMotionLevel].
@immutable
class StratumMotionLevels {
  const new({
    required this.veryFast,
    required this.fast,
    required this.normal,
    required this.slow,
    required this.verySlow,
  });

  final AnimationStyle veryFast;
  final AnimationStyle fast;
  final AnimationStyle normal;
  final AnimationStyle slow;
  final AnimationStyle verySlow;

  AnimationStyle operator [](StratumMotionLevel level) => switch (level) {
    StratumMotionLevel.veryFast => veryFast,
    StratumMotionLevel.fast => fast,
    StratumMotionLevel.normal => normal,
    StratumMotionLevel.slow => slow,
    StratumMotionLevel.verySlow => verySlow,
  };

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is StratumMotionLevels &&
      other.veryFast == veryFast &&
      other.fast == fast &&
      other.normal == normal &&
      other.slow == slow &&
      other.verySlow == verySlow;

  @override
  int get hashCode => Object.hash(veryFast, fast, normal, slow, verySlow);
}

/// A theme's motion: the `animation` group of its `theme.yaml` (spec
/// section 7.8). Reduced motion changes none of these values (C1): each
/// animating widget applies its own reduced-motion rule.
@immutable
class StratumAnimation extends StratumMotionLevels {
  const new({
    required super.veryFast,
    required super.fast,
    required super.normal,
    required super.slow,
    required super.verySlow,
    required this.appear,
    required this.defaultLevel,
  });

  /// Each level: forward the level's duration, reverse that duration times
  /// `reverseRatio` rounded to whole microseconds, both on the `standard`
  /// curve. [appear]: the same durations, forward on `enter`, reverse on
  /// `exit`. Throws an [ArgumentError] when [config] lacks a level, a
  /// curve role, or names an unknown default level.
  factory fromConfig(StratumAnimationConfig config) {
    Curve curve(String role) =>
        (config.curves[role] ??
                (throw ArgumentError.value(
                  role,
                  'role',
                  'no curve for this role in the animation config',
                )))
            .curve;
    final standard = curve('standard');
    final enter = curve('enter');
    final exit = curve('exit');
    AnimationStyle style(StratumMotionLevel level, Curve forward, Curve back) {
      final duration =
          config.durations[level.name] ??
          (throw ArgumentError.value(
            level.name,
            'level',
            'no duration for this level in the animation config',
          ));
      return AnimationStyle(
        duration: duration,
        reverseDuration: Duration(
          microseconds: (duration.inMicroseconds * config.reverseRatio).round(),
        ),
        curve: forward,
        reverseCurve: back,
      );
    }

    StratumMotionLevels levels(Curve forward, Curve back) =>
        StratumMotionLevels(
          veryFast: style(StratumMotionLevel.veryFast, forward, back),
          fast: style(StratumMotionLevel.fast, forward, back),
          normal: style(StratumMotionLevel.normal, forward, back),
          slow: style(StratumMotionLevel.slow, forward, back),
          verySlow: style(StratumMotionLevel.verySlow, forward, back),
        );
    final main = levels(standard, standard);
    return StratumAnimation(
      veryFast: main.veryFast,
      fast: main.fast,
      normal: main.normal,
      slow: main.slow,
      verySlow: main.verySlow,
      appear: levels(enter, exit),
      defaultLevel:
          StratumMotionLevel.values.asNameMap()[config.defaultLevel] ??
          (throw ArgumentError.value(
            config.defaultLevel,
            'defaultLevel',
            'not a motion level',
          )),
    );
  }

  /// The package default yaml's `animation` group as constants, for a
  /// widget with no theme above it (spec G20). A test keeps it equal to
  /// the yaml.
  static const packageDefault = StratumAnimation(
    veryFast: AnimationStyle(
      duration: Duration(milliseconds: 50),
      reverseDuration: Duration(milliseconds: 32),
      curve: Curves.easeInOutSine,
      reverseCurve: Curves.easeInOutSine,
    ),
    fast: AnimationStyle(
      duration: Duration(milliseconds: 125),
      reverseDuration: Duration(milliseconds: 80),
      curve: Curves.easeInOutSine,
      reverseCurve: Curves.easeInOutSine,
    ),
    normal: AnimationStyle(
      duration: Duration(milliseconds: 200),
      reverseDuration: Duration(milliseconds: 128),
      curve: Curves.easeInOutSine,
      reverseCurve: Curves.easeInOutSine,
    ),
    slow: AnimationStyle(
      duration: Duration(milliseconds: 300),
      reverseDuration: Duration(milliseconds: 192),
      curve: Curves.easeInOutSine,
      reverseCurve: Curves.easeInOutSine,
    ),
    verySlow: AnimationStyle(
      duration: Duration(milliseconds: 400),
      reverseDuration: Duration(milliseconds: 256),
      curve: Curves.easeInOutSine,
      reverseCurve: Curves.easeInOutSine,
    ),
    appear: StratumMotionLevels(
      veryFast: AnimationStyle(
        duration: Duration(milliseconds: 50),
        reverseDuration: Duration(milliseconds: 32),
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
      fast: AnimationStyle(
        duration: Duration(milliseconds: 125),
        reverseDuration: Duration(milliseconds: 80),
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
      normal: AnimationStyle(
        duration: Duration(milliseconds: 200),
        reverseDuration: Duration(milliseconds: 128),
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
      slow: AnimationStyle(
        duration: Duration(milliseconds: 300),
        reverseDuration: Duration(milliseconds: 192),
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
      verySlow: AnimationStyle(
        duration: Duration(milliseconds: 400),
        reverseDuration: Duration(milliseconds: 256),
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    ),
    defaultLevel: StratumMotionLevel.fast,
  );

  /// `StratumTheme.of(context).animation`: the yaml values, unchanged
  /// under reduced motion too (spec C1). Throws the [FlutterError] of
  /// [StratumThemeApplication.of] when no application is above [context].
  static StratumAnimation of(BuildContext context) =>
      StratumTheme.of(context).animation;

  /// For things that appear and leave, such as dialogs and popups.
  final StratumMotionLevels appear;

  /// The level `duration.default` names.
  final StratumMotionLevel defaultLevel;

  /// The `default` level: `fast` in the package default.
  AnimationStyle get defaultStyle => this[defaultLevel];

  @override
  bool operator ==(Object other) =>
      super == other &&
      other is StratumAnimation &&
      other.appear == appear &&
      other.defaultLevel == defaultLevel;

  @override
  int get hashCode => Object.hash(super.hashCode, appear, defaultLevel);
}
