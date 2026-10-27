import 'dart:ui' show Color;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/focus_tokens.freezed.dart';

/// The focus ring's level 0 (FO-06 US-04 FR-03): the theme file's `focus`
/// set for one theme data's mode, each color from that data's own color
/// set (themes s03 INV-46). It holds the outside ring's color, width,
/// and gap and the inside ring's color and its hovered and focused widths,
/// and no inside gap, since the gap never applies inward. Every width is
/// above 0 and every color has an alpha above 0: the theme parser refuses a
/// value that hides the ring (FO-01 US-01 FR-01 E20). It holds only colors
/// and numbers, so the theme layer names no ring type.
@valueModel
abstract class StratumFocusTokens with _$StratumFocusTokens {
  const factory({
    /// The outside ring's color.
    required Color outsideColor,

    /// The outside ring's width in logical pixels.
    required double outsideWidth,

    /// The space between the box and the outside ring, in logical pixels.
    required double outsideGap,

    /// The inside ring's color.
    required Color insideColor,

    /// The inside ring's width while the box is hovered.
    required double insideHoveredWidth,

    /// The inside ring's width while the box is focused.
    required double insideFocusedWidth,
  }) = _StratumFocusTokens;
}
