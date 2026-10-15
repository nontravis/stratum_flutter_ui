import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/theme_transitions.freezed.dart';

/// The page transition type a theme names for each window size: the
/// `animation.transition` group of its `theme.yaml` (FO-01 US-01 FR-01),
/// which `StratumPageTransitionsBuilder` reads (FO-05 US-05 FR-04). Every
/// window size holds a type; there is no cascade.
@valueModel
abstract class StratumThemeTransitions with _$StratumThemeTransitions {
  const factory({
    required ScreenTransitionType watch,
    required ScreenTransitionType mobile,
    required ScreenTransitionType tablet,
    required ScreenTransitionType desktop,
    required ScreenTransitionType bigDesktop,
  }) = _StratumThemeTransitions;

  const new _();

  /// [ScreenTransitionType.platform] for every window size, the package
  /// default's.
  static const platform = StratumThemeTransitions(
    watch: ScreenTransitionType.platform,
    mobile: ScreenTransitionType.platform,
    tablet: ScreenTransitionType.platform,
    desktop: ScreenTransitionType.platform,
    bigDesktop: ScreenTransitionType.platform,
  );

  /// The type the theme names for [size].
  ScreenTransitionType operator [](WindowSize size) => switch (size) {
    WindowSize.watch => watch,
    WindowSize.mobile => mobile,
    WindowSize.tablet => tablet,
    WindowSize.desktop => desktop,
    WindowSize.bigDesktop => bigDesktop,
  };
}
