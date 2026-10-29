import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/implicit_scrolling.freezed.dart';

/// Turns on implicit scrolling for a page view layout: the view builds the
/// pages inside [scrollCacheExtent] ahead, so a screen reader moves page by
/// page and Tab reaches the neighbor pages.
///
/// A page view layout with a null `implicitScrolling` builds no neighbor
/// page ahead, as a layout with a null `Scroll` does not scroll.
///
/// Not a `const` constructor: the assertion reads the extent's `value`,
/// which a constant expression cannot.
@valueModel
abstract class ImplicitScrolling with _$ImplicitScrolling {
  @Assert(
    'scrollCacheExtent.value > 0',
    'scrollCacheExtent must be above zero: implicit scrolling with no '
        'cache extent builds no page ahead',
  )
  factory({
    /// How far ahead of the viewport the view builds pages; one viewport by
    /// default, the extent a `PageView` uses when implicit scrolling is on.
    @Default(ScrollCacheExtent.viewport(1.0))
    ScrollCacheExtent scrollCacheExtent,
  }) = _ImplicitScrolling;
}
