// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../stratum_focus_border_style.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StratumFocusBorderStyle {

/// The ring color, never fully transparent; level 0 sets it per
/// placement.
 WidgetStateProperty<Color?>? get color;/// The ring width in logical pixels, above 0; level 0 sets it per
/// placement, the inside one per shown state.
 WidgetStateProperty<double?>? get width;/// The space between the box and an outside ring; unused by the inside
/// placement and with `insideEdge`, since the gap never applies inward.
 WidgetStateProperty<double?>? get gap;/// The corner radius the ring follows, in place of the ring's
/// `borderRadius`; a ring around the box takes it plus the gap.
 WidgetStateProperty<BorderRadiusGeometry?>? get radius;/// Outside or inside, set only here, since the ring takes no placement
/// parameter of its own; null at every level is
/// [StratumFocusBorderPlacement.outside].
 StratumFocusBorderPlacement? get placement;/// The fade between looks, its duration and curve; by default the
/// theme's `fast` level on its `standard` curve.
 WidgetStateProperty<AnimationStyle?>? get motion;/// A second ring in `color` touching the first on the side away from the
/// box's edge, outward for an outside ring and inward for an inside or
/// `insideEdge` ring, a two-tone ring that shows on any background; a
/// null `width` takes the first ring's width.
 WidgetStateProperty<({Color color, double? width,})?>? get secondRing;/// A soft halo around the shown ring, as the shadow list Flutter's own
/// decorations use; it never changes the box's layout size and may clip
/// at the window edge.
 WidgetStateProperty<List<BoxShadow>?>? get glow;
/// Create a copy of StratumFocusBorderStyle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumFocusBorderStyleCopyWith<StratumFocusBorderStyle> get copyWith => _$StratumFocusBorderStyleCopyWithImpl<StratumFocusBorderStyle>(this as StratumFocusBorderStyle, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumFocusBorderStyle;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumFocusBorderStyle&&(identical(other.color, _this.color) || other.color == _this.color)&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.gap, _this.gap) || other.gap == _this.gap)&&(identical(other.radius, _this.radius) || other.radius == _this.radius)&&(identical(other.placement, _this.placement) || other.placement == _this.placement)&&(identical(other.motion, _this.motion) || other.motion == _this.motion)&&(identical(other.secondRing, _this.secondRing) || other.secondRing == _this.secondRing)&&(identical(other.glow, _this.glow) || other.glow == _this.glow));
}


@override
int get hashCode {
  final _this = this as StratumFocusBorderStyle;
  return Object.hash(runtimeType,_this.color,_this.width,_this.gap,_this.radius,_this.placement,_this.motion,_this.secondRing,_this.glow);
}

@override
String toString() {
  final _this = this as StratumFocusBorderStyle;
  return 'StratumFocusBorderStyle(color: ${_this.color}, width: ${_this.width}, gap: ${_this.gap}, radius: ${_this.radius}, placement: ${_this.placement}, motion: ${_this.motion}, secondRing: ${_this.secondRing}, glow: ${_this.glow})';
}


}

/// @nodoc
abstract mixin class $StratumFocusBorderStyleCopyWith<$Res>  {
  factory $StratumFocusBorderStyleCopyWith(StratumFocusBorderStyle value, $Res Function(StratumFocusBorderStyle) _then) = _$StratumFocusBorderStyleCopyWithImpl;
@useResult
$Res call({
 WidgetStateProperty<Color?>? color, WidgetStateProperty<double?>? width, WidgetStateProperty<double?>? gap, WidgetStateProperty<BorderRadiusGeometry?>? radius, StratumFocusBorderPlacement? placement, WidgetStateProperty<AnimationStyle?>? motion, WidgetStateProperty<({Color color, double? width,})?>? secondRing, WidgetStateProperty<List<BoxShadow>?>? glow
});




}
/// @nodoc
class _$StratumFocusBorderStyleCopyWithImpl<$Res>
    implements $StratumFocusBorderStyleCopyWith<$Res> {
  _$StratumFocusBorderStyleCopyWithImpl(this._self, this._then);

  final StratumFocusBorderStyle _self;
  final $Res Function(StratumFocusBorderStyle) _then;

/// Create a copy of StratumFocusBorderStyle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? color = freezed,Object? width = freezed,Object? gap = freezed,Object? radius = freezed,Object? placement = freezed,Object? motion = freezed,Object? secondRing = freezed,Object? glow = freezed,}) {
  return _then(StratumFocusBorderStyle(
color: freezed == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as WidgetStateProperty<Color?>?,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as WidgetStateProperty<double?>?,gap: freezed == gap ? _self.gap : gap // ignore: cast_nullable_to_non_nullable
as WidgetStateProperty<double?>?,radius: freezed == radius ? _self.radius : radius // ignore: cast_nullable_to_non_nullable
as WidgetStateProperty<BorderRadiusGeometry?>?,placement: freezed == placement ? _self.placement : placement // ignore: cast_nullable_to_non_nullable
as StratumFocusBorderPlacement?,motion: freezed == motion ? _self.motion : motion // ignore: cast_nullable_to_non_nullable
as WidgetStateProperty<AnimationStyle?>?,secondRing: freezed == secondRing ? _self.secondRing : secondRing // ignore: cast_nullable_to_non_nullable
as WidgetStateProperty<({Color color, double? width,})?>?,glow: freezed == glow ? _self.glow : glow // ignore: cast_nullable_to_non_nullable
as WidgetStateProperty<List<BoxShadow>?>?,
  ));
}

}



