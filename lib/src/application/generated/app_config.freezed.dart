// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../app_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StratumAppConfig {


/// Create a copy of StratumAppConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumAppConfigCopyWith<StratumAppConfig> get copyWith => _$StratumAppConfigCopyWithImpl<StratumAppConfig>(this as StratumAppConfig, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumAppConfig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumAppConfig&&(identical(other.theme, _this.theme) || other.theme == _this.theme)&&(identical(other.darkTheme, _this.darkTheme) || other.darkTheme == _this.darkTheme)&&(identical(other.themeMode, _this.themeMode) || other.themeMode == _this.themeMode)&&(identical(other.builder, _this.builder) || other.builder == _this.builder));
}


@override
int get hashCode {
  final _this = this as StratumAppConfig;
  return Object.hash(runtimeType,_this.theme,_this.darkTheme,_this.themeMode,_this.builder);
}

@override
String toString() {
  final _this = this as StratumAppConfig;
  return 'StratumAppConfig(theme: ${_this.theme}, darkTheme: ${_this.darkTheme}, themeMode: ${_this.themeMode}, builder: ${_this.builder})';
}


}

/// @nodoc
abstract mixin class $StratumAppConfigCopyWith<$Res>  {
  factory $StratumAppConfigCopyWith(StratumAppConfig value, $Res Function(StratumAppConfig) _then) = _$StratumAppConfigCopyWithImpl;
@useResult
$Res call({
 ThemeData theme, ThemeData? darkTheme, ThemeMode themeMode, TransitionBuilder builder
});




}
/// @nodoc
class _$StratumAppConfigCopyWithImpl<$Res>
    implements $StratumAppConfigCopyWith<$Res> {
  _$StratumAppConfigCopyWithImpl(this._self, this._then);

  final StratumAppConfig _self;
  final $Res Function(StratumAppConfig) _then;

/// Create a copy of StratumAppConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? theme = null,Object? darkTheme = freezed,Object? themeMode = null,Object? builder = null,}) {
  return _then(StratumAppConfig(
theme: null == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as ThemeData,darkTheme: freezed == darkTheme ? _self.darkTheme : darkTheme // ignore: cast_nullable_to_non_nullable
as ThemeData?,themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as ThemeMode,builder: null == builder ? _self.builder : builder // ignore: cast_nullable_to_non_nullable
as TransitionBuilder,
  ));
}

}



// dart format on
