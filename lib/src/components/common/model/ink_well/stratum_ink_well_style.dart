import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/components/common/model/focus_border/stratum_focus_border_style.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/stratum_ink_well_style.freezed.dart';

/// The tap surface's own style: it holds the surface's focus ring look next
/// to the surface's other looks, as Flutter's `ButtonStyle` holds a button's
/// focused look (FO-06 US-04 FR-03). Registered under `StratumInkWell` in
/// `componentPartDefaults` it is level 2 of every tap surface's ring;
/// passed as one surface's `customStyle` it is level 3.
@valueModel
abstract class StratumInkWellStyle with _$StratumInkWellStyle {
  const factory({
    /// The surface's focus ring look, laid field by field over the lower
    /// levels of the ring.
    StratumFocusBorderStyle? focus,
  }) = _StratumInkWellStyle;
}
