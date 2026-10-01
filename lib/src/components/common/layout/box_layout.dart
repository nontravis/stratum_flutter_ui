import 'dart:math' as math;

import 'package:stratum_ui/src/components/common/layout/scroll_frame.dart';
import 'package:stratum_ui/src/src.dart';

/// The base of the box layouts: one build pipeline for style, transforms,
/// interaction, semantics, and scrolling.
///
/// A subclass declares its own parameters and overrides [buildContent].
/// When [style], [ratio], [rotate], [transform], [interaction], and
/// [scroll] are null, the layout builds the bare tier: the content with
/// only the [semantics], [repaintBoundary], [debug], and [keepAlive]
/// wrappers, and no [AnimatedStyledBox]. Otherwise it builds the box tier
/// around an [AnimatedStyledBox].
///
/// The tier depends on whether a parameter is null, never on its content.
/// Content remounts when the tier changes (switching [scroll] between null
/// and a value on an otherwise bare layout counts), when [rotate] switches
/// between null and a value, when [repaintBoundary], [debug], or
/// [keepAlive] changes, or, on a bare layout, when [semantics] switches
/// between null and a value. Pass `const WidgetStyle()` or
/// `const StratumInteraction()` up front when a value can appear later; a
/// layout that toggles [scroll] passes `const WidgetStyle()` so the toggle
/// stays inside the box tier.
///
/// Inside the box tier, a scrolling layout's scroll position survives a
/// [style], [interaction], [semantics], or [StratumScroll] field change;
/// only a tier change, a new [StratumScroll.controller], or a flip of
/// [StratumScroll.fillViewport] resets it.
abstract class BoxLayout extends StatelessWidget {
  const new({
    super.key,
    this.style,
    this.ratio,
    this.rotate,
    this.transform,
    this.transformAlignment,
    this.keepAlive = false,
    this.repaintBoundary = false,
    this.debug = false,
    this.semantics,
    this.onEndAnimate,
    this.interaction,
    this.scroll,
  });

  /// Every visual value of the box: spacing, size, fill, border, shadows,
  /// blur, opacity, and animation.
  final WidgetStyle? style;

  /// Width divided by height, ignored unless greater than 0: of the
  /// content, or, with [scroll], of the visible frame, while the content
  /// scrolls inside it.
  final double? ratio;

  /// Clockwise rotation in degrees.
  final double? rotate;
  final Matrix4? transform;
  final AlignmentGeometry? transformAlignment;

  /// Keeps this layout alive when a lazy list scrolls it away.
  final bool keepAlive;
  final bool repaintBoundary;
  final bool debug;

  /// Semantics of the box, inside its margin. With a tap surface they
  /// replace the surface's button role.
  final SemanticsProperties? semantics;

  /// Called when a style animation completes; an instant change does not
  /// call it.
  final VoidCallback? onEndAnimate;

  /// Pointer, focus, and semantics settings of the tap surface; see
  /// [StratumInteraction].
  final StratumInteraction? interaction;

  /// Scrolls the padding and content inside the box along
  /// [StratumScroll.direction], else [scrollDirection], while fill, border,
  /// radius, and shadow stay in place. Null does not scroll.
  final StratumScroll? scroll;

  static const _interactionAnimation = AnimationStyle(
    duration: Duration(milliseconds: 100),
  );

  @nonVirtual
  @override
  Widget build(BuildContext context) {
    var current = _isBare ? _buildBare(context) : _buildBox(context);
    if (repaintBoundary) current = RepaintBoundary(child: current);
    if (debug) current = WidgetPerformanceMonitor(child: current);
    if (keepAlive) current = _KeepAlive(child: current);
    return current;
  }

  /// The layout's own content: a Column, Row, Stack, Wrap, or child.
  @protected
  Widget buildContent(BuildContext context);

  /// The axis that [scroll] scrolls along when [StratumScroll.direction]
  /// is null.
  @protected
  Axis get scrollDirection => Axis.vertical;

  bool get _isBare =>
      style == null &&
      ratio == null &&
      rotate == null &&
      transform == null &&
      interaction == null &&
      scroll == null;

  Widget _buildBare(BuildContext context) {
    final content = buildContent(context);
    final properties = semantics;
    if (properties == null) return content;
    return Semantics.fromProperties(properties: properties, child: content);
  }

