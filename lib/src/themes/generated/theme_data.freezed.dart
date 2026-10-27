// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../theme_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StratumThemeData {

/// `ThemeMode.light` for the light and high-contrast light data,
/// `ThemeMode.dark` for the other two.
 ThemeMode get themeMode;/// `color.<set>` without `app`.
 StratumColorTokens get color;/// `palette` without `app`.
 StratumPaletteTokens get palette; Map<String, StratumByWindowSize<StratumDimension>> get space; Map<String, StratumByWindowSize<StratumDimension>> get radius; Map<String, StratumByWindowSize<StratumDimension>> get layouts;/// `color.<set>.app`, by name.
 Map<String, Color> get appColors;/// `palette.app`, by ramp, then shade.
 Map<String, Map<String, Color>> get appPalettes; StratumAssetTokens get assets; Map<String, Object?> get extensions; StratumTypography get typography;/// The yaml values; `StratumTheme.animation` returns them unchanged,
/// reduced motion included (spec C1).
 StratumAnimation get animation;/// `opacity`: `disabled`, the opacity of a disabled component, which the
/// component base's disabled wrapper paints (FO-08 US-07).
 StratumOpacityTokens get opacity;/// `border`: `sm`, `md`, `lg`, each a width in logical pixels from the
/// theme file; a widget that needs the usual width reads `md`.
 StratumBorderTokens get border;/// `shadow`: `level1` to `level6`, each a list of `BoxShadow` in Figma
/// order, colored from this data's own color set.
 StratumShadowTokens get shadow;/// `blur`: `level1` to `level6`, each a background blur at sigma half
/// the Figma radius.
 StratumBlurTokens get blur;/// `system`: the look of the system bars from the theme file's `system`
/// set for this data's mode, a high-contrast set laid over its base; the
/// one system bar style the theme exposes and the lowest layer of the
/// system style merge (FO-03 US-10 FR-01 E05, US-14 FR-01). Its bar mode,
/// rotation lock, and app switcher label stay null: an app sets those in
/// code.
 SystemStyle get systemStyle;/// `focus`: the focus ring's level 0 from the theme file's `focus` set
/// for this data's mode, a high-contrast set laid over its base, each
/// color from this data's own color set (FO-06 US-04 FR-03; themes s03
/// INV-46).
 StratumFocusTokens get focus;/// The 64 built-in transparent steps.
 StratumTransparentTokens get transparent; WidgetSize get defaultWidgetSize; InteractiveInkFeatureFactory get splashFactory; ScrollBehavior get scrollBehavior; ScrollPhysics get physics;
/// Create a copy of StratumThemeData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumThemeDataCopyWith<StratumThemeData> get copyWith => _$StratumThemeDataCopyWithImpl<StratumThemeData>(this as StratumThemeData, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumThemeData;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumThemeData&&(identical(other.themeMode, _this.themeMode) || other.themeMode == _this.themeMode)&&(identical(other.color, _this.color) || other.color == _this.color)&&(identical(other.palette, _this.palette) || other.palette == _this.palette)&&const DeepCollectionEquality().equals(other.space, _this.space)&&const DeepCollectionEquality().equals(other.radius, _this.radius)&&const DeepCollectionEquality().equals(other.layouts, _this.layouts)&&const DeepCollectionEquality().equals(other.appColors, _this.appColors)&&const DeepCollectionEquality().equals(other.appPalettes, _this.appPalettes)&&(identical(other.assets, _this.assets) || other.assets == _this.assets)&&const DeepCollectionEquality().equals(other.extensions, _this.extensions)&&(identical(other.typography, _this.typography) || other.typography == _this.typography)&&(identical(other.animation, _this.animation) || other.animation == _this.animation)&&(identical(other.opacity, _this.opacity) || other.opacity == _this.opacity)&&(identical(other.border, _this.border) || other.border == _this.border)&&(identical(other.shadow, _this.shadow) || other.shadow == _this.shadow)&&(identical(other.blur, _this.blur) || other.blur == _this.blur)&&(identical(other.systemStyle, _this.systemStyle) || other.systemStyle == _this.systemStyle)&&(identical(other.focus, _this.focus) || other.focus == _this.focus)&&(identical(other.transparent, _this.transparent) || other.transparent == _this.transparent)&&(identical(other.defaultWidgetSize, _this.defaultWidgetSize) || other.defaultWidgetSize == _this.defaultWidgetSize)&&(identical(other.splashFactory, _this.splashFactory) || other.splashFactory == _this.splashFactory)&&(identical(other.scrollBehavior, _this.scrollBehavior) || other.scrollBehavior == _this.scrollBehavior)&&(identical(other.physics, _this.physics) || other.physics == _this.physics));
}


