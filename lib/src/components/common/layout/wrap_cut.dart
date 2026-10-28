import 'dart:math' as math;

/// Flutter's `precisionErrorTolerance` (`foundation/constants.dart`), the
/// slack `RenderWrap` allows before a child opens a new run.
const _tolerance = 1e-10;

/// Where a wrap with a limit cuts its children (US-14 FR-01, FR-02): the
/// first [shown] children in the runs of [runOf], then, when [overflowRun]
/// is set, the overflow child at the end of that run.
final class WrapCut {
  const new({required this.runOf, this.overflowRun});

  /// The run of each shown child, in child order, ascending from 0.
  final List<int> runOf;

  /// The run that ends with the overflow child; null builds none.
  final int? overflowRun;

  /// How many children show, from the first; the rest hide.
  int get shown => runOf.length;

  /// How many runs the cut lays out.
  int get runCount {
    final overflow = overflowRun;
    if (overflow != null) return overflow + 1;
    return runOf.isEmpty ? 0 : runOf.last + 1;
  }
}

/// Cuts children of main-axis [extents] that a wrap lays out in runs of
/// at most [limit], with [spacing] between the children of a run.
///
/// Runs follow `RenderWrap`'s rule (`rendering/wrap.dart`, Flutter
/// 3.47.3): a child opens a new run when the run's extent, [spacing], and
/// the child's extent pass [limit] by more than Flutter's tolerance. Only
/// main-axis extents matter, since neither limit depends on a child's
/// cross-axis extent.
///
/// The limit that hides more wins: [maxRuns] keeps the children of the
/// first runs, [maxChildren] the first children. When a child hides and
/// [overflowExtent] is set, it gives the overflow child's main-axis
/// extent for a hidden count. The overflow child follows the last shown
/// child under the same rule, opens a new run while that run stays within
/// [maxRuns], and at the cap hides shown children from the end, one at a
/// time, asking [overflowExtent] again for each new count, until it fits
/// or sits alone in the last allowed run (s03 INV-38).
WrapCut cutWrap({
  required List<double> extents,
  required double limit,
  required double spacing,
  int? maxRuns,
  int? maxChildren,
  double Function(int hiddenCount)? overflowExtent,
}) {
  final runOf = <int>[];
  var run = 0;
  var runExtent = 0.0;
  for (final extent in extents) {
    if (maxChildren != null && runOf.length >= maxChildren) break;
    if (runOf.isEmpty) {
      runExtent = extent;
    } else if (runExtent + spacing + extent - limit > _tolerance) {
      run += 1;
      runExtent = extent;
    } else {
      runExtent += spacing + extent;
    }
    if (maxRuns != null && run >= maxRuns) break;
    runOf.add(run);
  }
  if (runOf.length == extents.length || overflowExtent == null) {
    return WrapCut(runOf: runOf);
  }
  var shown = runOf.length;
  while (true) {
    final extent = overflowExtent(extents.length - shown);
    if (shown == 0) return const WrapCut(runOf: [], overflowRun: 0);
    final last = runOf[shown - 1];
    final kept = runOf.sublist(0, shown);
    if (_extentOf(last, kept, extents, spacing) + spacing + extent - limit <=
        _tolerance) {
      return WrapCut(runOf: kept, overflowRun: last);
    }
    if (maxRuns == null || last + 1 < maxRuns) {
      return WrapCut(runOf: kept, overflowRun: last + 1);
    }
    shown -= 1;
  }
}

/// The main-axis extent of [run] over the children [runOf] keeps.
double _extentOf(
  int run,
  List<int> runOf,
  List<double> extents,
  double spacing,
) {
  var extent = 0.0;
  var count = 0;
  for (var i = runOf.length - 1; i >= 0 && runOf[i] == run; i--) {
    extent += extents[i];
    count += 1;
  }
  return extent + spacing * math.max(0, count - 1);
}
