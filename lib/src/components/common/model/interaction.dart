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

/// [Interaction]'s name before naming rule R2, kept one minor version.
@Deprecated(
  'Use Interaction instead. StratumInteraction will be removed after one '
  'minor version.',
)
typedef StratumInteraction = Interaction;

/// The hovered, pressed, focused, and disabled values of a box layout's
/// tap surface, which `ContainerLayout.builder` builds its content from.
///
/// [hovered] is true while a pointer is over the tap surface, with or
/// without an activation callback, as [Interaction.onHover] reports it, or
/// while a caller sets [WidgetState.hovered] through
/// [Interaction.statesController]; [pressed] while the surface is held
/// down; both are false while [disabled]. [focused] is true exactly while
/// the surface shows its focus ring: under [FocusType.focusedVisible], the
/// default, while focus highlights are in keyboard (traditional) mode, so a
/// mouse click on the card does not set it, and on any focus under
/// [FocusType.focused]. [disabled] is the interaction's own `disabled` or a
/// disabled component around the surface. With no tap surface every value is
/// false.
///
/// No state may show by color alone: pair a state color with text, an
/// icon, or a shape (WCAG 1.4.1).
@immutable
class InteractionState {
  const new({
    this.hovered = false,
    this.pressed = false,
    this.focused = false,
    this.disabled = false,
  });

  final bool hovered;
  final bool pressed;
  final bool focused;
  final bool disabled;

  @override
  bool operator ==(Object other) =>
      other is InteractionState &&
      other.hovered == hovered &&
      other.pressed == pressed &&
      other.focused == focused &&
      other.disabled == disabled;

  @override
  int get hashCode => Object.hash(hovered, pressed, focused, disabled);
}
