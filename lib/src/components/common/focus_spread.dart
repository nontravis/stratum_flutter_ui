import 'package:stratum_ui/src/src.dart';

class FocusSpread extends StatelessWidget {
  const new({
    super.key,
    required this.child,
    this.borderRadius,
    this.spread = 4.0,
    this.focus = false,
    this.color,
  });

  final Widget child;
  final BorderRadiusGeometry? borderRadius;
  final double spread;
  final bool focus;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: 80.milliseconds,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: focus
            ? Border.fromBorderSide(
          BorderSide(
            width: 4,
            style: BorderStyle.solid,
            strokeAlign: BorderSide.strokeAlignOutside,
            color: color ??
                context.theme.color.borderBrand.withValues(alpha: 0.30),
          ),
        )
            : Border.fromBorderSide(
          BorderSide(
            width: 4,
            style: BorderStyle.solid,
            strokeAlign: BorderSide.strokeAlignOutside,
            color: context.theme.color.transparent.t0,
          ),
        ),
      ),
      child: child,
    );
  }
}
