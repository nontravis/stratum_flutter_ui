// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../web_view_configuration.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StratumWebViewConfiguration {

 Set<Uri> get allowedOrigins; bool get javaScriptEnabled; ValueChanged<StratumWebViewMessage>? get onMessage; StratumNavigationDecision Function(Uri url)? get onNavigationRequest; ValueChanged<Uri?>? get onPageStarted; ValueChanged<Uri?>? get onPageFinished; ValueChanged<StratumWebViewError>? get onError;
/// Create a copy of StratumWebViewConfiguration
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumWebViewConfigurationCopyWith<StratumWebViewConfiguration> get copyWith => _$StratumWebViewConfigurationCopyWithImpl<StratumWebViewConfiguration>(this as StratumWebViewConfiguration, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumWebViewConfiguration;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumWebViewConfiguration&&const DeepCollectionEquality().equals(other.allowedOrigins, _this.allowedOrigins)&&(identical(other.javaScriptEnabled, _this.javaScriptEnabled) || other.javaScriptEnabled == _this.javaScriptEnabled)&&(identical(other.onMessage, _this.onMessage) || other.onMessage == _this.onMessage)&&(identical(other.onNavigationRequest, _this.onNavigationRequest) || other.onNavigationRequest == _this.onNavigationRequest)&&(identical(other.onPageStarted, _this.onPageStarted) || other.onPageStarted == _this.onPageStarted)&&(identical(other.onPageFinished, _this.onPageFinished) || other.onPageFinished == _this.onPageFinished)&&(identical(other.onError, _this.onError) || other.onError == _this.onError));
}


@override
int get hashCode {
  final _this = this as StratumWebViewConfiguration;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.allowedOrigins),_this.javaScriptEnabled,_this.onMessage,_this.onNavigationRequest,_this.onPageStarted,_this.onPageFinished,_this.onError);
}

@override
String toString() {
  final _this = this as StratumWebViewConfiguration;
  return 'StratumWebViewConfiguration(allowedOrigins: ${_this.allowedOrigins}, javaScriptEnabled: ${_this.javaScriptEnabled}, onMessage: ${_this.onMessage}, onNavigationRequest: ${_this.onNavigationRequest}, onPageStarted: ${_this.onPageStarted}, onPageFinished: ${_this.onPageFinished}, onError: ${_this.onError})';
}


}

/// @nodoc
abstract mixin class $StratumWebViewConfigurationCopyWith<$Res>  {
  factory $StratumWebViewConfigurationCopyWith(StratumWebViewConfiguration value, $Res Function(StratumWebViewConfiguration) _then) = _$StratumWebViewConfigurationCopyWithImpl;
@useResult
$Res call({
 Set<Uri> allowedOrigins, bool javaScriptEnabled, ValueChanged<StratumWebViewMessage>? onMessage, StratumNavigationDecision Function(Uri url)? onNavigationRequest, ValueChanged<Uri?>? onPageStarted, ValueChanged<Uri?>? onPageFinished, ValueChanged<StratumWebViewError>? onError
});




}
/// @nodoc
class _$StratumWebViewConfigurationCopyWithImpl<$Res>
    implements $StratumWebViewConfigurationCopyWith<$Res> {
  _$StratumWebViewConfigurationCopyWithImpl(this._self, this._then);

  final StratumWebViewConfiguration _self;
  final $Res Function(StratumWebViewConfiguration) _then;

/// Create a copy of StratumWebViewConfiguration
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? allowedOrigins = null,Object? javaScriptEnabled = null,Object? onMessage = freezed,Object? onNavigationRequest = freezed,Object? onPageStarted = freezed,Object? onPageFinished = freezed,Object? onError = freezed,}) {
  return _then(StratumWebViewConfiguration(
allowedOrigins: null == allowedOrigins ? _self.allowedOrigins : allowedOrigins // ignore: cast_nullable_to_non_nullable
as Set<Uri>,javaScriptEnabled: null == javaScriptEnabled ? _self.javaScriptEnabled : javaScriptEnabled // ignore: cast_nullable_to_non_nullable
as bool,onMessage: freezed == onMessage ? _self.onMessage : onMessage // ignore: cast_nullable_to_non_nullable
as ValueChanged<StratumWebViewMessage>?,onNavigationRequest: freezed == onNavigationRequest ? _self.onNavigationRequest : onNavigationRequest // ignore: cast_nullable_to_non_nullable
as StratumNavigationDecision Function(Uri url)?,onPageStarted: freezed == onPageStarted ? _self.onPageStarted : onPageStarted // ignore: cast_nullable_to_non_nullable
as ValueChanged<Uri?>?,onPageFinished: freezed == onPageFinished ? _self.onPageFinished : onPageFinished // ignore: cast_nullable_to_non_nullable
as ValueChanged<Uri?>?,onError: freezed == onError ? _self.onError : onError // ignore: cast_nullable_to_non_nullable
as ValueChanged<StratumWebViewError>?,
  ));
}

}



/// @nodoc


