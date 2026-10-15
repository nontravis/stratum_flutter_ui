import 'package:stratum_ui/src/src.dart';

/// The gap before an outside ring when [StratumFocusBorder.gap] is null.
const double _defaultGap = 2;

/// The ring width when [StratumFocusBorder.width] is null, except the
/// inside style's focused look.
const double _defaultWidth = 3;

/// The inside style's focused width when [StratumFocusBorder.width] is
/// null.
const double _insideFocusedWidth = 2;

/// How far an outside-style [StratumFocusBorder] at [context] reaches
/// past its child's edge, with no per-instance override: the app-wide
/// `StratumComponentDefaults` style for [StratumFocusBorder] restyles the
/// width (R8); the gap stays the package default, since `ScrollFocus`'s
/// own ring takes no per-instance `gap` of its own.
///
/// Not exported: `utility/utility.dart` hides it, and `scroll_frame.dart`
/// imports this file by path for the window check of its ring.
double focusBorderOutsideReach(BuildContext context) {
  final layer = StratumComponentDefaults.styleOf(context, StratumFocusBorder);
  final width = layer?.border?.top.width ?? _defaultWidth;
  return _defaultGap + width;
}

/// Provides a **consistent keyboard-focus and hover indicator** that layers
/// on top of interactive elements, making the active element visually
/// obvious without modifying the element's own styling.
///
/// Its colors follow the Figma `FocusBorder` component and stay below the
/// 3:1 contrast of WCAG 1.4.11, an exception scoped to the focus ring; pass
/// [customColor] on one ring where an app needs that ratio.
///
/// ## Use when
///
/// - An interactive element needs a visible focus ring for keyboard
///   navigation
/// - You need to indicate hover state without altering the target
///   element's fills or strokes
/// - Building a composite component that must expose focus/hover visuals
///   as a separate, toggleable layer
///
/// ## Don't use when
///
/// - The parent component already has built-in focus styling (e.g. native
///   input fields with their own ring)
/// - You need a persistent selected/active indicator that remains visible
///   outside of interaction — use a selection highlight or active-state
///   variant instead
///
/// Pick [style] by component kind, and resolve `state` from focus and
/// hover alone, ahead of any other state of the box: a box that holds focus
/// while it shows an error or is loading passes [FullWidgetState.focused].
/// The ring reads only `normal`, `hovered`, and `focused`; any other value
/// shows the normal look, no ring. The ring fades to each look over the
/// theme's `fast` level on its `standard` curve, shows it at once when
/// motion is reduced, and never changes [child]'s layout size.
///
/// A `customStyle`, and an app-wide `StratumComponentDefaults` style for
/// this type, restyle the shown looks only, and only their color, width,
/// radius, and motion (R8), read from that style's border's top side only.
/// The side sets color and width together, as one `BorderSide`: a side
/// that sets only one takes Flutter's own default for the other, not the
/// ring's; a border with no top side (`BorderStyle.none`) restyles
/// nothing, and the ring keeps its default color and width. The ring
/// always computes its own placement from [style], [insideEdge], and the
/// gap against the resolved width, so no style layer moves it.
/// [customColor], [width], and [gap] win over either
/// layer. A state whose look is nothing still shows no ring.
class StratumFocusBorder extends StratumStatefulWidget {
  const new({
    super.key,
    this.style = StratumFocusBorderPlacement.outside,
    this.customColor,
    required this.child,
    this.insideEdge = false,
    this.borderRadius,
    this.width,
    this.gap,
    super.state,
    this.customStyle,
  });

  /// The look, picked by component kind: [StratumFocusBorderPlacement.inside]
  /// for form components the user types into, else
  /// [StratumFocusBorderPlacement.outside].
  final StratumFocusBorderPlacement style;

  /// Replaces the style's theme color on this ring with any color: the
  /// ring's only color override, so the base `color` never colors it.
  final Color? customColor;

  /// The box the ring surrounds; the ring never changes its layout size.
  final Widget child;

  /// Places an outside-style ring on [child]'s inner edge, with no gap, in
  /// the outside color and width, for a box whose ring around it would
  /// leave the window. Placement only: the ring never takes the inside
  /// style's look, and the inside style ignores it.
  final bool insideEdge;

  /// [child]'s own corner radius; null is radius 0. A ring around [child]
  /// takes it plus the gap, so the two stay concentric.
  final BorderRadiusGeometry? borderRadius;