@override
int get hashCode {
  final _this = this as StratumThemeData;
  return Object.hashAll([runtimeType,_this.themeMode,_this.color,_this.palette,const DeepCollectionEquality().hash(_this.space),const DeepCollectionEquality().hash(_this.radius),const DeepCollectionEquality().hash(_this.layouts),const DeepCollectionEquality().hash(_this.appColors),const DeepCollectionEquality().hash(_this.appPalettes),_this.assets,const DeepCollectionEquality().hash(_this.extensions),_this.typography,_this.animation,_this.opacity,_this.border,_this.shadow,_this.blur,_this.systemStyle,_this.focus,_this.transparent,_this.defaultWidgetSize,_this.splashFactory,_this.scrollBehavior,_this.physics]);
}

@override
String toString() {
  final _this = this as StratumThemeData;
  return 'StratumThemeData(themeMode: ${_this.themeMode}, color: ${_this.color}, palette: ${_this.palette}, space: ${_this.space}, radius: ${_this.radius}, layouts: ${_this.layouts}, appColors: ${_this.appColors}, appPalettes: ${_this.appPalettes}, assets: ${_this.assets}, extensions: ${_this.extensions}, typography: ${_this.typography}, animation: ${_this.animation}, opacity: ${_this.opacity}, border: ${_this.border}, shadow: ${_this.shadow}, blur: ${_this.blur}, systemStyle: ${_this.systemStyle}, focus: ${_this.focus}, transparent: ${_this.transparent}, defaultWidgetSize: ${_this.defaultWidgetSize}, splashFactory: ${_this.splashFactory}, scrollBehavior: ${_this.scrollBehavior}, physics: ${_this.physics})';
}


}