/// @nodoc


class _StratumFocusBorderStyle implements StratumFocusBorderStyle {
  const _StratumFocusBorderStyle({this.color, this.width, this.gap, this.radius, this.placement, this.motion, this.secondRing, this.glow});
  

/// The ring color, never fully transparent; level 0 sets it per
/// placement.
@override final  WidgetStateProperty<Color?>? color;
/// The ring width in logical pixels, above 0; level 0 sets it per
/// placement, the inside one per shown state.
@override final  WidgetStateProperty<double?>? width;
/// The space between the box and an outside ring; unused by the inside
/// placement and with `insideEdge`, since the gap never applies inward.
@override final  WidgetStateProperty<double?>? gap;
/// The corner radius the ring follows, in place of the ring's
/// `borderRadius`; a ring around the box takes it plus the gap.
@override final  WidgetStateProperty<BorderRadiusGeometry?>? radius;
/// Outside or inside, set only here, since the ring takes no placement
/// parameter of its own; null at every level is
/// [StratumFocusBorderPlacement.outside].
@override final  StratumFocusBorderPlacement? placement;
/// The fade between looks, its duration and curve; by default the
/// theme's `fast` level on its `standard` curve.
@override final  WidgetStateProperty<AnimationStyle?>? motion;
/// A second ring in `color` touching the first on the side away from the
/// box's edge, outward for an outside ring and inward for an inside or
/// `insideEdge` ring, a two-tone ring that shows on any background; a
/// null `width` takes the first ring's width.
@override final  WidgetStateProperty<({Color color, double? width,})?>? secondRing;
/// A soft halo around the shown ring, as the shadow list Flutter's own
/// decorations use; it never changes the box's layout size and may clip
/// at the window edge.
@override final  WidgetStateProperty<List<BoxShadow>?>? glow;

/// Create a copy of StratumFocusBorderStyle
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StratumFocusBorderStyleCopyWith<_StratumFocusBorderStyle> get copyWith => __$StratumFocusBorderStyleCopyWithImpl<_StratumFocusBorderStyle>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StratumFocusBorderStyle&&(identical(other.color, color) || other.color == color)&&(identical(other.width, width) || other.width == width)&&(identical(other.gap, gap) || other.gap == gap)&&(identical(other.radius, radius) || other.radius == radius)&&(identical(other.placement, placement) || other.placement == placement)&&(identical(other.motion, motion) || other.motion == motion)&&(identical(other.secondRing, secondRing) || other.secondRing == secondRing)&&(identical(other.glow, glow) || other.glow == glow));
}


@override
int get hashCode {
    return Object.hash(runtimeType,color,width,gap,radius,placement,motion,secondRing,glow);
}

@override
String toString() {
    return 'StratumFocusBorderStyle(color: $color, width: $width, gap: $gap, radius: $radius, placement: $placement, motion: $motion, secondRing: $secondRing, glow: $glow)';
}


}

/// @nodoc
abstract mixin class _$StratumFocusBorderStyleCopyWith<$Res> implements $StratumFocusBorderStyleCopyWith<$Res> {
  factory _$StratumFocusBorderStyleCopyWith(_StratumFocusBorderStyle value, $Res Function(_StratumFocusBorderStyle) _then) = __$StratumFocusBorderStyleCopyWithImpl;
@override @useResult
$Res call({
 WidgetStateProperty<Color?>? color, WidgetStateProperty<double?>? width, WidgetStateProperty<double?>? gap, WidgetStateProperty<BorderRadiusGeometry?>? radius, StratumFocusBorderPlacement? placement, WidgetStateProperty<AnimationStyle?>? motion, WidgetStateProperty<({Color color, double? width,})?>? secondRing, WidgetStateProperty<List<BoxShadow>?>? glow
});




}
/// @nodoc
class __$StratumFocusBorderStyleCopyWithImpl<$Res>
    implements _$StratumFocusBorderStyleCopyWith<$Res> {
  __$StratumFocusBorderStyleCopyWithImpl(this._self, this._then);

  final _StratumFocusBorderStyle _self;
  final $Res Function(_StratumFocusBorderStyle) _then;

/// Create a copy of StratumFocusBorderStyle
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? color = freezed,Object? width = freezed,Object? gap = freezed,Object? radius = freezed,Object? placement = freezed,Object? motion = freezed,Object? secondRing = freezed,Object? glow = freezed,}) {
  return _then(_StratumFocusBorderStyle(
color: freezed == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as WidgetStateProperty<Color?>?,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as WidgetStateProperty<double?>?,gap: freezed == gap ? _self.gap : gap // ignore: cast_nullable_to_non_nullable
as WidgetStateProperty<double?>?,radius: freezed == radius ? _self.radius : radius // ignore: cast_nullable_to_non_nullable
as WidgetStateProperty<BorderRadiusGeometry?>?,placement: freezed == placement ? _self.placement : placement // ignore: cast_nullable_to_non_nullable
as StratumFocusBorderPlacement?,motion: freezed == motion ? _self.motion : motion // ignore: cast_nullable_to_non_nullable
as WidgetStateProperty<AnimationStyle?>?,secondRing: freezed == secondRing ? _self.secondRing : secondRing // ignore: cast_nullable_to_non_nullable
as WidgetStateProperty<({Color color, double? width,})?>?,glow: freezed == glow ? _self.glow : glow // ignore: cast_nullable_to_non_nullable
as WidgetStateProperty<List<BoxShadow>?>?,
  ));
}


}

// dart format on
