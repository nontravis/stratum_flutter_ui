import 'package:stratum_ui/stratum_ui.dart';

import '../kit/preset.dart';

/// One field per `SplitLayout` constructor param, the `argsType` of its
/// stories (fo11/us04/fr01); `panes` counts the slot placeholders.
class SplitLayoutKnobs {
  const SplitLayoutKnobs({
    this.panes = 2,
    this.axis = Axis.horizontal,
    this.resizable = true,
    required this.controller,
    required this.dividerLabel,
    required this.dividerBuilder,
    required this.customStyle,
    required this.setting,
  });

  final int panes;
  final Axis axis;
  final bool resizable;
  final Preset<SplitLayoutController> controller;
  final Preset<String> dividerLabel;
  final Preset<SplitDividerBuilder> dividerBuilder;
  final Preset<SplitLayoutStyle> customStyle;
  final Preset<WidgetSettingKey> setting;
}
