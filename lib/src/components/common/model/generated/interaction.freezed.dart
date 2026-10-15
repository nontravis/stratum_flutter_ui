// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../interaction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Interaction {

 GestureTapCallback? get onTap;/// Has no keyboard or screen-reader path; never make a function
/// reachable only by double tap (WCAG 2.1.1). Bind a key in
/// [shortcuts] as its keyboard alternative.
 GestureTapCallback? get onDoubleTap; GestureLongPressCallback? get onLongPress;/// Also reached by the context-menu key, Shift+F10, and a semantics
/// action labeled [secondaryTapSemanticsLabel].
 GestureTapCallback? get onSecondaryTap; ValueChanged<bool>? get onHover; ValueChanged<bool>? get onHighlightChanged; MouseCursor? get mouseCursor; bool get enableFeedback;/// See [StratumInkWell.tapTargetSize].
 TapTargetSize get tapTargetSize; bool get disabledPressAnimation; FocusNode? get focusNode; FocusType get focusType; bool get showFocusOnPrimary; bool get canRequestFocus; bool get autofocus; ValueChanged<bool>? get onFocusChange;/// Turns off every callback; the layout then reads as a dimmed button.
 bool get disabled; WidgetStatesController? get statesController; bool get excludeFromSemantics;/// Label of the semantics action for [onSecondaryTap]; null uses
/// `MaterialLocalizations.showMenuTooltip` when material localizations
/// are present, else Stratum's built-in show menu label in the
/// locale's language. See `StratumInkWell.secondaryTapSemanticsLabel`.
 String? get secondaryTapSemanticsLabel;/// Key bindings that fire while the tap surface or a descendant has
/// focus; see `StratumInkWell.shortcuts`.
 Map<ShortcutActivator, VoidCallback> get shortcuts;
/// Create a copy of Interaction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InteractionCopyWith<Interaction> get copyWith => _$InteractionCopyWithImpl<Interaction>(this as Interaction, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Interaction;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Interaction&&(identical(other.onTap, _this.onTap) || other.onTap == _this.onTap)&&(identical(other.onDoubleTap, _this.onDoubleTap) || other.onDoubleTap == _this.onDoubleTap)&&(identical(other.onLongPress, _this.onLongPress) || other.onLongPress == _this.onLongPress)&&(identical(other.onSecondaryTap, _this.onSecondaryTap) || other.onSecondaryTap == _this.onSecondaryTap)&&(identical(other.onHover, _this.onHover) || other.onHover == _this.onHover)&&(identical(other.onHighlightChanged, _this.onHighlightChanged) || other.onHighlightChanged == _this.onHighlightChanged)&&(identical(other.mouseCursor, _this.mouseCursor) || other.mouseCursor == _this.mouseCursor)&&(identical(other.enableFeedback, _this.enableFeedback) || other.enableFeedback == _this.enableFeedback)&&(identical(other.tapTargetSize, _this.tapTargetSize) || other.tapTargetSize == _this.tapTargetSize)&&(identical(other.disabledPressAnimation, _this.disabledPressAnimation) || other.disabledPressAnimation == _this.disabledPressAnimation)&&(identical(other.focusNode, _this.focusNode) || other.focusNode == _this.focusNode)&&(identical(other.focusType, _this.focusType) || other.focusType == _this.focusType)&&(identical(other.showFocusOnPrimary, _this.showFocusOnPrimary) || other.showFocusOnPrimary == _this.showFocusOnPrimary)&&(identical(other.canRequestFocus, _this.canRequestFocus) || other.canRequestFocus == _this.canRequestFocus)&&(identical(other.autofocus, _this.autofocus) || other.autofocus == _this.autofocus)&&(identical(other.onFocusChange, _this.onFocusChange) || other.onFocusChange == _this.onFocusChange)&&(identical(other.disabled, _this.disabled) || other.disabled == _this.disabled)&&(identical(other.statesController, _this.statesController) || other.statesController == _this.statesController)&&(identical(other.excludeFromSemantics, _this.excludeFromSemantics) || other.excludeFromSemantics == _this.excludeFromSemantics)&&(identical(other.secondaryTapSemanticsLabel, _this.secondaryTapSemanticsLabel) || other.secondaryTapSemanticsLabel == _this.secondaryTapSemanticsLabel)&&const DeepCollectionEquality().equals(other.shortcuts, _this.shortcuts));
}


