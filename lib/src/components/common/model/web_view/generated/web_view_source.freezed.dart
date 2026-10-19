// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../web_view_source.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StratumWebViewSource {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumWebViewSource);
}


@override
int get hashCode => runtimeType.hashCode;



}

/// @nodoc
class $StratumWebViewSourceCopyWith<$Res>  {
$StratumWebViewSourceCopyWith(StratumWebViewSource _, $Res Function(StratumWebViewSource) __);
}



/// @nodoc


class StratumWebViewUrlSource extends StratumWebViewSource {
  const StratumWebViewUrlSource(this.url): super._();
  

/// Address of the page.
 final  Uri url;

/// Create a copy of StratumWebViewSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumWebViewUrlSourceCopyWith<StratumWebViewUrlSource> get copyWith => _$StratumWebViewUrlSourceCopyWithImpl<StratumWebViewUrlSource>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumWebViewUrlSource&&(identical(other.url, url) || other.url == url));
}


@override
int get hashCode {
    return Object.hash(runtimeType,url);
}



}

/// @nodoc
abstract mixin class $StratumWebViewUrlSourceCopyWith<$Res> implements $StratumWebViewSourceCopyWith<$Res> {
  factory $StratumWebViewUrlSourceCopyWith(StratumWebViewUrlSource value, $Res Function(StratumWebViewUrlSource) _then) = _$StratumWebViewUrlSourceCopyWithImpl;
@useResult
$Res call({
 Uri url
});




}
/// @nodoc
class _$StratumWebViewUrlSourceCopyWithImpl<$Res>
    implements $StratumWebViewUrlSourceCopyWith<$Res> {
  _$StratumWebViewUrlSourceCopyWithImpl(this._self, this._then);

  final StratumWebViewUrlSource _self;
  final $Res Function(StratumWebViewUrlSource) _then;

/// Create a copy of StratumWebViewSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? url = null,}) {
  return _then(StratumWebViewUrlSource(
null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as Uri,
  ));
}


}

/// @nodoc


class StratumWebViewHtmlSource extends StratumWebViewSource {
  const StratumWebViewHtmlSource(this.html): super._();
  

/// The HTML document.
 final  String html;

/// Create a copy of StratumWebViewSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StratumWebViewHtmlSourceCopyWith<StratumWebViewHtmlSource> get copyWith => _$StratumWebViewHtmlSourceCopyWithImpl<StratumWebViewHtmlSource>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is StratumWebViewHtmlSource&&(identical(other.html, html) || other.html == html));
}


@override
int get hashCode {
    return Object.hash(runtimeType,html);
}



}

/// @nodoc
abstract mixin class $StratumWebViewHtmlSourceCopyWith<$Res> implements $StratumWebViewSourceCopyWith<$Res> {
  factory $StratumWebViewHtmlSourceCopyWith(StratumWebViewHtmlSource value, $Res Function(StratumWebViewHtmlSource) _then) = _$StratumWebViewHtmlSourceCopyWithImpl;
@useResult
$Res call({
 String html
});




}
/// @nodoc
class _$StratumWebViewHtmlSourceCopyWithImpl<$Res>
    implements $StratumWebViewHtmlSourceCopyWith<$Res> {
  _$StratumWebViewHtmlSourceCopyWithImpl(this._self, this._then);

  final StratumWebViewHtmlSource _self;
  final $Res Function(StratumWebViewHtmlSource) _then;

/// Create a copy of StratumWebViewSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? html = null,}) {
  return _then(StratumWebViewHtmlSource(
null == html ? _self.html : html // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
