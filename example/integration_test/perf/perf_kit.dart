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

  /// A reorderable list of [itemCount] items [itemBuilder] builds, each
  /// keyed by the builder, that applies no move.
  Widget reorderList({
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
  });
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

  @override
  Widget reorderList({
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
  }) {
    return ReorderableListViewLayout.builder(
      itemCount: itemCount,
      onReorderItem: (from, to) {},
      itemBuilder: itemBuilder,
    );
  }
}

/// The layouts of the frozen baseline (spec section 9.3).
///
/// The baseline is the commit the branch under test starts from, which
/// each frozen file's header names: a tappable row is a
/// `BaselineRowLayout` on `BaselineFlexLayout` with its
/// `BaselineStratumInkWell` tap surface and the shared `Interaction`, and
/// the reorder list throws until a freeze adds
/// `BaselineReorderableListViewLayout` (R59, R64).
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

  @override
  Widget reorderList({
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
  }) => throw StateError(
    'S7 has no frozen baseline: freeze the reorder layout with '
    'tool/perf_freeze.dart first (R59, R64)',
  );
}
