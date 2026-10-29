import 'package:stratum_ui/stratum_ui.dart';

/// [count] slot placeholders named `child 1` to `child $count`, the children
/// a layout page's stories arrange (fo11/us06/fr01); a [height] gives each a
/// fixed height, for a page that must overflow to scroll.
List<Widget> slotChildren(int count, {double? height}) => [
  for (var i = 1; i <= count; i++)
    StratumSlot(name: 'child $i', height: height),
];
