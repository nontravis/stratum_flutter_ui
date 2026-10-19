// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../typography.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StratumTypeStyle {

/// The weight when the text style sets none.
 FontWeight get weight;/// The metrics of each size this type defines, smallest first.
 Map<FontSize, StratumSizeMetrics> get sizes;/// The window scale of this type, or null for the theme-wide one.
 Map<WindowSize, StratumDimension>? get scaleByWindowSize;
/// Create a copy of StratumTypeStyle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumTypeStyleCopyWith<StratumTypeStyle> get copyWith => _$StratumTypeStyleCopyWithImpl<StratumTypeStyle>(this as StratumTypeStyle, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumTypeStyle;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumTypeStyle&&(identical(other.weight, _this.weight) || other.weight == _this.weight)&&const DeepCollectionEquality().equals(other.sizes, _this.sizes)&&const DeepCollectionEquality().equals(other.scaleByWindowSize, _this.scaleByWindowSize));
}


@override
int get hashCode {
  final _this = this as StratumTypeStyle;
  return Object.hash(runtimeType,_this.weight,const DeepCollectionEquality().hash(_this.sizes),const DeepCollectionEquality().hash(_this.scaleByWindowSize));
}



}

/// @nodoc
abstract mixin class $StratumTypeStyleCopyWith<$Res>  {
  factory $StratumTypeStyleCopyWith(StratumTypeStyle value, $Res Function(StratumTypeStyle) _then) = _$StratumTypeStyleCopyWithImpl;
@useResult
$Res call({
 FontWeight weight, Map<FontSize, StratumSizeMetrics> sizes, Map<WindowSize, StratumDimension>? scaleByWindowSize
});




}
/// @nodoc
class _$StratumTypeStyleCopyWithImpl<$Res>
    implements $StratumTypeStyleCopyWith<$Res> {
  _$StratumTypeStyleCopyWithImpl(this._self, this._then);

  final StratumTypeStyle _self;
  final $Res Function(StratumTypeStyle) _then;

/// Create a copy of StratumTypeStyle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? weight = null,Object? sizes = null,Object? scaleByWindowSize = freezed,}) {
  return _then(StratumTypeStyle(
weight: null == weight ? _self.weight : weight // ignore: cast_nullable_to_non_nullable
as FontWeight,sizes: null == sizes ? _self.sizes : sizes // ignore: cast_nullable_to_non_nullable
as Map<FontSize, StratumSizeMetrics>,scaleByWindowSize: freezed == scaleByWindowSize ? _self.scaleByWindowSize : scaleByWindowSize // ignore: cast_nullable_to_non_nullable
as Map<WindowSize, StratumDimension>?,
  ));
}

}



/// @nodoc


class _StratumTypeStyle extends StratumTypeStyle {
  const _StratumTypeStyle({required this.weight, required  Map<FontSize, StratumSizeMetrics> sizes,  Map<WindowSize, StratumDimension>? scaleByWindowSize}): _sizes = sizes,_scaleByWindowSize = scaleByWindowSize,super._();
  

/// The weight when the text style sets none.
@override final  FontWeight weight;
/// The metrics of each size this type defines, smallest first.
 final  Map<FontSize, StratumSizeMetrics> _sizes;
/// The metrics of each size this type defines, smallest first.
@override Map<FontSize, StratumSizeMetrics> get sizes {
  if (_sizes is EqualUnmodifiableMapView) return _sizes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_sizes);
}

/// The window scale of this type, or null for the theme-wide one.
 final  Map<WindowSize, StratumDimension>? _scaleByWindowSize;
/// The window scale of this type, or null for the theme-wide one.
@override Map<WindowSize, StratumDimension>? get scaleByWindowSize {
  final value = _scaleByWindowSize;
  if (value == null) return null;
  if (_scaleByWindowSize is EqualUnmodifiableMapView) return _scaleByWindowSize;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of StratumTypeStyle
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StratumTypeStyleCopyWith<_StratumTypeStyle> get copyWith => __$StratumTypeStyleCopyWithImpl<_StratumTypeStyle>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StratumTypeStyle&&(identical(other.weight, weight) || other.weight == weight)&&const DeepCollectionEquality().equals(other.sizes, _sizes)&&const DeepCollectionEquality().equals(other.scaleByWindowSize, _scaleByWindowSize));
}


@override
int get hashCode {
    return Object.hash(runtimeType,weight,const DeepCollectionEquality().hash(_sizes),const DeepCollectionEquality().hash(_scaleByWindowSize));
}



}