  Widget _buildBox(BuildContext context) {
    final style = _effectiveStyle;
    final aspect = ratio;
    final duration = style?.animationStyle?.duration ?? Duration.zero;
    final scroll = this.scroll;
    Widget current = AnimatedStyledBox(
      style: style,
      ratio: aspect != null && aspect > 0 ? aspect : null,
      transform: transform,
      transformAlignment: transformAlignment,
      onEnd: duration > Duration.zero ? onEndAnimate : null,
      boxBuilder: _boxBuilder,
      scrollBuilder: scroll == null
          ? null
          : (content) => _buildScroll(scroll, content),
      child: buildContent(context),
    );
    final degrees = rotate;
    if (degrees != null) {
      current = Transform.rotate(
        angle: degrees * math.pi / 180,
        child: current,
      );
    }
    return current;
  }

  /// The style, with a 100 ms animation when an interaction is set and the
  /// style has no animation of its own.
  WidgetStyle? get _effectiveStyle {
    final style = this.style;
    if (style == null || interaction == null) return style;
    if (style.animationStyle != null) return style;
    return style.copyWith(animationStyle: _interactionAnimation);
  }

  StyledBoxBuilder? get _boxBuilder {
    final interaction = this.interaction;
    if (interaction != null && _needsTapSurface(interaction)) {
      return (style, box) => _buildInkWell(interaction, style, box);
    }
    if (semantics != null) return _buildSemantics;
    return null;
  }

  static bool _needsTapSurface(StratumInteraction interaction) =>
      interaction.onTap != null ||
      interaction.onDoubleTap != null ||
      interaction.onLongPress != null ||
      interaction.onSecondaryTap != null ||
      interaction.onHover != null ||
      interaction.onHighlightChanged != null ||
      interaction.onFocusChange != null;

  Widget _buildSemantics(WidgetStyle style, Widget box) {
    return Semantics.fromProperties(properties: semantics!, child: box);
  }

  Widget _buildInkWell(
    StratumInteraction interaction,
    WidgetStyle style,
    Widget box,
  ) {
    return StratumInkWell(
      borderRadius: style.borderRadius,
      onTap: interaction.onTap,
      onDoubleTap: interaction.onDoubleTap,
      onLongPress: interaction.onLongPress,
      onSecondaryTap: interaction.onSecondaryTap,
      onHover: interaction.onHover,
      onHighlightChanged: interaction.onHighlightChanged,
      mouseCursor: interaction.mouseCursor,
      enableFeedback: interaction.enableFeedback,
      disabledPressAnimation: interaction.disabledPressAnimation,
      focusNode: interaction.focusNode,
      focusType: interaction.focusType,
      showFocusOnPrimary: interaction.showFocusOnPrimary,
      canRequestFocus: interaction.canRequestFocus,
      autofocus: interaction.autofocus,
      onFocusChange: interaction.onFocusChange,
      disabled: interaction.disabled,
      statesController: interaction.statesController,
      excludeFromSemantics: interaction.excludeFromSemantics,
      semantics: semantics,
      child: box,
    );
  }

  /// Scrolls [content] (the padding and the layout's content) inside the
  /// box, as [scroll] says.
  Widget _buildScroll(StratumScroll scroll, Widget content) {
    return ScrollFrame(
      showScrollbar: scroll.showScrollbar,
      child: _BoxScrollView(
        scroll: scroll,
        axis: scroll.direction ?? scrollDirection,
        child: content,
      ),
    );
  }
}

/// The [SingleChildScrollView] of a scrolling box layout.
///
/// With [StratumScroll.fillViewport], content shorter than a finite
/// viewport stretches to it through a [LayoutBuilder]; in a parent that is
/// unbounded along [axis] the content keeps its own size (D17).
class _BoxScrollView extends StatelessWidget {
  const new({required this.scroll, required this.axis, required this.child});

  final StratumScroll scroll;
  final Axis axis;
  final Widget child;

  Widget _view(Widget content) {
    return SingleChildScrollView(
      scrollDirection: axis,
      reverse: scroll.reverse,
      controller: scroll.controller,
      primary: scroll.primary,
      physics: scroll.physics,
      keyboardDismissBehavior: scroll.keyboardDismissBehavior,
      restorationId: scroll.restorationId,
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!scroll.fillViewport) return _view(child);
    return LayoutBuilder(
      builder: (context, constraints) {
        final extent = axis == Axis.vertical
            ? constraints.maxHeight
            : constraints.maxWidth;
        final min = extent.isFinite ? extent : 0.0;
        return _view(
          ConstrainedBox(
            constraints: axis == Axis.vertical
                ? BoxConstraints(minHeight: min)
                : BoxConstraints(minWidth: min),
            child: child,
          ),
        );
      },
    );
  }
}

/// Keeps [child] alive inside a lazy list; does nothing elsewhere.
class _KeepAlive extends StatefulWidget {
  const new({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
