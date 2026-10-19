// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../stratum_toast_notice.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StratumToastNotice {


/// Create a copy of StratumToastNotice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumToastNoticeCopyWith<StratumToastNotice> get copyWith => _$StratumToastNoticeCopyWithImpl<StratumToastNotice>(this as StratumToastNotice, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumToastNotice;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumToastNotice&&(identical(other.message, _this.message) || other.message == _this.message)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.placement, _this.placement) || other.placement == _this.placement)&&(identical(other.insets, _this.insets) || other.insets == _this.insets)&&(identical(other.pageSnack, _this.pageSnack) || other.pageSnack == _this.pageSnack)&&(identical(other.customStyle, _this.customStyle) || other.customStyle == _this.customStyle)&&(identical(other.action, _this.action) || other.action == _this.action)&&(identical(other.close, _this.close) || other.close == _this.close)&&(identical(other.closeLabel, _this.closeLabel) || other.closeLabel == _this.closeLabel)&&(identical(other.kindLabel, _this.kindLabel) || other.kindLabel == _this.kindLabel));
}


@override
int get hashCode {
  final _this = this as StratumToastNotice;
  return Object.hash(runtimeType,_this.message,_this.kind,_this.placement,_this.insets,_this.pageSnack,_this.customStyle,_this.action,_this.close,_this.closeLabel,_this.kindLabel);
}

@override
String toString() {
  final _this = this as StratumToastNotice;
  return 'StratumToastNotice(message: ${_this.message}, kind: ${_this.kind}, placement: ${_this.placement}, insets: ${_this.insets}, pageSnack: ${_this.pageSnack}, customStyle: ${_this.customStyle}, action: ${_this.action}, close: ${_this.close}, closeLabel: ${_this.closeLabel}, kindLabel: ${_this.kindLabel})';
}


}

/// @nodoc
abstract mixin class $StratumToastNoticeCopyWith<$Res>  {
  factory $StratumToastNoticeCopyWith(StratumToastNotice value, $Res Function(StratumToastNotice) _then) = _$StratumToastNoticeCopyWithImpl;
@useResult
$Res call({
 String message, FeedbackState kind, StratumToastPlacement placement, EdgeInsets insets, WidgetStyle? pageSnack, WidgetStyle? customStyle, VoidCallback close, String closeLabel, String kindLabel, StratumToastAction? action
});


$StratumToastPlacementCopyWith<$Res> get placement;$WidgetStyleCopyWith<$Res>? get pageSnack;$WidgetStyleCopyWith<$Res>? get customStyle;$StratumToastActionCopyWith<$Res>? get action;

}
/// @nodoc
class _$StratumToastNoticeCopyWithImpl<$Res>
    implements $StratumToastNoticeCopyWith<$Res> {
  _$StratumToastNoticeCopyWithImpl(this._self, this._then);

  final StratumToastNotice _self;
  final $Res Function(StratumToastNotice) _then;

/// Create a copy of StratumToastNotice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = null,Object? kind = null,Object? placement = null,Object? insets = null,Object? pageSnack = freezed,Object? customStyle = freezed,Object? close = null,Object? closeLabel = null,Object? kindLabel = null,Object? action = freezed,}) {
  return _then(StratumToastNotice(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as FeedbackState,placement: null == placement ? _self.placement : placement // ignore: cast_nullable_to_non_nullable
as StratumToastPlacement,insets: null == insets ? _self.insets : insets // ignore: cast_nullable_to_non_nullable
as EdgeInsets,pageSnack: freezed == pageSnack ? _self.pageSnack : pageSnack // ignore: cast_nullable_to_non_nullable
as WidgetStyle?,customStyle: freezed == customStyle ? _self.customStyle : customStyle // ignore: cast_nullable_to_non_nullable
as WidgetStyle?,close: null == close ? _self.close : close // ignore: cast_nullable_to_non_nullable
as VoidCallback,closeLabel: null == closeLabel ? _self.closeLabel : closeLabel // ignore: cast_nullable_to_non_nullable
as String,kindLabel: null == kindLabel ? _self.kindLabel : kindLabel // ignore: cast_nullable_to_non_nullable
as String,action: freezed == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as StratumToastAction?,
  ));
}
/// Create a copy of StratumToastNotice
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumToastPlacementCopyWith<$Res> get placement {
  
  return $StratumToastPlacementCopyWith<$Res>(_self.placement, (value) {
    return _then(_self.copyWith(placement: value));
  });
}/// Create a copy of StratumToastNotice
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WidgetStyleCopyWith<$Res>? get pageSnack {
    if (_self.pageSnack == null) {
    return null;
  }

  return $WidgetStyleCopyWith<$Res>(_self.pageSnack!, (value) {
    return _then(_self.copyWith(pageSnack: value));
  });
}/// Create a copy of StratumToastNotice
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WidgetStyleCopyWith<$Res>? get customStyle {
    if (_self.customStyle == null) {
    return null;
  }

  return $WidgetStyleCopyWith<$Res>(_self.customStyle!, (value) {
    return _then(_self.copyWith(customStyle: value));
  });
}/// Create a copy of StratumToastNotice
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StratumToastActionCopyWith<$Res>? get action {
    if (_self.action == null) {
    return null;
  }

  return $StratumToastActionCopyWith<$Res>(_self.action!, (value) {
    return _then(_self.copyWith(action: value));
  });
}
}



// dart format on
