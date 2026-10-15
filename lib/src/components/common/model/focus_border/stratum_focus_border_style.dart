import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/stratum_focus_border_style.freezed.dart';

/// Where a `StratumFocusBorder` ring sits, picked by component kind (FO-06
/// US-04 FR-03).
enum StratumFocusBorderPlacement {
  /// For every interaction the user does not type into: `StratumInkWell`,
  /// `ScrollFocus`, and buttons. By default a 3 px `border.subtle.blue`
  /// ring after a 2 px gap outside the child, shown only when focused.
  outside,

  /// For form components the user types into. By default a
  /// `border.default.normal` ring on the child's inner edge, 3 px when
  /// hovered and 2 px when focused.
  inside,
}

/// The look of a `StratumFocusBorder` ring at one of its four levels, low
/// to high, a higher level winning field by field (FO-06 US-04 FR-03; layout
/// s03 invariant 80): the theme's `focus` group, the app-wide style of every
/// ring, the app-wide style of the ring's host type, and one host instance.
///
/// Every field is optional; a null field takes the next lower level. Every
/// field but [placement] holds one value for every shown state, through
/// `WidgetStateProperty.all`, or one per shown state, hovered and focused,
/// through `WidgetStateProperty.fromMap`, as `ButtonStyle` holds its
/// per-state values. A `.fromMap` value must be `WidgetStateProperty<T?>`
/// (nullable `T`) or carry a `WidgetState.any` entry: the ring resolves an
/// inside ring's hovered state and an outside ring's focused state even in
/// the normal look, and a non-nullable map with no `any` entry throws
/// Flutter's own `ArgumentError` for a state it was never given. No field
/// draws a dashed ring or hides the ring (WCAG 2.4.7): a width of 0 or a
/// fully transparent color fails a debug assert where the ring resolves
/// its style.
@valueModel
abstract class StratumFocusBorderStyle with _$StratumFocusBorderStyle {
  const factory({
    /// The ring color, never fully transparent; level 0 sets it per
    /// placement.
    WidgetStateProperty<Color?>? color,

    /// The ring width in logical pixels, above 0; level 0 sets it per
    /// placement, the inside one per shown state.
    WidgetStateProperty<double?>? width,

    /// The space between the box and an outside ring; unused by the inside
    /// placement and with `insideEdge`, since the gap never applies inward.
    WidgetStateProperty<double?>? gap,

    /// The corner radius the ring follows, in place of the ring's
    /// `borderRadius`; a ring around the box takes it plus the gap.
    WidgetStateProperty<BorderRadiusGeometry?>? radius,

    /// Outside or inside, set only here, since the ring takes no placement
    /// parameter of its own; null at every level is
    /// [StratumFocusBorderPlacement.outside].
    StratumFocusBorderPlacement? placement,

    /// The fade between looks, its duration and curve; by default the
    /// theme's `fast` level on its `standard` curve.
    WidgetStateProperty<AnimationStyle?>? motion,

    /// A second ring in `color` touching the first on the side away from the
    /// box's edge, outward for an outside ring and inward for an inside or
    /// `insideEdge` ring, a two-tone ring that shows on any background; a
    /// null `width` takes the first ring's width.
    WidgetStateProperty<({Color color, double? width})?>? secondRing,

    /// A soft halo around the shown ring, as the shadow list Flutter's own
    /// decorations use; it never changes the box's layout size and may clip
    /// at the window edge.
    WidgetStateProperty<List<BoxShadow>?>? glow,
  }) = _StratumFocusBorderStyle;
}
