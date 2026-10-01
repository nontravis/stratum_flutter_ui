import 'dart:math' as math;

import 'package:stratum_ui/src/components/common/layout/scroll_frame.dart';
import 'package:stratum_ui/src/src.dart';

/// The base of the box layouts: one build pipeline for style, transforms,
/// interaction, semantics, and scrolling.
///
/// A subclass declares its own parameters and overrides [buildContent].
/// When [style], [ratio], [rotate], [transform], and [interaction] are null
/// and [scrollable] is false, the layout builds the bare tier: the content
/// with only the [semantics], [repaintBoundary], [debug], and [keepAlive]
/// wrappers, and no [AnimatedStyledBox]. Otherwise it builds the box tier
/// around an [AnimatedStyledBox].
///
/// The tier depends on whether a parameter is null, never on its content.
/// Switching a parameter between null and a value remounts the content, so
/// pass `const WidgetStyle()` or `const StratumInteraction()` up front when a
/// value can appear later.
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
    this.scrollable = false,
  });

  /// Every visual value of the box: spacing, size, fill, border, shadows,
  /// blur, opacity, and animation.
  final WidgetStyle? style;

  /// Width divided by height for the content; ignored unless greater
  /// than 0.
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
  /// [scrollDirection], while fill, border, radius, and shadow stay in
  /// place.
  final bool scrollable;

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

  /// The axis that [scrollable] scrolls along.
  @protected
  Axis get scrollDirection => Axis.vertical;

  bool get _isBare =>
      style == null &&
      ratio == null &&
      rotate == null &&
      transform == null &&
      interaction == null &&
      !scrollable;

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
    Widget current = AnimatedStyledBox(
      style: style,
      ratio: aspect != null && aspect > 0 ? aspect : null,
      transform: transform,
      transformAlignment: transformAlignment,
      onEnd: duration > Duration.zero ? onEndAnimate : null,
      boxBuilder: _boxBuilder,
      scrollBuilder: scrollable ? _buildScroll : null,
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

  /// Scrolls [content], the padding and the layout's content, inside the
  /// box along [scrollDirection].
  Widget _buildScroll(Widget content) {
    return ScrollFrame(
      child: SingleChildScrollView(
        scrollDirection: scrollDirection,
        child: content,
      ),
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
