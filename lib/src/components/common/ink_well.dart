import 'package:flutter/rendering.dart' show RenderSemanticsAnnotations;
import 'package:stratum_ui/src/components/common/base/disabled.dart'
    show StratumDisabledScope;
import 'package:stratum_ui/src/components/common/l10n/built_in_labels.dart';
import 'package:stratum_ui/src/src.dart';

/// Whether a [StratumInkWell] with these settings takes focus: not
/// [disabled], [canRequestFocus] true, a [focusType] other than
/// [FocusType.none], and an activation callback ([onTap], [onDoubleTap],
/// [onLongPress], [onSecondaryTap]) or a non-empty [shortcuts] map.
///
/// The one tap-surface focus rule: [StratumInkWell] follows it, and a
/// scrolling `BoxLayout` gives up its own Tab stop exactly when it holds.
/// Not exported: `common/common.dart` hides it, and `box_layout.dart`
/// imports this file by path.
bool tapSurfaceTakesFocus({
  required bool disabled,
  required bool canRequestFocus,
  required FocusType focusType,
  required GestureTapCallback? onTap,
  required GestureTapCallback? onDoubleTap,
  required GestureLongPressCallback? onLongPress,
  required GestureTapCallback? onSecondaryTap,
  required Map<ShortcutActivator, VoidCallback> shortcuts,
}) {
  return !disabled &&
      canRequestFocus &&
      focusType != FocusType.none &&
      (onTap != null ||
          onDoubleTap != null ||
          onLongPress != null ||
          onSecondaryTap != null ||
          shortcuts.isNotEmpty);
}

/// The heading level of the node that holds a [StratumInkWell]'s button
/// node, or null when the surface builds no heading node.
///
/// On web the engine renders a header node with a label, or any node with
/// a heading level, as a heading with no tap behaviour, so the surface
/// splits: a heading node at this level holds the button node. That
/// happens exactly when [isWeb] holds, the surface builds its node
/// ([excludeFromSemantics] false), the node reads as a button ([semantics]
/// sets `button: true`, or [hasActivation] holds and [semantics] sets no
/// role-bearing field), and [semantics] sets `header: true` or a
/// `headingLevel`. The level is that `headingLevel`, else 2, the level the
/// engine gives a header.
///
/// Takes [isWeb] as a parameter, as `defaultScrollFocusable` does, so a
/// Dart VM test covers both sides. Not exported: `common/common.dart`
/// hides it.
int? tapSurfaceHeadingLevel({
  required bool isWeb,
  required bool hasActivation,
  required bool excludeFromSemantics,
  required SemanticsProperties? semantics,
}) {
  if (!isWeb || excludeFromSemantics || semantics == null) return null;
  final readsAsButton =
      semantics.button ?? (hasActivation && !_setsRole(semantics));
  if (!readsAsButton) return null;
  final level = semantics.headingLevel;
  if (level != null) return level;
  return semantics.header == true ? 2 : null;
}

/// A [Semantics.fromProperties] whose node carries every field of
/// [properties] but `header` and `headingLevel`.
///
/// [StratumInkWell] builds the caller's node through it when
/// [tapSurfaceHeadingLevel] gives a level, so that on web the button node
/// under the heading node renders as a button. Not exported:
/// `common/common.dart` hides it.
Widget semanticsWithoutHeading({
  required SemanticsProperties properties,
  required Widget child,
}) => _SemanticsWithoutHeading(properties: properties, child: child);

