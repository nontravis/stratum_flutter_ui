import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/stratum_toast_placement.freezed.dart';

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
@freezed
sealed class StratumToastPlacement with _$StratumToastPlacement {
  /// A float notice in [corner], no wider than the theme's notice width and
  /// the window less the float margin (US-01 FR-02).
  const factory float(StratumToastCorner corner) = StratumToastFloat;

  /// A solid notice centered along [edge] at the full width of the screen
  /// (US-01 FR-02).
  const factory solid(StratumToastEdge edge) = StratumToastSolid;
}
