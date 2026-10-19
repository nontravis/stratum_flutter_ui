// Proves, in code, on every target, the reorder live-region leaf queued
// from the reorder a11y gate round (master 69019c8;
// docs/specs/stratum_ui/components/common/layout/s03_domain.md invariant
// 60, lines 185-191; invariant 58, lines 177-178):
//
// - a screen-reader move announces within the leaf's 4 s hold
//   (`_liveHold`), gone right after (s03_domain.md:189; FR-06 E06:
//   `functional_requirements/fr06_screen_reader_hears_size_and_moves.md:37`);
// - the leaf sits beside the scroll view's own item-count node, which still
//   reports the right count while the leaf shows (invariant 58,
//   s03_domain.md:177-178; `_ReorderScrollView.semanticChildCount`,
//   `reorderable_list_view_layout.dart:3403`) — the node a screen reader's
//   own "showing items" collection readout reads; that readout's wording
//   and timing are not in any spec line found, so this file does not test
//   invented text for it, only the count node's presence and value;
// - a second announcement never reuses the first node, so the first
//   utterance is never cut off mid-read, only superseded by a fresh one
//   (`reorderable_list_view_layout.dart:3336`, `key: ValueKey(_liveCount)`;
//   FR-06 E06);
// - the leaf is 1x1 logical px, so touch exploration never lands on it
//   (s03_domain.md:187, "1×1 px live-region leaf";
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
//   flutter test integration_test/reorder_a11y_device_test.dart -d <device>
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/reorder_a11y_device_test.dart \
//     -d web-server --browser-name=chrome
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    's03/inv60 and fr06/e01: a screen-reader move announces through a 1x1 '
    'live-region leaf beside the item-count node',
    (tester) async {
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
            's03_domain.md:177-178 (invariant 58): semanticChildCount '
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
            's03_domain.md:185-191 (invariant 60): the move speaks '
            'through a live-region leaf when the platform does not take a '
            'direct announcement',
      );

      final rect = tester.getRect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
      );
      expect(
        rect.size,
        const Size(1, 1),
        reason:
            's03_domain.md:187: "1×1 px live-region leaf"; '
            'reorderable_list_view_layout.dart:3328-3330: a larger node '
            'can take touch exploration over the items',
      );

      // The count node still reports the right count while the leaf
      // shows: the leaf sits beside it, never in place of it
      // (s03_domain.md:177-178, :185-188).
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
            's03_domain.md:189: "the leaf leaves the tree 4 s after '
            'its last announcement"; at 3 s it still holds',
      );

      await tester.pump(const Duration(seconds: 2));
      expect(
        find.semantics.byLabel(secondText),
        findsNothing,
        reason: 's03_domain.md:189: gone once the 4 s hold passes',
      );
      expect(tester.takeException(), isNull);

      handle.dispose();
    },
  );
}
