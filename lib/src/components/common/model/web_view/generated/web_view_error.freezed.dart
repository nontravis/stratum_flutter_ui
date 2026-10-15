// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../web_view_error.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StratumWebViewError {

/// Kind of failure.
 StratumWebViewErrorType get type;/// Human-readable description from the platform.
 String get description;/// Platform error code for [StratumWebViewErrorType.network], HTTP status
/// for [StratumWebViewErrorType.http].
 int? get code;/// Address that failed to load, when the platform reports it.
 Uri? get url;
/// Create a copy of StratumWebViewError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumWebViewErrorCopyWith<StratumWebViewError> get copyWith => _$StratumWebViewErrorCopyWithImpl<StratumWebViewError>(this as StratumWebViewError, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumWebViewError;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumWebViewError&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.url, _this.url) || other.url == _this.url));
}


@override
int get hashCode {
  final _this = this as StratumWebViewError;
  return Object.hash(runtimeType,_this.type,_this.description,_this.code,_this.url);
}



}

/// @nodoc
abstract mixin class $StratumWebViewErrorCopyWith<$Res>  {
  factory $StratumWebViewErrorCopyWith(StratumWebViewError value, $Res Function(StratumWebViewError) _then) = _$StratumWebViewErrorCopyWithImpl;
@useResult
$Res call({
 StratumWebViewErrorType type, String description, int? code, Uri? url
});




}
/// @nodoc
class _$StratumWebViewErrorCopyWithImpl<$Res>
    implements $StratumWebViewErrorCopyWith<$Res> {
  _$StratumWebViewErrorCopyWithImpl(this._self, this._then);

  final StratumWebViewError _self;
  final $Res Function(StratumWebViewError) _then;

/// Create a copy of StratumWebViewError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? description = null,Object? code = freezed,Object? url = freezed,}) {
  return _then(StratumWebViewError(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as StratumWebViewErrorType,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as int?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as Uri?,
  ));
}

}



/// @nodoc


class _StratumWebViewError extends StratumWebViewError {
  const _StratumWebViewError({required this.type, required this.description, this.code, this.url}): super._();
  

/// Kind of failure.
@override final  StratumWebViewErrorType type;
/// Human-readable description from the platform.
@override final  String description;
/// Platform error code for [StratumWebViewErrorType.network], HTTP status
/// for [StratumWebViewErrorType.http].
@override final  int? code;
/// Address that failed to load, when the platform reports it.
@override final  Uri? url;

/// Create a copy of StratumWebViewError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StratumWebViewErrorCopyWith<_StratumWebViewError> get copyWith => __$StratumWebViewErrorCopyWithImpl<_StratumWebViewError>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StratumWebViewError&&(identical(other.type, type) || other.type == type)&&(identical(other.description, description) || other.description == description)&&(identical(other.code, code) || other.code == code)&&(identical(other.url, url) || other.url == url));
}


@override
int get hashCode {
    return Object.hash(runtimeType,type,description,code,url);
}



}

/// @nodoc
abstract mixin class _$StratumWebViewErrorCopyWith<$Res> implements $StratumWebViewErrorCopyWith<$Res> {
  factory _$StratumWebViewErrorCopyWith(_StratumWebViewError value, $Res Function(_StratumWebViewError) _then) = __$StratumWebViewErrorCopyWithImpl;
@override @useResult
$Res call({
 StratumWebViewErrorType type, String description, int? code, Uri? url
});




}
/// @nodoc
class __$StratumWebViewErrorCopyWithImpl<$Res>
    implements _$StratumWebViewErrorCopyWith<$Res> {
  __$StratumWebViewErrorCopyWithImpl(this._self, this._then);

  final _StratumWebViewError _self;
  final $Res Function(_StratumWebViewError) _then;

/// Create a copy of StratumWebViewError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? description = null,Object? code = freezed,Object? url = freezed,}) {
  return _then(_StratumWebViewError(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as StratumWebViewErrorType,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as int?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as Uri?,
  ));
}


}

// dart format on
