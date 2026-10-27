import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/component_defaults.dart'
    show debugCheckNoComponentStyle;

/// [upper] laid over [lower], field by field and shown state by shown
/// state: a field [upper] leaves null, or that resolves to null for a
/// state, takes [lower]'s value (layout s03 INV-80; FO-06 US-04
/// FR-03 E14). Null when both are null.
///
/// Not exported: `utility/utility.dart` hides it. A ring host lays its
/// instance style's `focus` (level 3) over its app-wide style's `focus`
/// (level 2) with it and passes the result as the ring's `customStyle`.
StratumFocusBorderStyle? focusStyleOver(
  StratumFocusBorderStyle? lower,
  StratumFocusBorderStyle? upper,
) {
  if (upper == null) return lower;
  if (lower == null) return upper;
  return StratumFocusBorderStyle(
    color: _over(lower.color, upper.color),
    width: _over(lower.width, upper.width),
    gap: _over(lower.gap, upper.gap),
    radius: _over(lower.radius, upper.radius),
    placement: upper.placement ?? lower.placement,
    motion: _over(lower.motion, upper.motion),
    secondRing: _over(lower.secondRing, upper.secondRing),
    glow: _over(lower.glow, upper.glow),
  );
}

WidgetStateProperty<T?>? _over<T>(
  WidgetStateProperty<T?>? lower,
  WidgetStateProperty<T?>? upper,
) {
  if (upper == null) return lower;
  if (lower == null) return upper;
  return _Over<T>(lower, upper);
}

/// Resolves [upper] first and falls back to [lower] for a state [upper]
/// leaves null.
final class _Over<T> implements WidgetStateProperty<T?> {
  const new(this.lower, this.upper);

  final WidgetStateProperty<T?> lower;
  final WidgetStateProperty<T?> upper;

  @override
  T? resolve(Set<WidgetState> states) =>
      upper.resolve(states) ?? lower.resolve(states);
}

/// Level 0 for [placement]: the theme's `focus` group, [radius], the box's
/// own corner radius, and the theme's `fast` level on its `standard` curve
/// (themes s03 INV-46). The inside ring takes no gap (choice (b)).
StratumFocusBorderStyle _themeLevel(
  StratumThemeData theme,
  StratumFocusBorderPlacement placement,
  BorderRadiusGeometry radius,
) {
  final focus = theme.focus;
  final outside = placement == StratumFocusBorderPlacement.outside;
  return StratumFocusBorderStyle(
    color: WidgetStatePropertyAll(
      outside ? focus.outsideColor : focus.insideColor,
    ),
    width: outside
        ? WidgetStatePropertyAll(focus.outsideWidth)
        : WidgetStateProperty<double?>.fromMap({
            WidgetState.focused: focus.insideFocusedWidth,
            WidgetState.hovered: focus.insideHoveredWidth,
          }),
    gap: WidgetStatePropertyAll(outside ? focus.outsideGap : 0.0),
    radius: WidgetStatePropertyAll(radius),
    placement: placement,
    motion: WidgetStatePropertyAll(theme.animation.fast),
  );
}

/// Throws a [FlutterError] naming the field when [style], the levels above
/// the theme's, sets a width of 0 or less or a fully transparent color for
/// a state the ring shows: focused, and hovered for an [inside] ring (FO-06
/// US-04 FR-03 E19; WCAG 2.4.7). Level 0 is checked when the theme loads
/// (FO-01 US-01 FR-01 E20).
bool _showsRing(StratumFocusBorderStyle? style, {required bool inside}) {
  if (style == null) return true;
  for (final state in [WidgetState.focused, if (inside) WidgetState.hovered]) {
    final states = {state};
    final width = style.width?.resolve(states);
    if (width != null && width <= 0) {
      throw FlutterError(
        'StratumFocusBorderStyle.width resolves to $width for the '
        '${state.name} look; a width of 0 hides the focus ring (WCAG '
        '2.4.7). Set a width above 0.',
      );
    }
    final color = style.color?.resolve(states);
    if (color != null && color.a == 0) {
      throw FlutterError(
        'StratumFocusBorderStyle.color resolves to a fully transparent color '
        'for the ${state.name} look, which hides the focus ring (WCAG '
        '2.4.7). Set a color with an alpha above 0.',
      );
    }
  }
  return true;
}

