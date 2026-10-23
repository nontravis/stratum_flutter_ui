import 'package:flutter/rendering.dart'
    show
        BoxHitTestResult,
        BoxParentData,
        ChildLayoutHelper,
        ChildLayouter,
        ContainerRenderObjectMixin,
        PipelineOwner,
        RenderBox,
        RenderObject,
        RenderObjectVisitor,
        RenderObjectWithChildMixin,
        RenderProxyBox,
        RenderSemanticsAnnotations,
        RenderShiftedBox;
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:stratum_ui/src/components/common/base/disabled.dart'
    show StratumDisabledScope;
import 'package:stratum_ui/src/components/common/l10n/built_in_labels.dart';
import 'package:stratum_ui/src/components/common/utility/focus_border.dart'
    show focusStyleOver;
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

/// Whether a box layout builds the tap surface for [interaction]: an
/// activation callback, `onHover`, `onHighlightChanged`, `onFocusChange`,
/// or a non-empty `shortcuts` map (layout s03 invariant 2).
///
/// The one tap-surface build rule: `BoxLayout` builds a [StratumInkWell]
/// exactly when it holds, and `ContainerLayout.builder` reads the surface's
/// [InteractionState] only then. Not exported: `common/common.dart` hides
/// it, and the layouts import this file by path.
bool interactionNeedsTapSurface(Interaction interaction) =>
    interaction.onTap != null ||
    interaction.onDoubleTap != null ||
    interaction.onLongPress != null ||
    interaction.onSecondaryTap != null ||
    interaction.onHover != null ||
    interaction.onHighlightChanged != null ||
    interaction.onFocusChange != null ||
    interaction.shortcuts.isNotEmpty;

