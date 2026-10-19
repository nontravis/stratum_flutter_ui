import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/split_pane.freezed.dart';

/// One pane of a `SplitLayout`: its [child] and its size along the split
/// axis, in logical pixels.
///
/// A pane opens at [size], or shares the space the sized panes leave in
/// proportion to [flex], 1 when both are null; [min] and [max] bound it
/// whatever opens it, a drag, a key, or a narrower window, while the
/// window leaves room for every pane's minimum.
@valueModel
class SplitPane with _$SplitPane {
  const new({required this.child, this.size, this.flex, this.min, this.max})
    : assert(
        size == null || flex == null,
        'A pane opens at a size or a flex, never both.',
      ),
      assert(
        min == null || max == null || min <= max,
        "A pane's min cannot pass its max.",
      );

  /// The pane's content, laid out at the pane's full size.
  final Widget child;

  /// The size the pane opens at, in logical pixels.
  final double? size;

  /// The pane's share of the space the sized panes leave.
  final double? flex;

  /// The smallest size the pane takes, in logical pixels.
  final double? min;

  /// The largest size the pane takes, in logical pixels.
  final double? max;
}
