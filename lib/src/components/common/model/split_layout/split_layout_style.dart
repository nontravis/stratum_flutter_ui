import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/components/common/model/focus_border/stratum_focus_border_style.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/split_layout_style.freezed.dart';

/// The split layout's own style: it holds its dividers' focus ring look next
/// to the split's other looks, as Flutter's `ButtonStyle` holds a button's
/// focused look (FO-06 US-21 FR-05). Registered under `SplitLayout` in
/// `componentPartDefaults` it is level 2 of every divider's ring; passed as
/// one split's `customStyle` it is level 3, since the split holds no box
/// style.
@valueModel
abstract class SplitLayoutStyle with _$SplitLayoutStyle {
  const factory({
    /// The dividers' focus ring look, laid field by field over the lower
    /// levels of the ring.
    StratumFocusBorderStyle? focus,
  }) = _SplitLayoutStyle;
}
