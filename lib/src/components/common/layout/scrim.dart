import 'package:stratum_ui/src/components/common/l10n/built_in_labels.dart';
import 'package:stratum_ui/src/src.dart';

/// The scrim a modal layout's route and a page drawer share (layout s03
/// invariants 67 and 72): the theme's `normal-inverse` color, its own
/// alpha times the `opacity.scrim` opacity as a Figma layer opacity,
/// blurred by `blur/1`, fading with [animation], over a [ModalBarrier] that
/// blocks what sits under it for taps
/// and screen readers, reads the dismiss label, and calls [onDismiss] on a
/// tap; with [showBackground] false only the barrier stays (US-20 FR-06;
/// US-19 FR-04, FR-05).
///
/// It reads the theme from its own context, so a theme switch restyles an
/// open scrim (US-20 FR-06 E02, E06; US-19 FR-04 E06). It declares the
/// color it paints at this frame for the automatic bar icons, so the icons
/// flip when the blend crosses the contrast pick, as the eye sees it, in
/// every mode the fade runs (US-19 FR-04 E08; US-20 FR-06 E07).
class Scrim extends StatelessWidget {
  const new({
    super.key,
    required this.animation,
    this.showBackground = true,
    this.onDismiss,
  });

  /// The fade, already on the theme's `standard` curve: the scrim eases
  /// nothing again, so a modal and a drawer fade alike.
  final Animation<double> animation;

  final bool showBackground;

  /// Dismisses what the scrim sits under; null pops the nearest
  /// navigator's top route.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final color = theme.color.background.defaults.normalInverse;
    return StackLayout(
      fit: StackFit.expand,
      children: [
        if (showBackground)
          IgnorePointer(
            child: FadeTransition(
              opacity: animation,
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, child) => SystemBarFill(
                  color: color.withValues(
                    alpha: color.a * theme.data.opacity.scrim * animation.value,
                  ),
                  child: child!,
                ),
                // The box behind this boundary paints the same pixels every
                // frame; only the declaration above it changes. Isolating
                // it here stops the per-frame fill color from re-executing
                // the blur (performance review I1).
                child: RepaintBoundary(
                  child: ContainerLayout(
                    style: WidgetStyle(
                      backgroundColor: color.withValues(
                        alpha: color.a * theme.data.opacity.scrim,
                      ),
                      backgroundBlur: theme.blur.level1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ModalBarrier(
          semanticsLabel: builtInLabelsOf(context).dismissLabel,
          onDismiss: onDismiss,
        ),
      ],
    );
  }
}
