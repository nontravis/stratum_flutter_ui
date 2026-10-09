import 'dart:math' as math;

import 'package:flutter/rendering.dart'
    show ClipRectLayer, LayerHandle, PipelineOwner, RenderAligningShiftedBox;
import 'package:stratum_ui/src/animations/screen_transition.dart'
    show curveOf, durationOf, reverseDurationOf;
import 'package:stratum_ui/src/src.dart';

/// How a [StratumShow] moves between shown and hidden (FO-06 US-15 FR-01).
enum StratumShowTransition {
  /// Takes its full size at once and fades; hides by fading, then takes no
  /// space.
  fade,

  /// Changes its size, with no fade.
  size,

  /// Changes its size and fades together; the default.
  sizeAndFade,

  /// Slides by its own full size from [StratumShow.slideDirection] while it
  /// fades (FR-02).
  slide,
}

/// The edge a [StratumShowTransition.slide] comes from and leaves toward;
/// [start] and [end] follow the text direction (US-15 FR-02).
enum StratumShowSlideDirection { top, bottom, start, end }

/// Shows [child] while [visible] is true and hides it while false, by
/// [transition], over the theme's default motion level on its `standard`
/// curve both ways (FO-06 US-15).
///
/// One [AnimationController] drives every transition, forward over the
/// show duration and back over the hide duration, so a flip of [visible]
/// mid-motion continues from where the motion is; a [transition] changed
/// mid-motion carries the size, the fade, and the slide from where they
/// are to the new transition's track by the motion's end. A size change anchors
/// at the top start corner. Hidden content has no size on either axis and
/// is unmounted after its hide motion, so it builds fresh when shown again,
/// unless [maintainState] keeps it. From the frame [visible] turns false,
/// the leaving content takes no pointer, focus, or semantics; focus held
/// inside it moves, after the frame, to this widget's own node, which is
/// not a Tab stop. It extends no component base, so the base's disabled
/// wrapper never wraps it.
class StratumShow extends StatefulWidget {
  const new({
    super.key,
    required this.visible,
    required this.child,
    this.transition = StratumShowTransition.sizeAndFade,
    this.slideDirection = StratumShowSlideDirection.end,
    this.duration,
    this.reverseDuration,
    this.curve,
    this.maintainState = false,
  });

  /// True shows [child]; false hides it.
  final bool visible;

  /// The content.
  final Widget child;

  /// How the content moves; [StratumShowTransition.sizeAndFade] by default.
  final StratumShowTransition transition;

  /// Used by [StratumShowTransition.slide] alone (FR-02 E04).
  final StratumShowSlideDirection slideDirection;

  /// The show duration; null takes the forward duration of the theme's
  /// default level, 125 ms in the package default.
  final Duration? duration;

  /// The hide duration; null takes the reverse duration of the theme's
  /// default level, 80 ms in the package default.
  final Duration? reverseDuration;

  /// Runs both ways, played backward on the hide; null takes the theme's
  /// `standard` curve.
  final Curve? curve;

  /// True keeps hidden content mounted, with no size, its tickers stopped,
  /// out of focus and semantics, so it keeps its state; false, the default,
  /// unmounts it after its hide motion. Changing it while mounted builds
  /// the content fresh, as [Visibility.maintainState] does.
  final bool maintainState;

  @override
  State<StratumShow> createState() => _StratumShowState();
}

