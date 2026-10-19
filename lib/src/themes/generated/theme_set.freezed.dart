// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../theme_set.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StratumThemeSet {

 StratumThemeData get light;/// Null shows [light] in dark mode (FO-03 US-04 FR-01).
 StratumThemeData? get dark;/// Null shows [light] when high contrast is on.
 StratumThemeData? get highContrastLight;/// Null shows the dark pick when high contrast is on.
 StratumThemeData? get highContrastDark;
/// Create a copy of StratumThemeSet
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumThemeSetCopyWith<StratumThemeSet> get copyWith => _$StratumThemeSetCopyWithImpl<StratumThemeSet>(this as StratumThemeSet, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumThemeSet;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumThemeSet&&(identical(other.light, _this.light) || other.light == _this.light)&&(identical(other.dark, _this.dark) || other.dark == _this.dark)&&(identical(other.highContrastLight, _this.highContrastLight) || other.highContrastLight == _this.highContrastLight)&&(identical(other.highContrastDark, _this.highContrastDark) || other.highContrastDark == _this.highContrastDark));
}


@override
int get hashCode {
  final _this = this as StratumThemeSet;
  return Object.hash(runtimeType,_this.light,_this.dark,_this.highContrastLight,_this.highContrastDark);
}

@override
String toString() {
  final _this = this as StratumThemeSet;
  return 'StratumThemeSet(light: ${_this.light}, dark: ${_this.dark}, highContrastLight: ${_this.highContrastLight}, highContrastDark: ${_this.highContrastDark})';
}


}

/// @nodoc
abstract mixin class $StratumThemeSetCopyWith<$Res>  {
  factory $StratumThemeSetCopyWith(StratumThemeSet value, $Res Function(StratumThemeSet) _then) = _$StratumThemeSetCopyWithImpl;
@useResult
$Res call({
 StratumThemeData light, StratumThemeData? dark, StratumThemeData? highContrastLight, StratumThemeData? highContrastDark
});


$StratumThemeDataCopyWith<$Res> get light;$StratumThemeDataCopyWith<$Res>? get dark;$StratumThemeDataCopyWith<$Res>? get highContrastLight;$StratumThemeDataCopyWith<$Res>? get highContrastDark;

}
/// @nodoc
class _$StratumThemeSetCopyWithImpl<$Res>
    implements $StratumThemeSetCopyWith<$Res> {
  _$StratumThemeSetCopyWithImpl(this._self, this._then);

  final StratumThemeSet _self;
  final $Res Function(StratumThemeSet) _then;

/// Create a copy of StratumThemeSet
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? light = null,Object? dark = freezed,Object? highContrastLight = freezed,Object? highContrastDark = freezed,}) {
  return _then(StratumThemeSet(
light: null == light ? _self.light : light // ignore: cast_nullable_to_non_nullable
as StratumThemeData,dark: freezed == dark ? _self.dark : dark // ignore: cast_nullable_to_non_nullable
as StratumThemeData?,highContrastLight: freezed == highContrastLight ? _self.highContrastLight : highContrastLight // ignore: cast_nullable_to_non_nullable
as StratumThemeData?,highContrastDark: freezed == highContrastDark ? _self.highContrastDark : highContrastDark // ignore: cast_nullable_to_non_nullable
as StratumThemeData?,
  ));
}
/// Create a copy of StratumThemeSet
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumThemeDataCopyWith<$Res> get light {
  
  return $StratumThemeDataCopyWith<$Res>(_self.light, (value) {
    return _then(_self.copyWith(light: value));
  });
}/// Create a copy of StratumThemeSet
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumThemeDataCopyWith<$Res>? get dark {
    if (_self.dark == null) {
    return null;
  }

  return $StratumThemeDataCopyWith<$Res>(_self.dark!, (value) {
    return _then(_self.copyWith(dark: value));
  });
}/// Create a copy of StratumThemeSet
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumThemeDataCopyWith<$Res>? get highContrastLight {
    if (_self.highContrastLight == null) {
    return null;
  }

  return $StratumThemeDataCopyWith<$Res>(_self.highContrastLight!, (value) {
    return _then(_self.copyWith(highContrastLight: value));
  });
}/// Create a copy of StratumThemeSet
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumThemeDataCopyWith<$Res>? get highContrastDark {
    if (_self.highContrastDark == null) {
    return null;
  }

  return $StratumThemeDataCopyWith<$Res>(_self.highContrastDark!, (value) {
    return _then(_self.copyWith(highContrastDark: value));
  });
}
}



