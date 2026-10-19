// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../font_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StratumFontData {

/// The family name the font is registered under: as written for
/// [StratumFontSource.app]; `<source theme id>/<family>` for
/// [StratumFontSource.theme], the source theme being the one whose file
/// set [files]; the bare Google Fonts family name (the `Google/` prefix
/// already stripped) for [StratumFontSource.google].
 String get family;/// The package that bundles the font, or null for a font of the app.
/// Always null when [source] is [StratumFontSource.google] or
/// [StratumFontSource.theme].
 String? get package;/// Added to the font size so this font looks as large as the others; a
/// percent resolves against the requested size.
 StratumDimension get adjustSize;/// Where [family] comes from.
 StratumFontSource get source;/// The asset path of each font file the theme lists, already joined to
/// the folder of the theme file that set them; empty unless [source] is
/// [StratumFontSource.theme].
 List<String> get files;
/// Create a copy of StratumFontData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumFontDataCopyWith<StratumFontData> get copyWith => _$StratumFontDataCopyWithImpl<StratumFontData>(this as StratumFontData, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StratumFontData;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumFontData&&(identical(other.family, _this.family) || other.family == _this.family)&&(identical(other.package, _this.package) || other.package == _this.package)&&(identical(other.adjustSize, _this.adjustSize) || other.adjustSize == _this.adjustSize)&&(identical(other.source, _this.source) || other.source == _this.source)&&const DeepCollectionEquality().equals(other.files, _this.files));
}


@override
int get hashCode {
  final _this = this as StratumFontData;
  return Object.hash(runtimeType,_this.family,_this.package,_this.adjustSize,_this.source,const DeepCollectionEquality().hash(_this.files));
}



}

/// @nodoc
abstract mixin class $StratumFontDataCopyWith<$Res>  {
  factory $StratumFontDataCopyWith(StratumFontData value, $Res Function(StratumFontData) _then) = _$StratumFontDataCopyWithImpl;
@useResult
$Res call({
 String family, String? package, StratumDimension adjustSize, StratumFontSource source, List<String> files
});




}
/// @nodoc
class _$StratumFontDataCopyWithImpl<$Res>
    implements $StratumFontDataCopyWith<$Res> {
  _$StratumFontDataCopyWithImpl(this._self, this._then);

  final StratumFontData _self;
  final $Res Function(StratumFontData) _then;

/// Create a copy of StratumFontData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? family = null,Object? package = freezed,Object? adjustSize = null,Object? source = null,Object? files = null,}) {
  return _then(StratumFontData(
family: null == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as String,package: freezed == package ? _self.package : package // ignore: cast_nullable_to_non_nullable
as String?,adjustSize: null == adjustSize ? _self.adjustSize : adjustSize // ignore: cast_nullable_to_non_nullable
as StratumDimension,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as StratumFontSource,files: null == files ? _self.files : files // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}



/// @nodoc


class _StratumFontData extends StratumFontData {
  const _StratumFontData({required this.family, this.package, this.adjustSize = const StratumDimension.fixed(0), this.source = StratumFontSource.app,  List<String> files = const <String>[]}): _files = files,super._();
  

/// The family name the font is registered under: as written for
/// [StratumFontSource.app]; `<source theme id>/<family>` for
/// [StratumFontSource.theme], the source theme being the one whose file
/// set [files]; the bare Google Fonts family name (the `Google/` prefix
/// already stripped) for [StratumFontSource.google].
@override final  String family;
/// The package that bundles the font, or null for a font of the app.
/// Always null when [source] is [StratumFontSource.google] or
/// [StratumFontSource.theme].
@override final  String? package;
/// Added to the font size so this font looks as large as the others; a
/// percent resolves against the requested size.
@override@JsonKey() final  StratumDimension adjustSize;
/// Where [family] comes from.
@override@JsonKey() final  StratumFontSource source;
/// The asset path of each font file the theme lists, already joined to
/// the folder of the theme file that set them; empty unless [source] is
/// [StratumFontSource.theme].
 final  List<String> _files;
/// The asset path of each font file the theme lists, already joined to
/// the folder of the theme file that set them; empty unless [source] is
/// [StratumFontSource.theme].
@override@JsonKey() List<String> get files {
  if (_files is EqualUnmodifiableListView) return _files;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_files);
}


/// Create a copy of StratumFontData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StratumFontDataCopyWith<_StratumFontData> get copyWith => __$StratumFontDataCopyWithImpl<_StratumFontData>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StratumFontData&&(identical(other.family, family) || other.family == family)&&(identical(other.package, package) || other.package == package)&&(identical(other.adjustSize, adjustSize) || other.adjustSize == adjustSize)&&(identical(other.source, source) || other.source == source)&&const DeepCollectionEquality().equals(other.files, _files));
}


@override
int get hashCode {
    return Object.hash(runtimeType,family,package,adjustSize,source,const DeepCollectionEquality().hash(_files));
}



}

/// @nodoc
abstract mixin class _$StratumFontDataCopyWith<$Res> implements $StratumFontDataCopyWith<$Res> {
  factory _$StratumFontDataCopyWith(_StratumFontData value, $Res Function(_StratumFontData) _then) = __$StratumFontDataCopyWithImpl;
@override @useResult
$Res call({
 String family, String? package, StratumDimension adjustSize, StratumFontSource source, List<String> files
});




}
/// @nodoc
class __$StratumFontDataCopyWithImpl<$Res>
    implements _$StratumFontDataCopyWith<$Res> {
  __$StratumFontDataCopyWithImpl(this._self, this._then);

  final _StratumFontData _self;
  final $Res Function(_StratumFontData) _then;

/// Create a copy of StratumFontData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? family = null,Object? package = freezed,Object? adjustSize = null,Object? source = null,Object? files = null,}) {
  return _then(_StratumFontData(
family: null == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as String,package: freezed == package ? _self.package : package // ignore: cast_nullable_to_non_nullable
as String?,adjustSize: null == adjustSize ? _self.adjustSize : adjustSize // ignore: cast_nullable_to_non_nullable
as StratumDimension,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as StratumFontSource,files: null == files ? _self._files : files // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
