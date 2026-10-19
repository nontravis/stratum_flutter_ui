import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/model/toast/stratum_toast_placement.dart';
import 'package:stratum_ui/src/themes/constant/window_size.dart';

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
// config, not per alignment.
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