/// @nodoc


class _StratumThemeSet extends StratumThemeSet {
  const _StratumThemeSet({required this.light, this.dark, this.highContrastLight, this.highContrastDark}): super._();
  

@override final  StratumThemeData light;
/// Null shows [light] in dark mode (FO-03 US-04 FR-01).
@override final  StratumThemeData? dark;
/// Null shows [light] when high contrast is on.
@override final  StratumThemeData? highContrastLight;
/// Null shows the dark pick when high contrast is on.
@override final  StratumThemeData? highContrastDark;

/// Create a copy of StratumThemeSet
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StratumThemeSetCopyWith<_StratumThemeSet> get copyWith => __$StratumThemeSetCopyWithImpl<_StratumThemeSet>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StratumThemeSet&&(identical(other.light, light) || other.light == light)&&(identical(other.dark, dark) || other.dark == dark)&&(identical(other.highContrastLight, highContrastLight) || other.highContrastLight == highContrastLight)&&(identical(other.highContrastDark, highContrastDark) || other.highContrastDark == highContrastDark));
}


@override
int get hashCode {
    return Object.hash(runtimeType,light,dark,highContrastLight,highContrastDark);
}

@override
String toString() {
    return 'StratumThemeSet(light: $light, dark: $dark, highContrastLight: $highContrastLight, highContrastDark: $highContrastDark)';
}


}

/// @nodoc
abstract mixin class _$StratumThemeSetCopyWith<$Res> implements $StratumThemeSetCopyWith<$Res> {
  factory _$StratumThemeSetCopyWith(_StratumThemeSet value, $Res Function(_StratumThemeSet) _then) = __$StratumThemeSetCopyWithImpl;
@override @useResult
$Res call({
 StratumThemeData light, StratumThemeData? dark, StratumThemeData? highContrastLight, StratumThemeData? highContrastDark
});


@override $StratumThemeDataCopyWith<$Res> get light;@override $StratumThemeDataCopyWith<$Res>? get dark;@override $StratumThemeDataCopyWith<$Res>? get highContrastLight;@override $StratumThemeDataCopyWith<$Res>? get highContrastDark;

}
/// @nodoc
class __$StratumThemeSetCopyWithImpl<$Res>
    implements _$StratumThemeSetCopyWith<$Res> {
  __$StratumThemeSetCopyWithImpl(this._self, this._then);

  final _StratumThemeSet _self;
  final $Res Function(_StratumThemeSet) _then;

/// Create a copy of StratumThemeSet
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? light = null,Object? dark = freezed,Object? highContrastLight = freezed,Object? highContrastDark = freezed,}) {
  return _then(_StratumThemeSet(
light: null == light ? _self.light : light // ignore: cast_nullable_to_non_nullable
as StratumThemeData,dark: freezed == dark ? _self.dark : dark // ignore: cast_nullable_to_non_nullable
as StratumThemeData?,highContrastLight: freezed == highContrastLight ? _self.highContrastLight : highContrastLight // ignore: cast_nullable_to_non_nullable
as StratumThemeData?,highContrastDark: freezed == highContrastDark ? _self.highContrastDark : highContrastDark // ignore: cast_nullable_to_non_nullable
as StratumThemeData?,
  ));
}

/// Create a copy of StratumThemeSet
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumThemeDataCopyWith<$Res> get light {
  
  return $StratumThemeDataCopyWith<$Res>(_self.light, (value) {
    return _then(_self.copyWith(light: value));
  });
}/// Create a copy of StratumThemeSet
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumThemeDataCopyWith<$Res>? get dark {
    if (_self.dark == null) {
    return null;
  }

  return $StratumThemeDataCopyWith<$Res>(_self.dark!, (value) {
    return _then(_self.copyWith(dark: value));
  });
}/// Create a copy of StratumThemeSet
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumThemeDataCopyWith<$Res>? get highContrastLight {
    if (_self.highContrastLight == null) {
    return null;
  }

  return $StratumThemeDataCopyWith<$Res>(_self.highContrastLight!, (value) {
    return _then(_self.copyWith(highContrastLight: value));
  });
}/// Create a copy of StratumThemeSet
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumThemeDataCopyWith<$Res>? get highContrastDark {
    if (_self.highContrastDark == null) {
    return null;
  }

  return $StratumThemeDataCopyWith<$Res>(_self.highContrastDark!, (value) {
    return _then(_self.copyWith(highContrastDark: value));
  });
}
}

// dart format on
