import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/page_areas.freezed.dart';

/// The page areas a notice places itself against, in global coordinates
/// (s03 toast INV-16).
@valueModel
class PageAreas with _$PageAreas {
  const new({this.body, this.footerTop, this.bottomTop, this.left, this.snack});

  /// The body slot's global rect.
  final Rect? body;

  /// The footer slot's global top; null with no footer.
  final double? footerTop;

  /// The bottom slot's global top; null with no bottom.
  final double? bottomTop;

  /// The inline `left` pane's global rect; null below the drawer cut.
  final Rect? left;

  /// The page's resolved `PageLayoutStyle.snack`.
  final WidgetStyle? snack;
}