/// @nodoc
abstract mixin class $StratumThemeDataCopyWith<$Res>  {
  factory $StratumThemeDataCopyWith(StratumThemeData value, $Res Function(StratumThemeData) _then) = _$StratumThemeDataCopyWithImpl;
@useResult
$Res call({
 ThemeMode themeMode, StratumColorTokens color, StratumPaletteTokens palette, Map<String, StratumByWindowSize<StratumDimension>> space, Map<String, StratumByWindowSize<StratumDimension>> radius, Map<String, StratumByWindowSize<StratumDimension>> layouts, Map<String, Color> appColors, Map<String, Map<String, Color>> appPalettes, StratumAssetTokens assets, Map<String, Object?> extensions, StratumTypography typography, StratumAnimation animation, StratumOpacityTokens opacity, StratumBorderTokens border, StratumShadowTokens shadow, StratumBlurTokens blur, SystemStyle systemStyle, StratumFocusTokens focus, StratumTransparentTokens transparent, WidgetSize defaultWidgetSize, InteractiveInkFeatureFactory splashFactory, ScrollBehavior scrollBehavior, ScrollPhysics physics
});


$StratumTypographyCopyWith<$Res> get typography;$StratumAnimationCopyWith<$Res> get animation;$SystemStyleCopyWith<$Res> get systemStyle;$StratumFocusTokensCopyWith<$Res> get focus;

}
/// @nodoc
class _$StratumThemeDataCopyWithImpl<$Res>
    implements $StratumThemeDataCopyWith<$Res> {
  _$StratumThemeDataCopyWithImpl(this._self, this._then);

  final StratumThemeData _self;
  final $Res Function(StratumThemeData) _then;

/// Create a copy of StratumThemeData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? themeMode = null,Object? color = null,Object? palette = null,Object? space = null,Object? radius = null,Object? layouts = null,Object? appColors = null,Object? appPalettes = null,Object? assets = null,Object? extensions = null,Object? typography = null,Object? animation = null,Object? opacity = null,Object? border = null,Object? shadow = null,Object? blur = null,Object? systemStyle = null,Object? focus = null,Object? transparent = null,Object? defaultWidgetSize = null,Object? splashFactory = null,Object? scrollBehavior = null,Object? physics = null,}) {
  return _then(StratumThemeData(
themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as ThemeMode,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as StratumColorTokens,palette: null == palette ? _self.palette : palette // ignore: cast_nullable_to_non_nullable
as StratumPaletteTokens,space: null == space ? _self.space : space // ignore: cast_nullable_to_non_nullable
as Map<String, StratumByWindowSize<StratumDimension>>,radius: null == radius ? _self.radius : radius // ignore: cast_nullable_to_non_nullable
as Map<String, StratumByWindowSize<StratumDimension>>,layouts: null == layouts ? _self.layouts : layouts // ignore: cast_nullable_to_non_nullable
as Map<String, StratumByWindowSize<StratumDimension>>,appColors: null == appColors ? _self.appColors : appColors // ignore: cast_nullable_to_non_nullable
as Map<String, Color>,appPalettes: null == appPalettes ? _self.appPalettes : appPalettes // ignore: cast_nullable_to_non_nullable
as Map<String, Map<String, Color>>,assets: null == assets ? _self.assets : assets // ignore: cast_nullable_to_non_nullable
as StratumAssetTokens,extensions: null == extensions ? _self.extensions : extensions // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,typography: null == typography ? _self.typography : typography // ignore: cast_nullable_to_non_nullable
as StratumTypography,animation: null == animation ? _self.animation : animation // ignore: cast_nullable_to_non_nullable
as StratumAnimation,opacity: null == opacity ? _self.opacity : opacity // ignore: cast_nullable_to_non_nullable
as StratumOpacityTokens,border: null == border ? _self.border : border // ignore: cast_nullable_to_non_nullable
as StratumBorderTokens,shadow: null == shadow ? _self.shadow : shadow // ignore: cast_nullable_to_non_nullable
as StratumShadowTokens,blur: null == blur ? _self.blur : blur // ignore: cast_nullable_to_non_nullable
as StratumBlurTokens,systemStyle: null == systemStyle ? _self.systemStyle : systemStyle // ignore: cast_nullable_to_non_nullable
as SystemStyle,focus: null == focus ? _self.focus : focus // ignore: cast_nullable_to_non_nullable
as StratumFocusTokens,transparent: null == transparent ? _self.transparent : transparent // ignore: cast_nullable_to_non_nullable
as StratumTransparentTokens,defaultWidgetSize: null == defaultWidgetSize ? _self.defaultWidgetSize : defaultWidgetSize // ignore: cast_nullable_to_non_nullable
as WidgetSize,splashFactory: null == splashFactory ? _self.splashFactory : splashFactory // ignore: cast_nullable_to_non_nullable
as InteractiveInkFeatureFactory,scrollBehavior: null == scrollBehavior ? _self.scrollBehavior : scrollBehavior // ignore: cast_nullable_to_non_nullable
as ScrollBehavior,physics: null == physics ? _self.physics : physics // ignore: cast_nullable_to_non_nullable
as ScrollPhysics,
  ));
}
/// Create a copy of StratumThemeData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumTypographyCopyWith<$Res> get typography {
  
  return $StratumTypographyCopyWith<$Res>(_self.typography, (value) {
    return _then(_self.copyWith(typography: value));
  });
}/// Create a copy of StratumThemeData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumAnimationCopyWith<$Res> get animation {
  
  return $StratumAnimationCopyWith<$Res>(_self.animation, (value) {
    return _then(_self.copyWith(animation: value));
  });
}/// Create a copy of StratumThemeData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SystemStyleCopyWith<$Res> get systemStyle {
  
  return $SystemStyleCopyWith<$Res>(_self.systemStyle, (value) {
    return _then(_self.copyWith(systemStyle: value));
  });
}/// Create a copy of StratumThemeData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumFocusTokensCopyWith<$Res> get focus {
  
  return $StratumFocusTokensCopyWith<$Res>(_self.focus, (value) {
    return _then(_self.copyWith(focus: value));
  });
}
}



/// @nodoc


