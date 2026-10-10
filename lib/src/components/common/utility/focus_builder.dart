import 'package:stratum_ui/src/components/common/base/disabled.dart'
    show StratumDisabledScope;
import 'package:stratum_ui/src/src.dart';

/// Builds [builder] from whether focus sits on any node inside the widget
/// it builds, a pointer's focus included, as the web's `:focus-within`
/// reads.
///
/// It only observes: it adds no Tab stop, focus ring, tap handling,
/// cursor, or size, so the wrapped widgets keep their own Tab order and
/// keys; for a Tab stop, a ring, or taps, use
/// `ContainerLayout(interaction:)`. [builder] runs, and [onFocusChange]
/// reports, only when `focused` changes: focus entering or leaving the
/// subtree, never a move between nodes inside it. Inside a disabled
/// component `focused` stays false and [onFocusChange] is not called.
///
/// `focused` differs on purpose from `InteractionState.focused`, which is
/// true only while a tap surface shows its focus ring.
///
/// No state may show by color alone: pair a focus color with text, an
/// icon, or a shape (WCAG 1.4.1).
class FocusBuilder extends StatefulWidget {
  const new({
    super.key,
    required this.builder,
    this.child,
    this.onFocusChange,
    this.semantics,
  });

  /// Builds the look from `focused`; [child] reaches it unrebuilt.
  final ValueWidgetBuilder<bool> builder;

  /// A subtree that does not depend on `focused`, handed to [builder] on
  /// every call.
  final Widget? child;

  /// Called with true when focus enters the subtree and false when it
  /// leaves it, never on a move between nodes inside it.
  final ValueChanged<bool>? onFocusChange;

  /// The group's semantics, with the name and type of
  /// `BoxLayout.semantics`: null adds no node; set, one container node of
  /// its own around the wrapped widgets, read before the nodes inside.
  final SemanticsProperties? semantics;

  @override
  State<FocusBuilder> createState() => _FocusBuilderState();
}

class _FocusBuilderState extends State<FocusBuilder> {
  // Takes no focus and skips traversal, so it adds no Tab stop, while its
  // `hasFocus` still counts focus on any node below it.
  final FocusNode _node = FocusNode(
    debugLabel: 'FocusBuilder',
    canRequestFocus: false,
    skipTraversal: true,
  );

  bool _disabled = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(_handleFocus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A disabled flip reads the new value and calls no listener (US-16
    // FR-05 E03).
    _disabled = StratumDisabledScope.of(context);
    _focused = _node.hasFocus && !_disabled;
  }

  @override
  void dispose() {
    _node
      ..removeListener(_handleFocus)
      ..dispose();
    super.dispose();
  }

  void _handleFocus() {
    final focused = _node.hasFocus && !_disabled;
    if (focused == _focused) return;
    setState(() => _focused = focused);
    widget.onFocusChange?.call(focused);
  }

  @override
  Widget build(BuildContext context) {
    final semantics = widget.semantics;
    final result = Focus(
      focusNode: _node,
      includeSemantics: false,
      child: widget.builder(context, _focused, widget.child),
    );
    // Always built as the same widget type, so toggling [semantics] null
    // <-> a value keeps the wrapped subtree mounted instead of remounting
    // it (Minor 2); `container: false` with no properties set still adds
    // no semantics node (US-16 FR-04 E02 stays green).
    return Semantics.fromProperties(
      container: semantics != null,
      properties: semantics ?? const SemanticsProperties(),
      child: result,
    );
  }
}
