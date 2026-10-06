// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../typography_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StratumFontRef {


/// Create a copy of StratumFontRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumFontRefCopyWith<StratumFontRef> get copyWith => _$StratumFontRefCopyWithImpl<StratumFontRef>(this as StratumFontRef, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumFontRef;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumFontRef&&(identical(other.font, _this.font) || other.font == _this.font)&&(identical(other.mono, _this.mono) || other.mono == _this.mono));
}


@override
int get hashCode {
  final _this = this as StratumFontRef;
  return Object.hash(runtimeType,_this.font,_this.mono);
}



}

/// @nodoc
abstract mixin class $StratumFontRefCopyWith<$Res>  {
  factory $StratumFontRefCopyWith(StratumFontRef value, $Res Function(StratumFontRef) _then) = _$StratumFontRefCopyWithImpl;
@useResult
$Res call({
 String font, String? mono
});




}
/// @nodoc
class _$StratumFontRefCopyWithImpl<$Res>
    implements $StratumFontRefCopyWith<$Res> {
  _$StratumFontRefCopyWithImpl(this._self, this._then);

  final StratumFontRef _self;
  final $Res Function(StratumFontRef) _then;

/// Create a copy of StratumFontRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? font = null,Object? mono = freezed,}) {
  return _then(StratumFontRef(
font: null == font ? _self.font : font // ignore: cast_nullable_to_non_nullable
as String,mono: freezed == mono ? _self.mono : mono // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
mixin _$StratumFamilySet {

/// The fonts of each type this tag names.
 Map<FontType, StratumFontRef> get types;/// Key of the theme-wide mono font of this tag, for `.mono` on a type
/// without a mono font of its own, or null.
 String? get mono;
/// Create a copy of StratumFamilySet
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumFamilySetCopyWith<StratumFamilySet> get copyWith => _$StratumFamilySetCopyWithImpl<StratumFamilySet>(this as StratumFamilySet, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumFamilySet;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumFamilySet&&const DeepCollectionEquality().equals(other.types, _this.types)&&(identical(other.mono, _this.mono) || other.mono == _this.mono));
}


@override
int get hashCode {
  final _this = this as StratumFamilySet;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.types),_this.mono);
}



}

/// @nodoc
abstract mixin class $StratumFamilySetCopyWith<$Res>  {
  factory $StratumFamilySetCopyWith(StratumFamilySet value, $Res Function(StratumFamilySet) _then) = _$StratumFamilySetCopyWithImpl;
@useResult
$Res call({
 Map<FontType, StratumFontRef> types, String? mono
});




}
/// @nodoc
class _$StratumFamilySetCopyWithImpl<$Res>
    implements $StratumFamilySetCopyWith<$Res> {
  _$StratumFamilySetCopyWithImpl(this._self, this._then);

  final StratumFamilySet _self;
  final $Res Function(StratumFamilySet) _then;

/// Create a copy of StratumFamilySet
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? types = null,Object? mono = freezed,}) {
  return _then(StratumFamilySet(
types: null == types ? _self.types : types // ignore: cast_nullable_to_non_nullable
as Map<FontType, StratumFontRef>,mono: freezed == mono ? _self.mono : mono // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc


class _StratumFamilySet extends StratumFamilySet {
  const _StratumFamilySet({required  Map<FontType, StratumFontRef> types, this.mono}): _types = types,super._();
  

/// The fonts of each type this tag names.
 final  Map<FontType, StratumFontRef> _types;
/// The fonts of each type this tag names.
@override Map<FontType, StratumFontRef> get types {
  if (_types is EqualUnmodifiableMapView) return _types;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_types);
}

/// Key of the theme-wide mono font of this tag, for `.mono` on a type
/// without a mono font of its own, or null.
@override final  String? mono;

/// Create a copy of StratumFamilySet
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StratumFamilySetCopyWith<_StratumFamilySet> get copyWith => __$StratumFamilySetCopyWithImpl<_StratumFamilySet>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StratumFamilySet&&const DeepCollectionEquality().equals(other.types, _types)&&(identical(other.mono, mono) || other.mono == mono));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_types),mono);
}



}

/// @nodoc
abstract mixin class _$StratumFamilySetCopyWith<$Res> implements $StratumFamilySetCopyWith<$Res> {
  factory _$StratumFamilySetCopyWith(_StratumFamilySet value, $Res Function(_StratumFamilySet) _then) = __$StratumFamilySetCopyWithImpl;
@override @useResult
$Res call({
 Map<FontType, StratumFontRef> types, String? mono
});




}
/// @nodoc
class __$StratumFamilySetCopyWithImpl<$Res>
    implements _$StratumFamilySetCopyWith<$Res> {
  __$StratumFamilySetCopyWithImpl(this._self, this._then);

  final _StratumFamilySet _self;
  final $Res Function(_StratumFamilySet) _then;

/// Create a copy of StratumFamilySet
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? types = null,Object? mono = freezed,}) {
  return _then(_StratumFamilySet(
types: null == types ? _self._types : types // ignore: cast_nullable_to_non_nullable
as Map<FontType, StratumFontRef>,mono: freezed == mono ? _self.mono : mono // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$StratumSizeMetrics {


/// Create a copy of StratumSizeMetrics
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumSizeMetricsCopyWith<StratumSizeMetrics> get copyWith => _$StratumSizeMetricsCopyWithImpl<StratumSizeMetrics>(this as StratumSizeMetrics, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumSizeMetrics;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumSizeMetrics&&(identical(other.spaceHeight, _this.spaceHeight) || other.spaceHeight == _this.spaceHeight)&&(identical(other.letterSpacing, _this.letterSpacing) || other.letterSpacing == _this.letterSpacing));
}


@override
int get hashCode {
  final _this = this as StratumSizeMetrics;
  return Object.hash(runtimeType,_this.spaceHeight,_this.letterSpacing);
}



}

/// @nodoc
abstract mixin class $StratumSizeMetricsCopyWith<$Res>  {
  factory $StratumSizeMetricsCopyWith(StratumSizeMetrics value, $Res Function(StratumSizeMetrics) _then) = _$StratumSizeMetricsCopyWithImpl;
@useResult
$Res call({
 StratumDimension spaceHeight, StratumDimension letterSpacing
});




}
/// @nodoc
class _$StratumSizeMetricsCopyWithImpl<$Res>
    implements $StratumSizeMetricsCopyWith<$Res> {
  _$StratumSizeMetricsCopyWithImpl(this._self, this._then);

  final StratumSizeMetrics _self;
  final $Res Function(StratumSizeMetrics) _then;

/// Create a copy of StratumSizeMetrics
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? spaceHeight = null,Object? letterSpacing = null,}) {
  return _then(StratumSizeMetrics(
spaceHeight: null == spaceHeight ? _self.spaceHeight : spaceHeight // ignore: cast_nullable_to_non_nullable
as StratumDimension,letterSpacing: null == letterSpacing ? _self.letterSpacing : letterSpacing // ignore: cast_nullable_to_non_nullable
as StratumDimension,
  ));
}

}



// dart format on
