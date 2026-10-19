// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../web_view_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StratumWebViewMessage {

/// Message payload. Encode structured data yourself, for example as JSON.
 String get data;/// Origin of the page that sent the message, which can differ from the
/// page shown now, or `null` for HTML content loaded from a
/// `StratumWebViewHtmlSource`.
 Uri? get origin;
/// Create a copy of StratumWebViewMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumWebViewMessageCopyWith<StratumWebViewMessage> get copyWith => _$StratumWebViewMessageCopyWithImpl<StratumWebViewMessage>(this as StratumWebViewMessage, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumWebViewMessage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumWebViewMessage&&(identical(other.data, _this.data) || other.data == _this.data)&&(identical(other.origin, _this.origin) || other.origin == _this.origin));
}


@override
int get hashCode {
  final _this = this as StratumWebViewMessage;
  return Object.hash(runtimeType,_this.data,_this.origin);
}



}

/// @nodoc
abstract mixin class $StratumWebViewMessageCopyWith<$Res>  {
  factory $StratumWebViewMessageCopyWith(StratumWebViewMessage value, $Res Function(StratumWebViewMessage) _then) = _$StratumWebViewMessageCopyWithImpl;
@useResult
$Res call({
 String data, Uri? origin
});




}
/// @nodoc
class _$StratumWebViewMessageCopyWithImpl<$Res>
    implements $StratumWebViewMessageCopyWith<$Res> {
  _$StratumWebViewMessageCopyWithImpl(this._self, this._then);

  final StratumWebViewMessage _self;
  final $Res Function(StratumWebViewMessage) _then;

/// Create a copy of StratumWebViewMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,Object? origin = freezed,}) {
  return _then(StratumWebViewMessage(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as String,origin: freezed == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as Uri?,
  ));
}

}



/// @nodoc


class _StratumWebViewMessage extends StratumWebViewMessage {
  const _StratumWebViewMessage({required this.data, this.origin}): super._();
  

/// Message payload. Encode structured data yourself, for example as JSON.
@override final  String data;
/// Origin of the page that sent the message, which can differ from the
/// page shown now, or `null` for HTML content loaded from a
/// `StratumWebViewHtmlSource`.
@override final  Uri? origin;

/// Create a copy of StratumWebViewMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StratumWebViewMessageCopyWith<_StratumWebViewMessage> get copyWith => __$StratumWebViewMessageCopyWithImpl<_StratumWebViewMessage>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StratumWebViewMessage&&(identical(other.data, data) || other.data == data)&&(identical(other.origin, origin) || other.origin == origin));
}


@override
int get hashCode {
    return Object.hash(runtimeType,data,origin);
}



}

/// @nodoc
abstract mixin class _$StratumWebViewMessageCopyWith<$Res> implements $StratumWebViewMessageCopyWith<$Res> {
  factory _$StratumWebViewMessageCopyWith(_StratumWebViewMessage value, $Res Function(_StratumWebViewMessage) _then) = __$StratumWebViewMessageCopyWithImpl;
@override @useResult
$Res call({
 String data, Uri? origin
});




}
/// @nodoc
class __$StratumWebViewMessageCopyWithImpl<$Res>
    implements _$StratumWebViewMessageCopyWith<$Res> {
  __$StratumWebViewMessageCopyWithImpl(this._self, this._then);

  final _StratumWebViewMessage _self;
  final $Res Function(_StratumWebViewMessage) _then;

/// Create a copy of StratumWebViewMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,Object? origin = freezed,}) {
  return _then(_StratumWebViewMessage(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as String,origin: freezed == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as Uri?,
  ));
}


}

// dart format on
