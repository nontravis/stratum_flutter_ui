// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../scroll.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Scroll {

/// The scroll axis; null keeps the layout's own axis: vertical, or
/// horizontal for a row, or across `direction` for a wrap.
 Axis? get direction;/// Stretches content shorter than the viewport to the viewport, minus
/// the padding, so `spaceBetween` and `end` alignments work.
///
/// A stretching layout builds a [LayoutBuilder], which is not supported
/// under [IntrinsicWidth], [IntrinsicHeight], `AlertDialog` content, or a
/// parent's `crossAxisIntrinsic`. Only a finite viewport stretches: in a
/// parent unbounded along the scroll axis the layout sizes to its
/// content. Flipping this value between builds resets the scroll offset.
 bool get fillViewport; bool get reverse; ScrollController? get controller; bool? get primary;/// Applies on top of the theme's physics.
 ScrollPhysics? get physics;/// Null keeps the scroll behavior's choice: a scrollbar on desktop.
 bool? get showScrollbar; ScrollViewKeyboardDismissBehavior? get keyboardDismissBehavior; String? get restorationId;/// A scrolling box's focus ring style, level 3, beside the box layout's
/// `style`, which draws the box; the box hands it to its `ScrollFocus`
/// as `customStyle` (FO-06 US-07 FR-03).
 ScrollFocusStyle? get scrollFocusStyle;
/// Create a copy of Scroll
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScrollCopyWith<Scroll> get copyWith => _$ScrollCopyWithImpl<Scroll>(this as Scroll, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Scroll;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Scroll&&(identical(other.direction, _this.direction) || other.direction == _this.direction)&&(identical(other.fillViewport, _this.fillViewport) || other.fillViewport == _this.fillViewport)&&(identical(other.reverse, _this.reverse) || other.reverse == _this.reverse)&&(identical(other.controller, _this.controller) || other.controller == _this.controller)&&(identical(other.primary, _this.primary) || other.primary == _this.primary)&&(identical(other.physics, _this.physics) || other.physics == _this.physics)&&(identical(other.showScrollbar, _this.showScrollbar) || other.showScrollbar == _this.showScrollbar)&&(identical(other.keyboardDismissBehavior, _this.keyboardDismissBehavior) || other.keyboardDismissBehavior == _this.keyboardDismissBehavior)&&(identical(other.restorationId, _this.restorationId) || other.restorationId == _this.restorationId)&&(identical(other.scrollFocusStyle, _this.scrollFocusStyle) || other.scrollFocusStyle == _this.scrollFocusStyle));
}


@override
int get hashCode {
  final _this = this as Scroll;
  return Object.hash(runtimeType,_this.direction,_this.fillViewport,_this.reverse,_this.controller,_this.primary,_this.physics,_this.showScrollbar,_this.keyboardDismissBehavior,_this.restorationId,_this.scrollFocusStyle);
}

@override
String toString() {
  final _this = this as Scroll;
  return 'Scroll(direction: ${_this.direction}, fillViewport: ${_this.fillViewport}, reverse: ${_this.reverse}, controller: ${_this.controller}, primary: ${_this.primary}, physics: ${_this.physics}, showScrollbar: ${_this.showScrollbar}, keyboardDismissBehavior: ${_this.keyboardDismissBehavior}, restorationId: ${_this.restorationId}, scrollFocusStyle: ${_this.scrollFocusStyle})';
}


}

