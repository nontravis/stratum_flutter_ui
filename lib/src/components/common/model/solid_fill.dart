import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';

/// Whether [fill] paints one solid color: a background color with no
/// gradient and no image (FO-06 US-18 FR-07).
bool paintsSolidFill(WidgetStyle fill) =>
    fill.backgroundColor != null &&
    fill.backgroundGradient == null &&
    fill.backgroundImage == null;

/// [fill]'s declared bar-fill color: its [WidgetStyle.backgroundColor] with
/// [WidgetStyle.opacity] folded into the alpha, so the bar resolver reads
/// the alpha the box actually paints, else fully transparent while [fill]
/// paints no single solid color, which blends as nothing
/// (FO-03 US-14 FR-05; FO-06 US-18 FR-07).
Color solidFillColor(WidgetStyle fill) {
  if (!paintsSolidFill(fill)) return const Color(0x00000000);
  final color = fill.backgroundColor!;
  final opacity = fill.opacity;
  return opacity == null || opacity >= 1
      ? color
      : color.withValues(alpha: color.a * opacity);
}
