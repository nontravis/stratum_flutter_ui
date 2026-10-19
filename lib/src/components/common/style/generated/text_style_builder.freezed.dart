// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../text_style_builder.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StratumTextStyle {


/// Create a copy of StratumTextStyle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumTextStyleCopyWith<StratumTextStyle> get copyWith => _$StratumTextStyleCopyWithImpl<StratumTextStyle>(this as StratumTextStyle, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumTextStyle;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumTextStyle&&(identical(other.fontType, _this.fontType) || other.fontType == _this.fontType)&&(identical(other.fontSize, _this.fontSize) || other.fontSize == _this.fontSize)&&(identical(other.customSize, _this.customSize) || other.customSize == _this.customSize)&&(identical(other.fontWeight, _this.fontWeight) || other.fontWeight == _this.fontWeight)&&(identical(other.isMono, _this.isMono) || other.isMono == _this.isMono)&&(identical(other.fontStyle, _this.fontStyle) || other.fontStyle == _this.fontStyle)&&(identical(other.textDecoration, _this.textDecoration) || other.textDecoration == _this.textDecoration)&&const DeepCollectionEquality().equals(other.textShadows, _this.textShadows)&&(identical(other.colorRole, _this.colorRole) || other.colorRole == _this.colorRole)&&(identical(other.customColor, _this.customColor) || other.customColor == _this.customColor)&&(identical(other.themeModeOverride, _this.themeModeOverride) || other.themeModeOverride == _this.themeModeOverride)&&(identical(other.localeOverride, _this.localeOverride) || other.localeOverride == _this.localeOverride)&&(identical(other.windowSizeOverride, _this.windowSizeOverride) || other.windowSizeOverride == _this.windowSizeOverride)&&(identical(other.textScalerOverride, _this.textScalerOverride) || other.textScalerOverride == _this.textScalerOverride));
}


@override
int get hashCode {
  final _this = this as StratumTextStyle;
  return Object.hash(runtimeType,_this.fontType,_this.fontSize,_this.customSize,_this.fontWeight,_this.isMono,_this.fontStyle,_this.textDecoration,const DeepCollectionEquality().hash(_this.textShadows),_this.colorRole,_this.customColor,_this.themeModeOverride,_this.localeOverride,_this.windowSizeOverride,_this.textScalerOverride);
}

@override
String toString() {
  final _this = this as StratumTextStyle;
  return 'StratumTextStyle(fontType: ${_this.fontType}, fontSize: ${_this.fontSize}, customSize: ${_this.customSize}, fontWeight: ${_this.fontWeight}, isMono: ${_this.isMono}, fontStyle: ${_this.fontStyle}, textDecoration: ${_this.textDecoration}, textShadows: ${_this.textShadows}, colorRole: ${_this.colorRole}, customColor: ${_this.customColor}, themeModeOverride: ${_this.themeModeOverride}, localeOverride: ${_this.localeOverride}, windowSizeOverride: ${_this.windowSizeOverride}, textScalerOverride: ${_this.textScalerOverride})';
}


}

/// @nodoc
abstract mixin class $StratumTextStyleCopyWith<$Res>  {
  factory $StratumTextStyleCopyWith(StratumTextStyle value, $Res Function(StratumTextStyle) _then) = _$StratumTextStyleCopyWithImpl;
@useResult
$Res call({
 FontType fontType, FontSize fontSize, double? customSize, FontWeight? fontWeight, bool isMono, FontStyle? fontStyle, TextDecoration? textDecoration, List<Shadow>? textShadows, FontColor colorRole, Color? customColor, ThemeMode? themeModeOverride, Locale? localeOverride, WindowSize? windowSizeOverride, TextScaler? textScalerOverride
});




}
/// @nodoc
class _$StratumTextStyleCopyWithImpl<$Res>
    implements $StratumTextStyleCopyWith<$Res> {
  _$StratumTextStyleCopyWithImpl(this._self, this._then);

  final StratumTextStyle _self;
  final $Res Function(StratumTextStyle) _then;

/// Create a copy of StratumTextStyle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fontType = null,Object? fontSize = null,Object? customSize = freezed,Object? fontWeight = freezed,Object? isMono = null,Object? fontStyle = freezed,Object? textDecoration = freezed,Object? textShadows = freezed,Object? colorRole = null,Object? customColor = freezed,Object? themeModeOverride = freezed,Object? localeOverride = freezed,Object? windowSizeOverride = freezed,Object? textScalerOverride = freezed,}) {
  return _then(StratumTextStyle._(
fontType: null == fontType ? _self.fontType : fontType // ignore: cast_nullable_to_non_nullable
as FontType,fontSize: null == fontSize ? _self.fontSize : fontSize // ignore: cast_nullable_to_non_nullable
as FontSize,customSize: freezed == customSize ? _self.customSize : customSize // ignore: cast_nullable_to_non_nullable
as double?,fontWeight: freezed == fontWeight ? _self.fontWeight : fontWeight // ignore: cast_nullable_to_non_nullable
as FontWeight?,isMono: null == isMono ? _self.isMono : isMono // ignore: cast_nullable_to_non_nullable
as bool,fontStyle: freezed == fontStyle ? _self.fontStyle : fontStyle // ignore: cast_nullable_to_non_nullable
as FontStyle?,textDecoration: freezed == textDecoration ? _self.textDecoration : textDecoration // ignore: cast_nullable_to_non_nullable
as TextDecoration?,textShadows: freezed == textShadows ? _self.textShadows : textShadows // ignore: cast_nullable_to_non_nullable
as List<Shadow>?,colorRole: null == colorRole ? _self.colorRole : colorRole // ignore: cast_nullable_to_non_nullable
as FontColor,customColor: freezed == customColor ? _self.customColor : customColor // ignore: cast_nullable_to_non_nullable
as Color?,themeModeOverride: freezed == themeModeOverride ? _self.themeModeOverride : themeModeOverride // ignore: cast_nullable_to_non_nullable
as ThemeMode?,localeOverride: freezed == localeOverride ? _self.localeOverride : localeOverride // ignore: cast_nullable_to_non_nullable
as Locale?,windowSizeOverride: freezed == windowSizeOverride ? _self.windowSizeOverride : windowSizeOverride // ignore: cast_nullable_to_non_nullable
as WindowSize?,textScalerOverride: freezed == textScalerOverride ? _self.textScalerOverride : textScalerOverride // ignore: cast_nullable_to_non_nullable
as TextScaler?,
  ));
}

}



// dart format on
