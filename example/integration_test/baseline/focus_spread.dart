// Frozen by tool/perf_freeze.dart from c0d459a:lib/src/components/common/utility/focus_spread.dart. Do not edit; run
// the tool again. Verbatim except this header, the baseline import,
// and the Baseline prefix on the names the frozen files declare.
// ignore_for_file: type=lint, unused_import, unnecessary_import
import 'baseline.dart';

import 'package:stratum_ui/src/src.dart';

/// The focus ring before [StratumFocusBorder], which it now builds.
///
/// [focus] shows the focused look, [color] becomes
/// [StratumFocusBorder.customColor], and [inside] places the ring on
/// [child]'s inner edge, as [StratumFocusBorder.insideEdge] does. The ring
/// takes the outside style of the Figma `FocusBorder`. Deprecated in 1.1.0.
@Deprecated(
  'Use StratumFocusBorder instead. BaselineFocusSpread will be removed after one '
  'minor version.',
)
class BaselineFocusSpread extends StatelessWidget {
  @Deprecated(
    'Use StratumFocusBorder instead. BaselineFocusSpread will be removed after one '
    'minor version.',
  )
  const new({
    super.key,
    required this.child,
    this.borderRadius,
    this.spread = 4.0,
    this.focus = false,
    this.color,
    this.inside,
  });

  /// The box the ring surrounds.
  final Widget child;

  /// [child]'s own corner radius; null is radius 0.
  final BorderRadiusGeometry? borderRadius;

  /// Unused, as before; kept so callers still compile.
  final double spread;

  /// Whether the ring shows its focused look.
  final bool focus;

  /// The ring's color, passed on as [StratumFocusBorder.customColor]; it no
  /// longer fills [child]'s box.
  final Color? color;

  /// Whether the ring draws on [child]'s inner edge while [focus] is true;
  /// null and false draw it around [child].
  final bool? inside;

  @override
  Widget build(BuildContext context) {
    return StratumFocusBorder(
      state: focus ? FullWidgetState.focused : FullWidgetState.normal,
      customColor: color,
      insideEdge: inside ?? false,
      borderRadius: borderRadius,
      child: child,
    );
  }
}