/// The tap surface of the design system.
///
/// Builds on [InkWell] for gestures, keyboard activation, focus, and hover,
/// and adds what [InkWell] leaves out:
///
/// * a flat overlay over [child]: the theme's `state.hover` color while
///   hovered and `state.press` while pressed;
/// * a [StratumFocusBorder] ring in its outside style, shown per
///   [focusType];
/// * a semantics node with a button role and a disabled flag;
/// * the context-menu key and Shift+F10 for [onSecondaryTap], and a custom
///   semantics action for it, so keyboard and screen-reader users reach
///   the secondary tap (K1);
/// * focus-scoped [shortcuts] (K2); adding or clearing them, or
///   [onSecondaryTap], keeps [child]'s State and focus;
/// * a keep-alive while it has focus, so a lazy list never disposes the
///   focused item.
///
/// Primitives name callbacks after the gesture ([onTap]); components built
/// on this widget name theirs after the intent (`onPressed`).
class StratumInkWell extends StatefulWidget {
  const new({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.onHover,
    this.onHighlightChanged,
    this.disabled = false,
    this.statesController,
    this.borderRadius,
    this.disabledPressAnimation = false,
    this.mouseCursor,
    this.focusNode,
    this.focusType = FocusType.focusedVisible,
    this.showFocusOnPrimary = true,
    this.canRequestFocus = true,
    this.autofocus = false,
    this.onFocusChange,
    this.semantics,
    this.excludeFromSemantics = false,
    this.enableFeedback = true,
    this.secondaryTapSemanticsLabel,
    this.shortcuts = const {},
  });

  final Widget child;
  final GestureTapCallback? onTap;

  /// Has no keyboard or screen-reader path; never make a function
  /// reachable only by double tap (WCAG 2.1.1). Bind a key in [shortcuts]
  /// as its keyboard alternative.
  final GestureTapCallback? onDoubleTap;
  final GestureLongPressCallback? onLongPress;

  /// Also called by the context-menu key and Shift+F10 while this widget
  /// has focus, and by a custom semantics action labeled
  /// [secondaryTapSemanticsLabel].
  final GestureTapCallback? onSecondaryTap;

  /// Called with true when a pointer enters and false when it leaves, also
  /// when no activation callback is set.
  final ValueChanged<bool>? onHover;
  final ValueChanged<bool>? onHighlightChanged;

  /// Turns off every callback, the overlay, the ring, and focus; semantics
  /// then report a disabled button unless [semantics] sets `enabled`.
  ///
  /// Inside a disabled component the surface acts as if this were true, and
  /// a press already down on it is cancelled at the flip (FR-02 E10).
  final bool disabled;

  /// Receives the interaction states from [InkWell] and drives the overlay.
  ///
  /// A controller that starts with a state, for example
  /// `{WidgetState.hovered}`, shows that state without a pointer, as long as
  /// an activation callback is set and [disabled] is false. Otherwise
  /// [InkWell] marks the controller disabled and the overlay stays idle.
  final WidgetStatesController? statesController;

  /// Shape of the overlay and the focus ring.
  final BorderRadiusGeometry? borderRadius;

  /// Turns off the hover and press overlay.
  final bool disabledPressAnimation;
  final MouseCursor? mouseCursor;
  final FocusNode? focusNode;

  /// Whether this widget takes focus, when it shows the ring, and whether
  /// a tap requests focus ([FocusType.focused] only).
  final FocusType focusType;

  /// Shows the ring only while this widget holds primary focus.
  final bool showFocusOnPrimary;
  final bool canRequestFocus;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;

  /// The caller's semantics. A set `button`, true or false, decides the
  /// role; a set `link`, `textField`, `slider`, `keyboardKey`, `checked`,
  /// `mixed`, `toggled`, or a `role` other than [SemanticsRole.none]
  /// removes the default button role; any other field, such as a label,
  /// `header`, or `image`, keeps it. A set `enabled` decides the enabled
  /// flag; otherwise, with an activation callback, [disabled] does.
  /// `container` is still set. Applies also when [excludeFromSemantics] is
  /// true.
  ///
  /// On web, a node that reads as a button with `header` or `headingLevel`
  /// becomes a heading node at that level, default 2, holding the button
  /// node; native keeps one node (FR-02 E07, E09).
  final SemanticsProperties? semantics;
  final bool excludeFromSemantics;

  /// Plays the platform click and long-press feedback.
  final bool enableFeedback;

  /// Label of the semantics action for [onSecondaryTap]; null uses
  /// `MaterialLocalizations.showMenuTooltip` when material localizations
  /// are present, else Stratum's built-in show menu label in the locale's
  /// language when the built-in labels hold it (English and Thai), else in
  /// English.
  final String? secondaryTapSemanticsLabel;

  /// Key bindings that fire while this widget or a descendant has focus,
  /// never while [disabled]. A binding without a control, meta, or alt
  /// modifier is skipped while focus is inside a text field, so typing
  /// still reaches the field (WCAG 2.1.4). With no activation callback the
  /// focus node moves to an outer [Focus], because [InkWell] grants focus
  /// only to an enabled surface; the node then reports focusable and no
  /// button role. An empty map builds nothing.
  final Map<ShortcutActivator, VoidCallback> shortcuts;

