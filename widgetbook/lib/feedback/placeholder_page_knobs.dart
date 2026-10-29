import '../kit/preset.dart';
import '../kit/slot_preset.dart';

/// One field per `StratumPlaceholderPage` constructor param, the `argsType`
/// of its stories (fo11/us04/fr01).
class PlaceholderPageKnobs {
  const PlaceholderPageKnobs({
    required this.title,
    required this.message,
    this.icon = SlotPreset.icon,
  });

  final Preset<String> title;
  final Preset<String> message;
  final SlotPreset icon;
}
