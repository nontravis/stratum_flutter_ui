import 'package:stratum_ui/stratum_ui.dart';

import '../kit/preset.dart';

/// [count] slot placeholders named `child 1` to `child $count`, the children
/// a layout page's stories arrange (fo11/us06/fr01).
List<Widget> slotChildren(int count) => [
  for (var i = 1; i <= count; i++) StratumSlot(name: 'child $i'),
];

/// The styles a layout `style` knob and a `WidgetStyle` `customStyle` knob
/// offer, built from theme tokens so no layout page writes a raw style field
/// (s03 INV-10).
final List<Preset<WidgetStyle>> widgetStylePresets = [
  const Preset('None', _noStyle),
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

WidgetStyle? _noStyle(BuildContext context) => null;