class _StratumThemeData extends StratumThemeData {
  const _StratumThemeData({required this.themeMode, required this.color, required this.palette, required  Map<String, StratumByWindowSize<StratumDimension>> space, required  Map<String, StratumByWindowSize<StratumDimension>> radius, required  Map<String, StratumByWindowSize<StratumDimension>> layouts, required  Map<String, Color> appColors, required  Map<String, Map<String, Color>> appPalettes, required this.assets, required  Map<String, Object?> extensions, required this.typography, required this.animation, required this.opacity, required this.border, required this.shadow, required this.blur, required this.systemStyle, required this.focus, this.transparent = StratumTransparentTokens.builtIn, this.defaultWidgetSize = WidgetSize.medium, this.splashFactory = NoSplash.splashFactory, this.scrollBehavior = const StratumScrollBehavior(), this.physics = const ClampingScrollPhysics()}): _space = space,_radius = radius,_layouts = layouts,_appColors = appColors,_appPalettes = appPalettes,_extensions = extensions,super._();
  

/// `ThemeMode.light` for the light and high-contrast light data,
/// `ThemeMode.dark` for the other two.
@override final  ThemeMode themeMode;
/// `color.<set>` without `app`.
@override final  StratumColorTokens color;
/// `palette` without `app`.
@override final  StratumPaletteTokens palette;
 final  Map<String, StratumByWindowSize<StratumDimension>> _space;
@override Map<String, StratumByWindowSize<StratumDimension>> get space {
  if (_space is EqualUnmodifiableMapView) return _space;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_space);
}

 final  Map<String, StratumByWindowSize<StratumDimension>> _radius;
@override Map<String, StratumByWindowSize<StratumDimension>> get radius {
  if (_radius is EqualUnmodifiableMapView) return _radius;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_radius);
}

 final  Map<String, StratumByWindowSize<StratumDimension>> _layouts;
@override Map<String, StratumByWindowSize<StratumDimension>> get layouts {
  if (_layouts is EqualUnmodifiableMapView) return _layouts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_layouts);
}

/// `color.<set>.app`, by name.
 final  Map<String, Color> _appColors;
/// `color.<set>.app`, by name.
@override Map<String, Color> get appColors {
  if (_appColors is EqualUnmodifiableMapView) return _appColors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_appColors);
}

/// `palette.app`, by ramp, then shade.
 final  Map<String, Map<String, Color>> _appPalettes;
/// `palette.app`, by ramp, then shade.
@override Map<String, Map<String, Color>> get appPalettes {
  if (_appPalettes is EqualUnmodifiableMapView) return _appPalettes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_appPalettes);
}

@override final  StratumAssetTokens assets;
 final  Map<String, Object?> _extensions;
@override Map<String, Object?> get extensions {
  if (_extensions is EqualUnmodifiableMapView) return _extensions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_extensions);
}

@override final  StratumTypography typography;
/// The yaml values; `StratumTheme.animation` returns them unchanged,
/// reduced motion included (spec C1).
@override final  StratumAnimation animation;
/// `opacity`: `disabled`, the opacity of a disabled component, which the
/// component base's disabled wrapper paints (FO-08 US-07).
@override final  StratumOpacityTokens opacity;
/// `border`: `sm`, `md`, `lg`, each a width in logical pixels from the
/// theme file; a widget that needs the usual width reads `md`.
@override final  StratumBorderTokens border;
/// `shadow`: `level1` to `level6`, each a list of `BoxShadow` in Figma
/// order, colored from this data's own color set.
@override final  StratumShadowTokens shadow;
/// `blur`: `level1` to `level6`, each a background blur at sigma half
/// the Figma radius.
@override final  StratumBlurTokens blur;
/// `system`: the look of the system bars from the theme file's `system`
/// set for this data's mode, a high-contrast set laid over its base; the
/// one system bar style the theme exposes and the lowest layer of the
/// system style merge (FO-03 US-10 FR-01 E05, US-14 FR-01). Its bar mode,
/// rotation lock, and app switcher label stay null: an app sets those in
/// code.
@override final  SystemStyle systemStyle;
/// `focus`: the focus ring's level 0 from the theme file's `focus` set
/// for this data's mode, a high-contrast set laid over its base, each
/// color from this data's own color set (FO-06 US-04 FR-03; themes s03
/// INV-46).
@override final  StratumFocusTokens focus;
/// The 64 built-in transparent steps.
@override@JsonKey() final  StratumTransparentTokens transparent;
@override@JsonKey() final  WidgetSize defaultWidgetSize;
@override@JsonKey() final  InteractiveInkFeatureFactory splashFactory;
@override@JsonKey() final  ScrollBehavior scrollBehavior;
@override@JsonKey() final  ScrollPhysics physics;

