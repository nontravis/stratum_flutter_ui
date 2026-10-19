// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../animation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StratumMotionLevels {


/// Create a copy of StratumMotionLevels
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumMotionLevelsCopyWith<StratumMotionLevels> get copyWith => _$StratumMotionLevelsCopyWithImpl<StratumMotionLevels>(this as StratumMotionLevels, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumMotionLevels;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumMotionLevels&&(identical(other.micro, _this.micro) || other.micro == _this.micro)&&(identical(other.veryFast, _this.veryFast) || other.veryFast == _this.veryFast)&&(identical(other.fast, _this.fast) || other.fast == _this.fast)&&(identical(other.normal, _this.normal) || other.normal == _this.normal)&&(identical(other.slow, _this.slow) || other.slow == _this.slow)&&(identical(other.verySlow, _this.verySlow) || other.verySlow == _this.verySlow));
}


@override
int get hashCode {
  final _this = this as StratumMotionLevels;
  return Object.hash(runtimeType,_this.micro,_this.veryFast,_this.fast,_this.normal,_this.slow,_this.verySlow);
}

@override
String toString() {
  final _this = this as StratumMotionLevels;
  return 'StratumMotionLevels(micro: ${_this.micro}, veryFast: ${_this.veryFast}, fast: ${_this.fast}, normal: ${_this.normal}, slow: ${_this.slow}, verySlow: ${_this.verySlow})';
}


}

/// @nodoc
abstract mixin class $StratumMotionLevelsCopyWith<$Res>  {
  factory $StratumMotionLevelsCopyWith(StratumMotionLevels value, $Res Function(StratumMotionLevels) _then) = _$StratumMotionLevelsCopyWithImpl;
@useResult
$Res call({
 AnimationStyle micro, AnimationStyle veryFast, AnimationStyle fast, AnimationStyle normal, AnimationStyle slow, AnimationStyle verySlow
});




}
/// @nodoc
class _$StratumMotionLevelsCopyWithImpl<$Res>
    implements $StratumMotionLevelsCopyWith<$Res> {
  _$StratumMotionLevelsCopyWithImpl(this._self, this._then);

  final StratumMotionLevels _self;
  final $Res Function(StratumMotionLevels) _then;

/// Create a copy of StratumMotionLevels
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? micro = null,Object? veryFast = null,Object? fast = null,Object? normal = null,Object? slow = null,Object? verySlow = null,}) {
  return _then(StratumMotionLevels(
micro: null == micro ? _self.micro : micro // ignore: cast_nullable_to_non_nullable
as AnimationStyle,veryFast: null == veryFast ? _self.veryFast : veryFast // ignore: cast_nullable_to_non_nullable
as AnimationStyle,fast: null == fast ? _self.fast : fast // ignore: cast_nullable_to_non_nullable
as AnimationStyle,normal: null == normal ? _self.normal : normal // ignore: cast_nullable_to_non_nullable
as AnimationStyle,slow: null == slow ? _self.slow : slow // ignore: cast_nullable_to_non_nullable
as AnimationStyle,verySlow: null == verySlow ? _self.verySlow : verySlow // ignore: cast_nullable_to_non_nullable
as AnimationStyle,
  ));
}

}



/// @nodoc
mixin _$StratumAnimation {


/// Create a copy of StratumAnimation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumAnimationCopyWith<StratumAnimation> get copyWith => _$StratumAnimationCopyWithImpl<StratumAnimation>(this as StratumAnimation, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumAnimation;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumAnimation&&(identical(other.micro, _this.micro) || other.micro == _this.micro)&&(identical(other.veryFast, _this.veryFast) || other.veryFast == _this.veryFast)&&(identical(other.fast, _this.fast) || other.fast == _this.fast)&&(identical(other.normal, _this.normal) || other.normal == _this.normal)&&(identical(other.slow, _this.slow) || other.slow == _this.slow)&&(identical(other.verySlow, _this.verySlow) || other.verySlow == _this.verySlow)&&(identical(other.appear, _this.appear) || other.appear == _this.appear)&&(identical(other.defaultLevel, _this.defaultLevel) || other.defaultLevel == _this.defaultLevel)&&(identical(other.transition, _this.transition) || other.transition == _this.transition));
}


