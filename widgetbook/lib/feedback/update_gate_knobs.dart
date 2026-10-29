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

  final Preset<UpdateChecker> checker;
  final Preset<Widget Function(BuildContext, UpdateGateState)> builder;
  final SlotPreset child;
}
