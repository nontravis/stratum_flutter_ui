// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../stratum_caret_style.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StratumCaretStyle {

/// Fades the box; the glyph keeps its look.
 double? get opacity;/// Grows the box; the glyph stays centered inside it at full size.
 EdgeInsetsGeometry? get margin;/// Grows the box past its side, never below it; the glyph keeps its
/// size, centered.
 double? get width;/// Grows the box past its side, never below it; the glyph keeps its
/// size, centered.
 double? get height;/// The box's border.
 Border? get border;/// The box's corner radius.
 BorderRadiusGeometry? get borderRadius;/// The box's fill behind the glyph.
 Color? get backgroundColor;/// The box's gradient fill behind the glyph.
 Gradient? get backgroundGradient;/// The box's image fill behind the glyph.
 DecorationImage? get backgroundImage;/// Blurs what lies behind the box.
 ImageBlurFilter? get backgroundBlur;/// A layer over the box's fill, under the glyph.
 Color? get foregroundColor;/// A gradient layer over the box's fill, under the glyph.
 Gradient? get foregroundGradient;/// An image layer over the box's fill, under the glyph.
 DecorationImage? get foregroundImage;/// The box's inner shadows.
 List<BoxShadow>? get innerShadow;/// The box's drop shadows.
 List<BoxShadow>? get dropShadow;/// The motion from one box style to the next.
 AnimationStyle? get animationStyle;
/// Create a copy of StratumCaretStyle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumCaretStyleCopyWith<StratumCaretStyle> get copyWith => _$StratumCaretStyleCopyWithImpl<StratumCaretStyle>(this as StratumCaretStyle, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumCaretStyle;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumCaretStyle&&(identical(other.opacity, _this.opacity) || other.opacity == _this.opacity)&&(identical(other.margin, _this.margin) || other.margin == _this.margin)&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.height, _this.height) || other.height == _this.height)&&(identical(other.border, _this.border) || other.border == _this.border)&&(identical(other.borderRadius, _this.borderRadius) || other.borderRadius == _this.borderRadius)&&(identical(other.backgroundColor, _this.backgroundColor) || other.backgroundColor == _this.backgroundColor)&&(identical(other.backgroundGradient, _this.backgroundGradient) || other.backgroundGradient == _this.backgroundGradient)&&(identical(other.backgroundImage, _this.backgroundImage) || other.backgroundImage == _this.backgroundImage)&&(identical(other.backgroundBlur, _this.backgroundBlur) || other.backgroundBlur == _this.backgroundBlur)&&(identical(other.foregroundColor, _this.foregroundColor) || other.foregroundColor == _this.foregroundColor)&&(identical(other.foregroundGradient, _this.foregroundGradient) || other.foregroundGradient == _this.foregroundGradient)&&(identical(other.foregroundImage, _this.foregroundImage) || other.foregroundImage == _this.foregroundImage)&&const DeepCollectionEquality().equals(other.innerShadow, _this.innerShadow)&&const DeepCollectionEquality().equals(other.dropShadow, _this.dropShadow)&&(identical(other.animationStyle, _this.animationStyle) || other.animationStyle == _this.animationStyle));
}


@override
int get hashCode {
  final _this = this as StratumCaretStyle;
  return Object.hash(runtimeType,_this.opacity,_this.margin,_this.width,_this.height,_this.border,_this.borderRadius,_this.backgroundColor,_this.backgroundGradient,_this.backgroundImage,_this.backgroundBlur,_this.foregroundColor,_this.foregroundGradient,_this.foregroundImage,const DeepCollectionEquality().hash(_this.innerShadow),const DeepCollectionEquality().hash(_this.dropShadow),_this.animationStyle);
}

@override
String toString() {
  final _this = this as StratumCaretStyle;
  return 'StratumCaretStyle(opacity: ${_this.opacity}, margin: ${_this.margin}, width: ${_this.width}, height: ${_this.height}, border: ${_this.border}, borderRadius: ${_this.borderRadius}, backgroundColor: ${_this.backgroundColor}, backgroundGradient: ${_this.backgroundGradient}, backgroundImage: ${_this.backgroundImage}, backgroundBlur: ${_this.backgroundBlur}, foregroundColor: ${_this.foregroundColor}, foregroundGradient: ${_this.foregroundGradient}, foregroundImage: ${_this.foregroundImage}, innerShadow: ${_this.innerShadow}, dropShadow: ${_this.dropShadow}, animationStyle: ${_this.animationStyle})';
}


}

