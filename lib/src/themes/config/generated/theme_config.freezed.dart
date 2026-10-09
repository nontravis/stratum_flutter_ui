// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../theme_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StratumThemeConfig {

 String get name;/// Each slot that names an asset (`splash-screen`, `loading`); an empty
/// slot has no entry.
 Map<String, StratumThemeAsset> get assets; Map<String, StratumByWindowSize<StratumDimension>> get space; Map<String, StratumByWindowSize<StratumDimension>> get radius; Map<String, StratumByWindowSize<StratumDimension>> get layouts;/// Every shade by its path under `palette`: `brand.500`,
/// `app.<ramp>.<shade>`. 88 entries for the package default.
 Map<String, Color> get palette; StratumColorSets get color; StratumTypography get typography;/// The merged `animation` group (spec section 8.1).
 StratumAnimationConfig get animation;/// The merged `opacity` group: `disabled`, the opacity of a disabled
/// component (FO-08 US-07), from 0 to 1; 0.5 in the package default.
 Map<String, double> get opacity;/// The merged `extensions` group as plain Dart values: maps with string
/// keys, lists, strings, numbers, booleans, and null. Never
/// alias-resolved and never checked.
 Map<String, Object?> get extensions;
/// Create a copy of StratumThemeConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumThemeConfigCopyWith<StratumThemeConfig> get copyWith => _$StratumThemeConfigCopyWithImpl<StratumThemeConfig>(this as StratumThemeConfig, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumThemeConfig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumThemeConfig&&(identical(other.name, _this.name) || other.name == _this.name)&&const DeepCollectionEquality().equals(other.assets, _this.assets)&&const DeepCollectionEquality().equals(other.space, _this.space)&&const DeepCollectionEquality().equals(other.radius, _this.radius)&&const DeepCollectionEquality().equals(other.layouts, _this.layouts)&&const DeepCollectionEquality().equals(other.palette, _this.palette)&&(identical(other.color, _this.color) || other.color == _this.color)&&(identical(other.typography, _this.typography) || other.typography == _this.typography)&&(identical(other.animation, _this.animation) || other.animation == _this.animation)&&const DeepCollectionEquality().equals(other.opacity, _this.opacity)&&const DeepCollectionEquality().equals(other.extensions, _this.extensions));
}


@override
int get hashCode {
  final _this = this as StratumThemeConfig;
  return Object.hash(runtimeType,_this.name,const DeepCollectionEquality().hash(_this.assets),const DeepCollectionEquality().hash(_this.space),const DeepCollectionEquality().hash(_this.radius),const DeepCollectionEquality().hash(_this.layouts),const DeepCollectionEquality().hash(_this.palette),_this.color,_this.typography,_this.animation,const DeepCollectionEquality().hash(_this.opacity),const DeepCollectionEquality().hash(_this.extensions));
}

@override
String toString() {
  final _this = this as StratumThemeConfig;
  return 'StratumThemeConfig(name: ${_this.name}, assets: ${_this.assets}, space: ${_this.space}, radius: ${_this.radius}, layouts: ${_this.layouts}, palette: ${_this.palette}, color: ${_this.color}, typography: ${_this.typography}, animation: ${_this.animation}, opacity: ${_this.opacity}, extensions: ${_this.extensions})';
}


}