/// @nodoc
abstract mixin class _$StratumTypeStyleCopyWith<$Res> implements $StratumTypeStyleCopyWith<$Res> {
  factory _$StratumTypeStyleCopyWith(_StratumTypeStyle value, $Res Function(_StratumTypeStyle) _then) = __$StratumTypeStyleCopyWithImpl;
@override @useResult
$Res call({
 FontWeight weight, Map<FontSize, StratumSizeMetrics> sizes, Map<WindowSize, StratumDimension>? scaleByWindowSize
});




}
/// @nodoc
class __$StratumTypeStyleCopyWithImpl<$Res>
    implements _$StratumTypeStyleCopyWith<$Res> {
  __$StratumTypeStyleCopyWithImpl(this._self, this._then);

  final _StratumTypeStyle _self;
  final $Res Function(_StratumTypeStyle) _then;

/// Create a copy of StratumTypeStyle
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? weight = null,Object? sizes = null,Object? scaleByWindowSize = freezed,}) {
  return _then(_StratumTypeStyle(
weight: null == weight ? _self.weight : weight // ignore: cast_nullable_to_non_nullable
as FontWeight,sizes: null == sizes ? _self._sizes : sizes // ignore: cast_nullable_to_non_nullable
as Map<FontSize, StratumSizeMetrics>,scaleByWindowSize: freezed == scaleByWindowSize ? _self._scaleByWindowSize : scaleByWindowSize // ignore: cast_nullable_to_non_nullable
as Map<WindowSize, StratumDimension>?,
  ));
}


}

/// @nodoc
mixin _$StratumTypography {

/// Each font by its key.
 Map<String, StratumFontData> get fonts;/// Each family set by its locale tag (`default`, `th`, `th_TH`), in
/// yaml order.
 Map<String, StratumFamilySet> get families;/// The style of every type except `table`, which has no entry here:
/// its style is `body`'s, read in code.
 Map<FontType, StratumTypeStyle> get types;/// The size each window size adds, or null when the theme names no
/// window size. A window size the yaml map omits takes the value of
/// the nearest smaller window size it names, else of the smallest one
/// it names; with neither this map nor a type's own map set, the
/// scale adds 0.
 StratumByWindowSize<StratumDimension>? get scaleByWindowSize;
/// Create a copy of StratumTypography
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumTypographyCopyWith<StratumTypography> get copyWith => _$StratumTypographyCopyWithImpl<StratumTypography>(this as StratumTypography, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumTypography;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumTypography&&const DeepCollectionEquality().equals(other.fonts, _this.fonts)&&const DeepCollectionEquality().equals(other.families, _this.families)&&const DeepCollectionEquality().equals(other.types, _this.types)&&(identical(other.scaleByWindowSize, _this.scaleByWindowSize) || other.scaleByWindowSize == _this.scaleByWindowSize));
}


@override
int get hashCode {
  final _this = this as StratumTypography;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.fonts),const DeepCollectionEquality().hash(_this.families),const DeepCollectionEquality().hash(_this.types),_this.scaleByWindowSize);
}

@override
String toString() {
  final _this = this as StratumTypography;
  return 'StratumTypography(fonts: ${_this.fonts}, families: ${_this.families}, types: ${_this.types}, scaleByWindowSize: ${_this.scaleByWindowSize})';
}


}

/// @nodoc
abstract mixin class $StratumTypographyCopyWith<$Res>  {
  factory $StratumTypographyCopyWith(StratumTypography value, $Res Function(StratumTypography) _then) = _$StratumTypographyCopyWithImpl;
@useResult
$Res call({
 Map<String, StratumFontData> fonts, Map<String, StratumFamilySet> families, Map<FontType, StratumTypeStyle> types, StratumByWindowSize<StratumDimension>? scaleByWindowSize
});




}
/// @nodoc
class _$StratumTypographyCopyWithImpl<$Res>
    implements $StratumTypographyCopyWith<$Res> {
  _$StratumTypographyCopyWithImpl(this._self, this._then);

  final StratumTypography _self;
  final $Res Function(StratumTypography) _then;

/// Create a copy of StratumTypography
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fonts = null,Object? families = null,Object? types = null,Object? scaleByWindowSize = freezed,}) {
  return _then(StratumTypography(
fonts: null == fonts ? _self.fonts : fonts // ignore: cast_nullable_to_non_nullable
as Map<String, StratumFontData>,families: null == families ? _self.families : families // ignore: cast_nullable_to_non_nullable
as Map<String, StratumFamilySet>,types: null == types ? _self.types : types // ignore: cast_nullable_to_non_nullable
as Map<FontType, StratumTypeStyle>,scaleByWindowSize: freezed == scaleByWindowSize ? _self.scaleByWindowSize : scaleByWindowSize // ignore: cast_nullable_to_non_nullable
as StratumByWindowSize<StratumDimension>?,
  ));
}

}



