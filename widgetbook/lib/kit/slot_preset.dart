import 'package:stratum_ui/stratum_ui.dart';

import 'sample_text.dart';

/// What a slot knob puts in a `Widget` param (s03 INV-8).
enum SlotPreset { none, icon, text, slot }

/// Builds the widget [preset] names for a slot called [name].
///
/// Returns null for [SlotPreset.none]; [text] is the sample text the
/// [SlotPreset.text] preset shows.
Widget? slotFor(
  BuildContext context,
  SlotPreset preset, {
  required String name,
  SampleText text = SampleTexts.label,
}) => switch (preset) {
  SlotPreset.none => null,
  SlotPreset.icon => const Icon(Icons.star_outline),
  SlotPreset.text => Text(text.resolve(Localizations.localeOf(context))),
  SlotPreset.slot => StratumSlot(name: name),
};
