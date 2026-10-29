import 'package:stratum_ui/stratum_ui.dart';

import 'preset.dart';

/// The styles a layout `style` knob and a `WidgetStyle` `customStyle` knob
/// offer, built from theme tokens so no layout page writes a raw style field
/// (s03 INV-10).
final List<Preset<WidgetStyle>> widgetStylePresets = [
  const Preset.none(),
  Preset(
    'Card',
    (context) => WidgetStyle(
      backgroundColor: context.theme.color.background.color.gray,
      borderRadius: BorderRadius.circular(context.theme.radius.lg),
      padding: EdgeInsets.all(context.theme.space.md),
    ),
  ),
  Preset(
    'Outlined',
    (context) => WidgetStyle(
      border: Border.all(color: context.theme.color.border.color.gray),
      borderRadius: BorderRadius.circular(context.theme.radius.lg),
    ),
  ),
  Preset(
    'Padded',
    (context) => WidgetStyle(padding: EdgeInsets.all(context.theme.space.md)),
  ),
];

/// The style preset of [widgetStylePresets] named [name], such as `Card`.
Preset<WidgetStyle> stylePreset(String name) =>
    widgetStylePresets.firstWhere((preset) => preset.name == name);
