// ignore_for_file: implementation_imports
import 'package:stratum_ui/src/src.dart';

import '../baseline/baseline.dart';

/// The layouts one side of the comparison draws with (spec section 9.2).
///
/// Scenes reach layouts only through a kit, so moving to a new layout API
/// changes the kits and leaves the scenes as they are.
abstract interface class PerfKit {
  /// A row; a non-null [onTap] makes it a tap surface with the theme's
  /// `fast` level style animation.
  Widget row({
    WidgetStyle? style,
    VoidCallback? onTap,
    required MainAxisAlignment mainAxisAlignment,
    required List<Widget> children,
  });

  /// A column without style. A true [crossAxisIntrinsic] sizes the column
  /// to its widest child.
  Widget column({
    required MainAxisSize mainAxisSize,
    required CrossAxisAlignment crossAxisAlignment,
    bool crossAxisIntrinsic = false,
    required List<Widget> children,
  });

  /// A box with [style] around [child].
  Widget container({WidgetStyle? style, Widget? child});
}

/// The layouts of the code under test.
class CurrentKit implements PerfKit {
  const new();

  @override
  Widget row({
    WidgetStyle? style,
    VoidCallback? onTap,
    required MainAxisAlignment mainAxisAlignment,
    required List<Widget> children,
  }) {
    return RowLayout(
      style: style,
      interaction: onTap == null ? null : Interaction(onTap: onTap),
      mainAxisAlignment: mainAxisAlignment,
      children: children,
    );
  }

  @override
  Widget column({
    required MainAxisSize mainAxisSize,
    required CrossAxisAlignment crossAxisAlignment,
    bool crossAxisIntrinsic = false,
    required List<Widget> children,
  }) {
    return ColumnLayout(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      crossAxisIntrinsic: crossAxisIntrinsic,
      children: children,
    );
  }

  @override
  Widget container({WidgetStyle? style, Widget? child}) {
    return ContainerLayout(style: style, child: child);
  }
}

/// The layouts of the frozen baseline (spec section 9.3).
///
/// The baseline is the pre-batch commit `7a50510`; the comparison covers
/// the perf batch, InkWell `280d77c`, BoxLayout R4 `8a0d26d`, and the
/// item-root fixes up to this HEAD. A tappable row is a `BaselineRowLayout`
/// on `BaselineFlexLayout`, whose tap surface is `BaselineStratumInkWell`
/// with the live `StratumFocusBorder` ring, and the shared `Interaction`.
class BaselineKit implements PerfKit {
  const new();

  @override
  Widget row({
    WidgetStyle? style,
    VoidCallback? onTap,
    required MainAxisAlignment mainAxisAlignment,
    required List<Widget> children,
  }) {
    return BaselineRowLayout(
      style: style,
      interaction: onTap == null ? null : Interaction(onTap: onTap),
      mainAxisAlignment: mainAxisAlignment,
      children: children,
    );
  }

  @override
  Widget column({
    required MainAxisSize mainAxisSize,
    required CrossAxisAlignment crossAxisAlignment,
    bool crossAxisIntrinsic = false,
    required List<Widget> children,
  }) {
    return BaselineColumnLayout(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      crossAxisIntrinsic: crossAxisIntrinsic,
      children: children,
    );
  }

  @override
  Widget container({WidgetStyle? style, Widget? child}) {
    return BaselineContainerLayout(style: style, child: child);
  }
}
