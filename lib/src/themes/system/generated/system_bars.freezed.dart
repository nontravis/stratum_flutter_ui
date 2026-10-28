// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../system_bars.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SystemBars {

/// The status bar fields, and the navigation bar fields when the
/// navigation bar's point was read; every bar color in it is
/// transparent, since the root paints the bar colors itself (themes s03
/// INV-45).
 SystemUiOverlayStyle get overlay;/// Null when no layer sets one this frame; the resolver falls back to
/// `edgeToEdge` only once some layer has set it during its life, and
/// before that leaves the platform's own bar mode untouched (R11).
 SystemBarMode? get barMode;/// Null when no layer sets one this frame; the resolver falls back to
/// no lock only once some layer has set it during its life, and before
/// that leaves the platform's own rotation lock untouched (R11).
 List<DeviceOrientation>? get orientations;/// Null when no layer sets one.
 String? get appSwitcherLabel;/// The merged `appSwitcherColor`.
 Color? get appSwitcherColor;/// The merged `statusBarColor`, which the root paints under the status
/// bar.
 Color? get statusBarColor;/// The merged `navigationBarColor`, which the root paints under the
/// navigation bar; null when its point was not read.
 Color? get navigationBarColor;/// The merged `navigationBarDividerColor`, which the root paints as the
/// navigation bar's edge line; null when its point was not read.
 Color? get navigationBarDividerColor;
/// Create a copy of SystemBars
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SystemBarsCopyWith<SystemBars> get copyWith => _$SystemBarsCopyWithImpl<SystemBars>(this as SystemBars, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SystemBars;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SystemBars&&(identical(other.overlay, _this.overlay) || other.overlay == _this.overlay)&&(identical(other.barMode, _this.barMode) || other.barMode == _this.barMode)&&const DeepCollectionEquality().equals(other.orientations, _this.orientations)&&(identical(other.appSwitcherLabel, _this.appSwitcherLabel) || other.appSwitcherLabel == _this.appSwitcherLabel)&&(identical(other.appSwitcherColor, _this.appSwitcherColor) || other.appSwitcherColor == _this.appSwitcherColor)&&(identical(other.statusBarColor, _this.statusBarColor) || other.statusBarColor == _this.statusBarColor)&&(identical(other.navigationBarColor, _this.navigationBarColor) || other.navigationBarColor == _this.navigationBarColor)&&(identical(other.navigationBarDividerColor, _this.navigationBarDividerColor) || other.navigationBarDividerColor == _this.navigationBarDividerColor));
}


@override
int get hashCode {
  final _this = this as SystemBars;
  return Object.hash(runtimeType,_this.overlay,_this.barMode,const DeepCollectionEquality().hash(_this.orientations),_this.appSwitcherLabel,_this.appSwitcherColor,_this.statusBarColor,_this.navigationBarColor,_this.navigationBarDividerColor);
}

@override
String toString() {
  final _this = this as SystemBars;
  return 'SystemBars(overlay: ${_this.overlay}, barMode: ${_this.barMode}, orientations: ${_this.orientations}, appSwitcherLabel: ${_this.appSwitcherLabel}, appSwitcherColor: ${_this.appSwitcherColor}, statusBarColor: ${_this.statusBarColor}, navigationBarColor: ${_this.navigationBarColor}, navigationBarDividerColor: ${_this.navigationBarDividerColor})';
}


}

