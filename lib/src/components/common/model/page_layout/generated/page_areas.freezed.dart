// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../page_areas.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PageAreas {


/// Create a copy of PageAreas
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PageAreasCopyWith<PageAreas> get copyWith => _$PageAreasCopyWithImpl<PageAreas>(this as PageAreas, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PageAreas;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PageAreas&&(identical(other.body, _this.body) || other.body == _this.body)&&(identical(other.footerTop, _this.footerTop) || other.footerTop == _this.footerTop)&&(identical(other.bottomTop, _this.bottomTop) || other.bottomTop == _this.bottomTop)&&(identical(other.left, _this.left) || other.left == _this.left)&&(identical(other.snack, _this.snack) || other.snack == _this.snack));
}


@override
int get hashCode {
  final _this = this as PageAreas;
  return Object.hash(runtimeType,_this.body,_this.footerTop,_this.bottomTop,_this.left,_this.snack);
}

@override
String toString() {
  final _this = this as PageAreas;
  return 'PageAreas(body: ${_this.body}, footerTop: ${_this.footerTop}, bottomTop: ${_this.bottomTop}, left: ${_this.left}, snack: ${_this.snack})';
}


}

/// @nodoc
abstract mixin class $PageAreasCopyWith<$Res>  {
  factory $PageAreasCopyWith(PageAreas value, $Res Function(PageAreas) _then) = _$PageAreasCopyWithImpl;
@useResult
$Res call({
 Rect? body, double? footerTop, double? bottomTop, Rect? left, WidgetStyle? snack
});


$WidgetStyleCopyWith<$Res>? get snack;

}
/// @nodoc
class _$PageAreasCopyWithImpl<$Res>
    implements $PageAreasCopyWith<$Res> {
  _$PageAreasCopyWithImpl(this._self, this._then);

  final PageAreas _self;
  final $Res Function(PageAreas) _then;

/// Create a copy of PageAreas
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? body = freezed,Object? footerTop = freezed,Object? bottomTop = freezed,Object? left = freezed,Object? snack = freezed,}) {
  return _then(PageAreas(
body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as Rect?,footerTop: freezed == footerTop ? _self.footerTop : footerTop // ignore: cast_nullable_to_non_nullable
as double?,bottomTop: freezed == bottomTop ? _self.bottomTop : bottomTop // ignore: cast_nullable_to_non_nullable
as double?,left: freezed == left ? _self.left : left // ignore: cast_nullable_to_non_nullable
as Rect?,snack: freezed == snack ? _self.snack : snack // ignore: cast_nullable_to_non_nullable
as WidgetStyle?,
  ));
}
/// Create a copy of PageAreas
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WidgetStyleCopyWith<$Res>? get snack {
    if (_self.snack == null) {
    return null;
  }

  return $WidgetStyleCopyWith<$Res>(_self.snack!, (value) {
    return _then(_self.copyWith(snack: value));
  });
}
}


/// Adds pattern-matching-related methods to [PageAreas].
extension PageAreasPatterns on PageAreas {
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
