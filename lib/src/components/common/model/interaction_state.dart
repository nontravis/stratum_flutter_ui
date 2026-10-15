import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/interaction_state.freezed.dart';

/// The hovered, pressed, focused, and disabled values of a box layout's
/// tap surface, which `ContainerLayout.builder` builds its content from.
///
/// [hovered] is true while a pointer is over the tap surface, with or
/// without an activation callback, as `Interaction.onHover` reports it, or
/// while a caller sets `WidgetState.hovered` through
/// `Interaction.statesController`; [pressed] while the surface is held
/// down; both are false while [disabled]. [focused] is true exactly while
/// the surface shows its focus ring: under `FocusType.focusedVisible`, the
/// default, while focus highlights are in keyboard (traditional) mode, so a
/// mouse click on the card does not set it, and on any focus under
/// `FocusType.focused`. [disabled] is the interaction's own `disabled` or a
/// disabled component around the surface. With no tap surface every value is
/// false.
///
/// No state may show by color alone: pair a state color with text, an
/// icon, or a shape (WCAG 1.4.1).
@valueModel
abstract class InteractionState with _$InteractionState {
  const factory({
    @Default(false) bool hovered,
    @Default(false) bool pressed,
    @Default(false) bool focused,
    @Default(false) bool disabled,
  }) = _InteractionState;
}
