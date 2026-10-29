import 'package:stratum_ui/stratum_ui.dart';

import '../kit/preset.dart';
import '../kit/slot_preset.dart';

/// One field per `StratumUpdateGate` constructor param, the `argsType` of
/// its stories (fo11/us04/fr01).
class UpdateGateKnobs {
  const UpdateGateKnobs({
    required this.checker,
    required this.builder,
    this.child = SlotPreset.slot,
  });

  final RequiredPreset<UpdateChecker> checker;
  final RequiredPreset<Widget Function(BuildContext, UpdateGateState)> builder;
  final SlotPreset child;
}
