// Frozen by tool/perf_freeze.dart from fe31fdc:lib/src/components/common/style/animated_styled_box.dart. Do not edit; run
// the tool again. Verbatim except this header, the baseline import,
// and the Baseline prefix on the names the frozen files declare.
// ignore_for_file: type=lint, unused_import
import 'baseline.dart';

import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/components/common/style/style_decoration.dart';

/// Wraps the styled box of an [BaselineAnimatedStyledBox] with the style of the
/// current animation frame; see [BaselineAnimatedStyledBox.boxBuilder].
typedef BaselineStyledBoxBuilder = Widget Function(WidgetStyle style, Widget box);

/// Puts the padded content of an [BaselineAnimatedStyledBox] into a scroll view;
/// see [BaselineAnimatedStyledBox.scrollBuilder].
typedef BaselineStyledScrollBuilder = Widget Function(Widget content);

/// Paints a [WidgetStyle] around [child] and animates between styles.
///
/// Duration and curve come from the target style's
/// [WidgetStyle.animationStyle]; a null value applies the new style in the
/// same frame. A null curve uses [Curves.easeInOutSine], because a linear
/// change looks stiff. `AnimationStyle.reverseDuration` and `reverseCurve`
/// are not used.
///
/// When the platform asks for less motion (`disableAnimations` or
/// `reduceMotion`), size, spacing, and alignment jump to the new style while
/// colors, gradients, images, borders, radius, shadows, blur, and opacity
/// still fade over the full duration. The fade keeps its duration on every
/// platform, because the controller uses [AnimationBehavior.preserve].
class BaselineAnimatedStyledBox extends StatefulWidget {
  const new({
    super.key,
    this.style,
    this.ratio,
    this.transform,
    this.transformAlignment,
    this.onEnd,
    this.boxBuilder,
    this.scrollBuilder,
    this.child,
  });

  final WidgetStyle? style;
  final double? ratio;
  final Matrix4? transform;
  final AlignmentGeometry? transformAlignment;

  /// Called when a style animation completes. A zero-duration change
  /// completes synchronously inside `didUpdateWidget`, so a `setState`
  /// inside [onEnd] during an instant change throws.
  final VoidCallback? onEnd;

  /// Wraps the box after its size constraints and before its margin,
  /// transform, and opacity.
  ///
  /// Receives the style of the current animation frame. The result keeps
  /// its State when wrappers above it come and go.
  final BaselineStyledBoxBuilder? boxBuilder;

  /// Wraps the padded content in a scroll view inside the box.
  ///
  /// Fill, border, radius, shadow, and blur stay in place while the padding
  /// and the child scroll. With a border radius and no `clipBehavior` in the
  /// style, the box clips the viewport to its corners with
  /// [Clip.antiAlias].
  final BaselineStyledScrollBuilder? scrollBuilder;
  final Widget? child;

  @override
  State<BaselineAnimatedStyledBox> createState() => _AnimatedStyledBoxState();
}