/// @nodoc
abstract mixin class $StratumCaretStyleCopyWith<$Res>  {
  factory $StratumCaretStyleCopyWith(StratumCaretStyle value, $Res Function(StratumCaretStyle) _then) = _$StratumCaretStyleCopyWithImpl;
@useResult
$Res call({
 double? opacity, EdgeInsetsGeometry? margin, double? width, double? height, Border? border, BorderRadiusGeometry? borderRadius, Color? backgroundColor, Gradient? backgroundGradient, DecorationImage? backgroundImage, ImageBlurFilter? backgroundBlur, Color? foregroundColor, Gradient? foregroundGradient, DecorationImage? foregroundImage, List<BoxShadow>? innerShadow, List<BoxShadow>? dropShadow, AnimationStyle? animationStyle
});


$ImageBlurFilterCopyWith<$Res>? get backgroundBlur;

}
/// @nodoc
class _$StratumCaretStyleCopyWithImpl<$Res>
    implements $StratumCaretStyleCopyWith<$Res> {
  _$StratumCaretStyleCopyWithImpl(this._self, this._then);

  final StratumCaretStyle _self;
  final $Res Function(StratumCaretStyle) _then;

/// Create a copy of StratumCaretStyle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? opacity = freezed,Object? margin = freezed,Object? width = freezed,Object? height = freezed,Object? border = freezed,Object? borderRadius = freezed,Object? backgroundColor = freezed,Object? backgroundGradient = freezed,Object? backgroundImage = freezed,Object? backgroundBlur = freezed,Object? foregroundColor = freezed,Object? foregroundGradient = freezed,Object? foregroundImage = freezed,Object? innerShadow = freezed,Object? dropShadow = freezed,Object? animationStyle = freezed,}) {
  return _then(StratumCaretStyle(
opacity: freezed == opacity ? _self.opacity : opacity // ignore: cast_nullable_to_non_nullable
as double?,margin: freezed == margin ? _self.margin : margin // ignore: cast_nullable_to_non_nullable
as EdgeInsetsGeometry?,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double?,border: freezed == border ? _self.border : border // ignore: cast_nullable_to_non_nullable
as Border?,borderRadius: freezed == borderRadius ? _self.borderRadius : borderRadius // ignore: cast_nullable_to_non_nullable
as BorderRadiusGeometry?,backgroundColor: freezed == backgroundColor ? _self.backgroundColor : backgroundColor // ignore: cast_nullable_to_non_nullable
as Color?,backgroundGradient: freezed == backgroundGradient ? _self.backgroundGradient : backgroundGradient // ignore: cast_nullable_to_non_nullable
as Gradient?,backgroundImage: freezed == backgroundImage ? _self.backgroundImage : backgroundImage // ignore: cast_nullable_to_non_nullable
as DecorationImage?,backgroundBlur: freezed == backgroundBlur ? _self.backgroundBlur : backgroundBlur // ignore: cast_nullable_to_non_nullable
as ImageBlurFilter?,foregroundColor: freezed == foregroundColor ? _self.foregroundColor : foregroundColor // ignore: cast_nullable_to_non_nullable
as Color?,foregroundGradient: freezed == foregroundGradient ? _self.foregroundGradient : foregroundGradient // ignore: cast_nullable_to_non_nullable
as Gradient?,foregroundImage: freezed == foregroundImage ? _self.foregroundImage : foregroundImage // ignore: cast_nullable_to_non_nullable
as DecorationImage?,innerShadow: freezed == innerShadow ? _self.innerShadow : innerShadow // ignore: cast_nullable_to_non_nullable
as List<BoxShadow>?,dropShadow: freezed == dropShadow ? _self.dropShadow : dropShadow // ignore: cast_nullable_to_non_nullable
as List<BoxShadow>?,animationStyle: freezed == animationStyle ? _self.animationStyle : animationStyle // ignore: cast_nullable_to_non_nullable
as AnimationStyle?,
  ));
}
/// Create a copy of StratumCaretStyle
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ImageBlurFilterCopyWith<$Res>? get backgroundBlur {
    if (_self.backgroundBlur == null) {
    return null;
  }

  return $ImageBlurFilterCopyWith<$Res>(_self.backgroundBlur!, (value) {
    return _then(_self.copyWith(backgroundBlur: value));
  });
}
}



/// @nodoc