@override
int get hashCode {
  final _this = this as Interaction;
  return Object.hashAll([runtimeType,_this.onTap,_this.onDoubleTap,_this.onLongPress,_this.onSecondaryTap,_this.onHover,_this.onHighlightChanged,_this.mouseCursor,_this.enableFeedback,_this.tapTargetSize,_this.disabledPressAnimation,_this.focusNode,_this.focusType,_this.showFocusOnPrimary,_this.canRequestFocus,_this.autofocus,_this.onFocusChange,_this.disabled,_this.statesController,_this.excludeFromSemantics,_this.secondaryTapSemanticsLabel,const DeepCollectionEquality().hash(_this.shortcuts)]);
}

@override
String toString() {
  final _this = this as Interaction;
  return 'Interaction(onTap: ${_this.onTap}, onDoubleTap: ${_this.onDoubleTap}, onLongPress: ${_this.onLongPress}, onSecondaryTap: ${_this.onSecondaryTap}, onHover: ${_this.onHover}, onHighlightChanged: ${_this.onHighlightChanged}, mouseCursor: ${_this.mouseCursor}, enableFeedback: ${_this.enableFeedback}, tapTargetSize: ${_this.tapTargetSize}, disabledPressAnimation: ${_this.disabledPressAnimation}, focusNode: ${_this.focusNode}, focusType: ${_this.focusType}, showFocusOnPrimary: ${_this.showFocusOnPrimary}, canRequestFocus: ${_this.canRequestFocus}, autofocus: ${_this.autofocus}, onFocusChange: ${_this.onFocusChange}, disabled: ${_this.disabled}, statesController: ${_this.statesController}, excludeFromSemantics: ${_this.excludeFromSemantics}, secondaryTapSemanticsLabel: ${_this.secondaryTapSemanticsLabel}, shortcuts: ${_this.shortcuts})';
}


}

