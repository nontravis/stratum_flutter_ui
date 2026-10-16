// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../widget_setting_key.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$WidgetSettingKey {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is WidgetSettingKey);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'WidgetSettingKey()';
}


}

/// @nodoc
class $WidgetSettingKeyCopyWith<$Res>  {
$WidgetSettingKeyCopyWith(WidgetSettingKey _, $Res Function(WidgetSettingKey) __);
}



/// @nodoc


class WidgetSettingGlobal implements WidgetSettingKey {
  const WidgetSettingGlobal();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is WidgetSettingGlobal);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'WidgetSettingKey.global()';
}


}




/// @nodoc


class WidgetSettingId implements WidgetSettingKey {
  const WidgetSettingId(this.id);
  

 final  String id;

/// Create a copy of WidgetSettingKey
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WidgetSettingIdCopyWith<WidgetSettingId> get copyWith => _$WidgetSettingIdCopyWithImpl<WidgetSettingId>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is WidgetSettingId&&(identical(other.id, id) || other.id == id));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id);
}

@override
String toString() {
    return 'WidgetSettingKey.id(id: $id)';
}


}

/// @nodoc
abstract mixin class $WidgetSettingIdCopyWith<$Res> implements $WidgetSettingKeyCopyWith<$Res> {
  factory $WidgetSettingIdCopyWith(WidgetSettingId value, $Res Function(WidgetSettingId) _then) = _$WidgetSettingIdCopyWithImpl;
@useResult
$Res call({
 String id
});




}
/// @nodoc
class _$WidgetSettingIdCopyWithImpl<$Res>
    implements $WidgetSettingIdCopyWith<$Res> {
  _$WidgetSettingIdCopyWithImpl(this._self, this._then);

  final WidgetSettingId _self;
  final $Res Function(WidgetSettingId) _then;

/// Create a copy of WidgetSettingKey
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,}) {
  return _then(WidgetSettingId(
null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
