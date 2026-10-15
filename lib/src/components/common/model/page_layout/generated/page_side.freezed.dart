// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../page_side.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PageSide {


/// Create a copy of PageSide
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PageSideCopyWith<PageSide> get copyWith => _$PageSideCopyWithImpl<PageSide>(this as PageSide, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PageSide;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PageSide&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.minWidth, _this.minWidth) || other.minWidth == _this.minWidth)&&(identical(other.maxWidth, _this.maxWidth) || other.maxWidth == _this.maxWidth)&&(identical(other.pageScale, _this.pageScale) || other.pageScale == _this.pageScale)&&(identical(other.semanticsLabel, _this.semanticsLabel) || other.semanticsLabel == _this.semanticsLabel));
}


@override
int get hashCode {
  final _this = this as PageSide;
  return Object.hash(runtimeType,_this.type,_this.minWidth,_this.maxWidth,_this.pageScale,_this.semanticsLabel);
}

@override
String toString() {
  final _this = this as PageSide;
  return 'PageSide(type: ${_this.type}, minWidth: ${_this.minWidth}, maxWidth: ${_this.maxWidth}, pageScale: ${_this.pageScale}, semanticsLabel: ${_this.semanticsLabel})';
}


}

/// @nodoc
abstract mixin class $PageSideCopyWith<$Res>  {
  factory $PageSideCopyWith(PageSide value, $Res Function(PageSide) _then) = _$PageSideCopyWithImpl;
@useResult
$Res call({
 PageDrawerType? type, double? minWidth, double? maxWidth, double? pageScale, String? semanticsLabel
});




}
/// @nodoc
class _$PageSideCopyWithImpl<$Res>
    implements $PageSideCopyWith<$Res> {
  _$PageSideCopyWithImpl(this._self, this._then);

  final PageSide _self;
  final $Res Function(PageSide) _then;

/// Create a copy of PageSide
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = freezed,Object? minWidth = freezed,Object? maxWidth = freezed,Object? pageScale = freezed,Object? semanticsLabel = freezed,}) {
  return _then(PageSide(
type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as PageDrawerType?,minWidth: freezed == minWidth ? _self.minWidth : minWidth // ignore: cast_nullable_to_non_nullable
as double?,maxWidth: freezed == maxWidth ? _self.maxWidth : maxWidth // ignore: cast_nullable_to_non_nullable
as double?,pageScale: freezed == pageScale ? _self.pageScale : pageScale // ignore: cast_nullable_to_non_nullable
as double?,semanticsLabel: freezed == semanticsLabel ? _self.semanticsLabel : semanticsLabel // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PageSide].
extension PageSidePatterns on PageSide {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({required TResult orElse(),}){
final _that = this;
switch (_that) {
case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(){
final _that = this;
switch (_that) {
case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(){
final _that = this;
switch (_that) {
case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({required TResult orElse(),}) {final _that = this;
switch (_that) {
case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>() {final _that = this;
switch (_that) {
case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>() {final _that = this;
switch (_that) {
case _:
  return null;

}
}

}

// dart format on
