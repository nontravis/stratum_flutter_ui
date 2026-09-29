import 'package:stratum_ui/src/src.dart';

class AppBorder {
  const AppBorder({
    this.none = const Border.fromBorderSide(
      BorderSide(
        width: 0.0,
        color: Colors.transparent,
      ),
    ),
    this.xs = const Border.fromBorderSide(
      BorderSide(
        width: 0.25,
        style: BorderStyle.solid,
        strokeAlign: BorderSide.strokeAlignInside,
      ),
    ),
    this.sm = const Border.fromBorderSide(
      BorderSide(
        width: 0.5,
        style: BorderStyle.solid,
        strokeAlign: BorderSide.strokeAlignInside,
      ),
    ),
    this.md = const Border.fromBorderSide(
      BorderSide(
        width: 1.0,
        style: BorderStyle.solid,
        strokeAlign: BorderSide.strokeAlignInside,
      ),
    ),
    this.lg = const Border.fromBorderSide(
      BorderSide(
        width: 1.5,
        style: BorderStyle.solid,
        strokeAlign: BorderSide.strokeAlignInside,
      ),
    ),
    this.xl = const Border.fromBorderSide(
      BorderSide(
        width: 2.0,
        style: BorderStyle.solid,
        strokeAlign: BorderSide.strokeAlignInside,
      ),
    ),
  });

  final Border none;
  final Border xs;
  final Border sm;
  final Border md;
  final Border lg;
  final Border xl;
}
