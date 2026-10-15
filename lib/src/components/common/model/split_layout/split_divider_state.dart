import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/split_divider_state.freezed.dart';

/// What a `SplitLayout` divider passes its `SplitDividerBuilder`.
@valueModel
class SplitDividerState with _$SplitDividerState {
  const new({
    this.hovered = false,
    this.dragging = false,
    this.focused = false,
  });

  /// True while a pointer rests over the divider's hit area and no drag
  /// runs.
  final bool hovered;

  /// True while the EndUser drags the divider.
  final bool dragging;

  /// True while the divider holds keyboard focus and shows its focus ring.
  final bool focused;
}
