// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../scroll_focus_style.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ScrollFocusStyle {

/// The area's focus ring look, laid field by field over the lower
/// levels of the ring.
 StratumFocusBorderStyle? get focus;
/// Create a copy of ScrollFocusStyle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScrollFocusStyleCopyWith<ScrollFocusStyle> get copyWith => _$ScrollFocusStyleCopyWithImpl<ScrollFocusStyle>(this as ScrollFocusStyle, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ScrollFocusStyle;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScrollFocusStyle&&(identical(other.focus, _this.focus) || other.focus == _this.focus));
}


@override
int get hashCode {
  final _this = this as ScrollFocusStyle;
  return Object.hash(runtimeType,_this.focus);
}

@override
String toString() {
  final _this = this as ScrollFocusStyle;
  return 'ScrollFocusStyle(focus: ${_this.focus})';
}


}

/// @nodoc
abstract mixin class $ScrollFocusStyleCopyWith<$Res>  {
  factory $ScrollFocusStyleCopyWith(ScrollFocusStyle value, $Res Function(ScrollFocusStyle) _then) = _$ScrollFocusStyleCopyWithImpl;
@useResult
$Res call({
 StratumFocusBorderStyle? focus
});


$StratumFocusBorderStyleCopyWith<$Res>? get focus;

}
/// @nodoc
class _$ScrollFocusStyleCopyWithImpl<$Res>
    implements $ScrollFocusStyleCopyWith<$Res> {
  _$ScrollFocusStyleCopyWithImpl(this._self, this._then);

  final ScrollFocusStyle _self;
  final $Res Function(ScrollFocusStyle) _then;

/// Create a copy of ScrollFocusStyle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? focus = freezed,}) {
  return _then(ScrollFocusStyle(
focus: freezed == focus ? _self.focus : focus // ignore: cast_nullable_to_non_nullable
as StratumFocusBorderStyle?,
  ));
}
/// Create a copy of ScrollFocusStyle
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumFocusBorderStyleCopyWith<$Res>? get focus {
    if (_self.focus == null) {
    return null;
  }

  return $StratumFocusBorderStyleCopyWith<$Res>(_self.focus!, (value) {
    return _then(_self.copyWith(focus: value));
  });
}
}



/// @nodoc


class _ScrollFocusStyle implements ScrollFocusStyle {
  const _ScrollFocusStyle({this.focus});
  

/// The area's focus ring look, laid field by field over the lower
/// levels of the ring.
@override final  StratumFocusBorderStyle? focus;

/// Create a copy of ScrollFocusStyle
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScrollFocusStyleCopyWith<_ScrollFocusStyle> get copyWith => __$ScrollFocusStyleCopyWithImpl<_ScrollFocusStyle>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScrollFocusStyle&&(identical(other.focus, focus) || other.focus == focus));
}


@override
int get hashCode {
    return Object.hash(runtimeType,focus);
}

@override
String toString() {
    return 'ScrollFocusStyle(focus: $focus)';
}


}

/// @nodoc
abstract mixin class _$ScrollFocusStyleCopyWith<$Res> implements $ScrollFocusStyleCopyWith<$Res> {
  factory _$ScrollFocusStyleCopyWith(_ScrollFocusStyle value, $Res Function(_ScrollFocusStyle) _then) = __$ScrollFocusStyleCopyWithImpl;
@override @useResult
$Res call({
 StratumFocusBorderStyle? focus
});


@override $StratumFocusBorderStyleCopyWith<$Res>? get focus;

}
/// @nodoc
class __$ScrollFocusStyleCopyWithImpl<$Res>
    implements _$ScrollFocusStyleCopyWith<$Res> {
  __$ScrollFocusStyleCopyWithImpl(this._self, this._then);

  final _ScrollFocusStyle _self;
  final $Res Function(_ScrollFocusStyle) _then;

/// Create a copy of ScrollFocusStyle
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? focus = freezed,}) {
  return _then(_ScrollFocusStyle(
focus: freezed == focus ? _self.focus : focus // ignore: cast_nullable_to_non_nullable
as StratumFocusBorderStyle?,
  ));
}

/// Create a copy of ScrollFocusStyle
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumFocusBorderStyleCopyWith<$Res>? get focus {
    if (_self.focus == null) {
    return null;
  }

  return $StratumFocusBorderStyleCopyWith<$Res>(_self.focus!, (value) {
    return _then(_self.copyWith(focus: value));
  });
}
}

// dart format on
