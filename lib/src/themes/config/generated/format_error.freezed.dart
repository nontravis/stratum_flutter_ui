// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../format_error.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StratumThemeFormatError {


/// Create a copy of StratumThemeFormatError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumThemeFormatErrorCopyWith<StratumThemeFormatError> get copyWith => _$StratumThemeFormatErrorCopyWithImpl<StratumThemeFormatError>(this as StratumThemeFormatError, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumThemeFormatError;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumThemeFormatError&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.path, _this.path) || other.path == _this.path)&&(identical(other.message, _this.message) || other.message == _this.message)&&(identical(other.line, _this.line) || other.line == _this.line)&&(identical(other.column, _this.column) || other.column == _this.column));
}


@override
int get hashCode {
  final _this = this as StratumThemeFormatError;
  return Object.hash(runtimeType,_this.code,_this.source,_this.path,_this.message,_this.line,_this.column);
}



}

/// @nodoc
abstract mixin class $StratumThemeFormatErrorCopyWith<$Res>  {
  factory $StratumThemeFormatErrorCopyWith(StratumThemeFormatError value, $Res Function(StratumThemeFormatError) _then) = _$StratumThemeFormatErrorCopyWithImpl;
@useResult
$Res call({
 StratumThemeErrorCode code, String source, String path, String message, int? line, int? column
});




}
/// @nodoc
class _$StratumThemeFormatErrorCopyWithImpl<$Res>
    implements $StratumThemeFormatErrorCopyWith<$Res> {
  _$StratumThemeFormatErrorCopyWithImpl(this._self, this._then);

  final StratumThemeFormatError _self;
  final $Res Function(StratumThemeFormatError) _then;

/// Create a copy of StratumThemeFormatError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? source = null,Object? path = null,Object? message = null,Object? line = freezed,Object? column = freezed,}) {
  return _then(StratumThemeFormatError(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as StratumThemeErrorCode,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,line: freezed == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as int?,column: freezed == column ? _self.column : column // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}



// dart format on
