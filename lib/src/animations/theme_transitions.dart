import 'package:stratum_ui/src/src.dart';

/// The page transition type a theme names for each window size: the
/// `animation.transition` group of its `theme.yaml` (FO-01 US-01 FR-01),
/// which `StratumPageTransitionsBuilder` reads (FO-05 US-05 FR-04). Every
/// window size holds a type; there is no cascade.
@immutable
class StratumThemeTransitions {
  const new({
    required this.watch,
    required this.mobile,
    required this.tablet,
    required this.desktop,
    required this.bigDesktop,
  });

  /// [ScreenTransitionType.platform] for every window size, the package
  /// default's.
  static const platform = StratumThemeTransitions(
    watch: ScreenTransitionType.platform,
    mobile: ScreenTransitionType.platform,
    tablet: ScreenTransitionType.platform,
    desktop: ScreenTransitionType.platform,
    bigDesktop: ScreenTransitionType.platform,
  );

  final ScreenTransitionType watch;
  final ScreenTransitionType mobile;
  final ScreenTransitionType tablet;
  final ScreenTransitionType desktop;
  final ScreenTransitionType bigDesktop;

  /// The type the theme names for [size].
  ScreenTransitionType operator [](WindowSize size) => switch (size) {
    WindowSize.watch => watch,
    WindowSize.mobile => mobile,
    WindowSize.tablet => tablet,
    WindowSize.desktop => desktop,
    WindowSize.bigDesktop => bigDesktop,
  };

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is StratumThemeTransitions &&
      other.watch == watch &&
      other.mobile == mobile &&
      other.tablet == tablet &&
      other.desktop == desktop &&
      other.bigDesktop == bigDesktop;

  @override
  int get hashCode => Object.hash(watch, mobile, tablet, desktop, bigDesktop);
}