  @override
  State<StratumInkWell> createState() => _StratumInkWellState();
}

class _StratumInkWellState extends State<StratumInkWell>
    with AutomaticKeepAliveClientMixin<StratumInkWell> {
  /// The keys that open a context menu (K1).
  static const _contextMenuKeys = [
    SingleActivator(LogicalKeyboardKey.contextMenu),
    SingleActivator(LogicalKeyboardKey.f10, shift: true),
  ];

  // Created on first use and kept until dispose, as TextField does, so a
  // node that InkWell's Focus still holds is never disposed mid-update.
  FocusNode? _internalFocusNode;
  WidgetStatesController? _internalStatesController;

  // InkWell's node while the outer Focus holds the surface's node, owned
  // here and kept until dispose like _internalFocusNode. Passing InkWell
  // null instead would let its Focus keep a listener on its own node across
  // each null-to-node swap, one more per shortcut toggle.
  FocusNode? _inkFocusNode;

  // The Focus and CallbackShortcuts above Material come and go with the
  // shortcuts and callbacks. The GlobalKey makes Flutter move Material's
  // element instead of rebuilding it, so InkWell and the child keep their
  // State.
  final GlobalKey _surfaceKey = GlobalKey(debugLabel: 'StratumInkWell.surface');

  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  WidgetStatesController get _statesController =>
      widget.statesController ??
      (_internalStatesController ??= WidgetStatesController());

  /// [StratumInkWell.disabled], or inside a disabled component. A flip of
  /// the scope rebuilds the surface, and [InkWell] then disposes the
  /// recognizers of a press already down (FR-02 E10).
  bool get _disabled => widget.disabled || StratumDisabledScope.of(context);

  bool get _hasActivation => _activates(widget);

  bool get _shortcutOnly => _isShortcutOnly(widget);

  static bool _activates(StratumInkWell surface) =>
      surface.onTap != null ||
      surface.onDoubleTap != null ||
      surface.onLongPress != null ||
      surface.onSecondaryTap != null;

  /// Whether [surface]'s focus node sits on an outer [Focus] instead of
  /// [InkWell]: shortcuts with no activation callback (K2).
  static bool _isShortcutOnly(StratumInkWell surface) =>
      !_activates(surface) && surface.shortcuts.isNotEmpty;

  /// Keeps a focused item alive in a lazy list, also in touch highlight
  /// mode and for a shortcut-only node, where [InkWell] builds no focus
  /// highlight that would keep it alive (D16).
  @override
  bool get wantKeepAlive => _focusNode.hasFocus;

  bool get _canFocus => tapSurfaceTakesFocus(
    disabled: _disabled,
    canRequestFocus: widget.canRequestFocus,
    focusType: widget.focusType,
    onTap: widget.onTap,
    onDoubleTap: widget.onDoubleTap,
    onLongPress: widget.onLongPress,
    onSecondaryTap: widget.onSecondaryTap,
    shortcuts: widget.shortcuts,
  );

  /// Whether [StratumInkWell.autofocus] may request focus: not [_disabled],
  /// a [StratumInkWell.focusType] other than [FocusType.none], and
  /// [StratumInkWell.canRequestFocus] true. Looser than [_canFocus]: it
  /// skips the activation-callback check, because a directional
  /// [NavigationMode] honors autofocus on its own, ignoring that check
  /// either way (`material/ink_well.dart:1292-1311`, `:1333-1336`).
  bool get _autofocusEligible =>
      !_disabled &&
      widget.focusType != FocusType.none &&
      widget.canRequestFocus;

  bool get _hasRing =>
      widget.focusType == FocusType.focused ||
      widget.focusType == FocusType.focusedVisible;

  bool get _ringVisible {
    if (_disabled) return false;
    final node = _focusNode;
    final focused = widget.showFocusOnPrimary
        ? node.hasPrimaryFocus
        : node.hasFocus;
    if (!focused) return false;
    return switch (widget.focusType) {
      FocusType.focused => true,
      FocusType.focusedVisible =>
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional,
      FocusType.none || FocusType.invisible => false,
    };
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
    FocusManager.instance.addHighlightModeListener(_handleHighlightMode);
  }

  @override
  void didUpdateWidget(StratumInkWell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _internalFocusNode)?.removeListener(
        _handleFocusChange,
      );
      _focusNode.addListener(_handleFocusChange);
      updateKeepAlive();
    }
    if (_isShortcutOnly(oldWidget) && !_canFocus) _yieldFocusKeepingChild();
    if (oldWidget.statesController != null && widget.statesController == null) {
      // InkWell rewrites only `disabled` on a swap, so a hover or press the
      // internal controller held before the caller's took over is stale.
      _internalStatesController?.value = <WidgetState>{};
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_handleHighlightMode);
    _focusNode.removeListener(_handleFocusChange);
    _internalFocusNode?.dispose();
    _inkFocusNode?.dispose();
    _internalStatesController?.dispose();
    super.dispose();
  }

  /// Sets `canRequestFocus` false before the rebuild when a descendant, not
  /// the node itself, holds focus. Called when shortcut-only settings
  /// change to settings that take no focus: leaving the mode, or staying in
  /// it while disabled.
  ///
  /// Leaving the mode moves the node into [InkWell]'s [Focus], which
  /// detaches [InkWell]'s node and drops the descendant from the scope's
  /// focus history; a flip after that moves focus out of the child. Flipped
  /// first, Flutter refocuses the descendant.
  void _yieldFocusKeepingChild() {
    final node = _focusNode;
    if (node.hasFocus && !node.hasPrimaryFocus) node.canRequestFocus = false;
  }

  void _handleFocusChange() {
    updateKeepAlive();
    if (_hasRing) setState(() {});
  }

  void _handleHighlightMode(FocusHighlightMode mode) {
    if (widget.focusType == FocusType.focusedVisible && _focusNode.hasFocus) {
      setState(() {});
    }
  }

  void _handleTap() {
    if (widget.focusType == FocusType.focused) _focusNode.requestFocus();
    widget.onTap?.call();
  }

  /// The key bindings while this widget or a descendant has focus; none
  /// while disabled.
  Map<ShortcutActivator, VoidCallback> get _bindings {
    if (_disabled) return const {};
    final secondary = widget.onSecondaryTap;
    return {
      if (secondary != null)
        for (final key in _contextMenuKeys) key: secondary,
      for (final MapEntry(key: activator, value: callback)
          in widget.shortcuts.entries)
        _guarded(activator): callback,
    };
  }

  /// [activator], skipped inside a text field unless it holds a control,
  /// meta, or alt modifier (text-entry guard).
  static ShortcutActivator _guarded(ShortcutActivator activator) {
    if (_hasCommandModifier(activator)) return activator;
    return _TextEntryGuard(activator);
  }

  static final _commandKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.alt,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
  };

  static bool _hasCommandModifier(ShortcutActivator activator) {
    return switch (activator) {
      SingleActivator(:final control, :final meta, :final alt) =>
        control || meta || alt,
      CharacterActivator(:final control, :final meta, :final alt) =>
        control || meta || alt,
      LogicalKeySet(:final keys) => keys.any(_commandKeys.contains),
      _ => false,
    };
  }

  String _secondaryTapLabel(BuildContext context) {
    return widget.secondaryTapSemanticsLabel ??
        Localizations.of<MaterialLocalizations>(
          context,
          MaterialLocalizations,
        )?.showMenuTooltip ??
        builtInLabelsOf(context).showMenuLabel;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = context.theme.color;
    final disabled = _disabled;
    final canFocus = _canFocus;
    final onHover = widget.onHover;
    final shortcutOnly = _shortcutOnly;

    Widget result = InkWell(
      onTap: disabled || widget.onTap == null ? null : _handleTap,
      onDoubleTap: disabled ? null : widget.onDoubleTap,
      onLongPress: disabled ? null : widget.onLongPress,
      onSecondaryTap: disabled ? null : widget.onSecondaryTap,
      onHighlightChanged: disabled ? null : widget.onHighlightChanged,
      onFocusChange: shortcutOnly ? null : widget.onFocusChange,
      mouseCursor:
          widget.mouseCursor ??
          (disabled ? SystemMouseCursors.forbidden : null),
      focusNode: shortcutOnly
          ? (_inkFocusNode ??= FocusNode(debugLabel: 'StratumInkWell.ink'))
          : _focusNode,
      canRequestFocus: !shortcutOnly && canFocus,
      autofocus: !shortcutOnly && widget.autofocus && _autofocusEligible,
      statesController: _statesController,
      enableFeedback: widget.enableFeedback,
      excludeFromSemantics: widget.excludeFromSemantics,
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      child: _StateOverlay(
        states: _statesController,
        hoverColor: colors.state.hover,
        pressedColor: colors.state.press,
        enabled: !disabled && !widget.disabledPressAnimation,
        borderRadius: widget.borderRadius,
        child: widget.child,
      ),
    );
    result = Material(
      key: _surfaceKey,
      type: MaterialType.transparency,
      child: result,
    );
    if (shortcutOnly) {
      // InkWell grants focus only when enabled and forces canRequestFocus
      // off on a node it receives otherwise, so the node lives here.
      result = Focus(
        focusNode: _focusNode,
        canRequestFocus: canFocus,
        autofocus: widget.autofocus && _autofocusEligible,
        onFocusChange: widget.onFocusChange,
        child: result,
      );
    }
    // Built from onSecondaryTap and shortcuts, not from disabled, so
    // toggling disabled never changes the structure below.
    if (widget.onSecondaryTap != null || widget.shortcuts.isNotEmpty) {
      result = CallbackShortcuts(bindings: _bindings, child: result);
    }
    // Always built, with null handlers when unused, so toggling onHover or
    // disabled never changes the structure below.
    final reportsHover = onHover != null && !disabled;
    result = MouseRegion(
      onEnter: reportsHover ? (_) => onHover(true) : null,
      onExit: reportsHover ? (_) => onHover(false) : null,
      child: result,
    );
    if (_hasRing) {
      result = StratumFocusBorder(
        state: _ringVisible ? FullWidgetState.focused : FullWidgetState.normal,
        borderRadius: widget.borderRadius,
        child: result,
      );
    }
    // A caller's semantics apply even with excludeFromSemantics, the usual
    // way to replace the gesture semantics with a custom label and actions.
    final properties = widget.semantics;
    final headingLevel = tapSurfaceHeadingLevel(
      isWeb: kIsWeb,
      hasActivation: _hasActivation,
      excludeFromSemantics: widget.excludeFromSemantics,
      semantics: properties,
    );
    if (properties != null) {
      result = headingLevel == null
          ? Semantics.fromProperties(properties: properties, child: result)
          : semanticsWithoutHeading(properties: properties, child: result);
    }
    if (!widget.excludeFromSemantics) {
      final hasActivation = _hasActivation;
      final secondary = widget.onSecondaryTap;
      result = Semantics(
        container: true,
        enabled: hasActivation && properties?.enabled == null
            ? !disabled
            : null,
        button: hasActivation && !_setsRole(properties) ? true : null,
        customSemanticsActions: secondary == null || disabled
            ? null
            : {
                CustomSemanticsAction(label: _secondaryTapLabel(context)):
                    secondary,
              },
        child: result,
      );
    }
    // On web the engine checks a heading role before the button role, so a
    // heading node holds the button node (FR-02 E07, E09).
    if (headingLevel != null) {
      result = Semantics(
        container: true,
        headingLevel: headingLevel,
        child: result,
      );
    }
    return result;
  }
}