/// @nodoc
abstract mixin class $InteractionCopyWith<$Res>  {
  factory $InteractionCopyWith(Interaction value, $Res Function(Interaction) _then) = _$InteractionCopyWithImpl;
@useResult
$Res call({
 GestureTapCallback? onTap, GestureTapCallback? onDoubleTap, GestureLongPressCallback? onLongPress, GestureTapCallback? onSecondaryTap, ValueChanged<bool>? onHover, ValueChanged<bool>? onHighlightChanged, MouseCursor? mouseCursor, bool enableFeedback, TapTargetSize tapTargetSize, bool disabledPressAnimation, FocusNode? focusNode, FocusType focusType, bool showFocusOnPrimary, bool canRequestFocus, bool autofocus, ValueChanged<bool>? onFocusChange, bool disabled, WidgetStatesController? statesController, bool excludeFromSemantics, String? secondaryTapSemanticsLabel, Map<ShortcutActivator, VoidCallback> shortcuts
});




}
/// @nodoc
class _$InteractionCopyWithImpl<$Res>
    implements $InteractionCopyWith<$Res> {
  _$InteractionCopyWithImpl(this._self, this._then);

  final Interaction _self;
  final $Res Function(Interaction) _then;

/// Create a copy of Interaction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? onTap = freezed,Object? onDoubleTap = freezed,Object? onLongPress = freezed,Object? onSecondaryTap = freezed,Object? onHover = freezed,Object? onHighlightChanged = freezed,Object? mouseCursor = freezed,Object? enableFeedback = null,Object? tapTargetSize = null,Object? disabledPressAnimation = null,Object? focusNode = freezed,Object? focusType = null,Object? showFocusOnPrimary = null,Object? canRequestFocus = null,Object? autofocus = null,Object? onFocusChange = freezed,Object? disabled = null,Object? statesController = freezed,Object? excludeFromSemantics = null,Object? secondaryTapSemanticsLabel = freezed,Object? shortcuts = null,}) {
  return _then(Interaction(
onTap: freezed == onTap ? _self.onTap : onTap // ignore: cast_nullable_to_non_nullable
as GestureTapCallback?,onDoubleTap: freezed == onDoubleTap ? _self.onDoubleTap : onDoubleTap // ignore: cast_nullable_to_non_nullable
as GestureTapCallback?,onLongPress: freezed == onLongPress ? _self.onLongPress : onLongPress // ignore: cast_nullable_to_non_nullable
as GestureLongPressCallback?,onSecondaryTap: freezed == onSecondaryTap ? _self.onSecondaryTap : onSecondaryTap // ignore: cast_nullable_to_non_nullable
as GestureTapCallback?,onHover: freezed == onHover ? _self.onHover : onHover // ignore: cast_nullable_to_non_nullable
as ValueChanged<bool>?,onHighlightChanged: freezed == onHighlightChanged ? _self.onHighlightChanged : onHighlightChanged // ignore: cast_nullable_to_non_nullable
as ValueChanged<bool>?,mouseCursor: freezed == mouseCursor ? _self.mouseCursor : mouseCursor // ignore: cast_nullable_to_non_nullable
as MouseCursor?,enableFeedback: null == enableFeedback ? _self.enableFeedback : enableFeedback // ignore: cast_nullable_to_non_nullable
as bool,tapTargetSize: null == tapTargetSize ? _self.tapTargetSize : tapTargetSize // ignore: cast_nullable_to_non_nullable
as TapTargetSize,disabledPressAnimation: null == disabledPressAnimation ? _self.disabledPressAnimation : disabledPressAnimation // ignore: cast_nullable_to_non_nullable
as bool,focusNode: freezed == focusNode ? _self.focusNode : focusNode // ignore: cast_nullable_to_non_nullable
as FocusNode?,focusType: null == focusType ? _self.focusType : focusType // ignore: cast_nullable_to_non_nullable
as FocusType,showFocusOnPrimary: null == showFocusOnPrimary ? _self.showFocusOnPrimary : showFocusOnPrimary // ignore: cast_nullable_to_non_nullable
as bool,canRequestFocus: null == canRequestFocus ? _self.canRequestFocus : canRequestFocus // ignore: cast_nullable_to_non_nullable
as bool,autofocus: null == autofocus ? _self.autofocus : autofocus // ignore: cast_nullable_to_non_nullable
as bool,onFocusChange: freezed == onFocusChange ? _self.onFocusChange : onFocusChange // ignore: cast_nullable_to_non_nullable
as ValueChanged<bool>?,disabled: null == disabled ? _self.disabled : disabled // ignore: cast_nullable_to_non_nullable
as bool,statesController: freezed == statesController ? _self.statesController : statesController // ignore: cast_nullable_to_non_nullable
as WidgetStatesController?,excludeFromSemantics: null == excludeFromSemantics ? _self.excludeFromSemantics : excludeFromSemantics // ignore: cast_nullable_to_non_nullable
as bool,secondaryTapSemanticsLabel: freezed == secondaryTapSemanticsLabel ? _self.secondaryTapSemanticsLabel : secondaryTapSemanticsLabel // ignore: cast_nullable_to_non_nullable
as String?,shortcuts: null == shortcuts ? _self.shortcuts : shortcuts // ignore: cast_nullable_to_non_nullable
as Map<ShortcutActivator, VoidCallback>,
  ));
}

}



/// @nodoc


