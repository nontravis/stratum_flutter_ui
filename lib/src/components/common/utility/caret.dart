import 'dart:math' as math;

import 'package:stratum_ui/src/src.dart';

/// Which way a [StratumCaret] points.
///
/// [start] and [end] point to the leading and the trailing side of the
/// ambient [Directionality], so they mirror in a right-to-left app; [up]
/// and [down] never mirror. The Figma `Caret` set draws left to right, so
/// its `LEFT` variant is [start] and its `RIGHT` variant is [end].
enum StratumCaretDirection {
  /// Points up in either text direction.
  up,

  /// Points down in either text direction. The default.
  down,

  /// Points to the leading side of the text: left in a left-to-right app,
  /// right in a right-to-left app.
  start,

  /// Points to the trailing side of the text: right in a left-to-right
  /// app, left in a right-to-left app.
  end,
}

/// The glyph of a [StratumCaret], the Figma `🕶️ style` property.
enum StratumCaretStyle {
  /// A round-capped chevron line, 1.0 px wide at every size.
  light,

  /// The same chevron, 1.5 px wide at every size. The Figma and Dart
  /// default.
  regular,

  /// A solid filled triangle that scales with the size.
  fill,
}

/// Indicates that an element is **expandable** or that a **menu/dropdown
/// will appear** on interaction. The style variants control visual weight
/// to match the density of the surrounding UI.
///
/// Points [StratumCaretDirection.start] and [StratumCaretDirection.end] by
/// the ambient text direction, turns the short way when [direction]
/// changes, shows the new direction at once under reduced motion, and
/// stays out of the semantics tree: the owning component announces
/// expanded or collapsed.
///
/// ## Use when
///
/// - A control toggles open a dropdown, select menu, or disclosure
/// - An interactive element needs a directional affordance to signal
///   hidden content
///
/// ## Don't use when
///
/// - Navigation between pages or sections — use a dedicated arrow or
///   chevron icon instead
/// - Pagination or sequential movement — use directional arrows
/// - The element is purely decorative with no expand/collapse behavior
///
/// ## Related
///
/// - Use a chevron or arrow icon instead when indicating **navigation
///   direction** rather than expand/collapse
///
/// The base `color` picks the theme's `icon.color.<name>` token through
/// [resolveColor], else `icon.default.primary`. `state`, `feedbackState`,
/// and `loading` leave the glyph's look unchanged, and `customStyle`
/// styles the square box, never the glyph.
class StratumCaret extends StratumStatefulWidget {
  const new({
    super.key,
    this.style = StratumCaretStyle.regular,
    this.direction = StratumCaretDirection.down,
    super.size,
    this.customSize,
    super.color,
    this.customColor,
    super.themeMode,
    super.windowSize,
    super.state,
    super.feedbackState,
    super.disabled,
    super.loading,
    super.debug,
    super.customStyle,
  });

  /// A [StratumCaretStyle.light] or [StratumCaretStyle.regular] chevron
  /// line, or a [StratumCaretStyle.fill] triangle.
  final StratumCaretStyle style;

  /// Which way the caret points; a change turns it the short way.
  final StratumCaretDirection direction;

  /// The side of the square box in logical pixels; wins over `size`.
  final double? customSize;

  /// The glyph color, used as given; wins over `color`.
  final Color? customColor;

  @override
  State<StratumCaret> createState() => _StratumCaretState();
}

class _StratumCaretState extends State<StratumCaret> {
  @override
  Widget build(BuildContext context) {
    final side = widget.customSize ?? _sideOf(widget.resolveSize(context));
    final quarterTurns = _quarterTurnsOf(
      widget.direction,
      Directionality.of(context),
    );
    // A decorative glyph: the owning component announces expanded or
    // collapsed (US-02 FR-05).
    return ExcludeSemantics(
      child: ContainerLayout(
        style: widget.resolveStyle(
          context,
          WidgetStyle(width: side, height: side),
        ),
        debug: widget.debug,
        child: CustomPaint(
          size: Size.square(side),
          painter: CaretPainter(
            style: widget.style,
            side: side,
            color: _color(context),
            angle: quarterTurns * math.pi / 2,
          ),
        ),
      ),
    );
  }

  /// `customColor`, else the base's named color in the icon group, else
  /// `icon.default.primary` (US-01 FR-03).
  Color _color(BuildContext context) =>
      widget.customColor ??
      widget.resolveColor(
        context,
        (colors) => colors.icon.color,
        widget.resolveTheme(context).color.icon.defaults.primary,
      );
}

/// The side in logical pixels of each [WidgetSize] (design D4); `medium`
/// is the Figma 16 px frame.
double _sideOf(WidgetSize size) => switch (size) {
  WidgetSize.tiny => 10,
  WidgetSize.extraSmall => 12,
  WidgetSize.small => 14,
  WidgetSize.medium => 16,
  WidgetSize.large => 20,
  WidgetSize.extraLarge => 24,
  WidgetSize.huge => 32,
};

/// Quarter turns clockwise from pointing down that point [direction]
/// under [textDirection] (spec `s03_domain.md` invariant 7).
int _quarterTurnsOf(
  StratumCaretDirection direction,
  TextDirection textDirection,
) => switch (direction) {
  StratumCaretDirection.down => 0,
  StratumCaretDirection.up => 2,
  StratumCaretDirection.start => textDirection == TextDirection.ltr ? 1 : 3,
  StratumCaretDirection.end => textDirection == TextDirection.ltr ? 3 : 1,
};

/// Paints one caret glyph of [side], turned [angle] radians clockwise from
/// pointing down, centered in the area it is given.
///
/// Library-internal: `utility.dart` hides it; tests read its fields.
class CaretPainter extends CustomPainter {
  const new({
    required this.style,
    required this.side,
    required this.color,
    required this.angle,
  });

  /// The glyph: a chevron line or a triangle.
  final StratumCaretStyle style;

  /// The caret's side in logical pixels; the glyph scales with it and
  /// never with the area it is given (US-01 FR-02 E03).
  final double side;

  /// The glyph color.
  final Color color;

  /// Radians clockwise from pointing down.
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    // The Figma glyph in its 16 px frame, centered on the origin and
    // pointing down: a 10 x 5 chevron centerline or an 11 x 6 triangle
    // (R8). The points scale with the side; the line width never does
    // (R1).
    final unit = side / 16;
    final paint = Paint()..color = color;
    final path = Path();
    switch (style) {
      case StratumCaretStyle.fill:
        path
          ..moveTo(-5.5 * unit, -3 * unit)
          ..lineTo(5.5 * unit, -3 * unit)
          ..lineTo(0, 3 * unit)
          ..close();
      case StratumCaretStyle.light || StratumCaretStyle.regular:
        path
          ..moveTo(-5 * unit, -2.5 * unit)
          ..lineTo(0, 2.5 * unit)
          ..lineTo(5 * unit, -2.5 * unit);
        // Round caps and joins give the Figma outline boxes: 11 x 6 at
        // 1.0 px and 11.5 x 6.5 at 1.5 px (R8).
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = style == StratumCaretStyle.light ? 1.0 : 1.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    }
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..rotate(angle)
      ..drawPath(path, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(CaretPainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.side != side ||
      oldDelegate.color != color ||
      oldDelegate.angle != angle;
}
