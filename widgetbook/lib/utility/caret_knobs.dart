import 'package:stratum_ui/stratum_ui.dart';

import '../kit/preset.dart';

/// One field per `StratumCaret` constructor param, the `argsType` of its
/// stories (fo11/us04/fr01).
class CaretKnobs {
  const CaretKnobs({
    this.style = StratumCaretGlyph.regular,
    this.direction = StratumCaretDirection.down,
    this.size,
    this.customSize,
    this.color,
    this.customColor,
    this.themeMode,
    this.disabled = false,
    required this.customStyle,
  });

  final StratumCaretGlyph style;
  final StratumCaretDirection direction;
  final WidgetSize? size;
  final double? customSize;
  final ColorEnum? color;
  final Color? customColor;
  final ThemeMode? themeMode;
  final bool disabled;
  final Preset<StratumCaretStyle> customStyle;
}