class _Interaction implements Interaction {
  const _Interaction({this.onTap, this.onDoubleTap, this.onLongPress, this.onSecondaryTap, this.onHover, this.onHighlightChanged, this.mouseCursor, this.enableFeedback = true, this.tapTargetSize = TapTargetSize.platform, this.disabledPressAnimation = false, this.focusNode, this.focusType = FocusType.focusedVisible, this.showFocusOnPrimary = true, this.canRequestFocus = true, this.autofocus = false, this.onFocusChange, this.disabled = false, this.statesController, this.excludeFromSemantics = false, this.secondaryTapSemanticsLabel,  Map<ShortcutActivator, VoidCallback> shortcuts = const <ShortcutActivator, VoidCallback>{}}): _shortcuts = shortcuts;
  

@override final  GestureTapCallback? onTap;
/// Has no keyboard or screen-reader path; never make a function
/// reachable only by double tap (WCAG 2.1.1). Bind a key in
/// [shortcuts] as its keyboard alternative.
@override final  GestureTapCallback? onDoubleTap;
@override final  GestureLongPressCallback? onLongPress;
/// Also reached by the context-menu key, Shift+F10, and a semantics
/// action labeled [secondaryTapSemanticsLabel].
@override final  GestureTapCallback? onSecondaryTap;
@override final  ValueChanged<bool>? onHover;
@override final  ValueChanged<bool>? onHighlightChanged;
@override final  MouseCursor? mouseCursor;
@override@JsonKey() final  bool enableFeedback;
/// See [StratumInkWell.tapTargetSize].
@override@JsonKey() final  TapTargetSize tapTargetSize;
@override@JsonKey() final  bool disabledPressAnimation;
@override final  FocusNode? focusNode;
@override@JsonKey() final  FocusType focusType;
@override@JsonKey() final  bool showFocusOnPrimary;
@override@JsonKey() final  bool canRequestFocus;
@override@JsonKey() final  bool autofocus;
@override final  ValueChanged<bool>? onFocusChange;
/// Turns off every callback; the layout then reads as a dimmed button.
@override@JsonKey() final  bool disabled;
@override final  WidgetStatesController? statesController;
@override@JsonKey() final  bool excludeFromSemantics;
/// Label of the semantics action for [onSecondaryTap]; null uses
/// `MaterialLocalizations.showMenuTooltip` when material localizations
/// are present, else Stratum's built-in show menu label in the
/// locale's language. See `StratumInkWell.secondaryTapSemanticsLabel`.
@override final  String? secondaryTapSemanticsLabel;
/// Key bindings that fire while the tap surface or a descendant has
/// focus; see `StratumInkWell.shortcuts`.
 final  Map<ShortcutActivator, VoidCallback> _shortcuts;
/// Key bindings that fire while the tap surface or a descendant has
/// focus; see `StratumInkWell.shortcuts`.
@override@JsonKey() Map<ShortcutActivator, VoidCallback> get shortcuts {
  if (_shortcuts is EqualUnmodifiableMapView) return _shortcuts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_shortcuts);
}


/// Create a copy of Interaction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InteractionCopyWith<_Interaction> get copyWith => __$InteractionCopyWithImpl<_Interaction>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Interaction&&(identical(other.onTap, onTap) || other.onTap == onTap)&&(identical(other.onDoubleTap, onDoubleTap) || other.onDoubleTap == onDoubleTap)&&(identical(other.onLongPress, onLongPress) || other.onLongPress == onLongPress)&&(identical(other.onSecondaryTap, onSecondaryTap) || other.onSecondaryTap == onSecondaryTap)&&(identical(other.onHover, onHover) || other.onHover == onHover)&&(identical(other.onHighlightChanged, onHighlightChanged) || other.onHighlightChanged == onHighlightChanged)&&(identical(other.mouseCursor, mouseCursor) || other.mouseCursor == mouseCursor)&&(identical(other.enableFeedback, enableFeedback) || other.enableFeedback == enableFeedback)&&(identical(other.tapTargetSize, tapTargetSize) || other.tapTargetSize == tapTargetSize)&&(identical(other.disabledPressAnimation, disabledPressAnimation) || other.disabledPressAnimation == disabledPressAnimation)&&(identical(other.focusNode, focusNode) || other.focusNode == focusNode)&&(identical(other.focusType, focusType) || other.focusType == focusType)&&(identical(other.showFocusOnPrimary, showFocusOnPrimary) || other.showFocusOnPrimary == showFocusOnPrimary)&&(identical(other.canRequestFocus, canRequestFocus) || other.canRequestFocus == canRequestFocus)&&(identical(other.autofocus, autofocus) || other.autofocus == autofocus)&&(identical(other.onFocusChange, onFocusChange) || other.onFocusChange == onFocusChange)&&(identical(other.disabled, disabled) || other.disabled == disabled)&&(identical(other.statesController, statesController) || other.statesController == statesController)&&(identical(other.excludeFromSemantics, excludeFromSemantics) || other.excludeFromSemantics == excludeFromSemantics)&&(identical(other.secondaryTapSemanticsLabel, secondaryTapSemanticsLabel) || other.secondaryTapSemanticsLabel == secondaryTapSemanticsLabel)&&const DeepCollectionEquality().equals(other.shortcuts, _shortcuts));
}


