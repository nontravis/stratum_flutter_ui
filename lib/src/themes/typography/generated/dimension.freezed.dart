// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../dimension.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FixedDimension {


/// Create a copy of FixedDimension
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FixedDimensionCopyWith<FixedDimension> get copyWith => _$FixedDimensionCopyWithImpl<FixedDimension>(this as FixedDimension, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as FixedDimension;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FixedDimension&&(identical(other.px, _this.px) || other.px == _this.px));
}


@override
int get hashCode {
  final _this = this as FixedDimension;
  return Object.hash(runtimeType,_this.px);
}



}

/// @nodoc
abstract mixin class $FixedDimensionCopyWith<$Res>  {
  factory $FixedDimensionCopyWith(FixedDimension value, $Res Function(FixedDimension) _then) = _$FixedDimensionCopyWithImpl;
@useResult
$Res call({
 double px
});




}
/// @nodoc
class _$FixedDimensionCopyWithImpl<$Res>
    implements $FixedDimensionCopyWith<$Res> {
  _$FixedDimensionCopyWithImpl(this._self, this._then);

  final FixedDimension _self;
  final $Res Function(FixedDimension) _then;

/// Create a copy of FixedDimension
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? px = null,}) {
  return _then(FixedDimension(
null == px ? _self.px : px // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}



/// @nodoc
mixin _$PercentDimension {


/// Create a copy of PercentDimension
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PercentDimensionCopyWith<PercentDimension> get copyWith => _$PercentDimensionCopyWithImpl<PercentDimension>(this as PercentDimension, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PercentDimension;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PercentDimension&&(identical(other.ratio, _this.ratio) || other.ratio == _this.ratio));
}


@override
int get hashCode {
  final _this = this as PercentDimension;
  return Object.hash(runtimeType,_this.ratio);
}



}

/// @nodoc
abstract mixin class $PercentDimensionCopyWith<$Res>  {
  factory $PercentDimensionCopyWith(PercentDimension value, $Res Function(PercentDimension) _then) = _$PercentDimensionCopyWithImpl;
@useResult
$Res call({
 double ratio
});




}
/// @nodoc
class _$PercentDimensionCopyWithImpl<$Res>
    implements $PercentDimensionCopyWith<$Res> {
  _$PercentDimensionCopyWithImpl(this._self, this._then);

  final PercentDimension _self;
  final $Res Function(PercentDimension) _then;

/// Create a copy of PercentDimension
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ratio = null,}) {
  return _then(PercentDimension(
null == ratio ? _self.ratio : ratio // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}



// dart format on