/// The [InteractionState] of the [StratumInkWell] nearest above [context],
/// or null when none is above; [context] rebuilds when it changes.
///
/// Not exported: `common/common.dart` hides it, and `container_layout.dart`
/// imports this file by path.
InteractionState? tapSurfaceStateOf(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<_InteractionStateScope>()?.state;

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

/// The one way [StratumInkWell] builds the caller's semantics node, exposed as
/// a seam a VM test drives.
///
/// The node carries every field of [properties], but `header` and
/// `headingLevel` when [withoutHeading] is set (on web, so the button node
/// under the heading node renders as a button). With [underSurface] it merges
/// into the surface node above it, identifier included; without, it stays a
/// boundary where it carries an identifier. Not exported: `common/common.dart`
/// hides it.
Widget tapSurfaceCallerSemantics({
  required SemanticsProperties properties,
  required bool withoutHeading,
  required bool underSurface,
  required Widget child,
}) => _CallerSemantics(
  properties: properties,
  withoutHeading: withoutHeading,
  underSurface: underSurface,
  child: child,
);

/// How far [StratumInkWell] pads its layout and hit area toward the
/// platform's minimum tap target (NFR-U05).
enum TapTargetSize {
  /// Pads to [minimumFor] when [StratumInkWell.child] is smaller.
  platform,

  /// Keeps [StratumInkWell.child]'s own size, opting a dense UI out of the
  /// padding.
  shrinkWrap;

  /// The minimum tap target on [platform]: 44 x 44 on iOS, 48 x 48 on
  /// Android and Fuchsia, 24 x 24 on macOS, Windows, Linux, and [web].
  static Size minimumFor(TargetPlatform platform, {bool web = kIsWeb}) {
    if (web) return const Size(24, 24);
    return switch (platform) {
      TargetPlatform.iOS => const Size(44, 44),
      TargetPlatform.android || TargetPlatform.fuchsia => const Size(48, 48),
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => const Size(24, 24),
    };
  }
}

/// The tap surface of the design system.
///
/// Builds on [InkWell] for gestures, keyboard activation, focus, and hover,
/// and adds what [InkWell] leaves out:
///
/// * a flat overlay over [child]: the theme's `state.hover` color while
///   hovered and `state.press` while pressed;
/// * a [StratumFocusBorder] ring in its outside placement, shown per
///   [focusType] and styled by [customStyle]'s `focus`;
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
    this.tapTargetSize = TapTargetSize.platform,
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
    this.customStyle,
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
  /// when no activation callback is set, and never while the surface is
  /// disabled. Turning disabled under the pointer calls it once with false,
  /// and turning enabled again under it calls it once with true, after the
  /// frame that applies the change (US-04 FR-04 E05, E06).
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

  /// Grows the layout footprint to [TapTargetSize.minimumFor] when
  /// [child] is smaller than the platform minimum; the painted child does
  /// not grow (NFR-U05). [TapTargetSize.shrinkWrap] opts a dense UI
  /// out, keeping [child]'s own size.
  final TapTargetSize tapTargetSize;

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

  /// This surface's own style: its `focus` field restyles this surface's
  /// focus ring, level 3, over the app-wide `StratumInkWellStyle` under
  /// `StratumInkWell` in `componentPartDefaults`, level 2 (FO-06 US-04
  /// FR-03); every field of it takes effect (NFR-E02).
  final StratumInkWellStyle? customStyle;

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

  // Whether a mouse pointer is over the surface, disabled or not: the
  // region in `build` reports it in every state, so a disabled flip under
  // a still pointer knows the pointer is there (US-04 FR-04 E05, E06).
  final ValueNotifier<bool> _pointerInside = ValueNotifier(false);

  // The value `onHover` last reported: a pointer over the surface while it
  // is not disabled.
  bool _hoverReported = false;

  // [_disabled] at the last dependency change or widget update, null
  // before the first. The pointer handlers and the post-frame report read
  // it, since they run outside a build.
  bool? _trackedDisabled;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _trackDisabled();
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
    _trackDisabled();
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_handleHighlightMode);
    _focusNode.removeListener(_handleFocusChange);
    _internalFocusNode?.dispose();
    _inkFocusNode?.dispose();
    _internalStatesController?.dispose();
    _pointerInside.dispose();
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

  /// Tracks [_disabled]; when it flipped, reports hover after the frame,
  /// since a listener that calls an ancestor's `setState` during a build
  /// fails.
  void _trackDisabled() {
    final disabled = _disabled;
    final flipped = _trackedDisabled != null && _trackedDisabled != disabled;
    _trackedDisabled = disabled;
    if (!flipped) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reportHover();
    });
  }

  /// Calls `onHover` when "a pointer over the surface while it is not
  /// disabled" changed since the last call: on enter and exit, and on a
  /// disabled flip under the pointer (US-04 FR-04 E03, E05, E06).
  void _reportHover() {
    final hovered = _pointerInside.value && !(_trackedDisabled ?? false);
    if (hovered == _hoverReported) return;
    _hoverReported = hovered;
    widget.onHover?.call(hovered);
  }

  void _handlePointer({required bool inside}) {
    _pointerInside.value = inside;
    _reportHover();
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
    final shortcutOnly = _shortcutOnly;
    final ringVisible = _ringVisible;

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
        child: _InteractionStateReport(
          states: _statesController,
          pointerInside: _pointerInside,
          disabled: disabled,
          focused: ringVisible,
          child: widget.child,
        ),
      ),
    );
    result = Material(
      key: _surfaceKey,
      type: MaterialType.transparency,
      child: result,
    );
    // Wraps the ring around the real visual child, ahead of the padding
    // below, so the ring hugs it (B2) and not the grown hit box.
    if (_hasRing) {
      result = StratumFocusBorder(
        state: ringVisible ? FullWidgetState.focused : FullWidgetState.normal,
        borderRadius: widget.borderRadius,
        customStyle: focusStyleOver(
          StratumComponentDefaults.partsOf<StratumInkWellStyle>(
            context,
            StratumInkWell,
          )?.focus,
          widget.customStyle?.focus,
        ),
        child: result,
      );
    }
    if (widget.tapTargetSize != TapTargetSize.shrinkWrap) {
      result = _TapTargetPadding(
        minimumSize: TapTargetSize.minimumFor(
          defaultTargetPlatform,
          web: kIsWeb,
        ),
        child: result,
      );
    }
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
    // Always built with its handlers, so toggling onHover or disabled never
    // changes the structure below and the pointer stays tracked while
    // disabled (US-04 FR-04 E05, E06).
    result = MouseRegion(
      onEnter: (_) => _handlePointer(inside: true),
      onExit: (_) => _handlePointer(inside: false),
      child: result,
    );
    // A caller's semantics apply even with excludeFromSemantics, the usual
    // way to replace the gesture semantics with a custom label and actions.
    // Under the surface they merge into its one node; with
    // excludeFromSemantics there is no surface, so they keep their own.
    final properties = widget.semantics;
    final headingLevel = tapSurfaceHeadingLevel(
      isWeb: kIsWeb,
      hasActivation: _hasActivation,
      excludeFromSemantics: widget.excludeFromSemantics,
      semantics: properties,
    );
    if (properties != null) {
      result = tapSurfaceCallerSemantics(
        properties: properties,
        withoutHeading: headingLevel != null,
        underSurface: !widget.excludeFromSemantics,
        child: result,
      );
    }
    if (!widget.excludeFromSemantics) {
      final hasActivation = _hasActivation;
      final secondary = widget.onSecondaryTap;
      result = _SurfaceSemantics(
        container: true,
        enabled: hasActivation && properties?.enabled == null
            ? !disabled
            : null,
        button: hasActivation && !_setsRole(properties) ? true : null,
        customActions: secondary == null || disabled
            ? null
            : {
                CustomSemanticsAction(label: _secondaryTapLabel(context)):
                    secondary,
              },
        // Whether this surface's own node (or a caller's own `enabled` it
        // merges) ever sets the enabled tristate; a pass node above it
        // flags `hidden` only then, else `join` (I1).
        setsEnabledTristate: hasActivation || properties?.enabled != null,
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

/// A [Semantics.fromProperties] for a caller's node that can drop `header`
/// and `headingLevel` ([withoutHeading]) and merge into the surface node
/// above it ([underSurface]).
///
/// [SemanticsProperties] has no `copyWith`, so the render object adjusts the
/// configuration after the inherited one copies the fields in; any field a
/// later Flutter adds passes through unchanged.
class _CallerSemantics extends Semantics {
  const new({
    required super.properties,
    required this.withoutHeading,
    required this.underSurface,
    super.child,
  }) : super.fromProperties();

  /// Whether the node carries neither `header` nor `headingLevel`.
  final bool withoutHeading;

  /// Whether the node merges into the surface node above it, identifier
  /// included, instead of splitting off as its own.
  final bool underSurface;

  @override
  RenderSemanticsAnnotations createRenderObject(BuildContext context) {
    final renderObject = _RenderCallerSemantics(
      withoutHeading: withoutHeading,
      underSurface: underSurface,
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

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSemanticsAnnotations renderObject,
  ) {
    super.updateRenderObject(context, renderObject);
    (renderObject as _RenderCallerSemantics)
      ..withoutHeading = withoutHeading
      ..underSurface = underSurface;
  }
}

/// Adjusts the inherited configuration for [_CallerSemantics]: clears
/// `header` and `headingLevel` only when it set them, so a config that
/// would contribute no node still contributes none.
class _RenderCallerSemantics extends RenderSemanticsAnnotations {
  new({
    required bool withoutHeading,
    required bool underSurface,
    required super.properties,
    super.container,
    super.explicitChildNodes,
    super.excludeSemantics,
    super.blockUserActions,
    super.localeForSubtree,
  }) : _withoutHeading = withoutHeading,
       _underSurface = underSurface;

  bool _withoutHeading;
  bool _underSurface;

  set withoutHeading(bool value) {
    if (_withoutHeading == value) return;
    _withoutHeading = value;
    markNeedsSemanticsUpdate();
  }

  set underSurface(bool value) {
    if (_underSurface == value) return;
    _underSurface = value;
    markNeedsSemanticsUpdate();
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    if (_withoutHeading) {
      if (config.isHeader) config.isHeader = false;
      // Skips the write when the level is already 0, so a config with no
      // level stays unannotated; otherwise it clears the copied level.
      config.headingLevel = 0;
    }
    // `rendering/object.dart:4941@3.47.7` makes a non-null `identifier` a
    // semantic boundary, which would split this node off the surface's
    // container; resetting it to `container` lets the caller's fields,
    // identifier included, merge into the surface's one node (US-04 FR-02).
    if (_underSurface) config.isSemanticBoundary = container;
  }
}

/// Marks a reorder item's root, so a flagged node below, such as the pass
/// node `StratumDisabled` builds, can seed its [_ItemRootFlag.role] from
/// this marker (layout s03 invariant 81).
///
/// `_wrapItem` wraps every item in this first, [active] false for a
/// leaving item, which keeps the marker, inactive, so the item keeps its
/// widgets and its `State` across the leave.
class ReorderItemRoot extends StatelessWidget {
  const new({super.key, required this.active, required this.child});

  /// False for a leaving item.
  final bool active;

  /// The item this marks the root of.
  final Widget child;

  /// The node `_wrapWithSemantics` builds around a reorder item, above its
  /// marker: a [Semantics] with [container] and the item's move
  /// [customSemanticsActions] that, while the item's root surface joins
  /// it, also describes that surface's own custom actions, such as its
  /// secondary tap, so the two share the one config Flutter merges into
  /// (layout s03 invariant 81, D6(a)). A leaving item builds it too, with
  /// no container and no actions, so its element stays across the leave.
  static Widget itemNode({
    required bool container,
    Map<CustomSemanticsAction, VoidCallback>? customSemanticsActions,
    required Widget child,
  }) => _ItemNodeSemantics(
    container: container,
    customSemanticsActions: customSemanticsActions,
    child: child,
  );

  @override
  Widget build(BuildContext context) => _ItemRootScope(
    child: _ItemRootMarker(active: active, child: child),
  );
}

/// Tells a flagged widget below, at build, that a [ReorderItemRoot] sits
/// above it, so a widget outside any reorder item never seeds.
class _ItemRootScope extends InheritedWidget {
  const new({required super.child});

  @override
  bool updateShouldNotify(_ItemRootScope oldWidget) => false;
}

/// Whether [context] sits inside a [ReorderItemRoot]; the one inherited
/// lookup a flagged widget pays per build, refreshed by a reparent through
/// `didChangeDependencies`.
bool _insideItemRoot(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<_ItemRootScope>() != null;

/// How a flagged node describes its semantics config at a reorder item
/// root (layout s03 invariant 81; base s03 invariant 15).
enum _ItemRootRole {
  /// Outside any reorder item root: describes as [Semantics] does.
  none,

  /// Merges into the item's node: the config is never a semantics
  /// boundary.
  join,

  /// Describes nothing, a pass node above a root surface (M1-T2).
  hidden,
}

/// The role a reorder item root's marker sets on a flagged render object,
/// and the seed-and-mark and describe-bookkeeping sequences every flagged
/// render object shares.
mixin _ItemRootFlag on RenderObject {
  /// The role the last seed set; [describeSemanticsConfiguration] reads
  /// this to decide what it describes.
  _ItemRootRole role = _ItemRootRole.none;

  /// The role the last [describeSemanticsConfiguration] call used; null
  /// before the first.
  _ItemRootRole? describedRole;

  /// Whether a [_ItemRootScope] sat above this object's widget at build.
  bool inItem = false;

  /// Seeds [role] by walking this object's parents to an active marker
  /// through [_RenderItemRoot._seedFrom], and tells the marker found to
  /// flag every node in [passes], which starts as `this` alone for a pass
  /// node, or empty for [surface], so the walk's ancestors land in front
  /// of it, top first. Sets [role] to [_ItemRootRole.none] when the walk
  /// finds no marker.
  void _seedAndMark(
    List<_RenderPassSemantics> passes, {
    _RenderSurfaceSemantics? surface,
  }) {
    final marker = _RenderItemRoot._seedFrom(this, passes);
    if (marker == null) {
      role = _ItemRootRole.none;
      return;
    }
    for (final node in marker._flag(surface: surface, passes: passes)) {
      node.markNeedsSemanticsUpdate();
    }
  }

  /// Records [role] as the answer this description used.
  void _recordDescribedRole() => describedRole = role;

  /// Whether this object described before and its last description no
  /// longer matches what the marker set on it since.
  bool get describedStale => describedRole != null && describedRole != role;
}

/// The widget [ReorderItemRoot] builds: [SingleChildRenderObjectWidget]
/// over [_RenderItemRoot].
class _ItemRootMarker extends SingleChildRenderObjectWidget {
  const new({required this.active, super.child});

  /// [ReorderItemRoot.active] passed through.
  final bool active;

  @override
  _RenderItemRoot createRenderObject(BuildContext context) =>
      _RenderItemRoot(active);

  @override
  void updateRenderObject(BuildContext context, _RenderItemRoot renderObject) {
    renderObject.active = active;
  }
}

/// The render object [ReorderItemRoot] builds: opens no semantics node of
/// its own, and flags every pass node a seed finds below it `join`
/// (layout s03 invariant 81).
class _RenderItemRoot extends RenderProxyBox {
  new(this._active);

  /// Backs [active].
  bool _active;

  /// Whether the item this marks the root of is live; false lets
  /// [_seedFrom] skip a leaving item.
  bool get active => _active;

  set active(bool value) {
    if (_active == value) return;
    _active = value;
    markNeedsSemanticsUpdate();
    // Runs in build, outside the flush, so a leaving item's node drops the
    // root's actions in its first exit frame (E05), before the item node's
    // own walk could see the inactive marker. Unlinks only from this
    // marker's own item node: [_surface] goes stale while the sliver keeps
    // this item alive off screen and skips its walk, and a [GlobalKey] may
    // have moved that surface into another item's node by then.
    if (!value) {
      final surface = _surface;
      final node = _ownItemNode();
      if (surface != null &&
          node != null &&
          identical(surface._linkedCarrier, node)) {
        surface._unlink();
      }
    }
  }

  /// This marker's own item node: the nearest [_RenderItemNode] above it,
  /// or null when another marker comes first. Reads parents only, so it
  /// is safe in build.
  _RenderItemNode? _ownItemNode() {
    for (var node = parent; node != null; node = node.parent) {
      if (node is _RenderItemNode) return node;
      if (node is _RenderItemRoot) return null;
    }
    return null;
  }

  /// The pass nodes this marker last flagged, top first; `const []`
  /// before any seed registers.
  List<_RenderPassSemantics> _passes = const [];

  /// The surface this marker last flagged `join`; null before any seed
  /// registers one.
  _RenderSurfaceSemantics? _surface;

  /// Flags [surface] `join` and every node in [passes] `hidden` when
  /// [surface] is given and sets the enabled tristate
  /// ([_RenderSurfaceSemantics.setsEnabledTristate]), or `join` otherwise,
  /// so a surface with no activation callback never hides the disabled
  /// state a pass node above it describes (I1); flags every previously
  /// registered pass node or surface that [passes] or [surface] drops
  /// back to `none`, registers both, and returns every attached touched
  /// node whose last description no longer matches.
  Set<_ItemRootFlag> _flag({
    _RenderSurfaceSemantics? surface,
    required List<_RenderPassSemantics> passes,
  }) {
    final kept = passes.toSet();
    final dropped = _passes.where((node) => !kept.contains(node));
    for (final node in dropped) {
      node.role = _ItemRootRole.none;
    }
    final passRole = surface != null && surface.setsEnabledTristate
        ? _ItemRootRole.hidden
        : _ItemRootRole.join;
    for (final node in passes) {
      node.role = passRole;
    }
    final droppedSurface = _surface != surface ? _surface : null;
    droppedSurface?.role = _ItemRootRole.none;
    surface?.role = _ItemRootRole.join;
    _passes = passes;
    _surface = surface;
    return {
      for (final node in <_ItemRootFlag>[
        ...dropped,
        ...passes,
        ?droppedSurface,
        ?surface,
      ])
        if (node.attached && node.describedStale) node,
    };
  }

  /// Walks up from [from]'s parent, keeping `below` as the one child a
  /// chain holds: at a [_RenderItemRoot], returns it when [active], else
  /// null; at a [_RenderSurfaceSemantics], returns null, because the walk
  /// stops at the first surface above [from] (M1-T2); when
  /// [_onlyLinkedChild] is false, returns null; at a [_RenderPassSemantics],
  /// inserts it at the front of [passes], top first; at any other node
  /// that [_opensNode], returns null.
  static _RenderItemRoot? _seedFrom(
    RenderObject from,
    List<_RenderPassSemantics> passes,
  ) {
    var below = from;
    for (var node = from.parent; node != null; node = node.parent) {
      if (node is _RenderItemRoot) return node.active ? node : null;
      if (node is _RenderSurfaceSemantics) return null;
      if (!_onlyLinkedChild(node, below)) return null;
      if (node is _RenderPassSemantics) {
        passes.insert(0, node);
      } else if (_opensNode(node)) {
        return null;
      }
      below = node;
    }
    return null;
  }

  /// Whether a fresh [SemanticsConfiguration] [node] describes is a
  /// semantics boundary or has `explicitChildNodes`.
  static bool _opensNode(RenderObject node) {
    final config = SemanticsConfiguration();
    node.describeSemanticsConfiguration(config);
    return config.isSemanticBoundary || config.explicitChildNodes;
  }

  /// Whether [below] is [parent]'s one linked child; a container links a
  /// child only after attaching it, so mid-insert this is false
  /// (`rendering/object.dart:4515`, `:4522@3.47.7`).
  static bool _onlyLinkedChild(RenderObject parent, RenderObject below) =>
      switch (parent) {
        RenderObjectWithChildMixin(:final child) => identical(child, below),
        ContainerRenderObjectMixin(:final childCount, :final firstChild) =>
          childCount == 1 && identical(firstChild, below),
        _ => false,
      };

  /// Walks down from [child]: at a [_RenderSurfaceSemantics], returns it
  /// with the pass nodes collected on the way down; at a nested
  /// [_RenderItemRoot], stops, so a reorder item's own marker never walks
  /// into a different list's item sitting below it (I1, mirrors
  /// [_seedFrom]'s own stop at any marker); at a [_RenderPassSemantics],
  /// appends it and goes on; at any other object that [_opensNode], stops.
  /// The next object is [_onlySemanticsChild]; null stops the walk too. A
  /// stop short of a surface returns the pass nodes the chain reached, so
  /// they join on their own (R11b). Gives nothing while inactive. Runs
  /// only inside the flush (M1-T3).
  ({_RenderSurfaceSemantics? surface, List<_RenderPassSemantics> passes})
  _findRoot() {
    if (!active) return (surface: null, passes: const []);
    final passes = <_RenderPassSemantics>[];
    RenderObject? node = child;
    while (node != null) {
      if (node is _RenderSurfaceSemantics) {
        return (surface: node, passes: passes);
      }
      if (node is _RenderItemRoot) break;
      if (node is _RenderPassSemantics) {
        passes.add(node);
      } else if (_opensNode(node)) {
        break;
      }
      node = _onlySemanticsChild(node);
    }
    return (surface: null, passes: passes);
  }

  /// The only object [node]'s own [RenderObject.visitChildrenForSemantics]
  /// visits, or null when it visits none or more than one. Runs only
  /// inside the flush, [_findRoot]'s one caller.
  static RenderObject? _onlySemanticsChild(RenderObject node) {
    RenderObject? only;
    var count = 0;
    node.visitChildrenForSemantics((child) {
      count += 1;
      only = child;
    });
    return count == 1 ? only : null;
  }

  /// Whether [passes] holds the same nodes, in the same order, as
  /// [_passes]; identity, not `==`, since a pass node carries no value
  /// equality.
  bool _samePasses(List<_RenderPassSemantics> passes) {
    if (passes.length != _passes.length) return false;
    for (var i = 0; i < passes.length; i += 1) {
      if (!identical(passes[i], _passes[i])) return false;
    }
    return true;
  }

  // Re-walks this marker's subtree on every semantics flush (D4): a
  // reparent, a sibling add or remove, or any other change that moves the
  // surface or a pass node without re-running its own attach-time seed.
  // Also re-flags when the found surface or a found pass node's own `role`
  // field no longer matches what `_flag` would newly give it, which, with
  // [_surface] and [_passes] both still matching, means something other
  // than this marker moved it: a run-time flip of the found surface's
  // `setsEnabledTristate` (M2, for example `Interaction.onTap` going from
  // null to set, never moves [_surface] or [_passes]), or a losing item's
  // own re-walk clobbering a role this marker's attach-time seed already
  // set on a surface a [GlobalKey] just moved in (M1). When the answer
  // differs, `_flag` moves the flags and this defers
  // `markNeedsSemanticsUpdate` on each touched, still-attached node to one
  // post-frame callback (`rendering/object.dart:3923@3.47.7`: that call
  // asserts outside the flush).
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    final found = _findRoot();
    final surface = found.surface;
    final passRole = surface != null && surface.setsEnabledTristate
        ? _ItemRootRole.hidden
        : _ItemRootRole.join;
    final stale =
        (surface != null && surface.role != _ItemRootRole.join) ||
        found.passes.any((node) => node.role != passRole);
    if (surface != _surface || !_samePasses(found.passes) || stale) {
      final flipped = _flag(surface: surface, passes: found.passes);
      if (flipped.isNotEmpty) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          for (final node in flipped) {
            if (node.attached) node.markNeedsSemanticsUpdate();
          }
        });
      }
    }
    super.visitChildrenForSemantics(visitor);
  }
}

