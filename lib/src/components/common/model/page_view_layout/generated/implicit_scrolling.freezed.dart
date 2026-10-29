// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../implicit_scrolling.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ImplicitScrolling {

/// How far ahead of the viewport the view builds pages; one viewport by
/// default, the extent a `PageView` uses when implicit scrolling is on.
 ScrollCacheExtent get scrollCacheExtent;
/// Create a copy of ImplicitScrolling
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImplicitScrollingCopyWith<ImplicitScrolling> get copyWith => _$ImplicitScrollingCopyWithImpl<ImplicitScrolling>(this as ImplicitScrolling, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ImplicitScrolling;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ImplicitScrolling&&(identical(other.scrollCacheExtent, _this.scrollCacheExtent) || other.scrollCacheExtent == _this.scrollCacheExtent));
}


@override
int get hashCode {
  final _this = this as ImplicitScrolling;
  return Object.hash(runtimeType,_this.scrollCacheExtent);
}

@override
String toString() {
  final _this = this as ImplicitScrolling;
  return 'ImplicitScrolling(scrollCacheExtent: ${_this.scrollCacheExtent})';
}


}

/// @nodoc
abstract mixin class $ImplicitScrollingCopyWith<$Res>  {
  factory $ImplicitScrollingCopyWith(ImplicitScrolling value, $Res Function(ImplicitScrolling) _then) = _$ImplicitScrollingCopyWithImpl;
@useResult
$Res call({
 ScrollCacheExtent scrollCacheExtent
});




}
/// @nodoc
class _$ImplicitScrollingCopyWithImpl<$Res>
    implements $ImplicitScrollingCopyWith<$Res> {
  _$ImplicitScrollingCopyWithImpl(this._self, this._then);

  final ImplicitScrolling _self;
  final $Res Function(ImplicitScrolling) _then;

/// Create a copy of ImplicitScrolling
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? scrollCacheExtent = null,}) {
  return _then(ImplicitScrolling(
scrollCacheExtent: null == scrollCacheExtent ? _self.scrollCacheExtent : scrollCacheExtent // ignore: cast_nullable_to_non_nullable
as ScrollCacheExtent,
  ));
}

}



/// @nodoc


class _ImplicitScrolling implements ImplicitScrolling {
   _ImplicitScrolling({this.scrollCacheExtent = const ScrollCacheExtent.viewport(1.0)}): assert(scrollCacheExtent.value > 0, 'scrollCacheExtent must be above zero: implicit scrolling with no cache extent builds no page ahead');
  

/// How far ahead of the viewport the view builds pages; one viewport by
/// default, the extent a `PageView` uses when implicit scrolling is on.
@override@JsonKey() final  ScrollCacheExtent scrollCacheExtent;

/// Create a copy of ImplicitScrolling
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ImplicitScrollingCopyWith<_ImplicitScrolling> get copyWith => __$ImplicitScrollingCopyWithImpl<_ImplicitScrolling>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ImplicitScrolling&&(identical(other.scrollCacheExtent, scrollCacheExtent) || other.scrollCacheExtent == scrollCacheExtent));
}


@override
int get hashCode {
    return Object.hash(runtimeType,scrollCacheExtent);
}

@override
String toString() {
    return 'ImplicitScrolling(scrollCacheExtent: $scrollCacheExtent)';
}


}

/// @nodoc
abstract mixin class _$ImplicitScrollingCopyWith<$Res> implements $ImplicitScrollingCopyWith<$Res> {
  factory _$ImplicitScrollingCopyWith(_ImplicitScrolling value, $Res Function(_ImplicitScrolling) _then) = __$ImplicitScrollingCopyWithImpl;
@override @useResult
$Res call({
 ScrollCacheExtent scrollCacheExtent
});




}
/// @nodoc
class __$ImplicitScrollingCopyWithImpl<$Res>
    implements _$ImplicitScrollingCopyWith<$Res> {
  __$ImplicitScrollingCopyWithImpl(this._self, this._then);

  final _ImplicitScrolling _self;
  final $Res Function(_ImplicitScrolling) _then;

/// Create a copy of ImplicitScrolling
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? scrollCacheExtent = null,}) {
  return _then(_ImplicitScrolling(
scrollCacheExtent: null == scrollCacheExtent ? _self.scrollCacheExtent : scrollCacheExtent // ignore: cast_nullable_to_non_nullable
as ScrollCacheExtent,
  ));
}


}

// dart format on
