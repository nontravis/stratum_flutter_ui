import 'dart:math' as math;

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
/// mid-motion continues from where the motion is. A size change anchors
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

  /// The controller through [_curve]; every transition reads it.
  late final Animation<double> _value = _controller.drive(_curve);

  /// The slide's start, in the child's own size; `Offset.zero` holds the
  /// content in place (layout s03 invariant 42).
  final _slide = Tween<Offset>(begin: Offset.zero, end: Offset.zero);

  /// The controller through [_curve] and [_slide].
  late final Animation<Offset> _position = _value.drive(_slide);

  /// Whether the app or the platform asks for less motion; read with the
  /// theme in [_applyMotion].
  var _reduced = false;

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
  void _applyMotion() {
    _reduced = context.reducesMotion;
    final style =
        (StratumThemeApplication.maybeOf(context)?.animation ??
                StratumAnimation.packageDefault)
            .defaultStyle;
    _controller
      ..duration = widget.duration ?? style.duration
      ..reverseDuration = widget.reverseDuration ?? style.reverseDuration;
    _curve.curve = widget.curve ?? style.curve!;
    // Only `slide` moves the content (FR-02 E04), and not under reduced
    // motion (invariant 44).
    _slide.begin = widget.transition == StratumShowTransition.slide && !_reduced
        ? _edge(widget.slideDirection, Directionality.of(context))
        : Offset.zero;
  }

  /// Runs the show or the hide from where the motion is now.
  void _move() {
    if (_reduced && widget.transition == StratumShowTransition.size) {
      // `size` shows and hides at once under reduced motion (invariant 44).
      _controller.value = widget.visible ? 1 : 0;
      return;
    }
    if (widget.visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  /// Rebuilds once the hide motion ends, so the content leaves the tree.
  void _onStatus(AnimationStatus status) {
    if (status.isDismissed) setState(() {});
  }

  /// The size factor: the motion under `size` and `sizeAndFade`; the full
  /// size under `fade` and `slide`, and under reduced motion (invariant
  /// 44).
  Animation<double> get _sizeFactor => switch (widget.transition) {
    StratumShowTransition.size ||
    StratumShowTransition.sizeAndFade when !_reduced => _value,
    _ => kAlwaysCompleteAnimation,
  };

  /// The opacity: the motion under every transition but `size`.
  Animation<double> get _opacity =>
      widget.transition == StratumShowTransition.size
      ? kAlwaysCompleteAnimation
      : _value;

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

  /// One clip around a size change on both axes, anchored at the top
  /// start corner (layout s03 invariant 45; PD6, PD7).
  Widget _motion() {
    final size = _sizeFactor;
    return ClipRect(
      child: AnimatedBuilder(
        animation: size,
        builder: (context, child) {
          final factor = math.max(size.value, 0.0);
          return Align(
            alignment: AlignmentDirectional.topStart,
            widthFactor: factor,
            heightFactor: factor,
            child: child,
          );
        },
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(position: _position, child: widget.child),
        ),
      ),
    );
  }
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
