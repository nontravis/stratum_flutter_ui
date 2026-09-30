// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../image_blur_filter.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ImageBlurFilter {

 double get sigmaX; double get sigmaY; TileMode? get tileMode;
/// Create a copy of ImageBlurFilter
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImageBlurFilterCopyWith<ImageBlurFilter> get copyWith => _$ImageBlurFilterCopyWithImpl<ImageBlurFilter>(this as ImageBlurFilter, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ImageBlurFilter;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ImageBlurFilter&&(identical(other.sigmaX, _this.sigmaX) || other.sigmaX == _this.sigmaX)&&(identical(other.sigmaY, _this.sigmaY) || other.sigmaY == _this.sigmaY)&&(identical(other.tileMode, _this.tileMode) || other.tileMode == _this.tileMode));
}


@override
int get hashCode {
  final _this = this as ImageBlurFilter;
  return Object.hash(runtimeType,_this.sigmaX,_this.sigmaY,_this.tileMode);
}

@override
String toString() {
  final _this = this as ImageBlurFilter;
  return 'ImageBlurFilter(sigmaX: ${_this.sigmaX}, sigmaY: ${_this.sigmaY}, tileMode: ${_this.tileMode})';
}


}

/// @nodoc
abstract mixin class $ImageBlurFilterCopyWith<$Res>  {
  factory $ImageBlurFilterCopyWith(ImageBlurFilter value, $Res Function(ImageBlurFilter) _then) = _$ImageBlurFilterCopyWithImpl;
@useResult
$Res call({
 double sigmaX, double sigmaY, TileMode? tileMode
});




}
/// @nodoc
class _$ImageBlurFilterCopyWithImpl<$Res>
    implements $ImageBlurFilterCopyWith<$Res> {
  _$ImageBlurFilterCopyWithImpl(this._self, this._then);

  final ImageBlurFilter _self;
  final $Res Function(ImageBlurFilter) _then;

/// Create a copy of ImageBlurFilter
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sigmaX = null,Object? sigmaY = null,Object? tileMode = freezed,}) {
  return _then(ImageBlurFilter(
sigmaX: null == sigmaX ? _self.sigmaX : sigmaX // ignore: cast_nullable_to_non_nullable
as double,sigmaY: null == sigmaY ? _self.sigmaY : sigmaY // ignore: cast_nullable_to_non_nullable
as double,tileMode: freezed == tileMode ? _self.tileMode : tileMode // ignore: cast_nullable_to_non_nullable
as TileMode?,
  ));
}

}


/// Adds pattern-matching-related methods to [ImageBlurFilter].
extension ImageBlurFilterPatterns on ImageBlurFilter {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ImageBlurFilter value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ImageBlurFilter() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ImageBlurFilter value)  $default,){
final _that = this;
switch (_that) {
case _ImageBlurFilter():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ImageBlurFilter value)?  $default,){
final _that = this;
switch (_that) {
case _ImageBlurFilter() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double sigmaX,  double sigmaY,  TileMode? tileMode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ImageBlurFilter() when $default != null:
return $default(_that.sigmaX,_that.sigmaY,_that.tileMode);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double sigmaX,  double sigmaY,  TileMode? tileMode)  $default,) {final _that = this;
switch (_that) {
case _ImageBlurFilter():
return $default(_that.sigmaX,_that.sigmaY,_that.tileMode);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double sigmaX,  double sigmaY,  TileMode? tileMode)?  $default,) {final _that = this;
switch (_that) {
case _ImageBlurFilter() when $default != null:
return $default(_that.sigmaX,_that.sigmaY,_that.tileMode);case _:
  return null;

}
}

}

/// @nodoc


class _ImageBlurFilter extends ImageBlurFilter {
  const _ImageBlurFilter({this.sigmaX = 0.0, this.sigmaY = 0.0, this.tileMode}): super._();
  

@override@JsonKey() final  double sigmaX;
@override@JsonKey() final  double sigmaY;
@override final  TileMode? tileMode;

/// Create a copy of ImageBlurFilter
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ImageBlurFilterCopyWith<_ImageBlurFilter> get copyWith => __$ImageBlurFilterCopyWithImpl<_ImageBlurFilter>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ImageBlurFilter&&(identical(other.sigmaX, sigmaX) || other.sigmaX == sigmaX)&&(identical(other.sigmaY, sigmaY) || other.sigmaY == sigmaY)&&(identical(other.tileMode, tileMode) || other.tileMode == tileMode));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sigmaX,sigmaY,tileMode);
}

@override
String toString() {
    return 'ImageBlurFilter(sigmaX: $sigmaX, sigmaY: $sigmaY, tileMode: $tileMode)';
}


}

/// @nodoc
abstract mixin class _$ImageBlurFilterCopyWith<$Res> implements $ImageBlurFilterCopyWith<$Res> {
  factory _$ImageBlurFilterCopyWith(_ImageBlurFilter value, $Res Function(_ImageBlurFilter) _then) = __$ImageBlurFilterCopyWithImpl;
@override @useResult
$Res call({
 double sigmaX, double sigmaY, TileMode? tileMode
});




}
/// @nodoc
class __$ImageBlurFilterCopyWithImpl<$Res>
    implements _$ImageBlurFilterCopyWith<$Res> {
  __$ImageBlurFilterCopyWithImpl(this._self, this._then);

  final _ImageBlurFilter _self;
  final $Res Function(_ImageBlurFilter) _then;

/// Create a copy of ImageBlurFilter
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sigmaX = null,Object? sigmaY = null,Object? tileMode = freezed,}) {
  return _then(_ImageBlurFilter(
sigmaX: null == sigmaX ? _self.sigmaX : sigmaX // ignore: cast_nullable_to_non_nullable
as double,sigmaY: null == sigmaY ? _self.sigmaY : sigmaY // ignore: cast_nullable_to_non_nullable
as double,tileMode: freezed == tileMode ? _self.tileMode : tileMode // ignore: cast_nullable_to_non_nullable
as TileMode?,
  ));
}


}

// dart format on
