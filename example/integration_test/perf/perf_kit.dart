// ignore_for_file: implementation_imports
import 'package:stratum_ui/src/src.dart';

/// The layouts one side of the comparison draws with (spec section 9.2).
///
/// Scenes reach layouts only through a kit, so moving to a new layout API
/// changes the kits and leaves the scenes as they are.
abstract interface class PerfKit {
  /// A row; a non-null [onTap] makes it a tap surface with the default
  /// 100 ms style animation.
  Widget row({
    WidgetStyle? style,
    VoidCallback? onTap,
    required MainAxisAlignment mainAxisAlignment,
    required List<Widget> children,
  });

  /// A column without style.
  Widget column({
    required MainAxisSize mainAxisSize,
    required CrossAxisAlignment crossAxisAlignment,
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
      interaction: onTap == null ? null : StratumInteraction(onTap: onTap),
      mainAxisAlignment: mainAxisAlignment,
      children: children,
    );
  }

  @override
  Widget column({
    required MainAxisSize mainAxisSize,
    required CrossAxisAlignment crossAxisAlignment,
    required List<Widget> children,
  }) {
    return ColumnLayout(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );
  }

  @override
  Widget container({WidgetStyle? style, Widget? child}) {
    return ContainerLayout(style: style, child: child);
  }
}