class _StratumShowState extends State<StratumShow>
    with SingleTickerProviderStateMixin {
  /// 0 hidden, 1 shown; forward over the show duration, reverse over the
  /// hide duration (layout s03 invariant 43).
  late final AnimationController _controller;

  /// The curve both ways (PD9).
  final _curve = CurveTween(curve: Curves.easeInOutSine);

  /// The controller through [_curve]; every channel reads it.
  late final Animation<double> _value = _controller.drive(_curve);

  /// The size factor's line over [_value], set by [_aim].
  final _sizeLine = Tween<double>(begin: 1, end: 1);

  /// The opacity's line over [_value], set by [_aim].
  final _opacityLine = Tween<double>(begin: 1, end: 1);

  /// The slide offset's line over [_value], in the child's own size, set
  /// by [_aim].
  final _slideLine = Tween<Offset>(begin: Offset.zero, end: Offset.zero);

  late final Animation<double> _sizeFactor = _value.drive(_sizeLine);
  late final Animation<double> _opacity = _value.drive(_opacityLine);
  late final Animation<Offset> _slide = _value.drive(_slideLine);

  /// Whether the app or the platform asks for less motion; read with the
  /// theme in [_applyMotion].
  var _reduced = false;

  /// The edge [StratumShow.slideDirection] names, resolved through the
  /// text direction in [_applyMotion] (invariant 42).
  Offset _edgeOffset = Offset.zero;

  /// Takes focus when focus sat inside content that hides; Tab skips it
  /// (layout s03 invariant 46, the rule of `IndexedStackLayout`).
  final _showNode = FocusNode(debugLabel: 'StratumShow', skipTraversal: true);

  /// Marks the content's subtree only.
  final _contentNode = FocusNode(
    debugLabel: 'StratumShow content',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      value: widget.visible ? 1 : 0,
    )..addStatusListener(_onStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyMotion();
  }

  @override
  void didUpdateWidget(StratumShow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applyMotion();
    if (widget.visible == oldWidget.visible) return;
    // The build below excludes the content from focus, so check now
    // whether focus sits inside it (invariant 46).
    if (!widget.visible && _contentNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showNode.requestFocus();
      });
    }
    _move();
  }

  @override
  void dispose() {
    _showNode.dispose();
    _contentNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Takes the show and hide durations and the curve from the theme's
  /// `defaultStyle`, unless this instance sets them (invariant 43).
  ///
  /// A level that sets none of them, such as [AnimationStyle.noAnimation],
  /// takes zero, its own forward duration, and `easeInOutSine` (themes s03
  /// invariant 15).
  void _applyMotion() {
    final now = _look;
    _reduced = context.reducesMotion;
    final style =
        (StratumThemeApplication.maybeOf(context)?.animation ??
                StratumAnimation.packageDefault)
            .defaultStyle;
    _controller
      ..duration = widget.duration ?? durationOf(style)
      ..reverseDuration = widget.reverseDuration ?? reverseDurationOf(style);
    _curve.curve = widget.curve ?? curveOf(style);
    _edgeOffset = _edge(widget.slideDirection, Directionality.of(context));
    _aim(now);
  }

  /// Runs the show or the hide from where the motion is now.
  void _move() {
    final now = _look;
    if (_reduced && widget.transition == StratumShowTransition.size) {
      // `size` shows and hides at once under reduced motion (invariant 44).
      _controller.value = widget.visible ? 1 : 0;
    } else if (widget.visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    _aim(now);
  }

  /// Rebuilds once the hide motion ends, so the content leaves the tree.
  void _onStatus(AnimationStatus status) {
    if (status.isDismissed) setState(() {});
  }

  /// What the content shows now.
  _Look get _look =>
      (size: _sizeFactor.value, opacity: _opacity.value, slide: _slide.value);

  /// What [StratumShow.transition] shows at the curved motion value [t].
  ///
  /// The size changes under `size` and `sizeAndFade`, the opacity under
  /// all but `size`, and the content slides under `slide` alone (FR-02
  /// E04); under reduced motion neither the size nor the slide moves
  /// (invariant 44).
  _Look _track(double t) {
    final transition = widget.transition;
    final resizes =
        !_reduced &&
        (transition == StratumShowTransition.size ||
            transition == StratumShowTransition.sizeAndFade);
    final slides = !_reduced && transition == StratumShowTransition.slide;
    return (
      size: resizes ? t : 1.0,
      opacity: transition == StratumShowTransition.size ? 1.0 : t,
      slide: slides ? _edgeOffset * (1 - t) : Offset.zero,
    );
  }

  /// Sets each channel's line: at rest the track itself; mid-motion the
  /// line from [now], what the content showed before the change, to the
  /// track's value at the motion's end, so no change jumps (invariant 48).
  ///
  /// Every track is linear in the motion value, so a line through the
  /// value now and the track's end reaches the track at the end.
  void _aim(_Look now) {
    final t = _value.value;
    final end = _controller.status == AnimationStatus.forward ? 1.0 : 0.0;
    if (!_controller.isAnimating || t == end) {
      _setLines(hidden: _track(0), shown: _track(1));
      return;
    }
    final target = _track(end);
    // The line through (t, now) and (end, target), read at [at].
    _Look line(double at) {
      final k = (at - end) / (t - end);
      return (
        size: target.size + (now.size - target.size) * k,
        opacity: target.opacity + (now.opacity - target.opacity) * k,
        slide: target.slide + (now.slide - target.slide) * k,
      );
    }

    _setLines(hidden: line(0), shown: line(1));
  }

  /// Sets each channel's value at motion value 0 to [hidden] and at 1 to
  /// [shown].
  void _setLines({required _Look hidden, required _Look shown}) {
    _sizeLine
      ..begin = hidden.size
      ..end = shown.size;
    _opacityLine
      ..begin = hidden.opacity
      ..end = shown.opacity;
    _slideLine
      ..begin = hidden.slide
      ..end = shown.slide;
  }

  @override
  Widget build(BuildContext context) {
    final hidden = !widget.visible;
    return Focus(
      focusNode: _showNode,
      includeSemantics: false,
      child: Focus(
        focusNode: _contentNode,
        includeSemantics: false,
        child: ExcludeFocus(
          excluding: hidden,
          child: ExcludeSemantics(
            excluding: hidden,
            child: IgnorePointer(
              ignoring: hidden,
              // Dismissed: the content leaves the tree, or with
              // maintainState stays offstage under TickerMode(enabled:
              // false) (invariant 46, PD8).
              child: Visibility(
                visible: !_controller.isDismissed,
                maintainState: widget.maintainState,
                child: _motion(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The size change on both axes, anchored at the top start corner, with
  /// the fade and the slide inside it (layout s03 invariant 45; PD6, PD7).
  Widget _motion() => _SizeFactorBox(
    factor: _sizeFactor,
    slide: _slide,
    child: FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    ),
  );
}

/// The size factor, the opacity, and the slide offset content shows at one
/// point of a motion.
typedef _Look = ({double size, double opacity, Offset slide});

/// Sizes itself to its child's size times [factor] and places the child at
/// the top start corner (layout s03 invariant 45; PD6, PD7).
///
/// The child lays out under the incoming constraints unchanged, so a shown
/// child stretches as it would with no show around it. It clips to its own
/// box only while the child moves, [factor] below 1 or [slide] off zero, so
/// at rest a focus ring or a shadow paints outside it.
class _SizeFactorBox extends SingleChildRenderObjectWidget {
  const new({required this.factor, required this.slide, required super.child});

  /// The size factor on both axes; a value below 0 counts as 0.
  final Animation<double> factor;

  /// The slide offset, read only to decide the clip.
  final Animation<Offset> slide;

  @override
  _RenderSizeFactorBox createRenderObject(BuildContext context) =>
      _RenderSizeFactorBox(
        factor: factor,
        slide: slide,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSizeFactorBox renderObject,
  ) {
    renderObject
      ..factor = factor
      ..slide = slide
      ..textDirection = Directionality.of(context);
  }
}

/// The render box of [_SizeFactorBox]. It listens to both animations
/// itself, so a motion frame lays it out or repaints it with no rebuild.
class _RenderSizeFactorBox extends RenderAligningShiftedBox {
  new({
    required Animation<double> factor,
    required Animation<Offset> slide,
    required super.textDirection,
  }) : _factor = factor,
       _slide = slide,
       super(alignment: AlignmentDirectional.topStart);

  Animation<double> _factor;
  set factor(Animation<double> value) {
    if (value == _factor) return;
    if (attached) _factor.removeListener(_onFactor);
    _factor = value;
    if (attached) _factor.addListener(_onFactor);
    markNeedsLayout();
  }

  Animation<Offset> _slide;
  set slide(Animation<Offset> value) {
    if (value == _slide) return;
    if (attached) _slide.removeListener(_onSlide);
    _slide = value;
    if (attached) _slide.addListener(_onSlide);
    _onSlide();
  }

  /// The clip layer of the last clipped paint.
  final _clipLayer = LayerHandle<ClipRectLayer>();

  /// Whether the last paint clipped.
  var _clipped = false;

  double get _sizeFactor => math.max(_factor.value, 0.0);

  /// Whether the child moves: smaller than its own size, or slid off.
  bool get _moving => _sizeFactor < 1 || _slide.value != Offset.zero;

  /// The size factor of the last layout.
  double? _laidOutFactor;

  /// Lays out only when the factor changed, so a transition whose size
  /// holds runs no layout per motion frame.
  void _onFactor() {
    if (_sizeFactor != _laidOutFactor) markNeedsLayout();
  }

  /// A slide moves only the paint, so it repaints when the clip turns on
  /// or off; a size change lays out, which repaints.
  void _onSlide() {
    if (_moving != _clipped) markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _factor.addListener(_onFactor);
    _slide.addListener(_onSlide);
  }

  @override
  void detach() {
    _factor.removeListener(_onFactor);
    _slide.removeListener(_onSlide);
    super.detach();
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      super.computeMinIntrinsicWidth(height) * _sizeFactor;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      super.computeMaxIntrinsicWidth(height) * _sizeFactor;

  @override
  double computeMinIntrinsicHeight(double width) =>
      super.computeMinIntrinsicHeight(width) * _sizeFactor;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      super.computeMaxIntrinsicHeight(width) * _sizeFactor;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return constraints.constrain(child.getDryLayout(constraints) * _sizeFactor);
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    _laidOutFactor = _sizeFactor;
    size = constraints.constrain(child.size * _sizeFactor);
    alignChild();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _clipped = child != null && _moving;
    if (!_clipped) {
      _clipLayer.layer = null;
      super.paint(context, offset);
      return;
    }
    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      super.paint,
      oldLayer: _clipLayer.layer,
    );
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      _clipped ? Offset.zero & size : null;
}

/// The offset, in the child's own size, of [direction]'s edge (invariant
/// 42); `start` and `end` resolve through [text].
Offset _edge(StratumShowSlideDirection direction, TextDirection text) {
  final rtl = text == TextDirection.rtl;
  return switch (direction) {
    StratumShowSlideDirection.top => const Offset(0, -1),
    StratumShowSlideDirection.bottom => const Offset(0, 1),
    StratumShowSlideDirection.start => Offset(rtl ? 1 : -1, 0),
    StratumShowSlideDirection.end => Offset(rtl ? -1 : 1, 0),
  };
}