/// @nodoc
abstract mixin class $StratumThemeConfigCopyWith<$Res>  {
  factory $StratumThemeConfigCopyWith(StratumThemeConfig value, $Res Function(StratumThemeConfig) _then) = _$StratumThemeConfigCopyWithImpl;
@useResult
$Res call({
 String name, Map<String, StratumThemeAsset> assets, Map<String, StratumByWindowSize<StratumDimension>> space, Map<String, StratumByWindowSize<StratumDimension>> radius, Map<String, StratumByWindowSize<StratumDimension>> layouts, Map<String, Color> palette, StratumColorSets color, StratumTypography typography, StratumAnimationConfig animation, Map<String, double> opacity, Map<String, Object?> extensions
});


$StratumColorSetsCopyWith<$Res> get color;$StratumTypographyCopyWith<$Res> get typography;$StratumAnimationConfigCopyWith<$Res> get animation;

}
/// @nodoc
class _$StratumThemeConfigCopyWithImpl<$Res>
    implements $StratumThemeConfigCopyWith<$Res> {
  _$StratumThemeConfigCopyWithImpl(this._self, this._then);

  final StratumThemeConfig _self;
  final $Res Function(StratumThemeConfig) _then;

/// Create a copy of StratumThemeConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? assets = null,Object? space = null,Object? radius = null,Object? layouts = null,Object? palette = null,Object? color = null,Object? typography = null,Object? animation = null,Object? opacity = null,Object? extensions = null,}) {
  return _then(StratumThemeConfig(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,assets: null == assets ? _self.assets : assets // ignore: cast_nullable_to_non_nullable
as Map<String, StratumThemeAsset>,space: null == space ? _self.space : space // ignore: cast_nullable_to_non_nullable
as Map<String, StratumByWindowSize<StratumDimension>>,radius: null == radius ? _self.radius : radius // ignore: cast_nullable_to_non_nullable
as Map<String, StratumByWindowSize<StratumDimension>>,layouts: null == layouts ? _self.layouts : layouts // ignore: cast_nullable_to_non_nullable
as Map<String, StratumByWindowSize<StratumDimension>>,palette: null == palette ? _self.palette : palette // ignore: cast_nullable_to_non_nullable
as Map<String, Color>,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as StratumColorSets,typography: null == typography ? _self.typography : typography // ignore: cast_nullable_to_non_nullable
as StratumTypography,animation: null == animation ? _self.animation : animation // ignore: cast_nullable_to_non_nullable
as StratumAnimationConfig,opacity: null == opacity ? _self.opacity : opacity // ignore: cast_nullable_to_non_nullable
as Map<String, double>,extensions: null == extensions ? _self.extensions : extensions // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}
/// Create a copy of StratumThemeConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumColorSetsCopyWith<$Res> get color {
  
  return $StratumColorSetsCopyWith<$Res>(_self.color, (value) {
    return _then(_self.copyWith(color: value));
  });
}/// Create a copy of StratumThemeConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumTypographyCopyWith<$Res> get typography {
  
  return $StratumTypographyCopyWith<$Res>(_self.typography, (value) {
    return _then(_self.copyWith(typography: value));
  });
}/// Create a copy of StratumThemeConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumAnimationConfigCopyWith<$Res> get animation {
  
  return $StratumAnimationConfigCopyWith<$Res>(_self.animation, (value) {
    return _then(_self.copyWith(animation: value));
  });
}
}



/// @nodoc


class _StratumThemeConfig implements StratumThemeConfig {
  const _StratumThemeConfig({required this.name, required  Map<String, StratumThemeAsset> assets, required  Map<String, StratumByWindowSize<StratumDimension>> space, required  Map<String, StratumByWindowSize<StratumDimension>> radius, required  Map<String, StratumByWindowSize<StratumDimension>> layouts, required  Map<String, Color> palette, required this.color, required this.typography, required this.animation, required  Map<String, double> opacity, required  Map<String, Object?> extensions}): _assets = assets,_space = space,_radius = radius,_layouts = layouts,_palette = palette,_opacity = opacity,_extensions = extensions;
  

@override final  String name;
/// Each slot that names an asset (`splash-screen`, `loading`); an empty
/// slot has no entry.
 final  Map<String, StratumThemeAsset> _assets;
/// Each slot that names an asset (`splash-screen`, `loading`); an empty
/// slot has no entry.
@override Map<String, StratumThemeAsset> get assets {
  if (_assets is EqualUnmodifiableMapView) return _assets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_assets);
}

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

/// Every shade by its path under `palette`: `brand.500`,
/// `app.<ramp>.<shade>`. 88 entries for the package default.
 final  Map<String, Color> _palette;
/// Every shade by its path under `palette`: `brand.500`,
/// `app.<ramp>.<shade>`. 88 entries for the package default.
@override Map<String, Color> get palette {
  if (_palette is EqualUnmodifiableMapView) return _palette;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_palette);
}

@override final  StratumColorSets color;
@override final  StratumTypography typography;
/// The merged `animation` group (spec section 8.1).
@override final  StratumAnimationConfig animation;
/// The merged `opacity` group: `disabled`, the opacity of a disabled
/// component (FO-08 US-07), from 0 to 1; 0.5 in the package default.
 final  Map<String, double> _opacity;
