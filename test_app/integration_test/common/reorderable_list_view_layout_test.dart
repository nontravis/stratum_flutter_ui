// Proves, in code, on every target, the reorder live-region leaf queued
// from the reorder a11y gate round (master 69019c8; INV-60 and INV-58 of
// docs/specs/stratum_ui/components/common/layout/reorderable_list_view_layout/
// s03_domain.md):
//
// - a screen-reader move announces within the leaf's 4 s hold
//   (`_liveHold`), gone right after (INV-60; FR-06 E06:
//   `functional_requirements/fr06_screen_reader_hears_size_and_moves.md:37`);
// - the leaf sits beside the scroll view's own item-count node, which still
//   reports the right count while the leaf shows (INV-58;
//   `_ReorderScrollView.semanticChildCount`,
//   `reorderable_list_view_layout.dart:3403`) — the node a screen reader's
//   own "showing items" collection readout reads; that readout's wording
//   and timing are not in any spec line found, so this file does not test
//   invented text for it, only the count node's presence and value;
// - a second announcement never reuses the first node, so the first
//   utterance is never cut off mid-read, only superseded by a fresh one
//   (`reorderable_list_view_layout.dart:3336`, `key: ValueKey(_liveCount)`;
//   FR-06 E06);
// - the leaf is 1x1 logical px, so touch exploration never lands on it
//   (INV-60, "1×1 px live-region leaf";
//   `reorderable_list_view_layout.dart:3328-3330`).
//
// This file forces `supportsAnnounce: false` (every target this ran on so
// far reports it true by default, which takes the direct-announcement
// path instead and never builds the leaf), so the live-region leaf is the
// one path proven here on every target, even where the platform would
// otherwise skip it.
//
// Code cannot judge: whether TalkBack or VoiceOver actually speaks the
// text, and which path a target picks on its own (`supportsAnnounce`'s
// real value). A person listens for those on check 1 of the screen
// reader checks page, `lib/screen_reader_demo.dart` (F-01 US-13).
//
// Also beyond code, and beyond check 1's own steps: whether a fresh node
// truly reads clean with no audible overlap on the platform's own speech
// engine, and the real wording of a platform's built-in "showing items"
// collection announcement. A person judges both only in this device
// round, by ear.
//
// The raster test below proves FO-06 US-11 FR-01 E14 (design D5, D16): the
// still raster under the pointer keeps the lifted item's size and place
// while a spinner and a caret run inside it. Chrome needs both renderers
// checked explicitly, `--web-renderer=canvaskit` and `--web-renderer=skwasm`.
// A person judges by eye whether the frozen spinner and caret look right.
//
//   flutter test integration_test/common/reorderable_list_view_layout_test.dart -d <device>
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/common/reorderable_list_view_layout_test.dart \
//     -d web-server --browser-name=chrome
import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/stratum_ui.dart';

/// A reorderable list of five 40 px items, keyed by their stable id, that
/// applies every move it reports to its own `ids`.
class _ReorderDemo extends StatefulWidget {
  const _ReorderDemo();

  @override
  State<_ReorderDemo> createState() => _ReorderDemoState();
}

class _ReorderDemoState extends State<_ReorderDemo> {
  final ids = [0, 1, 2, 3, 4];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 120,
      child: ReorderableListViewLayout.builder(
        itemCount: ids.length,
        itemExtent: 40,
        moveAnnouncement: (position, count) => 'moved $position of $count',
        onReorderItem: (from, to) {
          setState(() => ids.insert(to, ids.removeAt(from)));
        },
        itemBuilder: (context, index) =>
            SizedBox(key: ValueKey(ids[index]), height: 40, width: 200),
      ),
    );
  }
}

/// The `MaterialApp` the demo list builds in, over [controller]'s theme,
/// with `supportsAnnounce` forced false so the move goes through the
/// live-region leaf this file proves, on every target, not through a
/// direct platform announcement a target may offer instead.
Widget _app(StratumThemeController controller) => MaterialApp(
  builder: (context, child) => StratumThemeApplication.controlled(
    controller: controller,
    themeMode: ThemeMode.light,
    child: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(supportsAnnounce: false),
        child: child!,
      ),
    ),
  ),
  home: const Material(child: _ReorderDemo()),
);

