// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../focus_group.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FocusGroup {

/// The semantics role of the group node.
///
/// Flutter's debug checks constrain the items, which take their role
/// through their own `semantics:` (`SemanticsProperties(role: ...)`):
/// `tabBar` needs at least one item and every item with role `tab`;
/// `menu` and `menuBar` need at least one item, and a `menuItem` must sit
/// under one of them; `radioGroup` allows at most one checked item;
/// `list` has no check. Set `menu`, `menuBar`, or `tabBar` only when
/// items exist.
 SemanticsRole? get role;/// Whether arrows wrap from the last item to the first and back.
 bool get loop;
/// Create a copy of FocusGroup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FocusGroupCopyWith<FocusGroup> get copyWith => _$FocusGroupCopyWithImpl<FocusGroup>(this as FocusGroup, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as FocusGroup;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FocusGroup&&(identical(other.role, _this.role) || other.role == _this.role)&&(identical(other.loop, _this.loop) || other.loop == _this.loop));
}


@override
int get hashCode {
  final _this = this as FocusGroup;
  return Object.hash(runtimeType,_this.role,_this.loop);
}

@override
String toString() {
  final _this = this as FocusGroup;
  return 'FocusGroup(role: ${_this.role}, loop: ${_this.loop})';
}


}

/// @nodoc
abstract mixin class $FocusGroupCopyWith<$Res>  {
  factory $FocusGroupCopyWith(FocusGroup value, $Res Function(FocusGroup) _then) = _$FocusGroupCopyWithImpl;
@useResult
$Res call({
 SemanticsRole? role, bool loop
});




}
/// @nodoc
class _$FocusGroupCopyWithImpl<$Res>
    implements $FocusGroupCopyWith<$Res> {
  _$FocusGroupCopyWithImpl(this._self, this._then);

  final FocusGroup _self;
  final $Res Function(FocusGroup) _then;

/// Create a copy of FocusGroup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? role = freezed,Object? loop = null,}) {
  return _then(FocusGroup(
role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as SemanticsRole?,loop: null == loop ? _self.loop : loop // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc


class _FocusGroup implements FocusGroup {
  const _FocusGroup({this.role, this.loop = false});
  

/// The semantics role of the group node.
///
/// Flutter's debug checks constrain the items, which take their role
/// through their own `semantics:` (`SemanticsProperties(role: ...)`):
/// `tabBar` needs at least one item and every item with role `tab`;
/// `menu` and `menuBar` need at least one item, and a `menuItem` must sit
/// under one of them; `radioGroup` allows at most one checked item;
/// `list` has no check. Set `menu`, `menuBar`, or `tabBar` only when
/// items exist.
@override final  SemanticsRole? role;
/// Whether arrows wrap from the last item to the first and back.
@override@JsonKey() final  bool loop;

/// Create a copy of FocusGroup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FocusGroupCopyWith<_FocusGroup> get copyWith => __$FocusGroupCopyWithImpl<_FocusGroup>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FocusGroup&&(identical(other.role, role) || other.role == role)&&(identical(other.loop, loop) || other.loop == loop));
}


@override
int get hashCode {
    return Object.hash(runtimeType,role,loop);
}

@override
String toString() {
    return 'FocusGroup(role: $role, loop: $loop)';
}


}

/// @nodoc
abstract mixin class _$FocusGroupCopyWith<$Res> implements $FocusGroupCopyWith<$Res> {
  factory _$FocusGroupCopyWith(_FocusGroup value, $Res Function(_FocusGroup) _then) = __$FocusGroupCopyWithImpl;
@override @useResult
$Res call({
 SemanticsRole? role, bool loop
});




}
/// @nodoc
class __$FocusGroupCopyWithImpl<$Res>
    implements _$FocusGroupCopyWith<$Res> {
  __$FocusGroupCopyWithImpl(this._self, this._then);

  final _FocusGroup _self;
  final $Res Function(_FocusGroup) _then;

/// Create a copy of FocusGroup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? role = freezed,Object? loop = null,}) {
  return _then(_FocusGroup(
role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as SemanticsRole?,loop: null == loop ? _self.loop : loop // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
