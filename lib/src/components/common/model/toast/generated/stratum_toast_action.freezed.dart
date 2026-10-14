// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../stratum_toast_action.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StratumToastAction {


/// Create a copy of StratumToastAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumToastActionCopyWith<StratumToastAction> get copyWith => _$StratumToastActionCopyWithImpl<StratumToastAction>(this as StratumToastAction, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumToastAction;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumToastAction&&(identical(other.label, _this.label) || other.label == _this.label)&&(identical(other.onPressed, _this.onPressed) || other.onPressed == _this.onPressed));
}


@override
int get hashCode {
  final _this = this as StratumToastAction;
  return Object.hash(runtimeType,_this.label,_this.onPressed);
}

@override
String toString() {
  final _this = this as StratumToastAction;
  return 'StratumToastAction(label: ${_this.label}, onPressed: ${_this.onPressed})';
}


}

/// @nodoc
abstract mixin class $StratumToastActionCopyWith<$Res>  {
  factory $StratumToastActionCopyWith(StratumToastAction value, $Res Function(StratumToastAction) _then) = _$StratumToastActionCopyWithImpl;
@useResult
$Res call({
 String label, VoidCallback onPressed
});




}
/// @nodoc
class _$StratumToastActionCopyWithImpl<$Res>
    implements $StratumToastActionCopyWith<$Res> {
  _$StratumToastActionCopyWithImpl(this._self, this._then);

  final StratumToastAction _self;
  final $Res Function(StratumToastAction) _then;

/// Create a copy of StratumToastAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? label = null,Object? onPressed = null,}) {
  return _then(StratumToastAction(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,onPressed: null == onPressed ? _self.onPressed : onPressed // ignore: cast_nullable_to_non_nullable
as VoidCallback,
  ));
}

}


/// Adds pattern-matching-related methods to [StratumToastAction].
extension StratumToastActionPatterns on StratumToastAction {
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