@override
int get hashCode {
    return Object.hashAll([runtimeType,onTap,onDoubleTap,onLongPress,onSecondaryTap,onHover,onHighlightChanged,mouseCursor,enableFeedback,tapTargetSize,disabledPressAnimation,focusNode,focusType,showFocusOnPrimary,canRequestFocus,autofocus,onFocusChange,disabled,statesController,excludeFromSemantics,secondaryTapSemanticsLabel,const DeepCollectionEquality().hash(_shortcuts)]);
}

@override
String toString() {
    return 'Interaction(onTap: $onTap, onDoubleTap: $onDoubleTap, onLongPress: $onLongPress, onSecondaryTap: $onSecondaryTap, onHover: $onHover, onHighlightChanged: $onHighlightChanged, mouseCursor: $mouseCursor, enableFeedback: $enableFeedback, tapTargetSize: $tapTargetSize, disabledPressAnimation: $disabledPressAnimation, focusNode: $focusNode, focusType: $focusType, showFocusOnPrimary: $showFocusOnPrimary, canRequestFocus: $canRequestFocus, autofocus: $autofocus, onFocusChange: $onFocusChange, disabled: $disabled, statesController: $statesController, excludeFromSemantics: $excludeFromSemantics, secondaryTapSemanticsLabel: $secondaryTapSemanticsLabel, shortcuts: $shortcuts)';
}


}