/// @nodoc
abstract mixin class $SystemBarsCopyWith<$Res>  {
  factory $SystemBarsCopyWith(SystemBars value, $Res Function(SystemBars) _then) = _$SystemBarsCopyWithImpl;
@useResult
$Res call({
 SystemUiOverlayStyle overlay, SystemBarMode? barMode, List<DeviceOrientation>? orientations, String? appSwitcherLabel, Color? appSwitcherColor, Color? statusBarColor, Color? navigationBarColor, Color? navigationBarDividerColor
});




}
/// @nodoc
class _$SystemBarsCopyWithImpl<$Res>
    implements $SystemBarsCopyWith<$Res> {
  _$SystemBarsCopyWithImpl(this._self, this._then);

  final SystemBars _self;
  final $Res Function(SystemBars) _then;

/// Create a copy of SystemBars
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? overlay = null,Object? barMode = freezed,Object? orientations = freezed,Object? appSwitcherLabel = freezed,Object? appSwitcherColor = freezed,Object? statusBarColor = freezed,Object? navigationBarColor = freezed,Object? navigationBarDividerColor = freezed,}) {
  return _then(SystemBars(
overlay: null == overlay ? _self.overlay : overlay // ignore: cast_nullable_to_non_nullable
as SystemUiOverlayStyle,barMode: freezed == barMode ? _self.barMode : barMode // ignore: cast_nullable_to_non_nullable
as SystemBarMode?,orientations: freezed == orientations ? _self.orientations : orientations // ignore: cast_nullable_to_non_nullable
as List<DeviceOrientation>?,appSwitcherLabel: freezed == appSwitcherLabel ? _self.appSwitcherLabel : appSwitcherLabel // ignore: cast_nullable_to_non_nullable
as String?,appSwitcherColor: freezed == appSwitcherColor ? _self.appSwitcherColor : appSwitcherColor // ignore: cast_nullable_to_non_nullable
as Color?,statusBarColor: freezed == statusBarColor ? _self.statusBarColor : statusBarColor // ignore: cast_nullable_to_non_nullable
as Color?,navigationBarColor: freezed == navigationBarColor ? _self.navigationBarColor : navigationBarColor // ignore: cast_nullable_to_non_nullable
as Color?,navigationBarDividerColor: freezed == navigationBarDividerColor ? _self.navigationBarDividerColor : navigationBarDividerColor // ignore: cast_nullable_to_non_nullable
as Color?,
  ));
}

}



/// @nodoc


class _SystemBars implements SystemBars {
  const _SystemBars({required this.overlay, required this.barMode, required  List<DeviceOrientation>? orientations, required this.appSwitcherLabel, required this.appSwitcherColor, required this.statusBarColor, required this.navigationBarColor, required this.navigationBarDividerColor}): _orientations = orientations;
  

/// The status bar fields, and the navigation bar fields when the
/// navigation bar's point was read; every bar color in it is
/// transparent, since the root paints the bar colors itself (themes s03
/// INV-45).
@override final  SystemUiOverlayStyle overlay;
/// Null when no layer sets one this frame; the resolver falls back to
/// `edgeToEdge` only once some layer has set it during its life, and
/// before that leaves the platform's own bar mode untouched (R11).
@override final  SystemBarMode? barMode;
/// Null when no layer sets one this frame; the resolver falls back to
/// no lock only once some layer has set it during its life, and before
/// that leaves the platform's own rotation lock untouched (R11).
 final  List<DeviceOrientation>? _orientations;
/// Null when no layer sets one this frame; the resolver falls back to
/// no lock only once some layer has set it during its life, and before
/// that leaves the platform's own rotation lock untouched (R11).
@override List<DeviceOrientation>? get orientations {
  final value = _orientations;
  if (value == null) return null;
  if (_orientations is EqualUnmodifiableListView) return _orientations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

/// Null when no layer sets one.
@override final  String? appSwitcherLabel;
/// The merged `appSwitcherColor`.
@override final  Color? appSwitcherColor;
/// The merged `statusBarColor`, which the root paints under the status
/// bar.
@override final  Color? statusBarColor;
/// The merged `navigationBarColor`, which the root paints under the
/// navigation bar; null when its point was not read.
@override final  Color? navigationBarColor;
/// The merged `navigationBarDividerColor`, which the root paints as the
/// navigation bar's edge line; null when its point was not read.
@override final  Color? navigationBarDividerColor;

/// Create a copy of SystemBars
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SystemBarsCopyWith<_SystemBars> get copyWith => __$SystemBarsCopyWithImpl<_SystemBars>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SystemBars&&(identical(other.overlay, overlay) || other.overlay == overlay)&&(identical(other.barMode, barMode) || other.barMode == barMode)&&const DeepCollectionEquality().equals(other.orientations, _orientations)&&(identical(other.appSwitcherLabel, appSwitcherLabel) || other.appSwitcherLabel == appSwitcherLabel)&&(identical(other.appSwitcherColor, appSwitcherColor) || other.appSwitcherColor == appSwitcherColor)&&(identical(other.statusBarColor, statusBarColor) || other.statusBarColor == statusBarColor)&&(identical(other.navigationBarColor, navigationBarColor) || other.navigationBarColor == navigationBarColor)&&(identical(other.navigationBarDividerColor, navigationBarDividerColor) || other.navigationBarDividerColor == navigationBarDividerColor));
}