/// The merged `opacity` group: `disabled`, the opacity of a disabled
/// component (FO-08 US-07), from 0 to 1; 0.5 in the package default.
@override Map<String, double> get opacity {
  if (_opacity is EqualUnmodifiableMapView) return _opacity;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_opacity);
}

/// The merged `extensions` group as plain Dart values: maps with string
/// keys, lists, strings, numbers, booleans, and null. Never
/// alias-resolved and never checked.
 final  Map<String, Object?> _extensions;
/// The merged `extensions` group as plain Dart values: maps with string
/// keys, lists, strings, numbers, booleans, and null. Never
/// alias-resolved and never checked.
@override Map<String, Object?> get extensions {
  if (_extensions is EqualUnmodifiableMapView) return _extensions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_extensions);
}


/// Create a copy of StratumThemeConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StratumThemeConfigCopyWith<_StratumThemeConfig> get copyWith => __$StratumThemeConfigCopyWithImpl<_StratumThemeConfig>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StratumThemeConfig&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.assets, _assets)&&const DeepCollectionEquality().equals(other.space, _space)&&const DeepCollectionEquality().equals(other.radius, _radius)&&const DeepCollectionEquality().equals(other.layouts, _layouts)&&const DeepCollectionEquality().equals(other.palette, _palette)&&(identical(other.color, color) || other.color == color)&&(identical(other.typography, typography) || other.typography == typography)&&(identical(other.animation, animation) || other.animation == animation)&&const DeepCollectionEquality().equals(other.opacity, _opacity)&&const DeepCollectionEquality().equals(other.extensions, _extensions));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,const DeepCollectionEquality().hash(_assets),const DeepCollectionEquality().hash(_space),const DeepCollectionEquality().hash(_radius),const DeepCollectionEquality().hash(_layouts),const DeepCollectionEquality().hash(_palette),color,typography,animation,const DeepCollectionEquality().hash(_opacity),const DeepCollectionEquality().hash(_extensions));
}

@override
String toString() {
    return 'StratumThemeConfig(name: $name, assets: $assets, space: $space, radius: $radius, layouts: $layouts, palette: $palette, color: $color, typography: $typography, animation: $animation, opacity: $opacity, extensions: $extensions)';
}


}

/// @nodoc
abstract mixin class _$StratumThemeConfigCopyWith<$Res> implements $StratumThemeConfigCopyWith<$Res> {
  factory _$StratumThemeConfigCopyWith(_StratumThemeConfig value, $Res Function(_StratumThemeConfig) _then) = __$StratumThemeConfigCopyWithImpl;
@override @useResult
$Res call({
 String name, Map<String, StratumThemeAsset> assets, Map<String, StratumByWindowSize<StratumDimension>> space, Map<String, StratumByWindowSize<StratumDimension>> radius, Map<String, StratumByWindowSize<StratumDimension>> layouts, Map<String, Color> palette, StratumColorSets color, StratumTypography typography, StratumAnimationConfig animation, Map<String, double> opacity, Map<String, Object?> extensions
});


@override $StratumColorSetsCopyWith<$Res> get color;@override $StratumTypographyCopyWith<$Res> get typography;@override $StratumAnimationConfigCopyWith<$Res> get animation;

}
/// @nodoc
class __$StratumThemeConfigCopyWithImpl<$Res>
    implements _$StratumThemeConfigCopyWith<$Res> {
  __$StratumThemeConfigCopyWithImpl(this._self, this._then);

  final _StratumThemeConfig _self;
  final $Res Function(_StratumThemeConfig) _then;

/// Create a copy of StratumThemeConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? assets = null,Object? space = null,Object? radius = null,Object? layouts = null,Object? palette = null,Object? color = null,Object? typography = null,Object? animation = null,Object? opacity = null,Object? extensions = null,}) {
  return _then(_StratumThemeConfig(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,assets: null == assets ? _self._assets : assets // ignore: cast_nullable_to_non_nullable
as Map<String, StratumThemeAsset>,space: null == space ? _self._space : space // ignore: cast_nullable_to_non_nullable
as Map<String, StratumByWindowSize<StratumDimension>>,radius: null == radius ? _self._radius : radius // ignore: cast_nullable_to_non_nullable
as Map<String, StratumByWindowSize<StratumDimension>>,layouts: null == layouts ? _self._layouts : layouts // ignore: cast_nullable_to_non_nullable
as Map<String, StratumByWindowSize<StratumDimension>>,palette: null == palette ? _self._palette : palette // ignore: cast_nullable_to_non_nullable
as Map<String, Color>,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as StratumColorSets,typography: null == typography ? _self.typography : typography // ignore: cast_nullable_to_non_nullable
as StratumTypography,animation: null == animation ? _self.animation : animation // ignore: cast_nullable_to_non_nullable
as StratumAnimationConfig,opacity: null == opacity ? _self._opacity : opacity // ignore: cast_nullable_to_non_nullable
as Map<String, double>,extensions: null == extensions ? _self._extensions : extensions // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

/// Create a copy of StratumThemeConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumColorSetsCopyWith<$Res> get color {
  
  return $StratumColorSetsCopyWith<$Res>(_self.color, (value) {
    return _then(_self.copyWith(color: value));
  });
}/// Create a copy of StratumThemeConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumTypographyCopyWith<$Res> get typography {
  
  return $StratumTypographyCopyWith<$Res>(_self.typography, (value) {
    return _then(_self.copyWith(typography: value));
  });
}/// Create a copy of StratumThemeConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumAnimationConfigCopyWith<$Res> get animation {
  
  return $StratumAnimationConfigCopyWith<$Res>(_self.animation, (value) {
    return _then(_self.copyWith(animation: value));
  });
}
}

