// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../split_layout_style.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SplitLayoutStyle {

/// The dividers' focus ring look, laid field by field over the lower
/// levels of the ring.
 StratumFocusBorderStyle? get focus;
/// Create a copy of SplitLayoutStyle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SplitLayoutStyleCopyWith<SplitLayoutStyle> get copyWith => _$SplitLayoutStyleCopyWithImpl<SplitLayoutStyle>(this as SplitLayoutStyle, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SplitLayoutStyle;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SplitLayoutStyle&&(identical(other.focus, _this.focus) || other.focus == _this.focus));
}


@override
int get hashCode {
  final _this = this as SplitLayoutStyle;
  return Object.hash(runtimeType,_this.focus);
}

@override
String toString() {
  final _this = this as SplitLayoutStyle;
  return 'SplitLayoutStyle(focus: ${_this.focus})';
}


}

/// @nodoc
abstract mixin class $SplitLayoutStyleCopyWith<$Res>  {
  factory $SplitLayoutStyleCopyWith(SplitLayoutStyle value, $Res Function(SplitLayoutStyle) _then) = _$SplitLayoutStyleCopyWithImpl;
@useResult
$Res call({
 StratumFocusBorderStyle? focus
});


$StratumFocusBorderStyleCopyWith<$Res>? get focus;

}
/// @nodoc
class _$SplitLayoutStyleCopyWithImpl<$Res>
    implements $SplitLayoutStyleCopyWith<$Res> {
  _$SplitLayoutStyleCopyWithImpl(this._self, this._then);

  final SplitLayoutStyle _self;
  final $Res Function(SplitLayoutStyle) _then;

/// Create a copy of SplitLayoutStyle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? focus = freezed,}) {
  return _then(SplitLayoutStyle(
focus: freezed == focus ? _self.focus : focus // ignore: cast_nullable_to_non_nullable
as StratumFocusBorderStyle?,
  ));
}
/// Create a copy of SplitLayoutStyle
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


class _SplitLayoutStyle implements SplitLayoutStyle {
  const _SplitLayoutStyle({this.focus});
  

/// The dividers' focus ring look, laid field by field over the lower
/// levels of the ring.
@override final  StratumFocusBorderStyle? focus;

/// Create a copy of SplitLayoutStyle
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SplitLayoutStyleCopyWith<_SplitLayoutStyle> get copyWith => __$SplitLayoutStyleCopyWithImpl<_SplitLayoutStyle>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SplitLayoutStyle&&(identical(other.focus, focus) || other.focus == focus));
}


@override
int get hashCode {
    return Object.hash(runtimeType,focus);
}

@override
String toString() {
    return 'SplitLayoutStyle(focus: $focus)';
}


}

/// @nodoc
abstract mixin class _$SplitLayoutStyleCopyWith<$Res> implements $SplitLayoutStyleCopyWith<$Res> {
  factory _$SplitLayoutStyleCopyWith(_SplitLayoutStyle value, $Res Function(_SplitLayoutStyle) _then) = __$SplitLayoutStyleCopyWithImpl;
@override @useResult
$Res call({
 StratumFocusBorderStyle? focus
});


@override $StratumFocusBorderStyleCopyWith<$Res>? get focus;

}
/// @nodoc
class __$SplitLayoutStyleCopyWithImpl<$Res>
    implements _$SplitLayoutStyleCopyWith<$Res> {
  __$SplitLayoutStyleCopyWithImpl(this._self, this._then);

  final _SplitLayoutStyle _self;
  final $Res Function(_SplitLayoutStyle) _then;

/// Create a copy of SplitLayoutStyle
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? focus = freezed,}) {
  return _then(_SplitLayoutStyle(
focus: freezed == focus ? _self.focus : focus // ignore: cast_nullable_to_non_nullable
as StratumFocusBorderStyle?,
  ));
}

/// Create a copy of SplitLayoutStyle
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
