import 'package:stratum_ui/src/src.dart';

extension BorderExtension on Border {
  double get maxWidth => [
        bottom.width,
        this.left.width,
        this.right.width,
        top.width
      ].reduce((a, b) => a > b ? a : b);

  Border copy({
    Color? color,
    double? width,
    BorderStyle? style,
    double? strokeAlign,
  }) =>
      Border(
        bottom: BorderSide(
          color: color ?? bottom.color,
          width: width ?? bottom.width,
          style: style ?? bottom.style,
          strokeAlign: strokeAlign ?? bottom.strokeAlign,
        ),
        right: BorderSide(
          color: color ?? this.right.color,
          width: width ?? this.right.width,
          style: style ?? this.right.style,
          strokeAlign: strokeAlign ?? this.right.strokeAlign,
        ),
        left: BorderSide(
          color: color ?? this.left.color,
          width: width ?? this.left.width,
          style: style ?? this.left.style,
          strokeAlign: strokeAlign ?? this.left.strokeAlign,
        ),
        top: BorderSide(
          color: color ?? top.color,
          width: width ?? top.width,
          style: style ?? top.style,
          strokeAlign: strokeAlign ?? top.strokeAlign,
        ),
      );
}

extension BorderRadiusGeometryExtension on BorderRadiusGeometry {
  double get maxRadius => switch (this) {
        BorderRadius() => [
            (this as BorderRadius).topLeft.x,
            (this as BorderRadius).topRight.x,
            (this as BorderRadius).bottomLeft.x,
            (this as BorderRadius).bottomRight.x,
          ].reduce((a, b) => a > b ? a : b),
        BorderRadiusDirectional() => [
            (this as BorderRadiusDirectional).topStart.x,
            (this as BorderRadiusDirectional).topEnd.x,
            (this as BorderRadiusDirectional).bottomStart.x,
            (this as BorderRadiusDirectional).bottomEnd.x,
          ].reduce((a, b) => a > b ? a : b),
        _ => throw UnsupportedError('Please check BorderRadius type.')
      };

  BorderRadiusGeometry mapMaxRadius(double Function(double radius) f) =>
      switch (this) {
        BorderRadius() => BorderRadius.all(Radius.circular(f(maxRadius))),
        BorderRadiusDirectional() =>
          BorderRadiusDirectional.all(Radius.circular(f(maxRadius))),
        _ => throw UnsupportedError('Please check BorderRadius type.')
      };
}

extension BorderRadiusExtension on BorderRadius {
  BorderRadius mapMaxRadius(double Function(double radius) f) =>
      BorderRadius.all(Radius.circular(f(maxRadius)));
}

extension EdgeInsetsGeometryExtension on EdgeInsetsGeometry {
  double get maxValue => switch (this) {
        EdgeInsets() => [
            (this as EdgeInsets).left,
            (this as EdgeInsets).top,
            (this as EdgeInsets).right,
            (this as EdgeInsets).bottom,
          ].reduce((a, b) => a > b ? a : b),
        EdgeInsetsDirectional() => [
            (this as EdgeInsetsDirectional).start,
            (this as EdgeInsetsDirectional).top,
            (this as EdgeInsetsDirectional).end,
            (this as EdgeInsetsDirectional).bottom,
          ].reduce((a, b) => a > b ? a : b),
        _ => throw UnsupportedError('Please check EdgeInset type.')
      };
}