/// How far an outside [StratumFocusBorder] ring at [context] reaches past
/// its child's edge in its focused look, over the levels with
/// [customStyle] above the app-wide one: the resolved gap and width and,
/// when a second ring color is set, the second ring's width, the first
/// ring's unless the style sets its own (FO-06 US-07 FR-03 E01). A glow
/// counts nothing and may clip at the window edge. Zero with no Stratum
/// theme above [context], where no ring is built, and zero for an inside
/// placement, whose ring paints at `strokeAlignInside` and never protrudes
/// past the child.
///
/// Not exported: `utility/utility.dart` hides it, and `scroll_frame.dart`
/// imports this file by path for the window check of its ring.
double focusBorderOutsideReach(
  BuildContext context, {
  StratumFocusBorderStyle? customStyle,
}) {
  final theme = StratumThemeApplication.maybeOf(context);
  if (theme == null) return 0;
  final upper = focusStyleOver(
    StratumComponentDefaults.partsOf<StratumFocusBorderStyle>(
      context,
      StratumFocusBorder,
    ),
    customStyle,
  );
  // The merged upper levels' own placement, as `_looks` reads it (layout
  // s03 INV-80): an inside-placed host style floors on the theme's
  // inside look, never the outside one.
  final placement = upper?.placement ?? StratumFocusBorderPlacement.outside;
  if (placement == StratumFocusBorderPlacement.inside) return 0;
  final style = focusStyleOver(
    _themeLevel(theme, placement, BorderRadius.zero),
    upper,
  )!;
  const focused = {WidgetState.focused};
  final width = style.width?.resolve(focused) ?? 0.0;
  final gap = style.gap?.resolve(focused) ?? 0.0;
  final second = style.secondRing?.resolve(focused);
  return gap + width + (second == null ? 0.0 : second.width ?? width);
}

/// Provides a **consistent keyboard-focus and hover indicator** that layers
/// on top of interactive elements, making the active element visually
/// obvious without modifying the element's own styling.
///
/// Its colors follow the Figma `FocusBorder` component by default and stay
/// below the 3:1 contrast of WCAG 1.4.11, an exception scoped to the focus
/// ring; set a focus style color at any level, from the theme's `focus`
/// group up to one ring, where an app needs that ratio.
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
/// Resolve `state` from focus and hover alone, ahead of any other state of
/// the box: a box that holds focus while it shows an error or is loading
/// passes [FullWidgetState.focused]. The ring reads only `normal`,
/// `hovered`, and `focused`; any other value shows the normal look, no
/// ring. It never changes [child]'s layout size.
///
/// Every look value comes from one [StratumFocusBorderStyle], resolved
/// field by field over four levels, low to high: the theme's `focus` group
/// for the placement; the app-wide style registered under
/// `StratumFocusBorder` in `componentPartDefaults`; and [customStyle],
/// which a host fills with its app-wide host style's `focus` under its
/// instance style's `focus`, or which holds the ring's own style when the
/// ring is placed directly. A style restyles the shown looks only: a state
/// whose look is nothing shows no ring, no second ring, and no glow. The
/// ring fades over the style's motion, by default the theme's `fast` level
/// on its `standard` curve, and shows its look at once when motion is
/// reduced.
class StratumFocusBorder extends StratumStatefulWidget {
  const new({
    super.key,
    required this.child,
    this.insideEdge = false,
    this.borderRadius,
    super.state,
    this.customStyle,
  });

  /// The box the ring surrounds; the ring never changes its layout size.
  final Widget child;

  /// Places an outside ring on [child]'s inner edge, with no gap, in the
  /// outside color and width, for a box whose ring around it would leave
  /// the window. It never changes the placement; an inside ring ignores it.
  final bool insideEdge;

  /// [child]'s own corner radius; null is radius 0. A ring around [child]
  /// takes it plus the gap, so the two stay concentric; a focus style
  /// `radius` wins over it.
  final BorderRadiusGeometry? borderRadius;

  /// The ring's focus style above the app-wide level: a host's levels 2 and
  /// 3 laid together, or, when the ring is placed directly, its own style,
  /// level 3; every field of it changes the ring (NFR-E02).
  final StratumFocusBorderStyle? customStyle;

  @override
  State<StratumFocusBorder> createState() => _StratumFocusBorderState();
}

/// The first ring's look, which carries the radius, the glow, and the
/// motion, and the second ring's look; a record, so an equal look on a
/// rebuild starts no fade.
typedef _Looks = ({WidgetStyle ring, WidgetStyle second});

