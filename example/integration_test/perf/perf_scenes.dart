// ignore_for_file: implementation_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../widgets/animating_boxes.dart';
import '../widgets/glass_cards.dart';
import 'perf_host.dart';
import 'perf_kit.dart';
import 'perf_scene.dart';

const _rowCount = 1000;

/// S1-fast's scroll distance per traced second half: more than one new
/// row per frame at 144 Hz (111 px per frame).
const _fastDistance = 16000.0;

const _cardStyle = WidgetStyle(
  padding: EdgeInsets.all(12),
  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  backgroundColor: Color(0xFFFFFFFF),
  borderRadius: BorderRadius.all(Radius.circular(12)),
  dropShadow: [
    BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2)),
  ],
  innerShadow: [BoxShadow(color: Color(0x11000000), blurRadius: 4)],
);

List<Widget> _rowChildren(PerfKit kit, int index) {
  return [
    kit.column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text('Item $index'), const Text('Subtitle')],
    ),
    kit.column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [Text('${index * 3}'), const Text('units')],
    ),
  ];
}

/// S1's two columns as plain Flutter [Column]s, so a row's box is the only
/// layout box in S2-box and S2-plain.
List<Widget> _plainChildren(int index) {
  return [
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text('Item $index'), const Text('Subtitle')],
    ),
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [Text('${index * 3}'), const Text('units')],
    ),
  ];
}

/// S1: a row of two columns with text, no style.
Widget _row(PerfKit kit, int index) {
  return kit.row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: _rowChildren(kit, index),
  );
}

/// S2: S1 with fill, radius, drop shadow, and inner shadow.
Widget _styledRow(PerfKit kit, int index) {
  return kit.row(
    style: _cardStyle,
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: _rowChildren(kit, index),
  );
}

/// S2-box: S2's styled row around plain columns.
Widget _boxRow(PerfKit kit, int index) {
  return kit.row(
    style: _cardStyle,
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: _plainChildren(index),
  );
}

/// S3: S2 with a tap callback and the 100 ms default style animation.
Widget _tappableRow(PerfKit kit, int index) {
  return kit.row(
    style: _cardStyle,
    onTap: () {},
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: _rowChildren(kit, index),
  );
}

/// S2-plain: the S2-box row drawn without [AnimatedStyledBox] and without
/// a kit, so both sides run the same code (the null control).
///
/// The same margin, decoration, padding, and children as S2-box.
/// `_cardStyle` sets no size and no `clipBehavior`, so S2-box builds no
/// `RenderConstrainedBox` and no `RenderClipRRect`; S2-plain builds both as
/// pass-through render objects.
Widget _plainRow(int index) {
  return Padding(
    padding: _cardStyle.margin!,
    child: ConstrainedBox(
      constraints: const BoxConstraints(),
      child: DecoratedBox(
        decoration: StyleDecoration(
          color: _cardStyle.backgroundColor,
          borderRadius: _cardStyle.borderRadius,
          dropShadow: _cardStyle.dropShadow,
          innerShadow: _cardStyle.innerShadow,
        ),
        child: ClipRRect(
          borderRadius: _cardStyle.borderRadius!,
          clipBehavior: Clip.none,
          child: Padding(
            padding: _cardStyle.padding!,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _plainChildren(index),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _list(Widget Function(int index) row) {
  return ListView.builder(
    itemCount: _rowCount,
    itemBuilder: (context, index) => row(index),
  );
}

/// The position of the first [Scrollable].
ScrollPosition _position(WidgetTester tester) {
  return tester.state<ScrollableState>(find.byType(Scrollable).first).position;
}

/// Scrolls one traced window down [distance] and back.
Future<void> Function(WidgetTester tester) _scroll({
  double distance = 4000,
}) {
  return (tester) => scrollFor(tester, traceWindow, distance: distance);
}

/// Every scene of spec section 9.1, in table order.
final perfScenes = <PerfScene>[
  PerfScene(
    'S1',
    build: (kit) => _list((index) => _row(kit, index)),
    drive: _scroll(),
  ),
  PerfScene(
    'S1-fast',
    build: (kit) => _list((index) => _row(kit, index)),
    drive: _scroll(distance: _fastDistance),
    check: (tester, kit) async {
      // The list holds rows only, so its extent divided by the row count
      // is the row height.
      final position = _position(tester);
      final rowHeight =
          (position.maxScrollExtent + position.viewportDimension) / _rowCount;
      expect(rowHeight, lessThan(_fastDistance / 144));
    },
  ),
  PerfScene(
    'S2',
    build: (kit) => _list((index) => _styledRow(kit, index)),
    drive: _scroll(),
  ),
  PerfScene(
    'S2-box',
    build: (kit) => _list((index) => _boxRow(kit, index)),
    drive: _scroll(),
  ),
  PerfScene(
    'S2-plain',
    build: (_) => _list(_plainRow),
    drive: _scroll(),
    check: (tester, _) async {
      // Equal row heights give equal list extents, so S2-plain scrolls the
      // same rows as S2-box. The current kit draws S2-box on both sides, so
      // the null control's two sides do identical work before every trace
      // (spec section 9.4).
      final plainExtent = _position(tester).maxScrollExtent;
      await tester.pumpWidget(
        perfHost(_list((index) => _boxRow(const CurrentKit(), index))),
      );
      final boxExtent = _position(tester).maxScrollExtent;
      await tester.pumpWidget(perfHost(_list(_plainRow)));
      expect(plainExtent, closeTo(boxExtent, 0.5));
    },
  ),
  PerfScene(
    'S3',
    build: (kit) => _list((index) => _tappableRow(kit, index)),
    drive: _scroll(),
  ),
  PerfScene(
    'S4',
    build: (kit) => AnimatingBoxes(kit: kit),
    drive: (tester) => tester.pump(traceWindow),
  ),
  PerfScene(
    'S5',
    build: (kit) => GlassCards(kit: kit),
    drive: _scroll(distance: 2000),
  ),
];

/// The scene named [key].
PerfScene perfScene(String key) {
  return perfScenes.singleWhere((scene) => scene.key == key);
}

/// Scene groups, one per invocation (spec section 9.4). Each group starts
/// with the S2-plain null control and stays within 16 traces, because the
/// binding sends every timeline to the driver in one message.
///
/// `tool/perf_abba.dart` lists the same keys in its `groups`.
const perfGroups = <int, List<String>>{
  1: ['S2-plain', 'S1', 'S1-fast', 'S2'],
  2: ['S2-plain', 'S2-box', 'S3'],
  3: ['S2-plain', 'S4', 'S5'],
};

/// The scenes of [group], in run order.
List<PerfScene> perfGroup(int group) {
  final keys = perfGroups[group];
  if (keys == null) {
    throw ArgumentError.value(group, 'group', 'no such scene group');
  }
  return [for (final key in keys) perfScene(key)];
}