/// [activator], skipped while primary focus is inside an [EditableText],
/// so the key reaches the text field's own shortcuts.
class _TextEntryGuard extends ShortcutActivator {
  const new(this.activator);

  final ShortcutActivator activator;

  @override
  Iterable<LogicalKeyboardKey>? get triggers => activator.triggers;

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    return !primaryFocusInEditableText() && activator.accepts(event, state);
  }

  @override
  String debugDescribeKeys() => activator.debugDescribeKeys();
}

/// [style]'s duration, else [Duration.zero] for a hand-built [AnimationStyle]
/// that sets none (for example [AnimationStyle.noAnimation]).
Duration _durationOf(AnimationStyle style) => style.duration ?? Duration.zero;

/// [style]'s curve, else [Curves.easeInOutSine] for a hand-built
/// [AnimationStyle] that sets none.
Curve _curveOf(AnimationStyle style) => style.curve ?? Curves.easeInOutSine;

/// Whether [properties] sets a field that decides the role by itself: a
/// `button` value, true or false, a field naming another control, or a
/// `role` other than [SemanticsRole.none]. Any other field, such as a
/// label, `header`, `image`, `selected`, or `enabled`, combines with the
/// default button role.
bool _setsRole(SemanticsProperties? properties) =>
    properties != null &&
    (properties.button != null ||
        properties.link != null ||
        properties.textField != null ||
        properties.slider != null ||
        properties.keyboardKey != null ||
        properties.checked != null ||
        properties.mixed != null ||
        properties.toggled != null ||
        (properties.role != null && properties.role != SemanticsRole.none));