class _StratumCaretStyle extends StratumCaretStyle {
  const _StratumCaretStyle({this.opacity, this.margin, this.width, this.height, this.border, this.borderRadius, this.backgroundColor, this.backgroundGradient, this.backgroundImage, this.backgroundBlur, this.foregroundColor, this.foregroundGradient, this.foregroundImage,  List<BoxShadow>? innerShadow,  List<BoxShadow>? dropShadow, this.animationStyle}): _innerShadow = innerShadow,_dropShadow = dropShadow,super._();
  

/// Fades the box; the glyph keeps its look.
@override final  double? opacity;
/// Grows the box; the glyph stays centered inside it at full size.
@override final  EdgeInsetsGeometry? margin;
/// Grows the box past its side, never below it; the glyph keeps its
/// size, centered.
@override final  double? width;
/// Grows the box past its side, never below it; the glyph keeps its
/// size, centered.
@override final  double? height;
/// The box's border.
@override final  Border? border;
/// The box's corner radius.
@override final  BorderRadiusGeometry? borderRadius;
/// The box's fill behind the glyph.
@override final  Color? backgroundColor;
/// The box's gradient fill behind the glyph.
@override final  Gradient? backgroundGradient;
/// The box's image fill behind the glyph.
@override final  DecorationImage? backgroundImage;
/// Blurs what lies behind the box.
@override final  ImageBlurFilter? backgroundBlur;
/// A layer over the box's fill, under the glyph.
@override final  Color? foregroundColor;
/// A gradient layer over the box's fill, under the glyph.
@override final  Gradient? foregroundGradient;
/// An image layer over the box's fill, under the glyph.
@override final  DecorationImage? foregroundImage;
/// The box's inner shadows.
 final  List<BoxShadow>? _innerShadow;
/// The box's inner shadows.
@override List<BoxShadow>? get innerShadow {
  final value = _innerShadow;
  if (value == null) return null;
  if (_innerShadow is EqualUnmodifiableListView) return _innerShadow;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

/// The box's drop shadows.
 final  List<BoxShadow>? _dropShadow;
/// The box's drop shadows.
@override List<BoxShadow>? get dropShadow {
  final value = _dropShadow;
  if (value == null) return null;
  if (_dropShadow is EqualUnmodifiableListView) return _dropShadow;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

/// The motion from one box style to the next.
@override final  AnimationStyle? animationStyle;

/// Create a copy of StratumCaretStyle
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StratumCaretStyleCopyWith<_StratumCaretStyle> get copyWith => __$StratumCaretStyleCopyWithImpl<_StratumCaretStyle>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StratumCaretStyle&&(identical(other.opacity, opacity) || other.opacity == opacity)&&(identical(other.margin, margin) || other.margin == margin)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.border, border) || other.border == border)&&(identical(other.borderRadius, borderRadius) || other.borderRadius == borderRadius)&&(identical(other.backgroundColor, backgroundColor) || other.backgroundColor == backgroundColor)&&(identical(other.backgroundGradient, backgroundGradient) || other.backgroundGradient == backgroundGradient)&&(identical(other.backgroundImage, backgroundImage) || other.backgroundImage == backgroundImage)&&(identical(other.backgroundBlur, backgroundBlur) || other.backgroundBlur == backgroundBlur)&&(identical(other.foregroundColor, foregroundColor) || other.foregroundColor == foregroundColor)&&(identical(other.foregroundGradient, foregroundGradient) || other.foregroundGradient == foregroundGradient)&&(identical(other.foregroundImage, foregroundImage) || other.foregroundImage == foregroundImage)&&const DeepCollectionEquality().equals(other.innerShadow, _innerShadow)&&const DeepCollectionEquality().equals(other.dropShadow, _dropShadow)&&(identical(other.animationStyle, animationStyle) || other.animationStyle == animationStyle));
}


@override
int get hashCode {
    return Object.hash(runtimeType,opacity,margin,width,height,border,borderRadius,backgroundColor,backgroundGradient,backgroundImage,backgroundBlur,foregroundColor,foregroundGradient,foregroundImage,const DeepCollectionEquality().hash(_innerShadow),const DeepCollectionEquality().hash(_dropShadow),animationStyle);
}

@override
String toString() {
    return 'StratumCaretStyle(opacity: $opacity, margin: $margin, width: $width, height: $height, border: $border, borderRadius: $borderRadius, backgroundColor: $backgroundColor, backgroundGradient: $backgroundGradient, backgroundImage: $backgroundImage, backgroundBlur: $backgroundBlur, foregroundColor: $foregroundColor, foregroundGradient: $foregroundGradient, foregroundImage: $foregroundImage, innerShadow: $innerShadow, dropShadow: $dropShadow, animationStyle: $animationStyle)';
}


}

