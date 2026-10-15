import 'dart:ui' show SemanticsRole;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/focus_group.freezed.dart';

/// Makes the focusable children of a `ColumnLayout`, `RowLayout`, or
/// `WrapLayout` one roving Tab stop (K3).
///
/// * Tab enters the group once and lands on the item that last held focus,
///   or on the first item; Tab and Shift+Tab then leave it (WCAG 2.1.2).
///   From a node inside an item, such as an item of a focusable scroller,
///   they first move among that item and the nodes inside it.
/// * Arrows along the layout axis move to the next item on screen in the
///   pressed direction: Left and Right in a row, Up and Down in a column,
///   also under right-to-left text and `VerticalDirection.up`. In a wrap,
///   Left and Right move in reading order, and Up and Down move to the
///   nearest item of the adjacent run.
/// * Arrows across the axis keep Flutter's default.
/// * Home and End move to the first and last item in reading order.
/// * With [loop], moving past either end wraps around, including a wrap's
///   Up and Down past its first or last run. Without it, an arrow past
///   either end is swallowed when another item in the group still lies in
///   that direction on screen, so focus does not bounce to it; otherwise
///   it keeps Flutter's default: directional focus on desktop, scrolling
///   on web.
///
/// The group binds its own keys, so they work the same on web, and skips
/// them while focus is inside a text field. It covers built children only;
/// a lazy list uses Tab and its own keyboard scrolling instead.
@valueModel
abstract class FocusGroup with _$FocusGroup {
  const factory({
    /// The semantics role of the group node.
    ///
    /// Flutter's debug checks constrain the items, which take their role
    /// through their own `semantics:` (`SemanticsProperties(role: ...)`):
    /// `tabBar` needs at least one item and every item with role `tab`;
    /// `menu` and `menuBar` need at least one item, and a `menuItem` must sit
    /// under one of them; `radioGroup` allows at most one checked item;
    /// `list` has no check. Set `menu`, `menuBar`, or `tabBar` only when
    /// items exist.
    SemanticsRole? role,

    /// Whether arrows wrap from the last item to the first and back.
    @Default(false) bool loop,
  }) = _FocusGroup;
}