/// @nodoc
mixin _$StratumColorSets {

/// 192 entries for the package default.
 Map<String, Color> get light; Map<String, Color> get dark;/// Always full: [light] with the `highContrastLight` overlay applied.
 Map<String, Color> get highContrastLight;/// Always full: [dark] with the `highContrastDark` overlay applied.
 Map<String, Color> get highContrastDark;
/// Create a copy of StratumColorSets
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumColorSetsCopyWith<StratumColorSets> get copyWith => _$StratumColorSetsCopyWithImpl<StratumColorSets>(this as StratumColorSets, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumColorSets;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumColorSets&&const DeepCollectionEquality().equals(other.light, _this.light)&&const DeepCollectionEquality().equals(other.dark, _this.dark)&&const DeepCollectionEquality().equals(other.highContrastLight, _this.highContrastLight)&&const DeepCollectionEquality().equals(other.highContrastDark, _this.highContrastDark));
}


@override
int get hashCode {
  final _this = this as StratumColorSets;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.light),const DeepCollectionEquality().hash(_this.dark),const DeepCollectionEquality().hash(_this.highContrastLight),const DeepCollectionEquality().hash(_this.highContrastDark));
}

@override
String toString() {
  final _this = this as StratumColorSets;
  return 'StratumColorSets(light: ${_this.light}, dark: ${_this.dark}, highContrastLight: ${_this.highContrastLight}, highContrastDark: ${_this.highContrastDark})';
}


}

/// @nodoc
abstract mixin class $StratumColorSetsCopyWith<$Res>  {
  factory $StratumColorSetsCopyWith(StratumColorSets value, $Res Function(StratumColorSets) _then) = _$StratumColorSetsCopyWithImpl;
@useResult
$Res call({
 Map<String, Color> light, Map<String, Color> dark, Map<String, Color> highContrastLight, Map<String, Color> highContrastDark
});




}
/// @nodoc
class _$StratumColorSetsCopyWithImpl<$Res>
    implements $StratumColorSetsCopyWith<$Res> {
  _$StratumColorSetsCopyWithImpl(this._self, this._then);

  final StratumColorSets _self;
  final $Res Function(StratumColorSets) _then;

/// Create a copy of StratumColorSets
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? light = null,Object? dark = null,Object? highContrastLight = null,Object? highContrastDark = null,}) {
  return _then(StratumColorSets(
light: null == light ? _self.light : light // ignore: cast_nullable_to_non_nullable
as Map<String, Color>,dark: null == dark ? _self.dark : dark // ignore: cast_nullable_to_non_nullable
as Map<String, Color>,highContrastLight: null == highContrastLight ? _self.highContrastLight : highContrastLight // ignore: cast_nullable_to_non_nullable
as Map<String, Color>,highContrastDark: null == highContrastDark ? _self.highContrastDark : highContrastDark // ignore: cast_nullable_to_non_nullable
as Map<String, Color>,
  ));
}

}



