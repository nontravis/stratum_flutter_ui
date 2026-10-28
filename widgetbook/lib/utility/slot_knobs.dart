import 'package:stratum_ui/stratum_ui.dart';

import '../kit/preset.dart';

/// One field per `StratumSlot` constructor param, the `argsType` of its
/// stories (fo11/us04/fr01).
class SlotKnobs {
  const SlotKnobs({
    this.height,
    this.width,
    required this.padding,
    this.name = 'Slot',
  });

  final double? height;
  final double? width;
  final Preset<EdgeInsets> padding;
  final String name;
}