/// A [Semantics] whose node carries neither `header` nor `headingLevel`.
///
/// [SemanticsProperties] has no `copyWith`, so the render object clears the
/// two fields after the inherited configuration copies them in; any field
/// a later Flutter adds passes through unchanged.
class _SemanticsWithoutHeading extends Semantics {
  const new({required super.properties, super.child}) : super.fromProperties();

  @override
  RenderSemanticsAnnotations createRenderObject(BuildContext context) {
    final renderObject = _RenderSemanticsWithoutHeading(
      container: container,
      explicitChildNodes: explicitChildNodes,
      excludeSemantics: excludeSemantics,
      blockUserActions: blockUserActions,
      properties: properties,
      localeForSubtree: localeForSubtree,
    );
    // Sets the direction by the SDK's own rule, which is private to
    // `Semantics` in `widgets/basic.dart` and so unreachable from here.
    updateRenderObject(context, renderObject);
    return renderObject;
  }
}

/// Clears `header` and `headingLevel` after the inherited configuration,
/// only when it set them, so a config that would contribute no node
/// still contributes none.
class _RenderSemanticsWithoutHeading extends RenderSemanticsAnnotations {
  new({
    required super.properties,
    super.container,
    super.explicitChildNodes,
    super.excludeSemantics,
    super.blockUserActions,
    super.localeForSubtree,
  });

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    if (config.isHeader) config.isHeader = false;
    // Skips the write when the level is already 0, so a config with no
    // level stays unannotated; otherwise it clears the copied level.
    config.headingLevel = 0;
  }
}

