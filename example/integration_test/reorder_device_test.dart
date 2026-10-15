// FO-06 US-11 (design D16, D5, R47, R48, R49; s03 invariants 21, 24, 27, 35,
// 58). Runs in roadmap phase stratum-device-round, never in a feature
// session:
//
//   flutter test integration_test/reorder_device_test.dart -d <device>
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/reorder_device_test.dart \
//     -d web-server --browser-name=chrome
//
// Chrome needs both renderers checked explicitly, --web-renderer=canvaskit
// and --web-renderer=skwasm, since device-test.toml's chrome target names
// only the browser.
//
// The round also checks by eye, on iOS, Android, macOS, Chrome (CanvasKit
// and skwasm), and Linux: the still raster under the pointer shows at the
// lifted item's size and may lag one frame at the lift
// (`tmp/reorder-scope-freeze/probe-identity.findings.md:177-183`), and a
// running spinner or caret visibly freezes inside it, which the device
// round's own eye, not this file's asserts, must judge (design D16).
// In profile mode with VoiceOver (iOS) and TalkBack (Android) reading
// live, the round checks that the far move and the fading remove below
// speak or present each item once at its true place after the motion,
// with no duplicate, stale, or missing announcement
// (`memory/project_stratum_ui_component_batch.md:93`); that is a live
// transcript this file's semantics-tree asserts cannot reach.
import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/stratum_ui.dart';

/// A plain, [height]-tall item named [id], for the list's other slots.
Widget _plainItem(int id, double height) =>
    SizedBox(key: ValueKey(id), height: height, child: Text('item $id'));

/// The lifted item for group A: a drag handle, a running spinner, and a
/// focused text field, so its raster carries both a still spinner and a
/// still caret (US-11 FR-01 E14, design D5, D16).
Widget _liftedItem() => SizedBox(
  key: const ValueKey('lifted'),
  height: 56,
  child: Row(
    children: [
      ReorderableDragStartListener(
        index: 1,
        child: const SizedBox(
          key: ValueKey('handle'),
          width: 24,
          height: 56,
          child: ColoredBox(color: Color(0xFF9E9E9E)),
        ),
      ),
      const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      const SizedBox(width: 8),
      const Expanded(child: TextField(autofocus: true)),
    ],
  ),
);

/// A 220x320 reorderable list of 5 items, item 1 [_liftedItem], under a
/// [Material] ancestor the app supplies, never the lifted item's own.
///
/// Text scale pinned to 1.0 so a non-default OS/CI setting cannot overflow
/// the fixed-height rows for a reason unrelated to the feature under test.
Widget _groupAApp() => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
    child: child!,
  ),
  home: Material(
    child: Center(
      child: SizedBox(
        width: 220,
        height: 320,
        child: ReorderableListViewLayout.builder(
          itemCount: 5,
          longPressDrag: false,
          onReorderItem: (from, to) {},
          itemBuilder: (context, index) =>
              index == 1 ? _liftedItem() : _plainItem(index, 56),
        ),
      ),
    ),
  ),
);

/// Group B's list: 60 items of uneven heights, item 0 holding a nested
/// horizontal [ListView] one child wide (R1's base case: a
/// `RenderViewportBase` sets its own semantics boundary), its inner
/// control focused by [nestedNode]; [controller] drives a far [moveFar]
/// and a fading [removeFading] (US-11 FR-04 E02, FR-05 E04).
class _FarMoveList extends StatefulWidget {
  const _FarMoveList({required this.controller, required this.nestedNode});

  final ReorderableItemsController controller;
  final FocusNode nestedNode;

  @override
  State<_FarMoveList> createState() => _FarMoveListState();
}

class _FarMoveListState extends State<_FarMoveList> {
  final ids = List<int>.generate(60, (i) => i);

  /// Moves the id at [from] to [to], far enough past the laid-out and
  /// cached range that the move's frame cannot lay its new slot out, so
  /// the item parks with its State and focus (s03 invariant 35, R49).
  void moveFar(int from, int to) {
    setState(() => ids.insert(to, ids.removeAt(from)));
    widget.controller.moveItem(from, to);
  }

