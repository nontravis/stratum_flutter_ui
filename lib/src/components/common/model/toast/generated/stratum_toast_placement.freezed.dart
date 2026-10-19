// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../stratum_toast_placement.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StratumToastPlacement {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumToastPlacement);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'StratumToastPlacement()';
}


}

/// @nodoc
class $StratumToastPlacementCopyWith<$Res>  {
$StratumToastPlacementCopyWith(StratumToastPlacement _, $Res Function(StratumToastPlacement) __);
}



/// @nodoc


class StratumToastFloat implements StratumToastPlacement {
  const StratumToastFloat(this.corner);
  

 final  StratumToastCorner corner;

/// Create a copy of StratumToastPlacement
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumToastFloatCopyWith<StratumToastFloat> get copyWith => _$StratumToastFloatCopyWithImpl<StratumToastFloat>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumToastFloat&&(identical(other.corner, corner) || other.corner == corner));
}


@override
int get hashCode {
    return Object.hash(runtimeType,corner);
}

@override
String toString() {
    return 'StratumToastPlacement.float(corner: $corner)';
}


}

/// @nodoc
abstract mixin class $StratumToastFloatCopyWith<$Res> implements $StratumToastPlacementCopyWith<$Res> {
  factory $StratumToastFloatCopyWith(StratumToastFloat value, $Res Function(StratumToastFloat) _then) = _$StratumToastFloatCopyWithImpl;
@useResult
$Res call({
 StratumToastCorner corner
});




}
/// @nodoc
class _$StratumToastFloatCopyWithImpl<$Res>
    implements $StratumToastFloatCopyWith<$Res> {
  _$StratumToastFloatCopyWithImpl(this._self, this._then);

  final StratumToastFloat _self;
  final $Res Function(StratumToastFloat) _then;

/// Create a copy of StratumToastPlacement
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? corner = null,}) {
  return _then(StratumToastFloat(
null == corner ? _self.corner : corner // ignore: cast_nullable_to_non_nullable
as StratumToastCorner,
  ));
}


}

/// @nodoc


class StratumToastSolid implements StratumToastPlacement {
  const StratumToastSolid(this.edge);
  

 final  StratumToastEdge edge;

/// Create a copy of StratumToastPlacement
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumToastSolidCopyWith<StratumToastSolid> get copyWith => _$StratumToastSolidCopyWithImpl<StratumToastSolid>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumToastSolid&&(identical(other.edge, edge) || other.edge == edge));
}


@override
int get hashCode {
    return Object.hash(runtimeType,edge);
}

@override
String toString() {
    return 'StratumToastPlacement.solid(edge: $edge)';
}


}

/// @nodoc
abstract mixin class $StratumToastSolidCopyWith<$Res> implements $StratumToastPlacementCopyWith<$Res> {
  factory $StratumToastSolidCopyWith(StratumToastSolid value, $Res Function(StratumToastSolid) _then) = _$StratumToastSolidCopyWithImpl;
@useResult
$Res call({
 StratumToastEdge edge
});




}
/// @nodoc
class _$StratumToastSolidCopyWithImpl<$Res>
    implements $StratumToastSolidCopyWith<$Res> {
  _$StratumToastSolidCopyWithImpl(this._self, this._then);

  final StratumToastSolid _self;
  final $Res Function(StratumToastSolid) _then;

/// Create a copy of StratumToastPlacement
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? edge = null,}) {
  return _then(StratumToastSolid(
null == edge ? _self.edge : edge // ignore: cast_nullable_to_non_nullable
as StratumToastEdge,
  ));
}


}

// dart format on