@override
int get hashCode {
    return Object.hash(runtimeType,overlay,barMode,const DeepCollectionEquality().hash(_orientations),appSwitcherLabel,appSwitcherColor,statusBarColor,navigationBarColor,navigationBarDividerColor);
}

@override
String toString() {
    return 'SystemBars(overlay: $overlay, barMode: $barMode, orientations: $orientations, appSwitcherLabel: $appSwitcherLabel, appSwitcherColor: $appSwitcherColor, statusBarColor: $statusBarColor, navigationBarColor: $navigationBarColor, navigationBarDividerColor: $navigationBarDividerColor)';
}


}

/// @nodoc
abstract mixin class _$SystemBarsCopyWith<$Res> implements $SystemBarsCopyWith<$Res> {
  factory _$SystemBarsCopyWith(_SystemBars value, $Res Function(_SystemBars) _then) = __$SystemBarsCopyWithImpl;
@override @useResult
$Res call({
 SystemUiOverlayStyle overlay, SystemBarMode? barMode, List<DeviceOrientation>? orientations, String? appSwitcherLabel, Color? appSwitcherColor, Color? statusBarColor, Color? navigationBarColor, Color? navigationBarDividerColor
});




}
/// @nodoc
class __$SystemBarsCopyWithImpl<$Res>
    implements _$SystemBarsCopyWith<$Res> {
  __$SystemBarsCopyWithImpl(this._self, this._then);

  final _SystemBars _self;
  final $Res Function(_SystemBars) _then;

/// Create a copy of SystemBars
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? overlay = null,Object? barMode = freezed,Object? orientations = freezed,Object? appSwitcherLabel = freezed,Object? appSwitcherColor = freezed,Object? statusBarColor = freezed,Object? navigationBarColor = freezed,Object? navigationBarDividerColor = freezed,}) {
  return _then(_SystemBars(
overlay: null == overlay ? _self.overlay : overlay // ignore: cast_nullable_to_non_nullable
as SystemUiOverlayStyle,barMode: freezed == barMode ? _self.barMode : barMode // ignore: cast_nullable_to_non_nullable
as SystemBarMode?,orientations: freezed == orientations ? _self._orientations : orientations // ignore: cast_nullable_to_non_nullable
as List<DeviceOrientation>?,appSwitcherLabel: freezed == appSwitcherLabel ? _self.appSwitcherLabel : appSwitcherLabel // ignore: cast_nullable_to_non_nullable
as String?,appSwitcherColor: freezed == appSwitcherColor ? _self.appSwitcherColor : appSwitcherColor // ignore: cast_nullable_to_non_nullable
as Color?,statusBarColor: freezed == statusBarColor ? _self.statusBarColor : statusBarColor // ignore: cast_nullable_to_non_nullable
as Color?,navigationBarColor: freezed == navigationBarColor ? _self.navigationBarColor : navigationBarColor // ignore: cast_nullable_to_non_nullable
as Color?,navigationBarDividerColor: freezed == navigationBarDividerColor ? _self.navigationBarDividerColor : navigationBarDividerColor // ignore: cast_nullable_to_non_nullable
as Color?,
  ));
}


}

// dart format on