/// @nodoc
abstract mixin class _$StratumCaretStyleCopyWith<$Res> implements $StratumCaretStyleCopyWith<$Res> {
  factory _$StratumCaretStyleCopyWith(_StratumCaretStyle value, $Res Function(_StratumCaretStyle) _then) = __$StratumCaretStyleCopyWithImpl;
@override @useResult
$Res call({
 double? opacity, EdgeInsetsGeometry? margin, double? width, double? height, Border? border, BorderRadiusGeometry? borderRadius, Color? backgroundColor, Gradient? backgroundGradient, DecorationImage? backgroundImage, ImageBlurFilter? backgroundBlur, Color? foregroundColor, Gradient? foregroundGradient, DecorationImage? foregroundImage, List<BoxShadow>? innerShadow, List<BoxShadow>? dropShadow, AnimationStyle? animationStyle
});


@override $ImageBlurFilterCopyWith<$Res>? get backgroundBlur;

}
/// @nodoc
class __$StratumCaretStyleCopyWithImpl<$Res>
    implements _$StratumCaretStyleCopyWith<$Res> {
  __$StratumCaretStyleCopyWithImpl(this._self, this._then);

  final _StratumCaretStyle _self;
  final $Res Function(_StratumCaretStyle) _then;

/// Create a copy of StratumCaretStyle
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? opacity = freezed,Object? margin = freezed,Object? width = freezed,Object? height = freezed,Object? border = freezed,Object? borderRadius = freezed,Object? backgroundColor = freezed,Object? backgroundGradient = freezed,Object? backgroundImage = freezed,Object? backgroundBlur = freezed,Object? foregroundColor = freezed,Object? foregroundGradient = freezed,Object? foregroundImage = freezed,Object? innerShadow = freezed,Object? dropShadow = freezed,Object? animationStyle = freezed,}) {
  return _then(_StratumCaretStyle(
opacity: freezed == opacity ? _self.opacity : opacity // ignore: cast_nullable_to_non_nullable
as double?,margin: freezed == margin ? _self.margin : margin // ignore: cast_nullable_to_non_nullable
as EdgeInsetsGeometry?,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double?,border: freezed == border ? _self.border : border // ignore: cast_nullable_to_non_nullable
as Border?,borderRadius: freezed == borderRadius ? _self.borderRadius : borderRadius // ignore: cast_nullable_to_non_nullable
as BorderRadiusGeometry?,backgroundColor: freezed == backgroundColor ? _self.backgroundColor : backgroundColor // ignore: cast_nullable_to_non_nullable
as Color?,backgroundGradient: freezed == backgroundGradient ? _self.backgroundGradient : backgroundGradient // ignore: cast_nullable_to_non_nullable
as Gradient?,backgroundImage: freezed == backgroundImage ? _self.backgroundImage : backgroundImage // ignore: cast_nullable_to_non_nullable
as DecorationImage?,backgroundBlur: freezed == backgroundBlur ? _self.backgroundBlur : backgroundBlur // ignore: cast_nullable_to_non_nullable
as ImageBlurFilter?,foregroundColor: freezed == foregroundColor ? _self.foregroundColor : foregroundColor // ignore: cast_nullable_to_non_nullable
as Color?,foregroundGradient: freezed == foregroundGradient ? _self.foregroundGradient : foregroundGradient // ignore: cast_nullable_to_non_nullable
as Gradient?,foregroundImage: freezed == foregroundImage ? _self.foregroundImage : foregroundImage // ignore: cast_nullable_to_non_nullable
as DecorationImage?,innerShadow: freezed == innerShadow ? _self._innerShadow : innerShadow // ignore: cast_nullable_to_non_nullable
as List<BoxShadow>?,dropShadow: freezed == dropShadow ? _self._dropShadow : dropShadow // ignore: cast_nullable_to_non_nullable
as List<BoxShadow>?,animationStyle: freezed == animationStyle ? _self.animationStyle : animationStyle // ignore: cast_nullable_to_non_nullable
as AnimationStyle?,
  ));
}

/// Create a copy of StratumCaretStyle
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ImageBlurFilterCopyWith<$Res>? get backgroundBlur {
    if (_self.backgroundBlur == null) {
    return null;
  }

  return $ImageBlurFilterCopyWith<$Res>(_self.backgroundBlur!, (value) {
    return _then(_self.copyWith(backgroundBlur: value));
  });
}
}

// dart format on
