// Ignore because unnecessary
// ignore_for_file: avoid_bool_literals_in_conditional_expressions

import 'package:stratum_ui/src/src.dart';

class GestureContainerLayout extends StatefulWidget {
  const GestureContainerLayout({
    super.key,
    this.style,
    this.ratio,
    this.rotate,
    this.keepAlive = false,
    this.repaintBoundary = false,
    this.debug = false,
    this.transform,
    this.transformAlignment,
    this.onEndAnimate,
    //=== InkWell ===//
    this.disabledPressAnimation = false,
    this.disabled = false,
    this.onTap,
    this.onSecondaryPress,
    this.onDoubleTap,
    this.onLongPress,
    this.onHighlightChanged,
    this.onHover,
    this.mouseCursor,
    this.enableFeedback = true,
    this.excludeFromSemantics = false,
    this.focusNode,
    this.focusType = FocusType.focusedVisible,
    this.showFocusOnPrimary = true,
    this.canRequestFocus = true,
    this.onFocusChange,
    this.autofocus = false,
    this.statesController,
    this.semantics,
    //===============//
    this.child,
  });

  ///========== Frame ==========///
  final double? rotate; // 0-360 degree
  final double? ratio;

  ///========== Layout ==========///
  final Alignment? transformAlignment;
  final Matrix4? transform;
  final bool keepAlive;
  final bool repaintBoundary;
  final bool debug;

  ///===== Animate ======///
  final VoidCallback? onEndAnimate;

  ///===== Effect ======///

  ///========== Style ==========///
  /// Style changes animate over 100 ms unless the style sets its own
  /// `animationStyle`, keeping the old `animate: true` default.
  final WidgetStyle? style;

  ///===== InkWell ======///
  final bool disabledPressAnimation;
  final bool disabled;
  final GestureTapCallback? onTap;
  final GestureTapCallback? onSecondaryPress;
  final GestureTapCallback? onDoubleTap;
  final GestureLongPressCallback? onLongPress;
  final ValueChanged<bool>? onHighlightChanged;
  final ValueChanged<bool>? onHover;
  final MouseCursor? mouseCursor;
  final bool enableFeedback;
  final bool excludeFromSemantics;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChange;
  final FocusType focusType;
  final bool showFocusOnPrimary;
  final bool autofocus;
  final bool canRequestFocus;
  final WidgetStatesController? statesController;

  final SemanticsProperties? semantics;

  ///===== Child Widget ======///
  final Widget? child;

  @override
  State<GestureContainerLayout> createState() => _GestureContainerLayoutState();
}

class _GestureContainerLayoutState extends FalconState<GestureContainerLayout> {
  // ========== Focus & Input State ==========
  late FocusNode _focusNode;
  bool _isFocusSpread = false;

  InputMethod get currentInputMethod => _currentInputMethod;
  InputMethod _currentInputMethod = InputMethod.none;

  // ========== Cache Initialization Guard ==========
  bool _cacheInitialized = false;

  // ========== Cached Computed Values ==========
  late bool _hasGestures;
  late bool _canFocus;

  // ========== Cached Theme Colors ==========
  Color? _hoverColor;
  Color? _splashColor;
  Color? _highlightColor;

  // ========== Lifecycle Methods ==========