/// Performs the move action labeled [label] on the item whose stable id is
/// [id], as a screen reader's own move gesture does, then settles the
/// frame the move lands in and the frame after it, where the list
/// announces the move.
Future<void> _moveAction(WidgetTester tester, int id, String label) async {
  final node = tester.getSemantics(find.byKey(ValueKey(id)));
  node.owner!.performAction(
    node.id,
    SemanticsAction.customAction,
    CustomSemanticsAction.getIdentifier(CustomSemanticsAction(label: label)),
  );
  await tester.pumpAndSettle();
}

/// The live-region leaf's own node, the one `label` reads.
SemanticsNode _leaf(String label) =>
    find.semantics.byLabel(label).evaluate().single;

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
      // Opts out of the platform's own outside-tap unfocus: on desktop and
      // web, any pointer down outside a focused `TextField`'s tap region
      // unfocuses it by default (editable_text.dart:6881-6904), which is
      // the SDK's rule, not Stratum's, and is not what group A checks.
      Expanded(child: TextField(autofocus: true, onTapOutside: (_) {})),
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

  testWidgets('s03/inv60 and fo06/us11/fr06/e01: a screen-reader move announces through a 1x1 '
      'live-region leaf beside the item-count node', (tester) async {
    final handle = tester.ensureSemantics();
    final controller = await StratumThemeController.preload();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));

    final countNode = find.semantics
        .byFlag(SemanticsFlag.hasImplicitScrolling)
        .evaluate()
        .single;
    expect(
      countNode.scrollChildCount,
      5,
      reason:
          'INV-58: semanticChildCount '
          'stays the data count, the node a screen reader reads as its '
          'own "showing items" collection readout',
    );

    await _moveAction(tester, 0, 'Move down');

    const firstText = 'moved 2 of 5';
    final first = _leaf(firstText);
    expect(
      first,
      isSemantics(isLiveRegion: true),
      reason:
          'INV-60: the move speaks '
          'through a live-region leaf when the platform does not take a '
          'direct announcement',
    );

    final rect = tester.getRect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
    );
    expect(
      rect.size,
      const Size(1, 1),
      reason:
          'INV-60: "1×1 px live-region leaf"; '
          'reorderable_list_view_layout.dart:3328-3330: a larger node '
          'can take touch exploration over the items',
    );

    // The count node still reports the right count while the leaf
    // shows: the leaf sits beside it, never in place of it
    // (INV-58, INV-60).
    expect(
      find.semantics
          .byFlag(SemanticsFlag.hasImplicitScrolling)
          .evaluate()
          .single
          .scrollChildCount,
      5,
    );

    await _moveAction(tester, 0, 'Move down');

    const secondText = 'moved 3 of 5';
    final second = _leaf(secondText);
    expect(
      second,
      isSemantics(isLiveRegion: true),
      reason:
          'fr06_screen_reader_hears_size_and_moves.md:37 (E06): a '
          'later swipe never reads a stale move',
    );
    expect(
      second.id,
      isNot(first.id),
      reason:
          'reorderable_list_view_layout.dart:3336: each announcement '
          'keys a fresh Semantics node (`ValueKey(_liveCount)`), so the '
          'first utterance is superseded by a new node, never cut off by '
          'a change to the one it was reading',
    );
    expect(
      find.semantics.byLabel(firstText),
      findsNothing,
      reason:
          'the first announcement leaves the tree once a later one '
          'replaces it',
    );

    await tester.pump(const Duration(seconds: 3));
    expect(
      find.semantics.byLabel(secondText),
      findsOne,
      reason:
          'INV-60: "the leaf leaves the tree 4 s after '
          'its last announcement"; at 3 s it still holds',
    );

    await tester.pump(const Duration(seconds: 2));
    expect(
      find.semantics.byLabel(secondText),
      findsNothing,
      reason: 'INV-60: gone once the 4 s hold passes',
    );
    expect(tester.takeException(), isNull);

    handle.dispose();
  });

  testWidgets(
    'fo06/us11/fr01/e14, d5, d16: lifting an item with a running spinner and a '
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

        // The fixture opted out of the platform's own outside-tap unfocus
        // above, so this now proves only what Stratum owns: the lift,
        // raster, and overlay take no focus from a field inside the item
        // across the drag (FR-03 `:12`, D5), not the platform's separate
        // desktop tap-outside rule.
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
}
