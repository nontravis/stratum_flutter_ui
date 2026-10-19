import 'package:stratum_ui/src/components/common/ink_well.dart'
    show interactionNeedsTapSurface, tapSurfaceStateOf;
import 'package:stratum_ui/src/src.dart';

/// A box that paints a [WidgetStyle] around [child], or around the content
/// [builder] builds from the box's [InteractionState].
///
/// Every visual value (spacing, size, fill, border, shadows, blur, opacity,
/// and animation) comes from `style`, which [AnimatedStyledBox] builds and
/// animates. The other parameters come from [BoxLayout] and cover what a
/// style cannot: per-instance layout, interaction, behavior, and
/// accessibility.
class ContainerLayout extends BoxLayout {
  const new({
    super.key,
    super.style,
    super.ratio,
    super.rotate,
    super.transform,
    super.transformAlignment,
    super.keepAlive,
    super.repaintBoundary,
    super.semantics,
    super.onEndAnimate,
    super.interaction,
    super.scroll,
    this.fit,
    this.child,
    this.builder,
  }) : assert(
         fit == null || scroll == null,
         'fit needs a box with an extent to fit into; a scrolling box has '
         'none along its scroll axis',
       ),
       assert(
         child == null || builder == null,
         'Cannot provide both a child and a builder.\n'
         'Pass child for content that does not follow the interaction '
         'state, or builder to build it from the state; not both.',
       );

  /// Scales the content, [child] or what [builder] builds, into the box's
  /// padded area through [FittedBox].
  ///
  /// `style.alignment` becomes [FittedBox.alignment], centered when null,
  /// and builds no [Align], so the padded area's constraints reach the
  /// [FittedBox] unchanged and [BoxFit.cover] and [BoxFit.fill] reach the
  /// edges of a box with a fixed size. A change of `style.alignment` takes
  /// effect at once. The [FittedBox] does not clip: set
  /// `style.clipBehavior` to crop a [BoxFit.cover] child at the box edge,
  /// with its `borderRadius`. Null builds no [FittedBox].
  final BoxFit? fit;
  final Widget? child;

  /// Builds the content from the box's [InteractionState], in place of
  /// [child] and where [child] sits: under [fit] and `style.alignment`.
  ///
  /// The state comes from the tap surface the box builds for [interaction]:
  /// [builder] runs again when `hovered`, `pressed`, `focused`, or
  /// `disabled` changes, never on a pointer move that changes none. With no
  /// [interaction], or one that builds no tap surface, every value is false
  /// and [builder] adds no tap surface. Pass [child] or [builder], not both.
  ///
  /// No state may show by color alone: pair a state color with text, an
  /// icon, or a shape (WCAG 1.4.1).
  final Widget Function(BuildContext context, InteractionState state)? builder;

  @override
  bool get alignsContent => fit == null;

  @override
  Widget buildContent(BuildContext context) {
    final builder = this.builder;
    final interaction = this.interaction;
    final content = builder == null
        ? child ?? const SizedBox.shrink()
        : _StateContent(
            builder: builder,
            hasTapSurface:
                interaction != null && interactionNeedsTapSurface(interaction),
          );
    final fit = this.fit;
    if (fit == null) return content;
    return FittedBox(
      fit: fit,
      alignment: style?.alignment ?? Alignment.center,
      child: content,
    );
  }
}

/// The content [ContainerLayout.builder] builds, below the box's tap
/// surface, so it reads that surface's state.
class _StateContent extends StatelessWidget {
  const new({required this.builder, required this.hasTapSurface});

  final Widget Function(BuildContext context, InteractionState state) builder;

  /// Whether the box builds a tap surface. Without one every value is
  /// false, and no surface farther up is read (US-17 FR-04).
  final bool hasTapSurface;

  @override
  Widget build(BuildContext context) {
    final state = hasTapSurface ? tapSurfaceStateOf(context) : null;
    return builder(context, state ?? const InteractionState());
  }
}