class _StratumWebViewConfiguration implements StratumWebViewConfiguration {
  const _StratumWebViewConfiguration({ Set<Uri> allowedOrigins = const <Uri>{}, this.javaScriptEnabled = true, this.onMessage, this.onNavigationRequest, this.onPageStarted, this.onPageFinished, this.onError}): _allowedOrigins = allowedOrigins;
  

 final  Set<Uri> _allowedOrigins;
@override@JsonKey() Set<Uri> get allowedOrigins {
  if (_allowedOrigins is EqualUnmodifiableSetView) return _allowedOrigins;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_allowedOrigins);
}

@override@JsonKey() final  bool javaScriptEnabled;
@override final  ValueChanged<StratumWebViewMessage>? onMessage;
@override final  StratumNavigationDecision Function(Uri url)? onNavigationRequest;
@override final  ValueChanged<Uri?>? onPageStarted;
@override final  ValueChanged<Uri?>? onPageFinished;
@override final  ValueChanged<StratumWebViewError>? onError;

/// Create a copy of StratumWebViewConfiguration
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StratumWebViewConfigurationCopyWith<_StratumWebViewConfiguration> get copyWith => __$StratumWebViewConfigurationCopyWithImpl<_StratumWebViewConfiguration>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StratumWebViewConfiguration&&const DeepCollectionEquality().equals(other.allowedOrigins, _allowedOrigins)&&(identical(other.javaScriptEnabled, javaScriptEnabled) || other.javaScriptEnabled == javaScriptEnabled)&&(identical(other.onMessage, onMessage) || other.onMessage == onMessage)&&(identical(other.onNavigationRequest, onNavigationRequest) || other.onNavigationRequest == onNavigationRequest)&&(identical(other.onPageStarted, onPageStarted) || other.onPageStarted == onPageStarted)&&(identical(other.onPageFinished, onPageFinished) || other.onPageFinished == onPageFinished)&&(identical(other.onError, onError) || other.onError == onError));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_allowedOrigins),javaScriptEnabled,onMessage,onNavigationRequest,onPageStarted,onPageFinished,onError);
}

@override
String toString() {
    return 'StratumWebViewConfiguration(allowedOrigins: $allowedOrigins, javaScriptEnabled: $javaScriptEnabled, onMessage: $onMessage, onNavigationRequest: $onNavigationRequest, onPageStarted: $onPageStarted, onPageFinished: $onPageFinished, onError: $onError)';
}


}

/// @nodoc
abstract mixin class _$StratumWebViewConfigurationCopyWith<$Res> implements $StratumWebViewConfigurationCopyWith<$Res> {
  factory _$StratumWebViewConfigurationCopyWith(_StratumWebViewConfiguration value, $Res Function(_StratumWebViewConfiguration) _then) = __$StratumWebViewConfigurationCopyWithImpl;
@override @useResult
$Res call({
 Set<Uri> allowedOrigins, bool javaScriptEnabled, ValueChanged<StratumWebViewMessage>? onMessage, StratumNavigationDecision Function(Uri url)? onNavigationRequest, ValueChanged<Uri?>? onPageStarted, ValueChanged<Uri?>? onPageFinished, ValueChanged<StratumWebViewError>? onError
});




}
/// @nodoc
class __$StratumWebViewConfigurationCopyWithImpl<$Res>
    implements _$StratumWebViewConfigurationCopyWith<$Res> {
  __$StratumWebViewConfigurationCopyWithImpl(this._self, this._then);

  final _StratumWebViewConfiguration _self;
  final $Res Function(_StratumWebViewConfiguration) _then;

/// Create a copy of StratumWebViewConfiguration
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? allowedOrigins = null,Object? javaScriptEnabled = null,Object? onMessage = freezed,Object? onNavigationRequest = freezed,Object? onPageStarted = freezed,Object? onPageFinished = freezed,Object? onError = freezed,}) {
  return _then(_StratumWebViewConfiguration(
allowedOrigins: null == allowedOrigins ? _self._allowedOrigins : allowedOrigins // ignore: cast_nullable_to_non_nullable
as Set<Uri>,javaScriptEnabled: null == javaScriptEnabled ? _self.javaScriptEnabled : javaScriptEnabled // ignore: cast_nullable_to_non_nullable
as bool,onMessage: freezed == onMessage ? _self.onMessage : onMessage // ignore: cast_nullable_to_non_nullable
as ValueChanged<StratumWebViewMessage>?,onNavigationRequest: freezed == onNavigationRequest ? _self.onNavigationRequest : onNavigationRequest // ignore: cast_nullable_to_non_nullable
as StratumNavigationDecision Function(Uri url)?,onPageStarted: freezed == onPageStarted ? _self.onPageStarted : onPageStarted // ignore: cast_nullable_to_non_nullable
as ValueChanged<Uri?>?,onPageFinished: freezed == onPageFinished ? _self.onPageFinished : onPageFinished // ignore: cast_nullable_to_non_nullable
as ValueChanged<Uri?>?,onError: freezed == onError ? _self.onError : onError // ignore: cast_nullable_to_non_nullable
as ValueChanged<StratumWebViewError>?,
  ));
}


}

// dart format on
