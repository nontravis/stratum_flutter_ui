// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../remote_theme.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StratumRemoteTheme {

/// The `<id>` of `<id>.zip`: only `a-z`, `0-9`, `-`, and `_`, and never
/// `default`. The theme registers under it, replacing an earlier install
/// of that id, or a bundled theme of that id, for the app's run.
 String get id;/// The whole zip as the app downloaded and kept it.
 Uint8List get bytes;/// The expected checksum: `sha256:` followed by 64 hex digits.
 String get checksum;/// The cap on the total extracted size, in bytes.
 int get maxBytes;/// The cap on the entry count.
 int get maxEntries;
/// Create a copy of StratumRemoteTheme
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumRemoteThemeCopyWith<StratumRemoteTheme> get copyWith => _$StratumRemoteThemeCopyWithImpl<StratumRemoteTheme>(this as StratumRemoteTheme, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumRemoteTheme;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumRemoteTheme&&(identical(other.id, _this.id) || other.id == _this.id)&&const DeepCollectionEquality().equals(other.bytes, _this.bytes)&&(identical(other.checksum, _this.checksum) || other.checksum == _this.checksum)&&(identical(other.maxBytes, _this.maxBytes) || other.maxBytes == _this.maxBytes)&&(identical(other.maxEntries, _this.maxEntries) || other.maxEntries == _this.maxEntries));
}


@override
int get hashCode {
  final _this = this as StratumRemoteTheme;
  return Object.hash(runtimeType,_this.id,const DeepCollectionEquality().hash(_this.bytes),_this.checksum,_this.maxBytes,_this.maxEntries);
}



}

/// @nodoc
abstract mixin class $StratumRemoteThemeCopyWith<$Res>  {
  factory $StratumRemoteThemeCopyWith(StratumRemoteTheme value, $Res Function(StratumRemoteTheme) _then) = _$StratumRemoteThemeCopyWithImpl;
@useResult
$Res call({
 String id, Uint8List bytes, String checksum, int maxBytes, int maxEntries
});




}
/// @nodoc
class _$StratumRemoteThemeCopyWithImpl<$Res>
    implements $StratumRemoteThemeCopyWith<$Res> {
  _$StratumRemoteThemeCopyWithImpl(this._self, this._then);

  final StratumRemoteTheme _self;
  final $Res Function(StratumRemoteTheme) _then;

/// Create a copy of StratumRemoteTheme
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? bytes = null,Object? checksum = null,Object? maxBytes = null,Object? maxEntries = null,}) {
  return _then(StratumRemoteTheme(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,bytes: null == bytes ? _self.bytes : bytes // ignore: cast_nullable_to_non_nullable
as Uint8List,checksum: null == checksum ? _self.checksum : checksum // ignore: cast_nullable_to_non_nullable
as String,maxBytes: null == maxBytes ? _self.maxBytes : maxBytes // ignore: cast_nullable_to_non_nullable
as int,maxEntries: null == maxEntries ? _self.maxEntries : maxEntries // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc


class _StratumRemoteTheme extends StratumRemoteTheme {
  const _StratumRemoteTheme({required this.id, required this.bytes, required this.checksum, this.maxBytes = StratumRemoteTheme.defaultMaxBytes, this.maxEntries = StratumRemoteTheme.defaultMaxEntries}): super._();
  

/// The `<id>` of `<id>.zip`: only `a-z`, `0-9`, `-`, and `_`, and never
/// `default`. The theme registers under it, replacing an earlier install
/// of that id, or a bundled theme of that id, for the app's run.
@override final  String id;
/// The whole zip as the app downloaded and kept it.
@override final  Uint8List bytes;
/// The expected checksum: `sha256:` followed by 64 hex digits.
@override final  String checksum;
/// The cap on the total extracted size, in bytes.
@override@JsonKey() final  int maxBytes;
/// The cap on the entry count.
@override@JsonKey() final  int maxEntries;

/// Create a copy of StratumRemoteTheme
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StratumRemoteThemeCopyWith<_StratumRemoteTheme> get copyWith => __$StratumRemoteThemeCopyWithImpl<_StratumRemoteTheme>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StratumRemoteTheme&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.bytes, bytes)&&(identical(other.checksum, checksum) || other.checksum == checksum)&&(identical(other.maxBytes, maxBytes) || other.maxBytes == maxBytes)&&(identical(other.maxEntries, maxEntries) || other.maxEntries == maxEntries));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,const DeepCollectionEquality().hash(bytes),checksum,maxBytes,maxEntries);
}



}

/// @nodoc
abstract mixin class _$StratumRemoteThemeCopyWith<$Res> implements $StratumRemoteThemeCopyWith<$Res> {
  factory _$StratumRemoteThemeCopyWith(_StratumRemoteTheme value, $Res Function(_StratumRemoteTheme) _then) = __$StratumRemoteThemeCopyWithImpl;
@override @useResult
$Res call({
 String id, Uint8List bytes, String checksum, int maxBytes, int maxEntries
});




}
/// @nodoc
class __$StratumRemoteThemeCopyWithImpl<$Res>
    implements _$StratumRemoteThemeCopyWith<$Res> {
  __$StratumRemoteThemeCopyWithImpl(this._self, this._then);

  final _StratumRemoteTheme _self;
  final $Res Function(_StratumRemoteTheme) _then;

/// Create a copy of StratumRemoteTheme
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? bytes = null,Object? checksum = null,Object? maxBytes = null,Object? maxEntries = null,}) {
  return _then(_StratumRemoteTheme(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,bytes: null == bytes ? _self.bytes : bytes // ignore: cast_nullable_to_non_nullable
as Uint8List,checksum: null == checksum ? _self.checksum : checksum // ignore: cast_nullable_to_non_nullable
as String,maxBytes: null == maxBytes ? _self.maxBytes : maxBytes // ignore: cast_nullable_to_non_nullable
as int,maxEntries: null == maxEntries ? _self.maxEntries : maxEntries // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