/// @nodoc
abstract mixin class $ScrollCopyWith<$Res>  {
  factory $ScrollCopyWith(Scroll value, $Res Function(Scroll) _then) = _$ScrollCopyWithImpl;
@useResult
$Res call({
 Axis? direction, bool fillViewport, bool reverse, ScrollController? controller, bool? primary, ScrollPhysics? physics, bool? showScrollbar, ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior, String? restorationId, ScrollFocusStyle? scrollFocusStyle
});


$ScrollFocusStyleCopyWith<$Res>? get scrollFocusStyle;

}
/// @nodoc
class _$ScrollCopyWithImpl<$Res>
    implements $ScrollCopyWith<$Res> {
  _$ScrollCopyWithImpl(this._self, this._then);

  final Scroll _self;
  final $Res Function(Scroll) _then;

/// Create a copy of Scroll
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? direction = freezed,Object? fillViewport = null,Object? reverse = null,Object? controller = freezed,Object? primary = freezed,Object? physics = freezed,Object? showScrollbar = freezed,Object? keyboardDismissBehavior = freezed,Object? restorationId = freezed,Object? scrollFocusStyle = freezed,}) {
  return _then(Scroll(
direction: freezed == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as Axis?,fillViewport: null == fillViewport ? _self.fillViewport : fillViewport // ignore: cast_nullable_to_non_nullable
as bool,reverse: null == reverse ? _self.reverse : reverse // ignore: cast_nullable_to_non_nullable
as bool,controller: freezed == controller ? _self.controller : controller // ignore: cast_nullable_to_non_nullable
as ScrollController?,primary: freezed == primary ? _self.primary : primary // ignore: cast_nullable_to_non_nullable
as bool?,physics: freezed == physics ? _self.physics : physics // ignore: cast_nullable_to_non_nullable
as ScrollPhysics?,showScrollbar: freezed == showScrollbar ? _self.showScrollbar : showScrollbar // ignore: cast_nullable_to_non_nullable
as bool?,keyboardDismissBehavior: freezed == keyboardDismissBehavior ? _self.keyboardDismissBehavior : keyboardDismissBehavior // ignore: cast_nullable_to_non_nullable
as ScrollViewKeyboardDismissBehavior?,restorationId: freezed == restorationId ? _self.restorationId : restorationId // ignore: cast_nullable_to_non_nullable
as String?,scrollFocusStyle: freezed == scrollFocusStyle ? _self.scrollFocusStyle : scrollFocusStyle // ignore: cast_nullable_to_non_nullable
as ScrollFocusStyle?,
  ));
}
/// Create a copy of Scroll
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScrollFocusStyleCopyWith<$Res>? get scrollFocusStyle {
    if (_self.scrollFocusStyle == null) {
    return null;
  }

  return $ScrollFocusStyleCopyWith<$Res>(_self.scrollFocusStyle!, (value) {
    return _then(_self.copyWith(scrollFocusStyle: value));
  });
}
}



/// @nodoc


class _Scroll implements Scroll {
  const _Scroll({this.direction, this.fillViewport = false, this.reverse = false, this.controller, this.primary, this.physics, this.showScrollbar, this.keyboardDismissBehavior, this.restorationId, this.scrollFocusStyle}): assert(!(controller != null && (primary ?? false)), 'A primary scroll view takes its controller from the PrimaryScrollController; pass controller or primary: true, not both');
  

/// The scroll axis; null keeps the layout's own axis: vertical, or
/// horizontal for a row, or across `direction` for a wrap.
@override final  Axis? direction;
/// Stretches content shorter than the viewport to the viewport, minus
/// the padding, so `spaceBetween` and `end` alignments work.
///
/// A stretching layout builds a [LayoutBuilder], which is not supported
/// under [IntrinsicWidth], [IntrinsicHeight], `AlertDialog` content, or a
/// parent's `crossAxisIntrinsic`. Only a finite viewport stretches: in a
/// parent unbounded along the scroll axis the layout sizes to its
/// content. Flipping this value between builds resets the scroll offset.
@override@JsonKey() final  bool fillViewport;
@override@JsonKey() final  bool reverse;
@override final  ScrollController? controller;
@override final  bool? primary;
/// Applies on top of the theme's physics.
@override final  ScrollPhysics? physics;
/// Null keeps the scroll behavior's choice: a scrollbar on desktop.
@override final  bool? showScrollbar;
@override final  ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;
@override final  String? restorationId;
/// A scrolling box's focus ring style, level 3, beside the box layout's
/// `style`, which draws the box; the box hands it to its `ScrollFocus`
/// as `customStyle` (FO-06 US-07 FR-03).
@override final  ScrollFocusStyle? scrollFocusStyle;

/// Create a copy of Scroll
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScrollCopyWith<_Scroll> get copyWith => __$ScrollCopyWithImpl<_Scroll>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Scroll&&(identical(other.direction, direction) || other.direction == direction)&&(identical(other.fillViewport, fillViewport) || other.fillViewport == fillViewport)&&(identical(other.reverse, reverse) || other.reverse == reverse)&&(identical(other.controller, controller) || other.controller == controller)&&(identical(other.primary, primary) || other.primary == primary)&&(identical(other.physics, physics) || other.physics == physics)&&(identical(other.showScrollbar, showScrollbar) || other.showScrollbar == showScrollbar)&&(identical(other.keyboardDismissBehavior, keyboardDismissBehavior) || other.keyboardDismissBehavior == keyboardDismissBehavior)&&(identical(other.restorationId, restorationId) || other.restorationId == restorationId)&&(identical(other.scrollFocusStyle, scrollFocusStyle) || other.scrollFocusStyle == scrollFocusStyle));
}