@override
int get hashCode {
  final _this = this as StratumAnimation;
  return Object.hash(runtimeType,_this.micro,_this.veryFast,_this.fast,_this.normal,_this.slow,_this.verySlow,_this.appear,_this.defaultLevel,_this.transition);
}

@override
String toString() {
  final _this = this as StratumAnimation;
  return 'StratumAnimation(micro: ${_this.micro}, veryFast: ${_this.veryFast}, fast: ${_this.fast}, normal: ${_this.normal}, slow: ${_this.slow}, verySlow: ${_this.verySlow}, appear: ${_this.appear}, defaultLevel: ${_this.defaultLevel}, transition: ${_this.transition})';
}


}

/// @nodoc
abstract mixin class $StratumAnimationCopyWith<$Res> implements $StratumMotionLevelsCopyWith<$Res> {
  factory $StratumAnimationCopyWith(StratumAnimation value, $Res Function(StratumAnimation) _then) = _$StratumAnimationCopyWithImpl;
@useResult
$Res call({
 AnimationStyle micro, AnimationStyle veryFast, AnimationStyle fast, AnimationStyle normal, AnimationStyle slow, AnimationStyle verySlow, StratumMotionLevels appear, StratumMotionLevel defaultLevel, StratumThemeTransitions transition
});


$StratumMotionLevelsCopyWith<$Res> get appear;$StratumThemeTransitionsCopyWith<$Res> get transition;

}
/// @nodoc
class _$StratumAnimationCopyWithImpl<$Res>
    implements $StratumAnimationCopyWith<$Res> {
  _$StratumAnimationCopyWithImpl(this._self, this._then);

  final StratumAnimation _self;
  final $Res Function(StratumAnimation) _then;

/// Create a copy of StratumAnimation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? micro = null,Object? veryFast = null,Object? fast = null,Object? normal = null,Object? slow = null,Object? verySlow = null,Object? appear = null,Object? defaultLevel = null,Object? transition = null,}) {
  return _then(StratumAnimation(
micro: null == micro ? _self.micro : micro // ignore: cast_nullable_to_non_nullable
as AnimationStyle,veryFast: null == veryFast ? _self.veryFast : veryFast // ignore: cast_nullable_to_non_nullable
as AnimationStyle,fast: null == fast ? _self.fast : fast // ignore: cast_nullable_to_non_nullable
as AnimationStyle,normal: null == normal ? _self.normal : normal // ignore: cast_nullable_to_non_nullable
as AnimationStyle,slow: null == slow ? _self.slow : slow // ignore: cast_nullable_to_non_nullable
as AnimationStyle,verySlow: null == verySlow ? _self.verySlow : verySlow // ignore: cast_nullable_to_non_nullable
as AnimationStyle,appear: null == appear ? _self.appear : appear // ignore: cast_nullable_to_non_nullable
as StratumMotionLevels,defaultLevel: null == defaultLevel ? _self.defaultLevel : defaultLevel // ignore: cast_nullable_to_non_nullable
as StratumMotionLevel,transition: null == transition ? _self.transition : transition // ignore: cast_nullable_to_non_nullable
as StratumThemeTransitions,
  ));
}
/// Create a copy of StratumAnimation
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumMotionLevelsCopyWith<$Res> get appear {
  
  return $StratumMotionLevelsCopyWith<$Res>(_self.appear, (value) {
    return _then(_self.copyWith(appear: value));
  });
}/// Create a copy of StratumAnimation
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumThemeTransitionsCopyWith<$Res> get transition {
  
  return $StratumThemeTransitionsCopyWith<$Res>(_self.transition, (value) {
    return _then(_self.copyWith(transition: value));
  });
}
}



// dart format on