/// @nodoc
abstract mixin class _$InteractionCopyWith<$Res> implements $InteractionCopyWith<$Res> {
  factory _$InteractionCopyWith(_Interaction value, $Res Function(_Interaction) _then) = __$InteractionCopyWithImpl;
@override @useResult
$Res call({
 GestureTapCallback? onTap, GestureTapCallback? onDoubleTap, GestureLongPressCallback? onLongPress, GestureTapCallback? onSecondaryTap, ValueChanged<bool>? onHover, ValueChanged<bool>? onHighlightChanged, MouseCursor? mouseCursor, bool enableFeedback, TapTargetSize tapTargetSize, bool disabledPressAnimation, FocusNode? focusNode, FocusType focusType, bool showFocusOnPrimary, bool canRequestFocus, bool autofocus, ValueChanged<bool>? onFocusChange, bool disabled, WidgetStatesController? statesController, bool excludeFromSemantics, String? secondaryTapSemanticsLabel, Map<ShortcutActivator, VoidCallback> shortcuts
});




}
/// @nodoc
class __$InteractionCopyWithImpl<$Res>
    implements _$InteractionCopyWith<$Res> {
  __$InteractionCopyWithImpl(this._self, this._then);

  final _Interaction _self;
  final $Res Function(_Interaction) _then;

/// Create a copy of Interaction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? onTap = freezed,Object? onDoubleTap = freezed,Object? onLongPress = freezed,Object? onSecondaryTap = freezed,Object? onHover = freezed,Object? onHighlightChanged = freezed,Object? mouseCursor = freezed,Object? enableFeedback = null,Object? tapTargetSize = null,Object? disabledPressAnimation = null,Object? focusNode = freezed,Object? focusType = null,Object? showFocusOnPrimary = null,Object? canRequestFocus = null,Object? autofocus = null,Object? onFocusChange = freezed,Object? disabled = null,Object? statesController = freezed,Object? excludeFromSemantics = null,Object? secondaryTapSemanticsLabel = freezed,Object? shortcuts = null,}) {
  return _then(_Interaction(
onTap: freezed == onTap ? _self.onTap : onTap // ignore: cast_nullable_to_non_nullable
as GestureTapCallback?,onDoubleTap: freezed == onDoubleTap ? _self.onDoubleTap : onDoubleTap // ignore: cast_nullable_to_non_nullable
as GestureTapCallback?,onLongPress: freezed == onLongPress ? _self.onLongPress : onLongPress // ignore: cast_nullable_to_non_nullable
as GestureLongPressCallback?,onSecondaryTap: freezed == onSecondaryTap ? _self.onSecondaryTap : onSecondaryTap // ignore: cast_nullable_to_non_nullable
as GestureTapCallback?,onHover: freezed == onHover ? _self.onHover : onHover // ignore: cast_nullable_to_non_nullable
as ValueChanged<bool>?,onHighlightChanged: freezed == onHighlightChanged ? _self.onHighlightChanged : onHighlightChanged // ignore: cast_nullable_to_non_nullable
as ValueChanged<bool>?,mouseCursor: freezed == mouseCursor ? _self.mouseCursor : mouseCursor // ignore: cast_nullable_to_non_nullable
as MouseCursor?,enableFeedback: null == enableFeedback ? _self.enableFeedback : enableFeedback // ignore: cast_nullable_to_non_nullable
as bool,tapTargetSize: null == tapTargetSize ? _self.tapTargetSize : tapTargetSize // ignore: cast_nullable_to_non_nullable
as TapTargetSize,disabledPressAnimation: null == disabledPressAnimation ? _self.disabledPressAnimation : disabledPressAnimation // ignore: cast_nullable_to_non_nullable
as bool,focusNode: freezed == focusNode ? _self.focusNode : focusNode // ignore: cast_nullable_to_non_nullable
as FocusNode?,focusType: null == focusType ? _self.focusType : focusType // ignore: cast_nullable_to_non_nullable
as FocusType,showFocusOnPrimary: null == showFocusOnPrimary ? _self.showFocusOnPrimary : showFocusOnPrimary // ignore: cast_nullable_to_non_nullable
as bool,canRequestFocus: null == canRequestFocus ? _self.canRequestFocus : canRequestFocus // ignore: cast_nullable_to_non_nullable
as bool,autofocus: null == autofocus ? _self.autofocus : autofocus // ignore: cast_nullable_to_non_nullable
as bool,onFocusChange: freezed == onFocusChange ? _self.onFocusChange : onFocusChange // ignore: cast_nullable_to_non_nullable
as ValueChanged<bool>?,disabled: null == disabled ? _self.disabled : disabled // ignore: cast_nullable_to_non_nullable
as bool,statesController: freezed == statesController ? _self.statesController : statesController // ignore: cast_nullable_to_non_nullable
as WidgetStatesController?,excludeFromSemantics: null == excludeFromSemantics ? _self.excludeFromSemantics : excludeFromSemantics // ignore: cast_nullable_to_non_nullable
as bool,secondaryTapSemanticsLabel: freezed == secondaryTapSemanticsLabel ? _self.secondaryTapSemanticsLabel : secondaryTapSemanticsLabel // ignore: cast_nullable_to_non_nullable
as String?,shortcuts: null == shortcuts ? _self._shortcuts : shortcuts // ignore: cast_nullable_to_non_nullable
as Map<ShortcutActivator, VoidCallback>,
  ));
}


}

// dart format on
