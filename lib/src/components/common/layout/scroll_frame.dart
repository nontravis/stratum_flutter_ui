import 'package:stratum_ui/src/src.dart';

/// The scroll behavior for a layout scroll view at [context].
///
/// Starts from the theme's `scrollBehavior` with the theme's `physics` when
/// a [StratumThemeApplication] is above [context]. Without a theme it
/// starts from the [ScrollConfiguration] above the outermost [ScrollFrame],
/// so an outer frame's choices never reach an inner one. A null
/// [scrollbars] keeps the behavior's own choice, which shows a scrollbar on
/// desktop. A scroll view's own `physics` parameter applies on top of the
/// result.
ScrollBehavior resolveScrollBehavior(
  BuildContext context, {
  bool? scrollbars,
}) {
  final theme = StratumThemeApplication.maybeOf(context);
  final behavior =
      theme?.scrollBehavior ??
      _ScrollFrameScope.maybeBaseOf(context) ??
      ScrollConfiguration.of(context);
  return behavior.copyWith(physics: theme?.physics, scrollbars: scrollbars);
}

/// Applies [resolveScrollBehavior] to the scroll view in [child].
///
/// The behavior also reaches Flutter scroll views inside the items. Layout
/// scroll views among them resolve their own behavior, from the theme or
/// from the configuration above the outermost frame.
class ScrollFrame extends StatelessWidget {
  const new({super.key, this.showScrollbar, required this.child});

  /// Null keeps the behavior's choice: a scrollbar on desktop.
  final bool? showScrollbar;
  final Widget child;

  /// The style of the box around a viewport.
  ///
  /// The padding moves into the scroll view so it scrolls with the
  /// content, and a rounded box clips the viewport to its corners unless
  /// the style sets its own `clipBehavior`.
  static WidgetStyle boxStyle(WidgetStyle style) {
    return style.copyWith(
      padding: null,
      clipBehavior:
          style.clipBehavior ??
          (style.borderRadius == null ? null : Clip.antiAlias),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ScrollFrameScope(
      base:
          _ScrollFrameScope.maybeBaseOf(context) ??
          ScrollConfiguration.of(context),
      child: ScrollConfiguration(
        behavior: resolveScrollBehavior(context, scrollbars: showScrollbar),
        child: child,
      ),
    );
  }
}

/// Carries the [ScrollConfiguration] that was above the outermost
/// [ScrollFrame] down to the frames nested inside it.
class _ScrollFrameScope extends InheritedWidget {
  const new({required this.base, required super.child});

  final ScrollBehavior base;

  static ScrollBehavior? maybeBaseOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ScrollFrameScope>()
        ?.base;
  }

  @override
  bool updateShouldNotify(_ScrollFrameScope oldWidget) =>
      base != oldWidget.base;
}

/// Whether a scroll view takes keyboard focus when its `focusable` is null:
/// on web, mobile web included, and on desktop. Every scroller is then a
/// Tab stop, as in Firefox.
bool defaultScrollFocusable({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  return isWeb ||
      const {
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      }.contains(platform);
}

/// Keyboard scrolling for one scroll view (K4): the focus node, the keys,
/// and the focus ring.
///
/// Sits outside the box's clip, so the ring, which paints outside the box,
/// stays visible: around the box of a scroll view, and in `boxBuilder` for
/// a box layout with `scroll`. With [ownsFocus] false it wraps a tap
/// surface, creates no node, and acts on keys that bubble up from the
/// surface's node.
///
/// While the viewport node holds focus, the arrows along [axis] scroll
/// 50 px, Page Up and Page Down scroll 0.8 of the viewport, and Home and
/// End jump to the first and last item. While an item inside holds focus,
/// the arrows keep Flutter's default, and Page Up, Page Down, Home, and
/// End still scroll. No key acts while focus is inside a text field.
///
/// The scroll view reads its controller through [controllerOf]: the
/// caller's [controller]; else none when it inherits the
/// [PrimaryScrollController], which the keys then use; else, when
/// [focusable], an internal one.
class ScrollFocus extends StatefulWidget {
  const new({
    super.key,
    required this.focusable,
    required this.axis,
    this.controller,
    this.primary,
    this.semanticsLabel,
    this.borderRadius,
    this.ownsFocus = true,
    required this.child,
  });

  /// Whether the viewport takes focus and handles keys; false passes
  /// [child] through.
  final bool focusable;

  /// The scroll axis the arrows act along.
  final Axis axis;
  final ScrollController? controller;
  final bool? primary;

  /// Names the viewport node that a screen reader announces on focus.
  final String? semanticsLabel;

  /// Shape of the focus ring.
  final BorderRadiusGeometry? borderRadius;

  /// Whether this widget owns the viewport node; false when it wraps a tap
  /// surface whose node takes focus instead.
  final bool ownsFocus;
  final Widget child;

  /// The controller that the scroll view below the nearest [ScrollFocus]
  /// passes on; null lets it inherit the [PrimaryScrollController] or make
  /// its own.
  static ScrollController? controllerOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ScrollFocusScope>()
        ?.controller;
  }

  @override
  State<ScrollFocus> createState() => _ScrollFocusState();
}