/// @nodoc


class _StratumColorSets implements StratumColorSets {
  const _StratumColorSets({required  Map<String, Color> light, required  Map<String, Color> dark, required  Map<String, Color> highContrastLight, required  Map<String, Color> highContrastDark}): _light = light,_dark = dark,_highContrastLight = highContrastLight,_highContrastDark = highContrastDark;
  

/// 192 entries for the package default.
 final  Map<String, Color> _light;
/// 192 entries for the package default.
@override Map<String, Color> get light {
  if (_light is EqualUnmodifiableMapView) return _light;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_light);
}

 final  Map<String, Color> _dark;
@override Map<String, Color> get dark {
  if (_dark is EqualUnmodifiableMapView) return _dark;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_dark);
}

/// Always full: [light] with the `highContrastLight` overlay applied.
 final  Map<String, Color> _highContrastLight;
/// Always full: [light] with the `highContrastLight` overlay applied.
@override Map<String, Color> get highContrastLight {
  if (_highContrastLight is EqualUnmodifiableMapView) return _highContrastLight;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_highContrastLight);
}

/// Always full: [dark] with the `highContrastDark` overlay applied.
 final  Map<String, Color> _highContrastDark;
/// Always full: [dark] with the `highContrastDark` overlay applied.
@override Map<String, Color> get highContrastDark {
  if (_highContrastDark is EqualUnmodifiableMapView) return _highContrastDark;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_highContrastDark);
}


/// Create a copy of StratumColorSets
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StratumColorSetsCopyWith<_StratumColorSets> get copyWith => __$StratumColorSetsCopyWithImpl<_StratumColorSets>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StratumColorSets&&const DeepCollectionEquality().equals(other.light, _light)&&const DeepCollectionEquality().equals(other.dark, _dark)&&const DeepCollectionEquality().equals(other.highContrastLight, _highContrastLight)&&const DeepCollectionEquality().equals(other.highContrastDark, _highContrastDark));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_light),const DeepCollectionEquality().hash(_dark),const DeepCollectionEquality().hash(_highContrastLight),const DeepCollectionEquality().hash(_highContrastDark));
}

@override
String toString() {
    return 'StratumColorSets(light: $light, dark: $dark, highContrastLight: $highContrastLight, highContrastDark: $highContrastDark)';
}


}

/// @nodoc
abstract mixin class _$StratumColorSetsCopyWith<$Res> implements $StratumColorSetsCopyWith<$Res> {
  factory _$StratumColorSetsCopyWith(_StratumColorSets value, $Res Function(_StratumColorSets) _then) = __$StratumColorSetsCopyWithImpl;
@override @useResult
$Res call({
 Map<String, Color> light, Map<String, Color> dark, Map<String, Color> highContrastLight, Map<String, Color> highContrastDark
});




}
/// @nodoc
class __$StratumColorSetsCopyWithImpl<$Res>
    implements _$StratumColorSetsCopyWith<$Res> {
  __$StratumColorSetsCopyWithImpl(this._self, this._then);

  final _StratumColorSets _self;
  final $Res Function(_StratumColorSets) _then;

/// Create a copy of StratumColorSets
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? light = null,Object? dark = null,Object? highContrastLight = null,Object? highContrastDark = null,}) {
  return _then(_StratumColorSets(
light: null == light ? _self._light : light // ignore: cast_nullable_to_non_nullable
as Map<String, Color>,dark: null == dark ? _self._dark : dark // ignore: cast_nullable_to_non_nullable
as Map<String, Color>,highContrastLight: null == highContrastLight ? _self._highContrastLight : highContrastLight // ignore: cast_nullable_to_non_nullable
as Map<String, Color>,highContrastDark: null == highContrastDark ? _self._highContrastDark : highContrastDark // ignore: cast_nullable_to_non_nullable
as Map<String, Color>,
  ));
}


}

// dart format on
