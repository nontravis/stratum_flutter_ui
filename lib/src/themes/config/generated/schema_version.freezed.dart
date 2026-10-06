// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../schema_version.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StratumSchemaVersion {


/// Create a copy of StratumSchemaVersion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumSchemaVersionCopyWith<StratumSchemaVersion> get copyWith => _$StratumSchemaVersionCopyWithImpl<StratumSchemaVersion>(this as StratumSchemaVersion, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumSchemaVersion;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumSchemaVersion&&(identical(other.major, _this.major) || other.major == _this.major)&&(identical(other.minor, _this.minor) || other.minor == _this.minor)&&(identical(other.patch, _this.patch) || other.patch == _this.patch));
}


@override
int get hashCode {
  final _this = this as StratumSchemaVersion;
  return Object.hash(runtimeType,_this.major,_this.minor,_this.patch);
}



}

/// @nodoc
abstract mixin class $StratumSchemaVersionCopyWith<$Res>  {
  factory $StratumSchemaVersionCopyWith(StratumSchemaVersion value, $Res Function(StratumSchemaVersion) _then) = _$StratumSchemaVersionCopyWithImpl;
@useResult
$Res call({
 int major, int minor, int patch
});




}
/// @nodoc
class _$StratumSchemaVersionCopyWithImpl<$Res>
    implements $StratumSchemaVersionCopyWith<$Res> {
  _$StratumSchemaVersionCopyWithImpl(this._self, this._then);

  final StratumSchemaVersion _self;
  final $Res Function(StratumSchemaVersion) _then;

/// Create a copy of StratumSchemaVersion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? major = null,Object? minor = null,Object? patch = null,}) {
  return _then(StratumSchemaVersion(
null == major ? _self.major : major // ignore: cast_nullable_to_non_nullable
as int,null == minor ? _self.minor : minor // ignore: cast_nullable_to_non_nullable
as int,null == patch ? _self.patch : patch // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



// dart format on