/// The `Semantics` layer `StratumDisabled` builds in place of [Semantics]:
/// joins the item's node while a reorder item root's marker flags it
/// `join`, and describes nothing while flagged `hidden`, a pass node
/// above a root surface (M1-T2). Kept out of the barrel (layout s03
/// invariant 81; base s03 invariant 15).
class ItemRootPassSemantics extends Semantics {
  new({super.key, super.container, super.enabled, super.child});

  @override
  RenderSemanticsAnnotations createRenderObject(BuildContext context) {
    final renderObject = _RenderPassSemantics(
      container: container,
      explicitChildNodes: explicitChildNodes,
      excludeSemantics: excludeSemantics,
      blockUserActions: blockUserActions,
      properties: properties,
      localeForSubtree: localeForSubtree,
    );
    updateRenderObject(context, renderObject);
    return renderObject;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSemanticsAnnotations renderObject,
  ) {
    super.updateRenderObject(context, renderObject);
    (renderObject as _RenderPassSemantics).inItem = _insideItemRoot(context);
  }
}

/// The render object [ItemRootPassSemantics] builds: seeds [_ItemRootFlag]
/// at attach, and merges into or hides from the item's node by [role].
class _RenderPassSemantics extends RenderSemanticsAnnotations
    with _ItemRootFlag {
  new({
    required super.properties,
    super.container,
    super.explicitChildNodes,
    super.excludeSemantics,
    super.blockUserActions,
    super.localeForSubtree,
  });

  // Attach describes the config at once
  // (`rendering/object.dart:2507-2509@3.47.7`), before any marker visit
  // exists (M1-T3 adds the flush re-walk), so seed from the parents
  // already in place.
  @override
  void attach(PipelineOwner owner) {
    if (inItem) _seedAndMark(<_RenderPassSemantics>[this]);
    super.attach(owner);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    _recordDescribedRole();
    if (role == _ItemRootRole.hidden) return;
    super.describeSemanticsConfiguration(config);
    if (role == _ItemRootRole.join) config.isSemanticBoundary = false;
  }
}