/// Paints the hover and press overlay over [child] from [states].
///
/// It listens to [states] itself, below [InkWell]: [InkWell] updates the
/// controller inside its own update, and a listener above it would call
/// `setState` while a descendant builds.
class _StateOverlay extends StatelessWidget {
  const new({
    required this.states,
    required this.hoverColor,
    required this.pressedColor,
    required this.enabled,
    required this.borderRadius,
    required this.child,
  });

  final WidgetStatesController states;
  final Color hoverColor;
  final Color pressedColor;
  final bool enabled;
  final BorderRadiusGeometry? borderRadius;
  final Widget child;

  /// The color to animate to. The idle color is [hoverColor] at alpha 0,
  /// because a tween needs a non-null end and fading the alpha keeps the
  /// hue steady.
  Color _target(Set<WidgetState> value) {
    final idle = hoverColor.withValues(alpha: 0);
    if (!enabled || value.contains(WidgetState.disabled)) return idle;
    if (value.contains(WidgetState.pressed)) return pressedColor;
    if (value.contains(WidgetState.hovered)) return hoverColor;
    return idle;
  }

  @override
  Widget build(BuildContext context) {
    // The theme's fast level, else the package default's (spec G18).
    final fast =
        (StratumThemeApplication.maybeOf(context)?.animation ??
                StratumAnimation.packageDefault)
            .fast;
    return ListenableBuilder(
      listenable: states,
      builder: (context, child) => TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: _target(states.value)),
        duration: _durationOf(fast),
        curve: _curveOf(fast),
        // Alpha 0 becomes no color, so an idle surface paints nothing.
        builder: (context, color, child) => DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            color: color == null || color.a == 0 ? null : color,
            borderRadius: borderRadius,
          ),
          child: child,
        ),
        child: child,
      ),
      child: child,
    );
  }
}