class _StratumFocusBorderState extends State<StratumFocusBorder> {
  /// The looks of `state` in the resolved style. A state whose look is
  /// nothing draws the look it fades to at alpha 0 (PD6), so no style shows
  /// it and a fade in or out keeps the hue steady. Under reduced motion the
  /// look applies at once.
  _Looks _looks(BuildContext context) {
    final widget = this.widget;
    final theme = widget.resolveTheme(context);
    final upper = focusStyleOver(
      StratumComponentDefaults.partsOf<StratumFocusBorderStyle>(
        context,
        StratumFocusBorder,
      ),
      widget.customStyle,
    );
    final placement = upper?.placement ?? StratumFocusBorderPlacement.outside;
    final outside = placement == StratumFocusBorderPlacement.outside;
    assert(
      _showsRing(upper, inside: !outside),
      'unreachable: _showsRing either returns true or throws',
    );
    // The ring reads no entry of the componentDefaults styles map (choice
    // (j)); one registered under StratumFocusBorder is a mistake.
    assert(
      debugCheckNoComponentStyle(
        context,
        StratumFocusBorder,
        StratumFocusBorderStyle,
      ),
      'unreachable: debugCheckNoComponentStyle either returns true or throws',
    );
    final style = focusStyleOver(
      _themeLevel(theme, placement, widget.borderRadius ?? BorderRadius.zero),
      upper,
    )!;
    final focused = widget.state == FullWidgetState.focused;
    final shows =
        focused || (widget.state == FullWidgetState.hovered && !outside);
    final states = {
      if (outside || focused) WidgetState.focused else WidgetState.hovered,
    };
    Color seen(Color color) => shows ? color : color.withValues(alpha: 0);
    final width = style.width!.resolve(states)!;
    final around = outside && !widget.insideEdge;
    final gap = around ? style.gap?.resolve(states) ?? 0.0 : 0.0;
    final ring = BorderSide(
      color: seen(style.color!.resolve(states)!),
      width: width,
      // Around the child the stroke starts after the gap: its inner edge
      // lies [gap] outside the child's edge.
      strokeAlign: around
          ? BorderSide.strokeAlignOutside + 2 * gap / width
          : BorderSide.strokeAlignInside,
    );
    final second = style.secondRing?.resolve(states);
    final secondWidth = second?.width ?? width;
    final secondSide = second == null || secondWidth <= 0
        ? BorderSide.none
        : BorderSide(
            color: seen(second.color),
            width: secondWidth,
            // Touching the first ring on the side away from the child's
            // edge: outward around the child, inward on its inner edge, so
            // it never leaves the window (choice (c), R10(4)).
            strokeAlign: around
                ? BorderSide.strokeAlignOutside +
                      2 * (gap + width) / secondWidth
                : BorderSide.strokeAlignInside - 2 * width / secondWidth,
          );
    final radius = style.radius?.resolve(states) ?? BorderRadius.zero;
    final motion = context.reducesMotion
        ? AnimationStyle.noAnimation
        : style.motion?.resolve(states) ?? theme.animation.fast;
    final glow = style.glow?.resolve(states) ?? const <BoxShadow>[];
    return (
      ring: WidgetStyle(
        border: Border.fromBorderSide(ring),
        borderRadius: radius,
        dropShadow: [
          for (final shadow in glow) shadow.copyWith(color: seen(shadow.color)),
        ],
        animationStyle: motion,
      ),
      second: WidgetStyle(
        border: Border.fromBorderSide(secondSide),
        borderRadius: radius,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final looks = _looks(context);
    final motion = looks.ring.animationStyle;
    // One structure for every look, so no change of placement, state, or
    // style remounts the child.
    return TweenAnimationBuilder<_Looks>(
      tween: _LooksTween(end: looks),
      duration: motion?.duration ?? Duration.zero,
      curve: motion?.curve ?? Curves.easeInOutSine,
      builder: (context, looks, child) {
        final radius = looks.ring.borderRadius ?? BorderRadius.zero;
        final ring = looks.ring.border?.top ?? BorderSide.none;
        return DecoratedBox(
          position: DecorationPosition.foreground,
          // A rounded rectangle, even at radius 0, so a ring around the
          // child keeps the child's radius plus the gap.
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(side: ring, borderRadius: radius),
          ),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: ShapeDecoration(
              shape: RoundedRectangleBorder(
                side: looks.second.border?.top ?? BorderSide.none,
                borderRadius: radius,
              ),
            ),
            child: CustomPaint(
              painter: _GlowPainter(
                ring: ring,
                radius: radius,
                glow: looks.ring.dropShadow ?? const [],
                textDirection: Directionality.maybeOf(context),
              ),
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _LooksTween extends Tween<_Looks> {
  new({super.end});

  @override
  _Looks lerp(double t) => (
    ring: WidgetStyle.lerp(begin?.ring, end?.ring, t)!,
    second: WidgetStyle.lerp(begin?.second, end?.second, t)!,
  );
}

/// Paints the glow under the child (PD5): each shadow as a blurred stroke
/// along the first ring, its spread wider on each side and moved by its
/// offset, so the halo rings the ring and never covers the child's middle.
class _GlowPainter extends CustomPainter {
  const new({
    required this.ring,
    required this.radius,
    required this.glow,
    required this.textDirection,
  });

  final BorderSide ring;
  final BorderRadiusGeometry radius;
  final List<BoxShadow> glow;
  final TextDirection? textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (glow.isEmpty || ring.style == BorderStyle.none) return;
    // The ring stroke's center line, where RoundedRectangleBorder strokes.
    final center = radius
        .resolve(textDirection)
        .toRRect(Offset.zero & size)
        .inflate(ring.strokeOffset / 2);
    for (final shadow in glow) {
      final paint = shadow.toPaint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring.width + 2 * shadow.spreadRadius;
      canvas.drawRRect(center.shift(shadow.offset), paint);
    }
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) =>
      oldDelegate.ring != ring ||
      oldDelegate.radius != radius ||
      !listEquals(oldDelegate.glow, glow) ||
      oldDelegate.textDirection != textDirection;
}
