import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/components/common/style/style_decoration.dart';

/// Paints a [WidgetStyle] around [child] and animates between styles.
///
/// Duration and curve come from the target style's
/// [WidgetStyle.animationStyle]; a null value applies the new style in the
/// same frame. `AnimationStyle.reverseDuration` and `reverseCurve` are not
/// used, because [ImplicitlyAnimatedWidget] has no reverse settings.
class AnimatedStyledBox extends ImplicitlyAnimatedWidget {
  new({
    super.key,
    this.style,
    this.ratio,
    this.transform,
    this.transformAlignment,
    super.onEnd,
    this.child,
  }) : super(
         duration: style?.animationStyle?.duration ?? Duration.zero,
         curve: style?.animationStyle?.curve ?? Curves.linear,
       );

  final WidgetStyle? style;
  final double? ratio;
  final Matrix4? transform;
  final AlignmentGeometry? transformAlignment;
  final Widget? child;

  @override
  AnimatedWidgetBaseState<AnimatedStyledBox> createState() =>
      _AnimatedStyledBoxState();
}

class _AnimatedStyledBoxState
    extends AnimatedWidgetBaseState<AnimatedStyledBox> {
  final GlobalKey _childKey = GlobalKey(debugLabel: 'AnimatedStyledBox.child');
  _WidgetStyleTween? _style;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _style = visitor(
      _style,
      widget.style ?? const WidgetStyle(),
      (dynamic value) => _WidgetStyleTween(begin: value as WidgetStyle),
    ) as _WidgetStyleTween?;
  }

  @override
  Widget build(BuildContext context) => _buildBox(_style!.evaluate(animation));

  Widget _buildBox(WidgetStyle style) {
    final child = widget.child;
    final blur = style.backgroundBlur;
    // Wrappers above the child come and go with the style. The GlobalKey
    // makes Flutter move the child's element instead of rebuilding it, so
    // the child keeps its State.
    Widget current = KeyedSubtree(
      key: _childKey,
      child: child ?? const SizedBox.shrink(),
    );

    final ratio = widget.ratio;
    if (ratio != null) {
      current = AspectRatio(aspectRatio: ratio, child: current);
    }
    final alignment = style.alignment;
    if (alignment != null) {
      current = Align(alignment: alignment, child: current);
    }
    final padding = style.padding;
    if (padding != null) {
      current = Padding(padding: padding, child: current);
    }
    final foregroundBlur = style.foregroundBlur;
    if (foregroundBlur != null && child != null) {
      current = ImageFiltered(imageFilter: foregroundBlur.blur, child: current);
    }
    if (blur != null) {
      current = DecoratedBox(
        decoration: StyleDecoration(
          color: style.backgroundColor,
          gradient: style.backgroundGradient,
          image: style.backgroundImage,
          borderRadius: style.borderRadius,
          innerShadow: style.innerShadow,
        ),
        child: current,
      );
      current = BackdropFilter.grouped(filter: blur.blur, child: current);
    }
    current = _clip(style, hasBlur: blur != null, child: current);
    if (blur != null) {
      if (style.dropShadow != null) {
        current = DecoratedBox(
          decoration: StyleDecoration(
            borderRadius: style.borderRadius,
            dropShadow: style.dropShadow,
          ),
          child: current,
        );
      }
    } else if (_hasBackground(style)) {
      current = DecoratedBox(
        decoration: StyleDecoration(
          color: style.backgroundColor,
          gradient: style.backgroundGradient,
          image: style.backgroundImage,
          borderRadius: style.borderRadius,
          dropShadow: style.dropShadow,
          innerShadow: style.innerShadow,
        ),
        child: current,
      );
    }
    if (_hasForeground(style)) {
      current = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          color: style.foregroundColor,
          gradient: style.foregroundGradient,
          image: style.foregroundImage,
          border: style.border,
          borderRadius: style.borderRadius,
        ),
        child: current,
      );
    }
    final constraints = _constraints(style);
    if (constraints != null) {
      current = ConstrainedBox(constraints: constraints, child: current);
    }
    final margin = style.margin;
    if (margin != null) {
      current = Padding(padding: margin, child: current);
    }
    final transform = widget.transform;
    if (transform != null) {
      current = Transform(
        transform: transform,
        alignment: widget.transformAlignment,
        child: current,
      );
    }
    final opacity = style.opacity;
    if (opacity != null && opacity < 1) {
      current = Opacity(opacity: opacity, child: current);
    }
    return current;
  }

  static bool _hasBackground(WidgetStyle style) =>
      style.backgroundColor != null ||
      style.backgroundGradient != null ||
      style.backgroundImage != null ||
      style.dropShadow != null ||
      style.innerShadow != null;

  static bool _hasForeground(WidgetStyle style) =>
      style.foregroundColor != null ||
      style.foregroundGradient != null ||
      style.foregroundImage != null ||
      style.border != null;

  /// Clips when a blur is set or [WidgetStyle.clipBehavior] asks for it.
  ///
  /// A blur is always clipped, because an unclipped `BackdropFilter` blurs
  /// everything up to the nearest ancestor clip.
  static Widget _clip(
    WidgetStyle style, {
    required bool hasBlur,
    required Widget child,
  }) {
    final requested = style.clipBehavior ?? Clip.none;
    if (!hasBlur && requested == Clip.none) return child;
    final radius = style.borderRadius;
    final behavior = requested != Clip.none
        ? requested
        : (radius == null ? Clip.hardEdge : Clip.antiAlias);
    if (radius == null) {
      return ClipRect(clipBehavior: behavior, child: child);
    }
    return ClipRRect(
      borderRadius: radius,
      clipBehavior: behavior,
      child: child,
    );
  }

  /// Same rules as `Container`: min and max win over width and height.
  static BoxConstraints? _constraints(WidgetStyle style) {
    final hasRange = style.minWidth != null ||
        style.maxWidth != null ||
        style.minHeight != null ||
        style.maxHeight != null;
    var constraints = hasRange
        ? BoxConstraints(
            minWidth: style.minWidth ?? 0,
            maxWidth: style.maxWidth ?? double.infinity,
            minHeight: style.minHeight ?? 0,
            maxHeight: style.maxHeight ?? double.infinity,
          )
        : null;
    if (style.width != null || style.height != null) {
      constraints = constraints?.tighten(
            width: style.width,
            height: style.height,
          ) ??
          BoxConstraints.tightFor(width: style.width, height: style.height);
    }
    return constraints;
  }
}

class _WidgetStyleTween extends Tween<WidgetStyle> {
  new({super.begin});

  @override
  WidgetStyle lerp(double t) => WidgetStyle.lerp(begin, end, t)!;
}