/// Create a copy of StratumThemeData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StratumThemeDataCopyWith<_StratumThemeData> get copyWith => __$StratumThemeDataCopyWithImpl<_StratumThemeData>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StratumThemeData&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.color, color) || other.color == color)&&(identical(other.palette, palette) || other.palette == palette)&&const DeepCollectionEquality().equals(other.space, _space)&&const DeepCollectionEquality().equals(other.radius, _radius)&&const DeepCollectionEquality().equals(other.layouts, _layouts)&&const DeepCollectionEquality().equals(other.appColors, _appColors)&&const DeepCollectionEquality().equals(other.appPalettes, _appPalettes)&&(identical(other.assets, assets) || other.assets == assets)&&const DeepCollectionEquality().equals(other.extensions, _extensions)&&(identical(other.typography, typography) || other.typography == typography)&&(identical(other.animation, animation) || other.animation == animation)&&(identical(other.opacity, opacity) || other.opacity == opacity)&&(identical(other.border, border) || other.border == border)&&(identical(other.shadow, shadow) || other.shadow == shadow)&&(identical(other.blur, blur) || other.blur == blur)&&(identical(other.systemStyle, systemStyle) || other.systemStyle == systemStyle)&&(identical(other.focus, focus) || other.focus == focus)&&(identical(other.transparent, transparent) || other.transparent == transparent)&&(identical(other.defaultWidgetSize, defaultWidgetSize) || other.defaultWidgetSize == defaultWidgetSize)&&(identical(other.splashFactory, splashFactory) || other.splashFactory == splashFactory)&&(identical(other.scrollBehavior, scrollBehavior) || other.scrollBehavior == scrollBehavior)&&(identical(other.physics, physics) || other.physics == physics));
}


@override
int get hashCode {
    return Object.hashAll([runtimeType,themeMode,color,palette,const DeepCollectionEquality().hash(_space),const DeepCollectionEquality().hash(_radius),const DeepCollectionEquality().hash(_layouts),const DeepCollectionEquality().hash(_appColors),const DeepCollectionEquality().hash(_appPalettes),assets,const DeepCollectionEquality().hash(_extensions),typography,animation,opacity,border,shadow,blur,systemStyle,focus,transparent,defaultWidgetSize,splashFactory,scrollBehavior,physics]);
}

@override
String toString() {
    return 'StratumThemeData(themeMode: $themeMode, color: $color, palette: $palette, space: $space, radius: $radius, layouts: $layouts, appColors: $appColors, appPalettes: $appPalettes, assets: $assets, extensions: $extensions, typography: $typography, animation: $animation, opacity: $opacity, border: $border, shadow: $shadow, blur: $blur, systemStyle: $systemStyle, focus: $focus, transparent: $transparent, defaultWidgetSize: $defaultWidgetSize, splashFactory: $splashFactory, scrollBehavior: $scrollBehavior, physics: $physics)';
}


}

