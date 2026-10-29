import 'package:stratum_ui/stratum_ui.dart';

import '../kit/preset.dart';
import '../kit/slot_preset.dart';

/// One field per `ModalLayout` constructor param, the `argsType` of its
/// stories (fo11/us04/fr01); each slot param is a [SlotPreset].
class ModalLayoutKnobs {
  const ModalLayoutKnobs({
    this.top = SlotPreset.slot,
    this.tab = SlotPreset.slot,
    this.body = SlotPreset.slot,
    this.type,
    this.size = ModalLayoutSize.medium,
    this.showClose = true,
    this.onClose = true,
    required this.borderRadius,
    this.safeArea,
    this.fullHeight,
    this.scrollBody = true,
    required this.customStyle,
  });

  final SlotPreset top;
  final SlotPreset tab;
  final SlotPreset body;

  /// Null lets the window size pick the type.
  final ModalLayoutType? type;
  final ModalLayoutSize size;
  final bool showClose;

  /// Whether the layout reports each close.
  final bool onClose;
  final Preset<BorderRadiusGeometry> borderRadius;
  final bool? safeArea;
  final bool? fullHeight;
  final bool scrollBody;
  final Preset<ModalLayoutStyle> customStyle;
}
