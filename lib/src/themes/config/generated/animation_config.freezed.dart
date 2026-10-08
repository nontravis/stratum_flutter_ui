// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../animation_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StratumAnimationConfig {

/// Level name to forward duration: the levels of `animation.duration`
/// other than `default`.
 Map<String, Duration> get durations;/// `animation.duration.default`, a key of [durations].
 String get defaultLevel;/// `animation.reverseDuration` as a ratio: 0.64 for `64%`.
 double get reverseRatio;/// `animation.curve`: `standard`, `enter`, `exit`.
 Map<String, StratumCurve> get curves;/// `animation.transition`: window size name to page transition type
/// name, one for each of `watch`, `mobile`, `tablet`, `desktop`, and
/// `bigDesktop`. A config built by hand that sets none names
/// `platform` for all five, as the package default does.
 Map<String, String> get transitions;
/// Create a copy of StratumAnimationConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumAnimationConfigCopyWith<StratumAnimationConfig> get copyWith => _$StratumAnimationConfigCopyWithImpl<StratumAnimationConfig>(this as StratumAnimationConfig, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumAnimationConfig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumAnimationConfig&&const DeepCollectionEquality().equals(other.durations, _this.durations)&&(identical(other.defaultLevel, _this.defaultLevel) || other.defaultLevel == _this.defaultLevel)&&(identical(other.reverseRatio, _this.reverseRatio) || other.reverseRatio == _this.reverseRatio)&&const DeepCollectionEquality().equals(other.curves, _this.curves)&&const DeepCollectionEquality().equals(other.transitions, _this.transitions));
}


@override
int get hashCode {
  final _this = this as StratumAnimationConfig;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.durations),_this.defaultLevel,_this.reverseRatio,const DeepCollectionEquality().hash(_this.curves),const DeepCollectionEquality().hash(_this.transitions));
}

@override
String toString() {
  final _this = this as StratumAnimationConfig;
  return 'StratumAnimationConfig(durations: ${_this.durations}, defaultLevel: ${_this.defaultLevel}, reverseRatio: ${_this.reverseRatio}, curves: ${_this.curves}, transitions: ${_this.transitions})';
}


}