/// @nodoc
abstract mixin class _$StratumThemeDataCopyWith<$Res> implements $StratumThemeDataCopyWith<$Res> {
  factory _$StratumThemeDataCopyWith(_StratumThemeData value, $Res Function(_StratumThemeData) _then) = __$StratumThemeDataCopyWithImpl;
@override @useResult
$Res call({
 ThemeMode themeMode, StratumColorTokens color, StratumPaletteTokens palette, Map<String, StratumByWindowSize<StratumDimension>> space, Map<String, StratumByWindowSize<StratumDimension>> radius, Map<String, StratumByWindowSize<StratumDimension>> layouts, Map<String, Color> appColors, Map<String, Map<String, Color>> appPalettes, StratumAssetTokens assets, Map<String, Object?> extensions, StratumTypography typography, StratumAnimation animation, StratumOpacityTokens opacity, StratumBorderTokens border, StratumShadowTokens shadow, StratumBlurTokens blur, SystemStyle systemStyle, StratumFocusTokens focus, StratumTransparentTokens transparent, WidgetSize defaultWidgetSize, InteractiveInkFeatureFactory splashFactory, ScrollBehavior scrollBehavior, ScrollPhysics physics
});


@override $StratumTypographyCopyWith<$Res> get typography;@override $StratumAnimationCopyWith<$Res> get animation;@override $SystemStyleCopyWith<$Res> get systemStyle;@override $StratumFocusTokensCopyWith<$Res> get focus;

}
/// @nodoc
class __$StratumThemeDataCopyWithImpl<$Res>
    implements _$StratumThemeDataCopyWith<$Res> {
  __$StratumThemeDataCopyWithImpl(this._self, this._then);

  final _StratumThemeData _self;
  final $Res Function(_StratumThemeData) _then;

/// Create a copy of StratumThemeData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? themeMode = null,Object? color = null,Object? palette = null,Object? space = null,Object? radius = null,Object? layouts = null,Object? appColors = null,Object? appPalettes = null,Object? assets = null,Object? extensions = null,Object? typography = null,Object? animation = null,Object? opacity = null,Object? border = null,Object? shadow = null,Object? blur = null,Object? systemStyle = null,Object? focus = null,Object? transparent = null,Object? defaultWidgetSize = null,Object? splashFactory = null,Object? scrollBehavior = null,Object? physics = null,}) {
  return _then(_StratumThemeData(
themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as ThemeMode,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as StratumColorTokens,palette: null == palette ? _self.palette : palette // ignore: cast_nullable_to_non_nullable
as StratumPaletteTokens,space: null == space ? _self._space : space // ignore: cast_nullable_to_non_nullable
as Map<String, StratumByWindowSize<StratumDimension>>,radius: null == radius ? _self._radius : radius // ignore: cast_nullable_to_non_nullable
as Map<String, StratumByWindowSize<StratumDimension>>,layouts: null == layouts ? _self._layouts : layouts // ignore: cast_nullable_to_non_nullable
as Map<String, StratumByWindowSize<StratumDimension>>,appColors: null == appColors ? _self._appColors : appColors // ignore: cast_nullable_to_non_nullable
as Map<String, Color>,appPalettes: null == appPalettes ? _self._appPalettes : appPalettes // ignore: cast_nullable_to_non_nullable
as Map<String, Map<String, Color>>,assets: null == assets ? _self.assets : assets // ignore: cast_nullable_to_non_nullable
as StratumAssetTokens,extensions: null == extensions ? _self._extensions : extensions // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,typography: null == typography ? _self.typography : typography // ignore: cast_nullable_to_non_nullable
as StratumTypography,animation: null == animation ? _self.animation : animation // ignore: cast_nullable_to_non_nullable
as StratumAnimation,opacity: null == opacity ? _self.opacity : opacity // ignore: cast_nullable_to_non_nullable
as StratumOpacityTokens,border: null == border ? _self.border : border // ignore: cast_nullable_to_non_nullable
as StratumBorderTokens,shadow: null == shadow ? _self.shadow : shadow // ignore: cast_nullable_to_non_nullable
as StratumShadowTokens,blur: null == blur ? _self.blur : blur // ignore: cast_nullable_to_non_nullable
as StratumBlurTokens,systemStyle: null == systemStyle ? _self.systemStyle : systemStyle // ignore: cast_nullable_to_non_nullable
as SystemStyle,focus: null == focus ? _self.focus : focus // ignore: cast_nullable_to_non_nullable
as StratumFocusTokens,transparent: null == transparent ? _self.transparent : transparent // ignore: cast_nullable_to_non_nullable
as StratumTransparentTokens,defaultWidgetSize: null == defaultWidgetSize ? _self.defaultWidgetSize : defaultWidgetSize // ignore: cast_nullable_to_non_nullable
as WidgetSize,splashFactory: null == splashFactory ? _self.splashFactory : splashFactory // ignore: cast_nullable_to_non_nullable
as InteractiveInkFeatureFactory,scrollBehavior: null == scrollBehavior ? _self.scrollBehavior : scrollBehavior // ignore: cast_nullable_to_non_nullable
as ScrollBehavior,physics: null == physics ? _self.physics : physics // ignore: cast_nullable_to_non_nullable
as ScrollPhysics,
  ));
}

