import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';

part 'generated/modal_layout_style.freezed.dart';

/// One `WidgetStyle` per part of a `ModalLayout`, each merged field by
/// field over the theme defaults (NFR-E02).
///
/// Register one app-wide through `StratumThemeApplication(
/// componentPartDefaults: (theme) => {ModalLayout: ModalLayoutStyle(...)})`;
/// it has value equality, so an equal map from a new builder call rebuilds
/// no modal layout (FO-03 US-06 FR-01).
@freezed
class ModalLayoutStyle with _$ModalLayoutStyle {
  const new({
    this.surface,
    this.top,
    this.tab,
    this.body,
    this.handle,
    this.close,
  });

  /// The card or sheet that holds the slots: fill, shadow, corners, width,
  /// and padding.
  final WidgetStyle? surface;

  /// The box around `ModalLayout.top`.
  final WidgetStyle? top;

  /// The box around `ModalLayout.tab`.
  final WidgetStyle? tab;

  /// The box around `ModalLayout.body`, which scrolls inside it.
  final WidgetStyle? body;

  /// The drag handle pill of a bottom sheet.
  final WidgetStyle? handle;

  /// The box around the close icon.
  final WidgetStyle? close;

  /// Returns a copy where each part merges [other]'s part over this one
  /// through [WidgetStyle.merge].
  ModalLayoutStyle merge(ModalLayoutStyle? other) {
    if (other == null) return this;
    return ModalLayoutStyle(
      surface: _mergePart(surface, other.surface),
      top: _mergePart(top, other.top),
      tab: _mergePart(tab, other.tab),
      body: _mergePart(body, other.body),
      handle: _mergePart(handle, other.handle),
      close: _mergePart(close, other.close),
    );
  }

  static WidgetStyle? _mergePart(WidgetStyle? base, WidgetStyle? other) =>
      base?.merge(other) ?? other;
}