/// @nodoc


class _StratumTypography implements StratumTypography {
  const _StratumTypography({required  Map<String, StratumFontData> fonts, required  Map<String, StratumFamilySet> families, required  Map<FontType, StratumTypeStyle> types, this.scaleByWindowSize}): _fonts = fonts,_families = families,_types = types;
  

/// Each font by its key.
 final  Map<String, StratumFontData> _fonts;
/// Each font by its key.
@override Map<String, StratumFontData> get fonts {
  if (_fonts is EqualUnmodifiableMapView) return _fonts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_fonts);
}

/// Each family set by its locale tag (`default`, `th`, `th_TH`), in
/// yaml order.
 final  Map<String, StratumFamilySet> _families;
/// Each family set by its locale tag (`default`, `th`, `th_TH`), in
/// yaml order.
@override Map<String, StratumFamilySet> get families {
  if (_families is EqualUnmodifiableMapView) return _families;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_families);
}

/// The style of every type except `table`, which has no entry here:
/// its style is `body`'s, read in code.
 final  Map<FontType, StratumTypeStyle> _types;
/// The style of every type except `table`, which has no entry here:
/// its style is `body`'s, read in code.
@override Map<FontType, StratumTypeStyle> get types {
  if (_types is EqualUnmodifiableMapView) return _types;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_types);
}

/// The size each window size adds, or null when the theme names no
/// window size. A window size the yaml map omits takes the value of
/// the nearest smaller window size it names, else of the smallest one
/// it names; with neither this map nor a type's own map set, the
/// scale adds 0.
@override final  StratumByWindowSize<StratumDimension>? scaleByWindowSize;

/// Create a copy of StratumTypography
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StratumTypographyCopyWith<_StratumTypography> get copyWith => __$StratumTypographyCopyWithImpl<_StratumTypography>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StratumTypography&&const DeepCollectionEquality().equals(other.fonts, _fonts)&&const DeepCollectionEquality().equals(other.families, _families)&&const DeepCollectionEquality().equals(other.types, _types)&&(identical(other.scaleByWindowSize, scaleByWindowSize) || other.scaleByWindowSize == scaleByWindowSize));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_fonts),const DeepCollectionEquality().hash(_families),const DeepCollectionEquality().hash(_types),scaleByWindowSize);
}

@override
String toString() {
    return 'StratumTypography(fonts: $fonts, families: $families, types: $types, scaleByWindowSize: $scaleByWindowSize)';
}


}

/// @nodoc
abstract mixin class _$StratumTypographyCopyWith<$Res> implements $StratumTypographyCopyWith<$Res> {
  factory _$StratumTypographyCopyWith(_StratumTypography value, $Res Function(_StratumTypography) _then) = __$StratumTypographyCopyWithImpl;
@override @useResult
$Res call({
 Map<String, StratumFontData> fonts, Map<String, StratumFamilySet> families, Map<FontType, StratumTypeStyle> types, StratumByWindowSize<StratumDimension>? scaleByWindowSize
});




}
/// @nodoc
class __$StratumTypographyCopyWithImpl<$Res>
    implements _$StratumTypographyCopyWith<$Res> {
  __$StratumTypographyCopyWithImpl(this._self, this._then);

  final _StratumTypography _self;
  final $Res Function(_StratumTypography) _then;

/// Create a copy of StratumTypography
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fonts = null,Object? families = null,Object? types = null,Object? scaleByWindowSize = freezed,}) {
  return _then(_StratumTypography(
fonts: null == fonts ? _self._fonts : fonts // ignore: cast_nullable_to_non_nullable
as Map<String, StratumFontData>,families: null == families ? _self._families : families // ignore: cast_nullable_to_non_nullable
as Map<String, StratumFamilySet>,types: null == types ? _self._types : types // ignore: cast_nullable_to_non_nullable
as Map<FontType, StratumTypeStyle>,scaleByWindowSize: freezed == scaleByWindowSize ? _self.scaleByWindowSize : scaleByWindowSize // ignore: cast_nullable_to_non_nullable
as StratumByWindowSize<StratumDimension>?,
  ));
}


}

// dart format on