/// The `Semantics` layer `_StratumInkWellState.build` builds in place of
/// [Semantics] for its outer node: joins the whole reorder item's node
/// while a marker flags it `join`, so the surface's label, button role,
/// enabled state, tap, and custom actions sit beside the item's move
/// actions on one node (layout s03 invariant 81).
/// `ContainerLayout(interaction:)` reaches this too, since it builds a
/// [StratumInkWell] (`box_layout.dart:219`).
class _SurfaceSemantics extends Semantics {
  new({
    super.container,
    super.enabled,
    super.button,
    this.customActions,
    required this.setsEnabledTristate,
    super.child,
  });

  /// The surface's own custom actions, such as its secondary tap; kept
  /// out of [properties], since the item node describes them in its
  /// place while this surface joins it (D6(a)).
  final Map<CustomSemanticsAction, VoidCallback>? customActions;

  /// Whether this surface's own node, or a caller's own `enabled` it
  /// merges, ever sets the enabled tristate (I1).
  final bool setsEnabledTristate;

  @override
  RenderSemanticsAnnotations createRenderObject(BuildContext context) {
    final renderObject = _RenderSurfaceSemantics(
      container: container,
      explicitChildNodes: explicitChildNodes,
      excludeSemantics: excludeSemantics,
      blockUserActions: blockUserActions,
      properties: properties,
      localeForSubtree: localeForSubtree,
      setsEnabledTristate: setsEnabledTristate,
    );
    updateRenderObject(context, renderObject);
    return renderObject;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSemanticsAnnotations renderObject,
  ) {
    super.updateRenderObject(context, renderObject);
    (renderObject as _RenderSurfaceSemantics)
      ..inItem = _insideItemRoot(context)
      ..setsEnabledTristate = setsEnabledTristate
      ..customActions = customActions;
  }
}