/// @nodoc
abstract mixin class $StratumAnimationConfigCopyWith<$Res>  {
  factory $StratumAnimationConfigCopyWith(StratumAnimationConfig value, $Res Function(StratumAnimationConfig) _then) = _$StratumAnimationConfigCopyWithImpl;
@useResult
$Res call({
 Map<String, Duration> durations, String defaultLevel, double reverseRatio, Map<String, StratumCurve> curves, Map<String, String> transitions
});




}
/// @nodoc
class _$StratumAnimationConfigCopyWithImpl<$Res>
    implements $StratumAnimationConfigCopyWith<$Res> {
  _$StratumAnimationConfigCopyWithImpl(this._self, this._then);

  final StratumAnimationConfig _self;
  final $Res Function(StratumAnimationConfig) _then;

/// Create a copy of StratumAnimationConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? durations = null,Object? defaultLevel = null,Object? reverseRatio = null,Object? curves = null,Object? transitions = null,}) {
  return _then(StratumAnimationConfig(
durations: null == durations ? _self.durations : durations // ignore: cast_nullable_to_non_nullable
as Map<String, Duration>,defaultLevel: null == defaultLevel ? _self.defaultLevel : defaultLevel // ignore: cast_nullable_to_non_nullable
as String,reverseRatio: null == reverseRatio ? _self.reverseRatio : reverseRatio // ignore: cast_nullable_to_non_nullable
as double,curves: null == curves ? _self.curves : curves // ignore: cast_nullable_to_non_nullable
as Map<String, StratumCurve>,transitions: null == transitions ? _self.transitions : transitions // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}

}



/// @nodoc


class _StratumAnimationConfig implements StratumAnimationConfig {
  const _StratumAnimationConfig({required  Map<String, Duration> durations, required this.defaultLevel, required this.reverseRatio, required  Map<String, StratumCurve> curves,  Map<String, String> transitions = const <String, String>{'watch' : 'platform', 'mobile' : 'platform', 'tablet' : 'platform', 'desktop' : 'platform', 'bigDesktop' : 'platform'}}): _durations = durations,_curves = curves,_transitions = transitions;
  

/// Level name to forward duration: the levels of `animation.duration`
/// other than `default`.
 final  Map<String, Duration> _durations;
/// Level name to forward duration: the levels of `animation.duration`
/// other than `default`.
@override Map<String, Duration> get durations {
  if (_durations is EqualUnmodifiableMapView) return _durations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_durations);
}

/// `animation.duration.default`, a key of [durations].
@override final  String defaultLevel;
/// `animation.reverseDuration` as a ratio: 0.64 for `64%`.
@override final  double reverseRatio;
/// `animation.curve`: `standard`, `enter`, `exit`.
 final  Map<String, StratumCurve> _curves;
/// `animation.curve`: `standard`, `enter`, `exit`.
@override Map<String, StratumCurve> get curves {
  if (_curves is EqualUnmodifiableMapView) return _curves;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_curves);
}

/// `animation.transition`: window size name to page transition type
/// name, one for each of `watch`, `mobile`, `tablet`, `desktop`, and
/// `bigDesktop`. A config built by hand that sets none names
/// `platform` for all five, as the package default does.
 final  Map<String, String> _transitions;
/// `animation.transition`: window size name to page transition type
/// name, one for each of `watch`, `mobile`, `tablet`, `desktop`, and
/// `bigDesktop`. A config built by hand that sets none names
/// `platform` for all five, as the package default does.
@override@JsonKey() Map<String, String> get transitions {
  if (_transitions is EqualUnmodifiableMapView) return _transitions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_transitions);
}


/// Create a copy of StratumAnimationConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StratumAnimationConfigCopyWith<_StratumAnimationConfig> get copyWith => __$StratumAnimationConfigCopyWithImpl<_StratumAnimationConfig>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StratumAnimationConfig&&const DeepCollectionEquality().equals(other.durations, _durations)&&(identical(other.defaultLevel, defaultLevel) || other.defaultLevel == defaultLevel)&&(identical(other.reverseRatio, reverseRatio) || other.reverseRatio == reverseRatio)&&const DeepCollectionEquality().equals(other.curves, _curves)&&const DeepCollectionEquality().equals(other.transitions, _transitions));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_durations),defaultLevel,reverseRatio,const DeepCollectionEquality().hash(_curves),const DeepCollectionEquality().hash(_transitions));
}

@override
String toString() {
    return 'StratumAnimationConfig(durations: $durations, defaultLevel: $defaultLevel, reverseRatio: $reverseRatio, curves: $curves, transitions: $transitions)';
}


}

