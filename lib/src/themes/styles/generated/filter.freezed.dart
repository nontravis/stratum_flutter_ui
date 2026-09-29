// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../filter.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AppImageFilter {

 double get sigmaX; double get sigmaY; TileMode? get tileMode;
/// Create a copy of AppImageFilter
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppImageFilterCopyWith<AppImageFilter> get copyWith => _$AppImageFilterCopyWithImpl<AppImageFilter>(this as AppImageFilter, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppImageFilter&&(identical(other.sigmaX, sigmaX) || other.sigmaX == sigmaX)&&(identical(other.sigmaY, sigmaY) || other.sigmaY == sigmaY)&&(identical(other.tileMode, tileMode) || other.tileMode == tileMode));
}


@override
int get hashCode => Object.hash(runtimeType,sigmaX,sigmaY,tileMode);

@override
String toString() {
  return 'AppImageFilter(sigmaX: $sigmaX, sigmaY: $sigmaY, tileMode: $tileMode)';
}


}

/// @nodoc
abstract mixin class $AppImageFilterCopyWith<$Res>  {
  factory $AppImageFilterCopyWith(AppImageFilter value, $Res Function(AppImageFilter) _then) = _$AppImageFilterCopyWithImpl;
@useResult
$Res call({
 double sigmaX, double sigmaY, TileMode? tileMode
});




}
/// @nodoc
class _$AppImageFilterCopyWithImpl<$Res>
    implements $AppImageFilterCopyWith<$Res> {
  _$AppImageFilterCopyWithImpl(this._self, this._then);

  final AppImageFilter _self;
  final $Res Function(AppImageFilter) _then;

/// Create a copy of AppImageFilter
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sigmaX = null,Object? sigmaY = null,Object? tileMode = freezed,}) {
  return _then(_self.copyWith(
sigmaX: null == sigmaX ? _self.sigmaX : sigmaX // ignore: cast_nullable_to_non_nullable
as double,sigmaY: null == sigmaY ? _self.sigmaY : sigmaY // ignore: cast_nullable_to_non_nullable
as double,tileMode: freezed == tileMode ? _self.tileMode : tileMode // ignore: cast_nullable_to_non_nullable
as TileMode?,
  ));
}

}


/// Adds pattern-matching-related methods to [AppImageFilter].
extension AppImageFilterPatterns on AppImageFilter {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppImageFilter value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppImageFilter() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppImageFilter value)  $default,){
final _that = this;
switch (_that) {
case _AppImageFilter():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppImageFilter value)?  $default,){
final _that = this;
switch (_that) {
case _AppImageFilter() when $default != null:
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
case _AppImageFilter() when $default != null:
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
case _AppImageFilter():
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
case _AppImageFilter() when $default != null:
return $default(_that.sigmaX,_that.sigmaY,_that.tileMode);case _:
  return null;

}
}

}

/// @nodoc


class _AppImageFilter extends AppImageFilter {
  const _AppImageFilter({this.sigmaX = 0.0, this.sigmaY = 0.0, this.tileMode}): super._();
  

@override@JsonKey() final  double sigmaX;
@override@JsonKey() final  double sigmaY;
@override final  TileMode? tileMode;

/// Create a copy of AppImageFilter
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppImageFilterCopyWith<_AppImageFilter> get copyWith => __$AppImageFilterCopyWithImpl<_AppImageFilter>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppImageFilter&&(identical(other.sigmaX, sigmaX) || other.sigmaX == sigmaX)&&(identical(other.sigmaY, sigmaY) || other.sigmaY == sigmaY)&&(identical(other.tileMode, tileMode) || other.tileMode == tileMode));
}


@override
int get hashCode => Object.hash(runtimeType,sigmaX,sigmaY,tileMode);

@override
String toString() {
  return 'AppImageFilter(sigmaX: $sigmaX, sigmaY: $sigmaY, tileMode: $tileMode)';
}


}

/// @nodoc
abstract mixin class _$AppImageFilterCopyWith<$Res> implements $AppImageFilterCopyWith<$Res> {
  factory _$AppImageFilterCopyWith(_AppImageFilter value, $Res Function(_AppImageFilter) _then) = __$AppImageFilterCopyWithImpl;
@override @useResult
$Res call({
 double sigmaX, double sigmaY, TileMode? tileMode
});




}
/// @nodoc
class __$AppImageFilterCopyWithImpl<$Res>
    implements _$AppImageFilterCopyWith<$Res> {
  __$AppImageFilterCopyWithImpl(this._self, this._then);

  final _AppImageFilter _self;
  final $Res Function(_AppImageFilter) _then;

/// Create a copy of AppImageFilter
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sigmaX = null,Object? sigmaY = null,Object? tileMode = freezed,}) {
  return _then(_AppImageFilter(
sigmaX: null == sigmaX ? _self.sigmaX : sigmaX // ignore: cast_nullable_to_non_nullable
as double,sigmaY: null == sigmaY ? _self.sigmaY : sigmaY // ignore: cast_nullable_to_non_nullable
as double,tileMode: freezed == tileMode ? _self.tileMode : tileMode // ignore: cast_nullable_to_non_nullable
as TileMode?,
  ));
}


}

// dart format on