/// The render object [_SurfaceSemantics] builds: seeds [_ItemRootFlag] at
/// attach as the item's own surface, merges into the item's node while
/// flagged `join`, and leaves its custom actions to that node while
/// linked with it ([carrier]).
class _RenderSurfaceSemantics extends RenderSemanticsAnnotations
    with _ItemRootFlag {
  new({
    required super.properties,
    required this.setsEnabledTristate,
    super.container,
    super.explicitChildNodes,
    super.excludeSemantics,
    super.blockUserActions,
    super.localeForSubtree,
  });

  /// [_SurfaceSemantics.setsEnabledTristate], passed through; `_flag`
  /// reads this to decide a pass node's role (I1).
  bool setsEnabledTristate;

  /// [_SurfaceSemantics.customActions], passed through.
  Map<CustomSemanticsAction, VoidCallback>? get customActions => _customActions;
  Map<CustomSemanticsAction, VoidCallback>? _customActions;

  set customActions(Map<CustomSemanticsAction, VoidCallback>? value) {
    if (mapEquals(_customActions, value)) return;
    _customActions = value;
    markNeedsSemanticsUpdate();
    // Outside the flush, so the item node describing them takes the new
    // actions in the same frame (D6(a)).
    _linkedCarrier?.markNeedsSemanticsUpdate();
  }

  /// The item node that last linked this surface; while that node links
  /// this surface back ([_linkedCarrier]), it describes [customActions]
  /// in place of this surface (D6(a)).
  _RenderItemNode? carrier;

  /// [carrier] while it links this surface back, so it describes
  /// [customActions] in place of this surface; else null.
  _RenderItemNode? get _linkedCarrier {
    final node = carrier;
    return node != null && identical(node.joined, this) ? node : null;
  }

  /// Whether [_linkedCarrier] was set at the last
  /// [describeSemanticsConfiguration] call; null before the first.
  bool? _describedCarried;

  @override
  bool get describedStale =>
      super.describedStale ||
      (_describedCarried != null &&
          _describedCarried != (_linkedCarrier != null));

  // Attach describes the config at once
  // (`rendering/object.dart:2507-2509@3.47.7`), before any marker visit
  // exists (M1-T3 adds the flush re-walk), so seed from the parents
  // already in place; the walk starts with no pass node of its own, since
  // the surface flags itself through `surface:`, not through `passes`.
  @override
  void attach(PipelineOwner owner) {
    if (inItem) _seedAndMark(<_RenderPassSemantics>[], surface: this);
    super.attach(owner);
  }

  // Hands its actions back from the item node at once, so a node that
  // stays never describes a removed surface's actions; a surface a
  // [GlobalKey] moves relinks at its new item node's next flush walk.
  @override
  void detach() {
    super.detach();
    _unlink();
  }

  /// Hands [customActions] back from [_linkedCarrier] and marks both
  /// still-attached sides, so each re-describes in this frame; runs only
  /// outside the flush, from a detach or a marker turning inactive.
  void _unlink() {
    final node = _linkedCarrier;
    carrier = null;
    if (node == null) return;
    node.joined = null;
    if (node.attached) node.markNeedsSemanticsUpdate();
    if (attached) markNeedsSemanticsUpdate();
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    _recordDescribedRole();
    final carried = _describedCarried = _linkedCarrier != null;
    if (role == _ItemRootRole.join) config.isSemanticBoundary = false;
    final actions = customActions;
    if (actions != null && !carried) config.customSemanticsActions = actions;
  }
}

