// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../shadow_layer.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StratumShadowLayer {


/// Create a copy of StratumShadowLayer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumShadowLayerCopyWith<StratumShadowLayer> get copyWith => _$StratumShadowLayerCopyWithImpl<StratumShadowLayer>(this as StratumShadowLayer, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumShadowLayer;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumShadowLayer&&(identical(other.x, _this.x) || other.x == _this.x)&&(identical(other.y, _this.y) || other.y == _this.y)&&(identical(other.blur, _this.blur) || other.blur == _this.blur)&&(identical(other.spread, _this.spread) || other.spread == _this.spread)&&(identical(other.color, _this.color) || other.color == _this.color));
}


@override
int get hashCode {
  final _this = this as StratumShadowLayer;
  return Object.hash(runtimeType,_this.x,_this.y,_this.blur,_this.spread,_this.color);
}

@override
String toString() {
  final _this = this as StratumShadowLayer;
  return 'StratumShadowLayer(x: ${_this.x}, y: ${_this.y}, blur: ${_this.blur}, spread: ${_this.spread}, color: ${_this.color})';
}


}

/// @nodoc
abstract mixin class $StratumShadowLayerCopyWith<$Res>  {
  factory $StratumShadowLayerCopyWith(StratumShadowLayer value, $Res Function(StratumShadowLayer) _then) = _$StratumShadowLayerCopyWithImpl;
@useResult
$Res call({
 double x, double y, double blur, double spread, StratumLayerColor color
});




}
/// @nodoc
class _$StratumShadowLayerCopyWithImpl<$Res>
    implements $StratumShadowLayerCopyWith<$Res> {
  _$StratumShadowLayerCopyWithImpl(this._self, this._then);

  final StratumShadowLayer _self;
  final $Res Function(StratumShadowLayer) _then;

/// Create a copy of StratumShadowLayer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? x = null,Object? y = null,Object? blur = null,Object? spread = null,Object? color = null,}) {
  return _then(StratumShadowLayer(
x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,blur: null == blur ? _self.blur : blur // ignore: cast_nullable_to_non_nullable
as double,spread: null == spread ? _self.spread : spread // ignore: cast_nullable_to_non_nullable
as double,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as StratumLayerColor,
  ));
}

}



/// @nodoc
mixin _$StratumFixedLayerColor {


/// Create a copy of StratumFixedLayerColor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumFixedLayerColorCopyWith<StratumFixedLayerColor> get copyWith => _$StratumFixedLayerColorCopyWithImpl<StratumFixedLayerColor>(this as StratumFixedLayerColor, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumFixedLayerColor;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumFixedLayerColor&&(identical(other.argb, _this.argb) || other.argb == _this.argb));
}


@override
int get hashCode {
  final _this = this as StratumFixedLayerColor;
  return Object.hash(runtimeType,_this.argb);
}

@override
String toString() {
  final _this = this as StratumFixedLayerColor;
  return 'StratumFixedLayerColor(argb: ${_this.argb})';
}


}

/// @nodoc
abstract mixin class $StratumFixedLayerColorCopyWith<$Res>  {
  factory $StratumFixedLayerColorCopyWith(StratumFixedLayerColor value, $Res Function(StratumFixedLayerColor) _then) = _$StratumFixedLayerColorCopyWithImpl;
@useResult
$Res call({
 int argb
});




}
/// @nodoc
class _$StratumFixedLayerColorCopyWithImpl<$Res>
    implements $StratumFixedLayerColorCopyWith<$Res> {
  _$StratumFixedLayerColorCopyWithImpl(this._self, this._then);

  final StratumFixedLayerColor _self;
  final $Res Function(StratumFixedLayerColor) _then;

/// Create a copy of StratumFixedLayerColor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? argb = null,}) {
  return _then(StratumFixedLayerColor(
null == argb ? _self.argb : argb // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
mixin _$StratumSetLayerColor {


/// Create a copy of StratumSetLayerColor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumSetLayerColorCopyWith<StratumSetLayerColor> get copyWith => _$StratumSetLayerColorCopyWithImpl<StratumSetLayerColor>(this as StratumSetLayerColor, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumSetLayerColor;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumSetLayerColor&&(identical(other.path, _this.path) || other.path == _this.path));
}


@override
int get hashCode {
  final _this = this as StratumSetLayerColor;
  return Object.hash(runtimeType,_this.path);
}

@override
String toString() {
  final _this = this as StratumSetLayerColor;
  return 'StratumSetLayerColor(path: ${_this.path})';
}


}

/// @nodoc
abstract mixin class $StratumSetLayerColorCopyWith<$Res>  {
  factory $StratumSetLayerColorCopyWith(StratumSetLayerColor value, $Res Function(StratumSetLayerColor) _then) = _$StratumSetLayerColorCopyWithImpl;
@useResult
$Res call({
 String path
});




}
/// @nodoc
class _$StratumSetLayerColorCopyWithImpl<$Res>
    implements $StratumSetLayerColorCopyWith<$Res> {
  _$StratumSetLayerColorCopyWithImpl(this._self, this._then);

  final StratumSetLayerColor _self;
  final $Res Function(StratumSetLayerColor) _then;

/// Create a copy of StratumSetLayerColor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,}) {
  return _then(StratumSetLayerColor(
null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



// dart format on
