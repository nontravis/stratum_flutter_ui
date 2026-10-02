import 'package:stratum_ui/src/src.dart';

class FocusSpread extends StatelessWidget {
  const new({
    super.key,
    required this.child,
    this.borderRadius,
    this.spread = 4.0,
    this.focus = false,
    this.color,
    this.inside,
  });

  final Widget child;
  final BorderRadiusGeometry? borderRadius;
  final double spread;
  final bool focus;
  final Color? color;

  /// Where the ring draws while [focus] is true: around [child] when null
  /// or false, and inside [child]'s edge, over [child], when true. A
  /// non-null value always builds the inside layer, so a flip keeps
  /// [child]'s State.
  final bool? inside;

  @override
  Widget build(BuildContext context) {
    final inside = this.inside;
    return AnimatedContainer(
      duration: 80.milliseconds,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: _ring(
          context,
          BorderSide.strokeAlignOutside,
          shows: focus && inside != true,
        ),
      ),
      foregroundDecoration: inside == null
          ? null
          : BoxDecoration(
              borderRadius: borderRadius,
              border: _ring(
                context,
                BorderSide.strokeAlignInside,
                shows: focus && inside,
              ),
            ),
      child: child,
    );
  }

  /// The 4 px ring at [strokeAlign]: in the ring color when it [shows],
  /// else transparent.
  Border _ring(
    BuildContext context,
    double strokeAlign, {
    required bool shows,
  }) {
    return Border.fromBorderSide(
      BorderSide(
        width: 4,
        strokeAlign: strokeAlign,
        color: shows
            ? color ?? context.theme.color.borderBrand.withValues(alpha: 0.30)
            : context.theme.color.transparent.t0,
      ),
    );
  }
}