/// The `Semantics` layer [ReorderItemRoot.itemNode] builds, over
/// [_RenderItemNode].
class _ItemNodeSemantics extends Semantics {
  new({super.container, super.customSemanticsActions, super.child});

  @override
  RenderSemanticsAnnotations createRenderObject(BuildContext context) {
    final renderObject = _RenderItemNode(
      container: container,
      explicitChildNodes: explicitChildNodes,
      excludeSemantics: excludeSemantics,
      blockUserActions: blockUserActions,
      properties: properties,
      localeForSubtree: localeForSubtree,
    );
    updateRenderObject(context, renderObject);
    return renderObject;
  }
}

/// The render object of a reorder item's node: describes the item's
/// moves from its properties and, while it links a root surface
/// ([joined]), that surface's custom actions in the same config, since
/// two configs that both carry custom actions never merge
/// (`semantics/semantics.dart:6755@3.47.7`; layout s03 invariant 81).
/// It links the surface its own semantics walk exposes ([_exposedRoot]),
/// so the actions sit here exactly when Flutter would expose them on the
/// surface's own config.
class _RenderItemNode extends RenderSemanticsAnnotations {
  new({
    required super.properties,
    super.container,
    super.explicitChildNodes,
    super.excludeSemantics,
    super.blockUserActions,
    super.localeForSubtree,
  });