class _AnimatedStyledBoxState extends State<BaselineAnimatedStyledBox>
    with SingleTickerProviderStateMixin {
  final GlobalKey _childKey = GlobalKey(debugLabel: 'BaselineAnimatedStyledBox.child');
  final GlobalKey _boxKey = GlobalKey(debugLabel: 'BaselineAnimatedStyledBox.box');
  late final GlobalKey _scrollKey = GlobalKey(
    debugLabel: 'BaselineAnimatedStyledBox.scroll',
  );

  late final AnimationController _controller = AnimationController(
    duration: _duration,
    animationBehavior: AnimationBehavior.preserve,
    vsync: this,
  );
  late CurvedAnimation _animation = CurvedAnimation(
    parent: _controller,
    curve: _curve,
  );
  late final _WidgetStyleTween _style = _WidgetStyleTween(
    begin: _target,
    end: _target,
  );

  WidgetStyle get _target => widget.style ?? const WidgetStyle();

  Duration get _duration =>
      widget.style?.animationStyle?.duration ?? Duration.zero;

  Curve get _curve => widget.style?.animationStyle?.curve ?? _defaultCurve;

  static const Curve _defaultCurve = Curves.easeInOutSine;

  @override
  void initState() {
    super.initState();
    _controller
      ..addListener(_handleTick)
      ..addStatusListener(_handleStatus);
  }

  @override
  void didUpdateWidget(BaselineAnimatedStyledBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldCurve = oldWidget.style?.animationStyle?.curve ?? _defaultCurve;
    if (_curve != oldCurve) {
      _animation.dispose();
      _animation = CurvedAnimation(parent: _controller, curve: _curve);
    }
    _controller.duration = _duration;
    final target = _target;
    if (target == _style.end) return;
    var begin = _style.evaluate(_animation);
    if (_reducesMotion) begin = _jumpGeometry(begin, to: target);
    _style
      ..begin = begin
      ..end = target;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleTick() => setState(() {});

  void _handleStatus(AnimationStatus status) {
    if (status.isCompleted) widget.onEnd?.call();
  }

  /// Whether the platform asks for less motion. `MediaQueryData` has no
  /// `reduceMotion` field, so the flags come from the view's dispatcher.
  bool get _reducesMotion {
    final features = View.of(context).platformDispatcher.accessibilityFeatures;
    return features.disableAnimations || features.reduceMotion;
  }

  /// [from] with the size, spacing, and alignment of [to], so those fields
  /// stay at their target while the rest of the style fades.
  static WidgetStyle _jumpGeometry(
    WidgetStyle from, {
    required WidgetStyle to,
  }) {
    return from.copyWith(
      width: to.width,
      height: to.height,
      minWidth: to.minWidth,
      maxWidth: to.maxWidth,
      minHeight: to.minHeight,
      maxHeight: to.maxHeight,
      padding: to.padding,
      margin: to.margin,
      alignment: to.alignment,
    );
  }

  @override
  Widget build(BuildContext context) => _buildBox(_style.evaluate(_animation));

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
    final scrollBuilder = widget.scrollBuilder;
    if (scrollBuilder != null) {
      current = KeyedSubtree(key: _scrollKey, child: scrollBuilder(current));
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
    current = _clip(
      style,
      hasBlur: blur != null,
      scrolls: scrollBuilder != null,
      child: current,
    );
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
    final boxBuilder = widget.boxBuilder;
    if (boxBuilder != null) {
      current = KeyedSubtree(key: _boxKey, child: boxBuilder(style, current));
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

  /// The one clip of the box: when a blur is set, when
  /// [WidgetStyle.clipBehavior] asks for it, or when a rounded box scrolls.
  ///
  /// A blur is always clipped, because an unclipped `BackdropFilter` blurs
  /// everything up to the nearest ancestor clip. A rounded scrolling box
  /// clips with [Clip.antiAlias], which adds no save layer; the scroll view
  /// keeps its own rectangular clip inside it.
  static Widget _clip(
    WidgetStyle style, {
    required bool hasBlur,
    required bool scrolls,
    required Widget child,
  }) {
    final radius = style.borderRadius;
    final requested =
        style.clipBehavior ??
        (scrolls && radius != null ? Clip.antiAlias : Clip.none);
    if (!hasBlur && requested == Clip.none) return child;
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
  ///
  /// The range is normalized first, because min and max animate on their
  /// own and can cross mid-animation.
  static BoxConstraints? _constraints(WidgetStyle style) {
    final hasRange =
        style.minWidth != null ||
        style.maxWidth != null ||
        style.minHeight != null ||
        style.maxHeight != null;
    var constraints = hasRange
        ? BoxConstraints(
            minWidth: style.minWidth ?? 0,
            maxWidth: style.maxWidth ?? double.infinity,
            minHeight: style.minHeight ?? 0,
            maxHeight: style.maxHeight ?? double.infinity,
          ).normalize()
        : null;
    if (style.width != null || style.height != null) {
      constraints =
          constraints?.tighten(width: style.width, height: style.height) ??
          BoxConstraints.tightFor(width: style.width, height: style.height);
    }
    return constraints;
  }
}

class _WidgetStyleTween extends Tween<WidgetStyle> {
  new({super.begin, super.end});

  @override
  WidgetStyle lerp(double t) => WidgetStyle.lerp(begin, end, t)!;
}