@override
int get hashCode {
    return Object.hash(runtimeType,direction,fillViewport,reverse,controller,primary,physics,showScrollbar,keyboardDismissBehavior,restorationId,scrollFocusStyle);
}

@override
String toString() {
    return 'Scroll(direction: $direction, fillViewport: $fillViewport, reverse: $reverse, controller: $controller, primary: $primary, physics: $physics, showScrollbar: $showScrollbar, keyboardDismissBehavior: $keyboardDismissBehavior, restorationId: $restorationId, scrollFocusStyle: $scrollFocusStyle)';
}


}

/// @nodoc
abstract mixin class _$ScrollCopyWith<$Res> implements $ScrollCopyWith<$Res> {
  factory _$ScrollCopyWith(_Scroll value, $Res Function(_Scroll) _then) = __$ScrollCopyWithImpl;
@override @useResult
$Res call({
 Axis? direction, bool fillViewport, bool reverse, ScrollController? controller, bool? primary, ScrollPhysics? physics, bool? showScrollbar, ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior, String? restorationId, ScrollFocusStyle? scrollFocusStyle
});


@override $ScrollFocusStyleCopyWith<$Res>? get scrollFocusStyle;

}
/// @nodoc
class __$ScrollCopyWithImpl<$Res>
    implements _$ScrollCopyWith<$Res> {
  __$ScrollCopyWithImpl(this._self, this._then);

  final _Scroll _self;
  final $Res Function(_Scroll) _then;

/// Create a copy of Scroll
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? direction = freezed,Object? fillViewport = null,Object? reverse = null,Object? controller = freezed,Object? primary = freezed,Object? physics = freezed,Object? showScrollbar = freezed,Object? keyboardDismissBehavior = freezed,Object? restorationId = freezed,Object? scrollFocusStyle = freezed,}) {
  return _then(_Scroll(
direction: freezed == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as Axis?,fillViewport: null == fillViewport ? _self.fillViewport : fillViewport // ignore: cast_nullable_to_non_nullable
as bool,reverse: null == reverse ? _self.reverse : reverse // ignore: cast_nullable_to_non_nullable
as bool,controller: freezed == controller ? _self.controller : controller // ignore: cast_nullable_to_non_nullable
as ScrollController?,primary: freezed == primary ? _self.primary : primary // ignore: cast_nullable_to_non_nullable
as bool?,physics: freezed == physics ? _self.physics : physics // ignore: cast_nullable_to_non_nullable
as ScrollPhysics?,showScrollbar: freezed == showScrollbar ? _self.showScrollbar : showScrollbar // ignore: cast_nullable_to_non_nullable
as bool?,keyboardDismissBehavior: freezed == keyboardDismissBehavior ? _self.keyboardDismissBehavior : keyboardDismissBehavior // ignore: cast_nullable_to_non_nullable
as ScrollViewKeyboardDismissBehavior?,restorationId: freezed == restorationId ? _self.restorationId : restorationId // ignore: cast_nullable_to_non_nullable
as String?,scrollFocusStyle: freezed == scrollFocusStyle ? _self.scrollFocusStyle : scrollFocusStyle // ignore: cast_nullable_to_non_nullable
as ScrollFocusStyle?,
  ));
}

/// Create a copy of Scroll
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScrollFocusStyleCopyWith<$Res>? get scrollFocusStyle {
    if (_self.scrollFocusStyle == null) {
    return null;
  }

  return $ScrollFocusStyleCopyWith<$Res>(_self.scrollFocusStyle!, (value) {
    return _then(_self.copyWith(scrollFocusStyle: value));
  });
}
}

// dart format on
