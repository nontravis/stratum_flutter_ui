import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/themes/constant/window_size.dart';

/// A corner of the screen a float notice shows in, start and end resolved
/// through `Directionality` (US-01 FR-02).
enum StratumToastCorner {
  topStart,
  topCenter,
  topEnd,
  bottomStart,
  bottomCenter,
  bottomEnd,
}

/// An edge a solid notice spans, top or bottom (US-01 FR-02).
enum StratumToastEdge { top, bottom }

/// Where a notice shows: a float corner, or a solid edge (US-01 FR-02).
sealed class StratumToastPlacement {
  const factory float(StratumToastCorner corner) = StratumToastFloat;
  const factory solid(StratumToastEdge edge) = StratumToastSolid;
}

/// A float notice in a [corner], no wider than the theme's notice width
/// and the window less the float margin (US-01 FR-02).
final class StratumToastFloat implements StratumToastPlacement {
  const new(this.corner);

  final StratumToastCorner corner;
}

/// A solid notice centered along [edge] at the full width of the screen
/// (US-01 FR-02).
final class StratumToastSolid implements StratumToastPlacement {
  const new(this.edge);

  final StratumToastEdge edge;
}

/// One button on a notice: a tap runs [onPressed] and closes the notice
/// (US-01 FR-01, FR-04).
class StratumToastAction {
  const new({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

/// The default placement of a call that passes none: a float notice in
/// the bottom center corner on mobile and tablet, bottom start on
/// desktop and bigDesktop (US-01 FR-01 E04).
StratumToastPlacement defaultToastPlacement(WindowSize window) =>
    window >= WindowSize.desktop
    ? const StratumToastFloat(StratumToastCorner.bottomStart)
    : const StratumToastFloat(StratumToastCorner.bottomCenter);

/// The toastification manager key of [placement] under [direction].
///
/// The key, not just the alignment, separates a solid edge from the
/// float center corners, since toastification freezes one config per
/// resolved alignment (`managers.putIfAbsent(` in its
/// `lib/src/core/toastification.dart`). A solid key takes an x no float
/// corner uses (-0.5); the full width hides it.
///
/// Internal to the toast folder; the barrel hides it.
// WORKAROUND: toastification keys a manager, and the config it freezes,
// by resolved `Alignment` alone, with no way to carry a second config at
// the same alignment; remove when toastification keys a manager per
// config, not per alignment (upstream issue #250).
Alignment toastManagerKey(
  StratumToastPlacement placement,
  TextDirection direction,
) {
  final start = direction == TextDirection.ltr ? -1.0 : 1.0;
  return switch (placement) {
    StratumToastSolid(edge: StratumToastEdge.top) => const Alignment(-0.5, -1),
    StratumToastSolid(edge: StratumToastEdge.bottom) => const Alignment(
      -0.5,
      1,
    ),
    StratumToastFloat(:final corner) => switch (corner) {
      StratumToastCorner.topStart => Alignment(start, -1),
      StratumToastCorner.topCenter => Alignment.topCenter,
      StratumToastCorner.topEnd => Alignment(-start, -1),
      StratumToastCorner.bottomStart => Alignment(start, 1),
      StratumToastCorner.bottomCenter => Alignment.bottomCenter,
      StratumToastCorner.bottomEnd => Alignment(-start, 1),
    },
  };
}