  /// The root surface whose custom actions this node describes, while
  /// that surface links this node back as its
  /// [_RenderSurfaceSemantics.carrier]; set by [_relink].
  _RenderSurfaceSemantics? joined;

  // Re-decides the link on every semantics flush that rebuilds this node,
  // which any change on the way down to the root surface triggers, since
  // nothing on that way is a node of its own; the walk never runs while no
  // semantics owner exists. A change here lands one frame later, the
  // flags' own window (D6(e)), through one post-frame callback
  // (`rendering/object.dart:3923@3.47.7`: that call asserts outside the
  // flush).
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    _relink(_exposedRoot());
    super.visitChildrenForSemantics(visitor);
  }

  /// The root surface Flutter's own semantics walk exposes from this node:
  /// reached through exactly one active marker, where each object on the
  /// way visits only that next object for semantics and describes no node
  /// of its own, no `explicitChildNodes`, and no block on user actions;
  /// null when none is. Asks each object through its own
  /// `visitChildrenForSemantics` and a fresh config, so it runs only
  /// inside the flush or once a frame is laid out, never at attach.
  _RenderSurfaceSemantics? _exposedRoot() {
    if (excludeSemantics) return null;
    var marked = false;
    RenderObject? node = child;
    while (node != null) {
      switch (node) {
        case _RenderSurfaceSemantics():
          return marked ? node : null;
        case _RenderItemNode():
          return null;
        case _RenderItemRoot(:final active, :final child):
          if (marked || !active) return null;
          marked = true;
          // Steps past the marker, whose own visit runs its role walk.
          node = child;
          continue;
        case _RenderPassSemantics():
          break;
        default:
          if (_hidesActions(node)) return null;
      }
      node = _RenderItemRoot._onlySemanticsChild(node);
    }
    return null;
  }

  /// Whether a fresh [SemanticsConfiguration] [node] describes would keep
  /// a root's actions off this node: a node of its own, `explicitChildNodes`,
  /// or a block on user actions, whose actions
  /// [SemanticsConfiguration.absorb] drops
  /// (`semantics/semantics.dart:6810@3.47.7`).
  static bool _hidesActions(RenderObject node) {
    final config = SemanticsConfiguration();
    node.describeSemanticsConfiguration(config);
    return config.isSemanticBoundary ||
        config.explicitChildNodes ||
        config.isBlockingUserActions;
  }

  /// Links [surface] in place of [joined], taking it from any other item
  /// node that still links it, and defers `markNeedsSemanticsUpdate` on
  /// every side whose link changed to one post-frame callback.
  void _relink(_RenderSurfaceSemantics? surface) {
    final previous = joined;
    if (identical(previous, surface) &&
        (surface == null || identical(surface.carrier, this))) {
      return;
    }
    final touched = <RenderObject>{this};
    if (previous != null && identical(previous.carrier, this)) {
      previous.carrier = null;
      touched.add(previous);
    }
    joined = surface;
    if (surface != null) {
      final other = surface.carrier;
      if (other != null && identical(other.joined, surface)) {
        other.joined = null;
        touched.add(other);
      }
      surface.carrier = this;
      touched.add(surface);
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      for (final node in touched) {
        if (node.attached) node.markNeedsSemanticsUpdate();
      }
    });
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    final surface = joined;
    if (surface == null || !identical(surface.carrier, this)) return;
    final actions = surface.customActions;
    if (actions == null) return;
    config.customSemanticsActions = {
      ...config.customSemanticsActions,
      // A change that hides the root lands here a frame late; the action
      // asks the walk again when it runs, so it never runs then.
      for (final MapEntry(:key, :value) in actions.entries)
        key: () {
          if (identical(_exposedRoot(), surface)) value();
        },
    };
  }
}

