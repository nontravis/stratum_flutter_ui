// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../split_pane.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SplitPane {


/// Create a copy of SplitPane
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SplitPaneCopyWith<SplitPane> get copyWith => _$SplitPaneCopyWithImpl<SplitPane>(this as SplitPane, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SplitPane;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SplitPane&&(identical(other.child, _this.child) || other.child == _this.child)&&(identical(other.size, _this.size) || other.size == _this.size)&&(identical(other.flex, _this.flex) || other.flex == _this.flex)&&(identical(other.min, _this.min) || other.min == _this.min)&&(identical(other.max, _this.max) || other.max == _this.max));
}


@override
int get hashCode {
  final _this = this as SplitPane;
  return Object.hash(runtimeType,_this.child,_this.size,_this.flex,_this.min,_this.max);
}

@override
String toString() {
  final _this = this as SplitPane;
  return 'SplitPane(child: ${_this.child}, size: ${_this.size}, flex: ${_this.flex}, min: ${_this.min}, max: ${_this.max})';
}


}

/// @nodoc
abstract mixin class $SplitPaneCopyWith<$Res>  {
  factory $SplitPaneCopyWith(SplitPane value, $Res Function(SplitPane) _then) = _$SplitPaneCopyWithImpl;
@useResult
$Res call({
 Widget child, double? size, double? flex, double? min, double? max
});




}
/// @nodoc
class _$SplitPaneCopyWithImpl<$Res>
    implements $SplitPaneCopyWith<$Res> {
  _$SplitPaneCopyWithImpl(this._self, this._then);

  final SplitPane _self;
  final $Res Function(SplitPane) _then;

/// Create a copy of SplitPane
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? child = null,Object? size = freezed,Object? flex = freezed,Object? min = freezed,Object? max = freezed,}) {
  return _then(SplitPane(
child: null == child ? _self.child : child // ignore: cast_nullable_to_non_nullable
as Widget,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as double?,flex: freezed == flex ? _self.flex : flex // ignore: cast_nullable_to_non_nullable
as double?,min: freezed == min ? _self.min : min // ignore: cast_nullable_to_non_nullable
as double?,max: freezed == max ? _self.max : max // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [SplitPane].
extension SplitPanePatterns on SplitPane {
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
