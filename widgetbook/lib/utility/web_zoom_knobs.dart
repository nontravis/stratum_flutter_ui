import '../kit/slot_preset.dart';

/// One field per `StratumWebZoom` constructor param, the `argsType` of its
/// stories (fo11/us04/fr01).
class WebZoomKnobs {
  const WebZoomKnobs({
    this.minScale = 1.0,
    this.maxScale = 2.5,
    this.child = SlotPreset.slot,
  });

  final double minScale;
  final double maxScale;
  final SlotPreset child;
}