  /// Removes the id at [index]; the app's [FadeTransition] below fades it
  /// through 0 as it leaves (US-11 FR-04 E02).
  void removeFading(int index) {
    setState(() => ids.removeAt(index));
    widget.controller.removeItem(index);
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListViewLayout.builder(
      itemCount: ids.length,
      itemsController: widget.controller,
      onReorderItem: (from, to) {},
      itemTransitionBuilder: (context, animation, child) =>
          FadeTransition(opacity: animation, child: child),
      itemBuilder: (context, index) {
        final id = ids[index];
        final height = 40.0 + (id % 3) * 24;
        if (id != 0) {
          return SizedBox(
            key: ValueKey(id),
            height: height,
            child: Text('item $id'),
          );
        }
        return SizedBox(
          key: const ValueKey(0),
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Focus(
                focusNode: widget.nestedNode,
                child: const SizedBox(
                  width: 160,
                  height: 40,
                  child: Text('item 0'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Text scale pinned to 1.0, as [_groupAApp], for the same overflow reason.
Widget _groupBApp(
  ReorderableItemsController controller,
  FocusNode nestedNode,
) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
    child: child!,
  ),
  home: Material(
    child: Center(
      child: SizedBox(
        width: 220,
        height: 320,
        child: _FarMoveList(controller: controller, nestedNode: nestedNode),
      ),
    ),
  ),
);

/// Whether a live semantics node reads [label], walked from the root: a
/// node `ExcludeSemantics` just took out of the tree can still answer
/// `find.bySemanticsLabel` through its render object's stale
/// `debugSemantics`, so a leaving item's absence is checked by a live
/// walk instead (US-11 FR-04 E05).
bool _liveLabel(WidgetTester tester, String label) {
  var found = false;
  bool visit(SemanticsNode node) {
    if (node.label == label) found = true;
    node.visitChildren(visit);
    return true;
  }

  visit(
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return found;
}

/// The item id in [node]'s own text label, found by walking its
/// descendants; null when none carries one (not a data item's node).
int? _idInLabel(SemanticsNode node) {
  final match = RegExp(r'item (\d+)').firstMatch(node.label);
  if (match != null) return int.parse(match.group(1)!);
  int? found;
  node.visitChildren((child) {
    found = _idInLabel(child);
    return found == null;
  });
  return found;
}

/// Whether [actual] matches [expected] within [epsilon] logical pixels, so
/// a renderer's own device-pixel-ratio rounding (CanvasKit vs skwasm)
/// never fails a feature assertion for an environment reason.
void _expectCloseSize(Size actual, Size expected, [double epsilon = 0.5]) {
  expect(actual.width, closeTo(expected.width, epsilon));
  expect(actual.height, closeTo(expected.height, epsilon));
}

/// As [_expectCloseSize], for an [Offset].
void _expectCloseOffset(
  Offset actual,
  Offset expected, [
  double epsilon = 0.5,
]) {
  expect(actual.dx, closeTo(expected.dx, epsilon));
  expect(actual.dy, closeTo(expected.dy, epsilon));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'us11/fr01/e14, d5, d16: lifting an item with a running spinner and a '
    'focused caret freezes a still raster at the item size and place, with '
    'its screen-reader node kept at its slot',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_groupAApp());
        await tester.pump();

        // Autofocus resolves on a post-frame callback; prove the field
        // already holds focus before the drag starts (FR-01 E14). The
        // `isFocused` flag sits on `EditableText`'s own render object, one
        // level inside `TextField`, which `getSemantics`'s parent-only walk
        // from `find.byType(TextField)` would never reach.
        expect(
          tester
              .getSemantics(find.byType(EditableText))
              .flagsCollection
              .isFocused,
          Tristate.isTrue,
        );

        // Item 0's list has no nested scrollable, but filter the same way
        // group B must, so a future nested scrollable here fails with a
        // clear `expect`, never a bare `StateError`.
        final scrollNode = find.semantics
            .byFlag(SemanticsFlag.hasImplicitScrolling)
            .evaluate()
            .where(
              (node) =>
                  node.scrollChildCount != null && node.scrollChildCount! > 1,
            )
            .single;
        final slot = tester.getRect(find.byKey(const ValueKey('lifted')));

        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('handle'))),
        );
        await tester.pump();
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump();
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump();

        final rawImage = find.byType(RawImage);
        expect(rawImage, findsOne);
        final image = tester.widget<RawImage>(rawImage).image;
        expect(image, isNotNull);
        _expectCloseSize(tester.getSize(rawImage), slot.size);

        // The raster stays the same frame while the spinner's own animation
        // keeps ticking: the proxy is a still snapshot, not a rebuild (D5).
        var framesChecked = 0;
        for (var i = 0; i < 4; i++) {
          await gesture.moveBy(const Offset(0, 5));
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.widget<RawImage>(rawImage).image, same(image));
          framesChecked += 1;
        }

        const totalDrag = Offset(0, 20 + 10 + 5 * 4);
        _expectCloseOffset(
          tester.getTopLeft(rawImage),
          slot.topLeft + totalDrag,
        );

        // The field keeps focus through the drag too, not only before it.
        expect(
          tester
              .getSemantics(find.byType(EditableText))
              .flagsCollection
              .isFocused,
          Tristate.isTrue,
        );

        // The item's own screen-reader node stays in the list at its slot
        // for the whole drag (D5): it never moves into the overlay.
        final node = tester.getSemantics(find.byKey(const ValueKey('lifted')));
        var inList = false;
        for (var up = node.parent; up != null; up = up.parent) {
          if (identical(up, scrollNode)) inList = true;
        }
        expect(inList, isTrue);
        expect(tester.getRect(find.byKey(const ValueKey('lifted'))), slot);

        binding.reportData = {
          'rasterWidth': slot.size.width,
          'rasterHeight': slot.size.height,
          'framesChecked': framesChecked,
        };

        await gesture.up();
        // The running spinner keeps scheduling frames forever, so the drop
        // settles over a few fixed pumps, never `pumpAndSettle`.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        // No app Material of its own reaches the raster: nothing rebuilds
        // the lifted item's text field into the overlay, so a missing
        // ancestor Material asserts nothing either (FR-01 E14).
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets(
    'us11/fr05/e04, fr04/e02, s03/inv21, inv24, inv27, inv35, inv58 (R47, '
    'R48, D11 L6 closed): a far move that parks a focused item holding a '
    'nested list, then a remove under a fading itemTransitionBuilder, land '
    'the accessibility tree with no assertion',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final controller = ReorderableItemsController();
        final nestedNode = FocusNode(debugLabel: 'nested 0');
        addTearDown(nestedNode.dispose);

        await tester.pumpWidget(_groupBApp(controller, nestedNode));
        await tester.pump();
        nestedNode.requestFocus();
        await tester.pump();

        // Item 0's own nested horizontal ListView also carries
        // `hasImplicitScrolling`, with one child: the outer list is the
        // one with many.
        SemanticsNode scrollNode() => find.semantics
            .byFlag(SemanticsFlag.hasImplicitScrolling)
            .evaluate()
            .where(
              (node) =>
                  node.scrollChildCount != null && node.scrollChildCount! > 1,
            )
            .single;
        expect(scrollNode().scrollChildCount, 60);

        final state = tester.state<_FarMoveListState>(
          find.byType(_FarMoveList),
        );

        // Item 0's new slot, 50, sits well past the laid-out and cached
        // range of a 320 px list: the move's frame cannot build it, so the
        // item parks with its State and focus, with no debug assertion
        // (s03 invariant 35, D11's L6 closed).
        state.moveFar(0, 50);
        await tester.pump();
        expect(tester.takeException(), isNull);

        // A caller FadeTransition fades a leaving item through 0, around
        // item 0's own nested semantics boundary parked above it; with
        // semantics on this raises no debug assertion (s03 invariant 24,
        // FR-04 E02). `moveFar`'s own reach already shifted ids and
        // scrolled the list, so the removed id is looked up by its own
        // current index, never assumed, or the removal and the checks
        // below could land on two different items. Id 52 sits well inside
        // the range the reach left on screen (id0's own park target, 50,
        // plus margin on both sides), so the checks below run on a node
        // that is actually live beforehand — proving something, instead
        // of an item already absent for an unrelated, scroll-driven
        // reason.
        const removeId = 52;
        expect(_liveLabel(tester, 'item $removeId'), isTrue);

        final removeIndex = state.ids.indexOf(removeId);
        state.removeFading(removeIndex);
        await tester.pump();
        expect(tester.takeException(), isNull);
        // The data model itself dropped the named id, scroll-independent
        // of whether that id's own slot is currently built (findings
        // correctness report, line 306/312).
        expect(state.ids.contains(removeId), isFalse);

        // The leaving item has no screen-reader node from the frame its
        // exit starts (s03 invariant 27, FR-04 E05), even while its own
        // widget is still built and mid-fade (the `FadeTransition` caller
        // wraps it until opacity reaches 0).
        // The one `FadeTransition` mid-fade (every other built item sits
        // at rest, opacity 1): its own look (the removed id's `Text`) is
        // still built, proving the item leaves the semantics tree below
        // while its widget has not finished leaving the render tree.
        final fade = tester
            .widgetList<FadeTransition>(find.byType(FadeTransition))
            .singleWhere((f) => f.opacity.value < 1.0);
        expect(fade.opacity.value, inExclusiveRange(0, 1));
        expect(_liveLabel(tester, 'item $removeId'), isFalse);

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final ids = state.ids;
        expect(ids.length, 59);
        final scroll = scrollNode();
        expect(scroll.scrollChildCount, ids.length);

        // The far move keeps the parked item's State and focus at every
        // distance, 50 slots being past the 4-frame reach budget
        // (`_reachFrames`) that a nearer move would clear, even though the
        // reach's own jump estimate can still scroll the list while it
        // tries (s03 invariant 35, FR-05 E04).
        expect(nestedNode.hasFocus, isTrue);

        // Every item the viewport still built carries its own data index,
        // once each, with none left null or repeated, and that index is
        // its own item id's actual place in the data, never merely a
        // unique slot a shuffle could still pass (s03 invariant 58):
        // checked on the scroll node's direct children, since each data
        // item's own `isSemanticBoundary` attaches there, one level up from
        // a leaving item, which carries no index at all.
        final builtIndices = <int>[];
        scroll.visitChildren((child) {
          final index = child.indexInParent;
          if (index == null) return true;
          builtIndices.add(index);
          final id = _idInLabel(child);
          if (id != null) expect(index, ids.indexOf(id), reason: 'item $id');
          return true;
        });
        expect(builtIndices, isNotEmpty);
        expect(builtIndices.toSet().length, builtIndices.length);
      } finally {
        handle.dispose();
      }
    },
  );
}