  @override
  void initState() {
    super.initState();
    // Initialize focus node and keyboard handler (no theme access needed)
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
    ServicesBinding.instance.keyboard.addHandler(_handleKeyEvent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Initialize all cached values once when theme context is available
    if (!_cacheInitialized) {
      _initializeComputedValues();
      _initializeThemeValues();
      _cacheInitialized = true;
    }
  }

  // ========== Cache Initialization Methods ==========

  /// Initialize computed values (gestures, focus, padding, border radius)
  void _initializeComputedValues() {
    _hasGestures =
        widget.onTap != null ||
        widget.onSecondaryPress != null ||
        widget.onLongPress != null ||
        widget.onDoubleTap != null ||
        widget.onHover != null ||
        widget.onHighlightChanged != null;

    _canFocus = widget.focusType.isNotNone;
  }

  /// Initialize theme-dependent values (colors)
  void _initializeThemeValues() {
    final theme = context.theme;
    if (!widget.disabledPressAnimation) {
      _hoverColor = theme.color.overlayHover;
      _splashColor = theme.color.overlayActive;
      _highlightColor = theme.color.overlayActive;
    }
  }

  @override
  void didUpdateWidget(GestureContainerLayout oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update focus node if changed
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_handleFocusChange);
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_handleFocusChange);
    }

    if (_cacheInitialized) {
      // Smart cache invalidation - only recompute what changed
      final needsComputedUpdate =
          oldWidget.disabled != widget.disabled ||
          oldWidget.onTap != widget.onTap ||
          oldWidget.onSecondaryPress != widget.onSecondaryPress ||
          oldWidget.onLongPress != widget.onLongPress ||
          oldWidget.onDoubleTap != widget.onDoubleTap ||
          oldWidget.onHover != widget.onHover ||
          oldWidget.onHighlightChanged != widget.onHighlightChanged ||
          oldWidget.focusType != widget.focusType;

      final needsThemeUpdate =
          oldWidget.disabledPressAnimation != widget.disabledPressAnimation;

      if (needsComputedUpdate) {
        _initializeComputedValues();
      }

      if (needsThemeUpdate) {
        _initializeThemeValues();
      }

      // Reset state if widget becomes disabled
      if (!oldWidget.disabled && widget.disabled) {
        _clearInputState();
      }
    }
  }

  static const _defaultAnimation = AnimationStyle(
    duration: Duration(milliseconds: 100),
  );

  WidgetStyle? get _effectiveStyle {
    final style = widget.style;
    if (style == null || style.animationStyle != null) return style;
    return style.copyWith(animationStyle: _defaultAnimation);
  }

  @override
  Widget buildStates(BuildContext context, FullWidgetStates states) {
    // Build child content with constraints and padding
    Widget content = ContainerLayout(
      style: _effectiveStyle,
      ratio: widget.ratio,
      rotate: widget.rotate,
      keepAlive: widget.keepAlive,
      repaintBoundary: widget.repaintBoundary,
      debug: widget.debug,
      transform: widget.transform,
      transformAlignment: widget.transformAlignment,
      onEndAnimate: widget.onEndAnimate,
      child: widget.child,
    );

    if (_hasGestures) {
      content = _buildGestureWrapper(context, content);
    }

    // Apply focus spread only if needed
    if (!widget.disabled &&
        _canFocus &&
        (widget.focusType.isFocused || widget.focusType.isFocusedVisible)) {
      content = FocusSpread(
        focus: _isFocusSpread,
        borderRadius: widget.style?.borderRadius,
        child: content,
      );
    }

    // Apply semantics if provided or auto-generate for interactive elements
    if (widget.semantics != null) {
      content = Semantics.fromProperties(
        properties: widget.semantics!,
        child: content,
      );
    }

    return content;
  }

  Widget _buildGestureWrapper(BuildContext context, Widget child) {
    // Build Material InkWell for complex gestures
    Widget result = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: widget.style?.borderRadius?.resolve(
          Directionality.of(context),
        ),
        hoverColor: widget.disabledPressAnimation
            ? Colors.transparent
            : _hoverColor,
        focusColor: Colors.transparent,
        splashColor: widget.disabledPressAnimation
            ? Colors.transparent
            : _splashColor,
        highlightColor: widget.disabledPressAnimation
            ? Colors.transparent
            : _highlightColor,
        mouseCursor:
            widget.mouseCursor ??
            (widget.disabled ? SystemMouseCursors.forbidden : null),
        enableFeedback: widget.enableFeedback,
        excludeFromSemantics: widget.excludeFromSemantics,
        focusNode: _canFocus ? _focusNode : null,
        canRequestFocus: _canFocus && widget.canRequestFocus,
        autofocus: _canFocus && widget.autofocus,
        statesController: widget.statesController,
        onTap: widget.onTap != null && !widget.disabled ? _handleTap : null,
        onSecondaryTap: !widget.disabled ? widget.onSecondaryPress : null,
        onDoubleTap: !widget.disabled ? widget.onDoubleTap : null,
        onLongPress: !widget.disabled ? widget.onLongPress : null,
        onHighlightChanged: !widget.disabled ? widget.onHighlightChanged : null,
        onHover: !widget.disabled ? _handleHover : null,
        child: child,
      ),
    );

    // Add pointer handling if needed
    if (_canFocus || widget.onHover != null) {
      result = Listener(
        onPointerDown: _handlePointerDown,
        child: result,
      );
    }

    return result;
  }

  void _updateFocusSpread() {
    final hasFocus = widget.showFocusOnPrimary
        ? _focusNode.hasPrimaryFocus
        : _focusNode.hasFocus;

    if (widget.focusType.isFocusedVisible && hasFocus) {
      if (_currentInputMethod.isKeyboard) {
        setState(() => _isFocusSpread = true);
      } else {
        setState(() => _isFocusSpread = false);
      }
    } else if (widget.focusType.isFocused && hasFocus) {
      setState(() => _isFocusSpread = true);
    } else {
      setState(() => _isFocusSpread = false);
    }
  }

  void _handleTap() {
    _focusNode.requestFocus();
    _updateFocusSpread();
    widget.onTap?.call();
  }

  void _handleHover(bool value) {
    _currentInputMethod = InputMethod.pointer;
    widget.onHover?.call(value);
  }

  void _handlePointerDown(PointerDownEvent event) {
    _currentInputMethod = InputMethod.pointer;
  }

  void _handleFocusChange() {
    _updateFocusSpread();
    widget.onFocusChange?.call(_focusNode.hasFocus);
  }

  bool _handleKeyEvent(KeyEvent event) {
    _currentInputMethod = InputMethod.keyboard;
    return false;
  }

  void _clearInputState() {
    _isFocusSpread = false;
    _currentInputMethod = InputMethod.none;
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    ServicesBinding.instance.keyboard.removeHandler(_handleKeyEvent);
    super.dispose();
  }
}