/// Create a copy of StratumThemeData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumTypographyCopyWith<$Res> get typography {
  
  return $StratumTypographyCopyWith<$Res>(_self.typography, (value) {
    return _then(_self.copyWith(typography: value));
  });
}/// Create a copy of StratumThemeData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumAnimationCopyWith<$Res> get animation {
  
  return $StratumAnimationCopyWith<$Res>(_self.animation, (value) {
    return _then(_self.copyWith(animation: value));
  });
}/// Create a copy of StratumThemeData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SystemStyleCopyWith<$Res> get systemStyle {
  
  return $SystemStyleCopyWith<$Res>(_self.systemStyle, (value) {
    return _then(_self.copyWith(systemStyle: value));
  });
}/// Create a copy of StratumThemeData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumFocusTokensCopyWith<$Res> get focus {
  
  return $StratumFocusTokensCopyWith<$Res>(_self.focus, (value) {
    return _then(_self.copyWith(focus: value));
  });
}
}

/// @nodoc
mixin _$StratumAppPalette {

 String get name;/// Shade name to color, as `palette.app.<name>` writes them.
 Map<String, Color> get shades;
/// Create a copy of StratumAppPalette
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumAppPaletteCopyWith<StratumAppPalette> get copyWith => _$StratumAppPaletteCopyWithImpl<StratumAppPalette>(this as StratumAppPalette, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumAppPalette;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumAppPalette&&(identical(other.name, _this.name) || other.name == _this.name)&&const DeepCollectionEquality().equals(other.shades, _this.shades));
}


@override
int get hashCode {
  final _this = this as StratumAppPalette;
  return Object.hash(runtimeType,_this.name,const DeepCollectionEquality().hash(_this.shades));
}

@override
String toString() {
  final _this = this as StratumAppPalette;
  return 'StratumAppPalette(name: ${_this.name}, shades: ${_this.shades})';
}


}

/// @nodoc
abstract mixin class $StratumAppPaletteCopyWith<$Res>  {
  factory $StratumAppPaletteCopyWith(StratumAppPalette value, $Res Function(StratumAppPalette) _then) = _$StratumAppPaletteCopyWithImpl;
@useResult
$Res call({
 String name, Map<String, Color> shades
});




}
/// @nodoc
class _$StratumAppPaletteCopyWithImpl<$Res>
    implements $StratumAppPaletteCopyWith<$Res> {
  _$StratumAppPaletteCopyWithImpl(this._self, this._then);

  final StratumAppPalette _self;
  final $Res Function(StratumAppPalette) _then;

/// Create a copy of StratumAppPalette
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? shades = null,}) {
  return _then(StratumAppPalette(
null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,null == shades ? _self.shades : shades // ignore: cast_nullable_to_non_nullable
as Map<String, Color>,
  ));
}

}



/// @nodoc


class _StratumAppPalette extends StratumAppPalette {
  const _StratumAppPalette(this.name,  Map<String, Color> shades): _shades = shades,super._();
  

@override final  String name;
/// Shade name to color, as `palette.app.<name>` writes them.
 final  Map<String, Color> _shades;
/// Shade name to color, as `palette.app.<name>` writes them.
@override Map<String, Color> get shades {
  if (_shades is EqualUnmodifiableMapView) return _shades;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_shades);
}


/// Create a copy of StratumAppPalette
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StratumAppPaletteCopyWith<_StratumAppPalette> get copyWith => __$StratumAppPaletteCopyWithImpl<_StratumAppPalette>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StratumAppPalette&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.shades, _shades));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,const DeepCollectionEquality().hash(_shades));
}

@override
String toString() {
    return 'StratumAppPalette(name: $name, shades: $shades)';
}


}

/// @nodoc
abstract mixin class _$StratumAppPaletteCopyWith<$Res> implements $StratumAppPaletteCopyWith<$Res> {
  factory _$StratumAppPaletteCopyWith(_StratumAppPalette value, $Res Function(_StratumAppPalette) _then) = __$StratumAppPaletteCopyWithImpl;
@override @useResult
$Res call({
 String name, Map<String, Color> shades
});




}
/// @nodoc
class __$StratumAppPaletteCopyWithImpl<$Res>
    implements _$StratumAppPaletteCopyWith<$Res> {
  __$StratumAppPaletteCopyWithImpl(this._self, this._then);

  final _StratumAppPalette _self;
  final $Res Function(_StratumAppPalette) _then;

/// Create a copy of StratumAppPalette
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? shades = null,}) {
  return _then(_StratumAppPalette(
null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,null == shades ? _self._shades : shades // ignore: cast_nullable_to_non_nullable
as Map<String, Color>,
  ));
}


}

// dart format on
