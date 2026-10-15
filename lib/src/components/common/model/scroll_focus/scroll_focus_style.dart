import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/components/common/model/focus_border/stratum_focus_border_style.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/scroll_focus_style.freezed.dart';

/// The scrolling area's own style: it holds the area's focus ring look next
/// to the area's other looks, as Flutter's `ButtonStyle` holds a button's
/// focused look (FO-06 US-07 FR-03). Registered under `ScrollFocus` in
/// `componentPartDefaults` it is level 2 of every scrolling area's ring;
/// passed as one area's `scrollFocusStyle`, or a `ScrollFocus`'s
/// `customStyle`, it is level 3.
@valueModel
abstract class ScrollFocusStyle with _$ScrollFocusStyle {
  const factory({
    /// The area's focus ring look, laid field by field over the lower
    /// levels of the ring.
    StratumFocusBorderStyle? focus,
  }) = _ScrollFocusStyle;
}
