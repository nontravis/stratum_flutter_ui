import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/page_layout_style.freezed.dart';

/// One `WidgetStyle` per slot of a `PageLayout`, plus [outer], the page's
/// own box, each merged field by field over the theme defaults (US-18
/// FR-03; NFR-E02).
///
/// Register one app-wide through `StratumThemeApplication(
/// componentPartDefaults: (theme) => {PageLayout: PageLayoutStyle(...)})`;
/// it has value equality, so an equal map from a new builder call rebuilds
/// no page layout (FO-03 US-06 FR-01).
@valueModel
class PageLayoutStyle with _$PageLayoutStyle {
  const new({
    this.outer,
    this.header,
    this.top,
    this.tab,
    this.left,
    this.body,
    this.right,
    this.bottom,
    this.footer,
    this.snack,
  });

  /// The page's own box, behind every slot.
  final WidgetStyle? outer;

  /// The box around `PageLayout.header`.
  final WidgetStyle? header;

  /// The box around `PageLayout.top`.
  final WidgetStyle? top;

  /// The box around `PageLayout.tab`.
  final WidgetStyle? tab;

  /// The box around `PageLayout.left`.
  final WidgetStyle? left;

  /// The box around `PageLayout.body`.
  final WidgetStyle? body;

  /// The box around `PageLayout.right`.
  final WidgetStyle? right;

  /// The box around `PageLayout.bottom`.
  final WidgetStyle? bottom;

  /// The box around `PageLayout.footer`.
  final WidgetStyle? footer;

  /// The box around `PageLayout.snack`.
  final WidgetStyle? snack;

  /// Returns a copy where each part merges [other]'s part over this one
  /// through [WidgetStyle.merge].
  PageLayoutStyle merge(PageLayoutStyle? other) {
    if (other == null) return this;
    return PageLayoutStyle(
      outer: _mergePart(outer, other.outer),
      header: _mergePart(header, other.header),
      top: _mergePart(top, other.top),
      tab: _mergePart(tab, other.tab),
      left: _mergePart(left, other.left),
      body: _mergePart(body, other.body),
      right: _mergePart(right, other.right),
      bottom: _mergePart(bottom, other.bottom),
      footer: _mergePart(footer, other.footer),
      snack: _mergePart(snack, other.snack),
    );
  }

  static WidgetStyle? _mergePart(WidgetStyle? base, WidgetStyle? other) =>
      base?.merge(other) ?? other;
}