  /// Replaces the ring width in every shown state of either style.
  final double? width;

  /// Replaces the 2 px gap before an outside ring; unused with
  /// [insideEdge], since the gap never applies inward.
  final double? gap;

  /// Restyles the shown looks, as the app-wide style for this type does
  /// (R8 of the 2026-10-07 focus-border design); the ring's own field.
  final WidgetStyle? customStyle;

  @override
  State<StratumFocusBorder> createState() => _StratumFocusBorderState();
}

class _StratumFocusBorderState extends State<StratumFocusBorder> {
  /// The look of `state` in [StratumFocusBorder.style], as a [WidgetStyle]:
  /// the ring is its border's top side, at its radius, over its motion.
  ///
  /// The style layers restyle the shown look; a hidden ring keeps that
  /// look at alpha 0, so no style shows it, and a fade in or out keeps the
  /// hue steady. Under reduced motion the look applies at once.
  WidgetStyle _look(BuildContext context) {
    final widget = this.widget;
    final theme = widget.resolveTheme(context);
    final outside = widget.style == StratumFocusBorderPlacement.outside;
    final focused = widget.state == FullWidgetState.focused;
    final hovered = widget.state == FullWidgetState.hovered;
    final shows = focused || (hovered && !outside);
    final defaultColor = outside
        ? theme.color.border.subtle.blue
        : theme.color.border.defaults.normal;
    final defaultWidth = focused && !outside
        ? _insideFocusedWidth
        : _defaultWidth;
    // Resolve the style layers first (R8): a layer restyles color, width,
    // radius and motion only. Placement is never read from a layer's
    // border; it is always computed below, against the resolved width.
    final resolved = widget.resolveStyle(
      context,
      WidgetStyle(
        border: Border.fromBorderSide(
          BorderSide(color: defaultColor, width: defaultWidth),
        ),
        borderRadius: widget.borderRadius ?? BorderRadius.zero,
        animationStyle: theme.animation.fast,
      ),
      widget.customStyle,
    );
    final layerSide = resolved.border?.top ?? BorderSide.none;
    // A layer border with no top side (BorderStyle.none) restyles nothing,
    // so its color and width fall back to the package default rather than
    // BorderSide.none's black, 0 px placeholder.
    final layerSideSet = layerSide.style != BorderStyle.none;
    // The ring's own overrides win over either style layer (D7, R8).
    final color =
        widget.customColor ?? (layerSideSet ? layerSide.color : defaultColor);
    final width =
        widget.width ?? (layerSideSet ? layerSide.width : defaultWidth);
    final gap = widget.gap ?? _defaultGap;
    final side = BorderSide(
      color: color,
      width: width,
      // Around the child the stroke starts after the gap: its inner
      // edge lies [gap] outside the child's edge.
      strokeAlign: outside && !widget.insideEdge
          ? BorderSide.strokeAlignOutside + 2 * gap / width
          : BorderSide.strokeAlignInside,
    );
    final shown = resolved.copyWith(border: Border.fromBorderSide(side));
    final look = shows
        ? shown
        : shown.copyWith(
            border: Border.fromBorderSide(
              side.copyWith(color: side.color.withValues(alpha: 0)),
            ),
          );
    if (!context.reducesMotion) return look;
    return look.copyWith(animationStyle: AnimationStyle.noAnimation);
  }

  @override
  Widget build(BuildContext context) {
    final look = _look(context);
    final motion = look.animationStyle;
    // One structure for every look, so no change of style, state, or
    // placement remounts the child.
    return TweenAnimationBuilder<WidgetStyle>(
      tween: _LookTween(end: look),
      duration: motion?.duration ?? Duration.zero,
      curve: motion?.curve ?? Curves.easeInOutSine,
      builder: (context, look, child) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: ShapeDecoration(
          // A rounded rectangle, even at radius 0, so a ring around the
          // child keeps the child's radius plus the gap.
          shape: RoundedRectangleBorder(
            side: look.border?.top ?? BorderSide.none,
            borderRadius: look.borderRadius ?? BorderRadius.zero,
          ),
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _LookTween extends Tween<WidgetStyle> {
  new({super.end});

  @override
  WidgetStyle lerp(double t) => WidgetStyle.lerp(begin, end, t)!;
}