/// Pads [child]'s layout footprint to [minimumSize] and redirects a hit
/// outside it, but inside the padded box, to its center (NFR-U05).
///
/// Ported from the SDK's `_InputPadding` (`material/button.dart`): only the
/// hit area and the reserved space grow, never the painted child.
class _TapTargetPadding extends SingleChildRenderObjectWidget {
  const new({required this.minimumSize, super.child});

  final Size minimumSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTapTargetPadding(minimumSize);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderTapTargetPadding renderObject,
  ) {
    renderObject.minimumSize = minimumSize;
  }
}

/// Lays [child] out at `constraints.constrain(max(child, minimumSize))`,
/// centers it, and falls a hit outside it through to its center.
class _RenderTapTargetPadding extends RenderShiftedBox {
  new(this._minimumSize, [RenderBox? child]) : super(child);

  Size get minimumSize => _minimumSize;
  Size _minimumSize;
  set minimumSize(Size value) {
    if (_minimumSize == value) return;
    _minimumSize = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final child = this.child;
    if (child == null) return 0;
    return max(child.getMinIntrinsicWidth(height), minimumSize.width);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final child = this.child;
    if (child == null) return 0;
    return max(child.getMinIntrinsicHeight(width), minimumSize.height);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final child = this.child;
    if (child == null) return 0;
    return max(child.getMaxIntrinsicWidth(height), minimumSize.width);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final child = this.child;
    if (child == null) return 0;
    return max(child.getMaxIntrinsicHeight(width), minimumSize.height);
  }

  Size _computeSize({
    required BoxConstraints constraints,
    required ChildLayouter layoutChild,
  }) {
    final child = this.child;
    if (child == null) return Size.zero;
    final childSize = layoutChild(child, constraints);
    final width = max(childSize.width, minimumSize.width);
    final height = max(childSize.height, minimumSize.height);
    return constraints.constrain(Size(width, height));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _computeSize(
    constraints: constraints,
    layoutChild: ChildLayoutHelper.dryLayoutChild,
  );

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final child = this.child;
    if (child == null) return null;
    final result = child.getDryBaseline(constraints, baseline);
    if (result == null) return null;
    final childSize = child.getDryLayout(constraints);
    return result +
        Alignment.center
            .alongOffset(getDryLayout(constraints) - childSize as Offset)
            .dy;
  }

  @override
  void performLayout() {
    size = _computeSize(
      constraints: constraints,
      layoutChild: ChildLayoutHelper.layoutChild,
    );
    final child = this.child;
    if (child == null) return;
    (child.parentData! as BoxParentData).offset = Alignment.center.alongOffset(
      size - child.size as Offset,
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (super.hitTest(result, position: position)) return true;
    final child = this.child;
    if (child == null) return false;
    final center = child.size.center(Offset.zero);
    return result.addWithRawTransform(
      transform: MatrixUtils.forceToPoint(center),
      position: center,
      hitTest: (result, position) => child.hitTest(result, position: center),
    );
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
    // No duration is exempt from reduced motion (NFR-U03); the curve stays,
    // since a zero-duration tween never samples it.
    final duration = context.reducesMotion ? Duration.zero : _durationOf(fast);
    return ListenableBuilder(
      listenable: states,
      builder: (context, child) => TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: _target(states.value)),
        duration: duration,
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

/// Reports the surface's [InteractionState] to the content below
/// [InkWell].
///
/// It listens to [states] below [InkWell], as [_StateOverlay] does, since
/// [InkWell] updates the controller inside its own update.
class _InteractionStateReport extends StatelessWidget {
  const new({
    required this.states,
    required this.pointerInside,
    required this.disabled,
    required this.focused,
    required this.child,
  });

  final WidgetStatesController states;
  final ValueListenable<bool> pointerInside;
  final bool disabled;
  final bool focused;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: pointerInside,
    builder: (context, child) => ListenableBuilder(
      listenable: states,
      builder: (context, child) {
        final value = states.value;
        return _InteractionStateScope(
          state: InteractionState(
            hovered:
                !disabled &&
                (pointerInside.value || value.contains(WidgetState.hovered)),
            pressed: !disabled && value.contains(WidgetState.pressed),
            focused: focused,
            disabled: disabled,
          ),
          child: child!,
        );
      },
      child: child,
    ),
    child: child,
  );
}

/// Holds the [InteractionState] [tapSurfaceStateOf] reads; notifies its
/// readers only when a value changes.
class _InteractionStateScope extends InheritedWidget {
  const new({required this.state, required super.child});

  final InteractionState state;

  @override
  bool updateShouldNotify(_InteractionStateScope oldWidget) =>
      state != oldWidget.state;
}
