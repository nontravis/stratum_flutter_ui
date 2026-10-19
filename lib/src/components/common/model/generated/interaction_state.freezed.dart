// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../interaction_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$InteractionState {

 bool get hovered; bool get pressed; bool get focused; bool get disabled;
/// Create a copy of InteractionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InteractionStateCopyWith<InteractionState> get copyWith => _$InteractionStateCopyWithImpl<InteractionState>(this as InteractionState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as InteractionState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InteractionState&&(identical(other.hovered, _this.hovered) || other.hovered == _this.hovered)&&(identical(other.pressed, _this.pressed) || other.pressed == _this.pressed)&&(identical(other.focused, _this.focused) || other.focused == _this.focused)&&(identical(other.disabled, _this.disabled) || other.disabled == _this.disabled));
}


@override
int get hashCode {
  final _this = this as InteractionState;
  return Object.hash(runtimeType,_this.hovered,_this.pressed,_this.focused,_this.disabled);
}

@override
String toString() {
  final _this = this as InteractionState;
  return 'InteractionState(hovered: ${_this.hovered}, pressed: ${_this.pressed}, focused: ${_this.focused}, disabled: ${_this.disabled})';
}


}

/// @nodoc
abstract mixin class $InteractionStateCopyWith<$Res>  {
  factory $InteractionStateCopyWith(InteractionState value, $Res Function(InteractionState) _then) = _$InteractionStateCopyWithImpl;
@useResult
$Res call({
 bool hovered, bool pressed, bool focused, bool disabled
});




}
/// @nodoc
class _$InteractionStateCopyWithImpl<$Res>
    implements $InteractionStateCopyWith<$Res> {
  _$InteractionStateCopyWithImpl(this._self, this._then);

  final InteractionState _self;
  final $Res Function(InteractionState) _then;

/// Create a copy of InteractionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hovered = null,Object? pressed = null,Object? focused = null,Object? disabled = null,}) {
  return _then(InteractionState(
hovered: null == hovered ? _self.hovered : hovered // ignore: cast_nullable_to_non_nullable
as bool,pressed: null == pressed ? _self.pressed : pressed // ignore: cast_nullable_to_non_nullable
as bool,focused: null == focused ? _self.focused : focused // ignore: cast_nullable_to_non_nullable
as bool,disabled: null == disabled ? _self.disabled : disabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc


class _InteractionState implements InteractionState {
  const _InteractionState({this.hovered = false, this.pressed = false, this.focused = false, this.disabled = false});
  

@override@JsonKey() final  bool hovered;
@override@JsonKey() final  bool pressed;
@override@JsonKey() final  bool focused;
@override@JsonKey() final  bool disabled;

/// Create a copy of InteractionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InteractionStateCopyWith<_InteractionState> get copyWith => __$InteractionStateCopyWithImpl<_InteractionState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _InteractionState&&(identical(other.hovered, hovered) || other.hovered == hovered)&&(identical(other.pressed, pressed) || other.pressed == pressed)&&(identical(other.focused, focused) || other.focused == focused)&&(identical(other.disabled, disabled) || other.disabled == disabled));
}


@override
int get hashCode {
    return Object.hash(runtimeType,hovered,pressed,focused,disabled);
}

@override
String toString() {
    return 'InteractionState(hovered: $hovered, pressed: $pressed, focused: $focused, disabled: $disabled)';
}


}

/// @nodoc
abstract mixin class _$InteractionStateCopyWith<$Res> implements $InteractionStateCopyWith<$Res> {
  factory _$InteractionStateCopyWith(_InteractionState value, $Res Function(_InteractionState) _then) = __$InteractionStateCopyWithImpl;
@override @useResult
$Res call({
 bool hovered, bool pressed, bool focused, bool disabled
});




}
/// @nodoc
class __$InteractionStateCopyWithImpl<$Res>
    implements _$InteractionStateCopyWith<$Res> {
  __$InteractionStateCopyWithImpl(this._self, this._then);

  final _InteractionState _self;
  final $Res Function(_InteractionState) _then;

/// Create a copy of InteractionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hovered = null,Object? pressed = null,Object? focused = null,Object? disabled = null,}) {
  return _then(_InteractionState(
hovered: null == hovered ? _self.hovered : hovered // ignore: cast_nullable_to_non_nullable
as bool,pressed: null == pressed ? _self.pressed : pressed // ignore: cast_nullable_to_non_nullable
as bool,focused: null == focused ? _self.focused : focused // ignore: cast_nullable_to_non_nullable
as bool,disabled: null == disabled ? _self.disabled : disabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
