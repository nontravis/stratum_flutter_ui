// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../split_divider_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SplitDividerState {


/// Create a copy of SplitDividerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SplitDividerStateCopyWith<SplitDividerState> get copyWith => _$SplitDividerStateCopyWithImpl<SplitDividerState>(this as SplitDividerState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SplitDividerState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SplitDividerState&&(identical(other.hovered, _this.hovered) || other.hovered == _this.hovered)&&(identical(other.dragging, _this.dragging) || other.dragging == _this.dragging)&&(identical(other.focused, _this.focused) || other.focused == _this.focused));
}


@override
int get hashCode {
  final _this = this as SplitDividerState;
  return Object.hash(runtimeType,_this.hovered,_this.dragging,_this.focused);
}

@override
String toString() {
  final _this = this as SplitDividerState;
  return 'SplitDividerState(hovered: ${_this.hovered}, dragging: ${_this.dragging}, focused: ${_this.focused})';
}


}

/// @nodoc
abstract mixin class $SplitDividerStateCopyWith<$Res>  {
  factory $SplitDividerStateCopyWith(SplitDividerState value, $Res Function(SplitDividerState) _then) = _$SplitDividerStateCopyWithImpl;
@useResult
$Res call({
 bool hovered, bool dragging, bool focused
});




}
/// @nodoc
class _$SplitDividerStateCopyWithImpl<$Res>
    implements $SplitDividerStateCopyWith<$Res> {
  _$SplitDividerStateCopyWithImpl(this._self, this._then);

  final SplitDividerState _self;
  final $Res Function(SplitDividerState) _then;

/// Create a copy of SplitDividerState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hovered = null,Object? dragging = null,Object? focused = null,}) {
  return _then(SplitDividerState(
hovered: null == hovered ? _self.hovered : hovered // ignore: cast_nullable_to_non_nullable
as bool,dragging: null == dragging ? _self.dragging : dragging // ignore: cast_nullable_to_non_nullable
as bool,focused: null == focused ? _self.focused : focused // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



// dart format on
