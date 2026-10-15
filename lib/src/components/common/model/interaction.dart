import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/interaction.freezed.dart';

/// The pointer, focus, keyboard, and semantics settings of a layout's tap
/// surface.
///
/// A layout passes these to [StratumInkWell], one field to one parameter.
/// It builds the tap surface only when at least one of [onTap],
/// [onDoubleTap], [onLongPress], [onSecondaryTap], [onHover],
/// [onHighlightChanged], or [onFocusChange] is set, or [shortcuts] is not
/// empty. A value with none of them still animates the layout's style over
/// the theme's `fast` level and adds no tap surface, so pass
/// `const Interaction()` when callbacks come and go: switching
/// `interaction` between null and a value remounts the content on an
/// otherwise bare layout; see `BoxLayout`'s tier rule for the full case.
///
/// `==` compares every field; the callbacks, [focusNode], and
/// [statesController] compare by identity (R1).
@valueModel
abstract class Interaction with _$Interaction {
  const factory({
    GestureTapCallback? onTap,

    /// Has no keyboard or screen-reader path; never make a function
    /// reachable only by double tap (WCAG 2.1.1). Bind a key in
    /// [shortcuts] as its keyboard alternative.
    GestureTapCallback? onDoubleTap,
    GestureLongPressCallback? onLongPress,

    /// Also reached by the context-menu key, Shift+F10, and a semantics
    /// action labeled [secondaryTapSemanticsLabel].
    GestureTapCallback? onSecondaryTap,
    ValueChanged<bool>? onHover,
    ValueChanged<bool>? onHighlightChanged,
    MouseCursor? mouseCursor,
    @Default(true) bool enableFeedback,

    /// See [StratumInkWell.tapTargetSize].
    @Default(TapTargetSize.platform) TapTargetSize tapTargetSize,
    @Default(false) bool disabledPressAnimation,
    FocusNode? focusNode,
    @Default(FocusType.focusedVisible) FocusType focusType,
    @Default(true) bool showFocusOnPrimary,
    @Default(true) bool canRequestFocus,
    @Default(false) bool autofocus,
    ValueChanged<bool>? onFocusChange,

    /// Turns off every callback; the layout then reads as a dimmed button.
    @Default(false) bool disabled,
    WidgetStatesController? statesController,
    @Default(false) bool excludeFromSemantics,

    /// Label of the semantics action for [onSecondaryTap]; null uses
    /// `MaterialLocalizations.showMenuTooltip` when material localizations
    /// are present, else Stratum's built-in show menu label in the
    /// locale's language. See `StratumInkWell.secondaryTapSemanticsLabel`.
    String? secondaryTapSemanticsLabel,

    /// Key bindings that fire while the tap surface or a descendant has
    /// focus; see `StratumInkWell.shortcuts`.
    @Default(<ShortcutActivator, VoidCallback>{})
    Map<ShortcutActivator, VoidCallback> shortcuts,
  }) = _Interaction;
}