class _ScrollFocusState extends State<ScrollFocus> {
  // Created on first use and kept until dispose, as StratumInkWell keeps
  // its node.
  FocusNode? _node;
  ScrollController? _internalController;

  FocusNode get _focusNode =>
      _node ??= FocusNode(debugLabel: 'ScrollFocus')
        ..addListener(_handleFocusChange);

  /// Whether the scroll view attaches to the [PrimaryScrollController], by
  /// the rule of `ScrollView` and `SingleChildScrollView`.
  bool get _inheritsPrimary =>
      widget.primary ??
      (widget.controller == null &&
          PrimaryScrollController.shouldInherit(context, widget.axis));

  /// The controller handed to the scroll view.
  ScrollController? get _viewController {
    final controller = widget.controller;
    if (controller != null) return controller;
    if (!widget.focusable || _inheritsPrimary) return null;
    return _internalController ??= ScrollController();
  }

  /// The controller the keys scroll through.
  ScrollController? get _keyController {
    final view = _viewController;
    if (view != null) return view;
    return _inheritsPrimary ? PrimaryScrollController.maybeOf(context) : null;
  }

  bool get _ringVisible =>
      _focusNode.hasPrimaryFocus &&
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_handleHighlightMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_handleHighlightMode);
    _node?.dispose();
    _internalController?.dispose();
    super.dispose();
  }

  void _handleFocusChange() => setState(() {});

  void _handleHighlightMode(FocusHighlightMode mode) {
    if (_node?.hasPrimaryFocus ?? false) setState(() {});
  }

  /// Whether the viewport itself holds focus: the own node, or the tap
  /// surface's node, which no focusable node separates from [handler].
  bool _viewportFocused(FocusNode handler) {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return false;
    if (primary == handler) return true;
    if (widget.ownsFocus) return false;
    for (final ancestor in primary.ancestors) {
      if (ancestor == handler) return true;
      if (ancestor.canRequestFocus && !ancestor.skipTraversal) return false;
    }
    return false;
  }

  KeyEventResult _handleKey(FocusNode handler, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        primaryFocusInEditableText()) {
      return KeyEventResult.ignored;
    }
    final controller = _keyController;
    if (controller == null || controller.positions.length != 1) {
      return KeyEventResult.ignored;
    }
    final position = controller.position;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.home) {
      position.jumpTo(position.minScrollExtent);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      _jumpToEnd(controller, position, 3);
      return KeyEventResult.handled;
    }
    final vertical = position.axis == Axis.vertical;
    final page =
        key == LogicalKeyboardKey.pageUp || key == LogicalKeyboardKey.pageDown;
    final AxisDirection? direction;
    if (key == LogicalKeyboardKey.pageUp) {
      direction = vertical ? AxisDirection.up : AxisDirection.left;
    } else if (key == LogicalKeyboardKey.pageDown) {
      direction = vertical ? AxisDirection.down : AxisDirection.right;
    } else if (!_viewportFocused(handler)) {
      direction = null;
    } else {
      direction = switch (key) {
        LogicalKeyboardKey.arrowUp => AxisDirection.up,
        LogicalKeyboardKey.arrowDown => AxisDirection.down,
        LogicalKeyboardKey.arrowLeft => AxisDirection.left,
        LogicalKeyboardKey.arrowRight => AxisDirection.right,
        _ => null,
      };
    }
    if (direction == null || axisDirectionToAxis(direction) != position.axis) {
      return KeyEventResult.ignored;
    }
    // The amounts of Flutter's ScrollAction: a line is 50 px and a page is
    // 0.8 of the viewport.
    final amount = page ? 0.8 * position.viewportDimension : 50.0;
    final delta = direction == position.axisDirection ? amount : -amount;
    position.moveTo(
      position.pixels + delta,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeInOut,
    );
    return KeyEventResult.handled;
  }

  /// Jumps to the end. A lazy list only estimates its extent, so it jumps
  /// again after each frame until the extent stops changing, at most
  /// [retries] more times.
  void _jumpToEnd(
    ScrollController controller,
    ScrollPosition position,
    int retries,
  ) {
    final extent = position.maxScrollExtent;
    position.jumpTo(extent);
    if (retries == 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.positions.contains(position)) return;
      if (position.maxScrollExtent != extent) {
        _jumpToEnd(controller, position, retries - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget result = _ScrollFocusScope(
      controller: _viewController,
      child: widget.child,
    );
    if (!widget.focusable) return result;
    if (!widget.ownsFocus) {
      return Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: _handleKey,
        child: result,
      );
    }
    result = Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      child: result,
    );
    // FocusSpread reads the theme; without one the viewport has no ring.
    if (StratumThemeApplication.maybeOf(context) != null) {
      result = FocusSpread(
        focus: _ringVisible,
        borderRadius: widget.borderRadius,
        child: result,
      );
    }
    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      child: result,
    );
  }
}

/// Hands [ScrollFocus]'s controller to the scroll view below it.
class _ScrollFocusScope extends InheritedWidget {
  const new({required this.controller, required super.child});

  final ScrollController? controller;

  @override
  bool updateShouldNotify(_ScrollFocusScope oldWidget) =>
      controller != oldWidget.controller;
}