/// @nodoc
abstract mixin class _$StratumAnimationConfigCopyWith<$Res> implements $StratumAnimationConfigCopyWith<$Res> {
  factory _$StratumAnimationConfigCopyWith(_StratumAnimationConfig value, $Res Function(_StratumAnimationConfig) _then) = __$StratumAnimationConfigCopyWithImpl;
@override @useResult
$Res call({
 Map<String, Duration> durations, String defaultLevel, double reverseRatio, Map<String, StratumCurve> curves, Map<String, String> transitions
});




}
/// @nodoc
class __$StratumAnimationConfigCopyWithImpl<$Res>
    implements _$StratumAnimationConfigCopyWith<$Res> {
  __$StratumAnimationConfigCopyWithImpl(this._self, this._then);

  final _StratumAnimationConfig _self;
  final $Res Function(_StratumAnimationConfig) _then;

/// Create a copy of StratumAnimationConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? durations = null,Object? defaultLevel = null,Object? reverseRatio = null,Object? curves = null,Object? transitions = null,}) {
  return _then(_StratumAnimationConfig(
durations: null == durations ? _self._durations : durations // ignore: cast_nullable_to_non_nullable
as Map<String, Duration>,defaultLevel: null == defaultLevel ? _self.defaultLevel : defaultLevel // ignore: cast_nullable_to_non_nullable
as String,reverseRatio: null == reverseRatio ? _self.reverseRatio : reverseRatio // ignore: cast_nullable_to_non_nullable
as double,curves: null == curves ? _self._curves : curves // ignore: cast_nullable_to_non_nullable
as Map<String, StratumCurve>,transitions: null == transitions ? _self._transitions : transitions // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}


}

/// @nodoc
mixin _$StratumNamedCurve {


/// Create a copy of StratumNamedCurve
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumNamedCurveCopyWith<StratumNamedCurve> get copyWith => _$StratumNamedCurveCopyWithImpl<StratumNamedCurve>(this as StratumNamedCurve, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumNamedCurve;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumNamedCurve&&(identical(other.name, _this.name) || other.name == _this.name));
}


@override
int get hashCode {
  final _this = this as StratumNamedCurve;
  return Object.hash(runtimeType,_this.name);
}



}

/// @nodoc
abstract mixin class $StratumNamedCurveCopyWith<$Res>  {
  factory $StratumNamedCurveCopyWith(StratumNamedCurve value, $Res Function(StratumNamedCurve) _then) = _$StratumNamedCurveCopyWithImpl;
@useResult
$Res call({
 String name
});




}
/// @nodoc
class _$StratumNamedCurveCopyWithImpl<$Res>
    implements $StratumNamedCurveCopyWith<$Res> {
  _$StratumNamedCurveCopyWithImpl(this._self, this._then);

  final StratumNamedCurve _self;
  final $Res Function(StratumNamedCurve) _then;

/// Create a copy of StratumNamedCurve
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,}) {
  return _then(StratumNamedCurve(
null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
mixin _$StratumCubicCurve {


/// Create a copy of StratumCubicCurve
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumCubicCurveCopyWith<StratumCubicCurve> get copyWith => _$StratumCubicCurveCopyWithImpl<StratumCubicCurve>(this as StratumCubicCurve, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumCubicCurve;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumCubicCurve&&(identical(other.a, _this.a) || other.a == _this.a)&&(identical(other.b, _this.b) || other.b == _this.b)&&(identical(other.c, _this.c) || other.c == _this.c)&&(identical(other.d, _this.d) || other.d == _this.d));
}


@override
int get hashCode {
  final _this = this as StratumCubicCurve;
  return Object.hash(runtimeType,_this.a,_this.b,_this.c,_this.d);
}



}

/// @nodoc
abstract mixin class $StratumCubicCurveCopyWith<$Res>  {
  factory $StratumCubicCurveCopyWith(StratumCubicCurve value, $Res Function(StratumCubicCurve) _then) = _$StratumCubicCurveCopyWithImpl;
@useResult
$Res call({
 double a, double b, double c, double d
});




}
/// @nodoc
class _$StratumCubicCurveCopyWithImpl<$Res>
    implements $StratumCubicCurveCopyWith<$Res> {
  _$StratumCubicCurveCopyWithImpl(this._self, this._then);

  final StratumCubicCurve _self;
  final $Res Function(StratumCubicCurve) _then;

/// Create a copy of StratumCubicCurve
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? a = null,Object? b = null,Object? c = null,Object? d = null,}) {
  return _then(StratumCubicCurve(
null == a ? _self.a : a // ignore: cast_nullable_to_non_nullable
as double,null == b ? _self.b : b // ignore: cast_nullable_to_non_nullable
as double,null == c ? _self.c : c // ignore: cast_nullable_to_non_nullable
as double,null == d ? _self.d : d // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}



// dart format on
