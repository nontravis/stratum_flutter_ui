import 'package:stratum_ui/stratum_ui.dart';

import '../kit/preset.dart';
import '../kit/slot_preset.dart';

/// One field per `StratumToastHost` constructor param, then one per
/// `showToast` param, the `argsType` of its stories (fo11/us04/fr01).
class ToastKnobs {
  const ToastKnobs({
    this.child = SlotPreset.slot,
    required this.builder,
    required this.closeButtonLabel,
    required this.kindLabels,
    required this.focusShortcuts,
    required this.focusShortcutHint,
    required this.message,
    required this.action,
    required this.kind,
    required this.placement,
    required this.customStyle,
  });

  final SlotPreset child;
  final Preset<StratumToastBuilder> builder;
  final Preset<String> closeButtonLabel;
  final Preset<Map<FeedbackState, String>> kindLabels;
  final Preset<List<SingleActivator>> focusShortcuts;
  final Preset<String> focusShortcutHint;
  final RequiredPreset<String> message;
  final Preset<StratumToastAction> action;
  final FeedbackState kind;
  final Preset<StratumToastPlacement> placement;
  final Preset<WidgetStyle> customStyle;
}
