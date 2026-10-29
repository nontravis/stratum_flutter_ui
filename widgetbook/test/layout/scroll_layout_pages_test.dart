import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/components.g.dart';
import 'package:stratum_ui_widgetbook/kit/docs/accessibility_notes_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/figma_link_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/usage_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/story_set.dart';
import 'package:stratum_ui_widgetbook/layout/custom_scroll_view_layout.stories.dart'
    as custom;
import 'package:stratum_ui_widgetbook/layout/grid_view_layout.stories.dart'
    as grid;
import 'package:stratum_ui_widgetbook/layout/list_view_layout.stories.dart'
    as list;
import 'package:stratum_ui_widgetbook/layout/nested_scroll_view_layout.stories.dart'
    as nested;
import 'package:stratum_ui_widgetbook/layout/page_view_layout.stories.dart'
    as page;
import 'package:stratum_ui_widgetbook/layout/recipes.dart';
import 'package:stratum_ui_widgetbook/layout/reorderable_list_view_layout.stories.dart'
    as reorder;
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../support/open_story.dart';

/// The params `ListViewLayout.builder` takes, in constructor order.
const _listKnobs = [
  'style',
  'gap',
  'scrollDirection',
  'reverse',
  'controller',
  'primary',
  'physics',
  'showScrollbar',
  'shrinkWrap',
  'itemExtent',
  'prototypeItem',
  'itemCount',
  'itemBuilder',
  'findChildIndexCallback',
  'addAutomaticKeepAlives',
  'addRepaintBoundaries',
  'addSemanticIndexes',
  'scrollCacheExtent',
  'semanticChildCount',
  'dragStartBehavior',
  'keyboardDismissBehavior',
  'restorationId',
  'clipBehavior',
  'focusable',
  'semanticsLabel',
  'scrollFocusStyle',
];

/// The params `GridViewLayout.builder` takes, in constructor order.
const _gridKnobs = [
  'style',
  'gridDelegate',
  'scrollDirection',
  'reverse',
  'controller',
  'primary',
  'physics',
  'showScrollbar',
  'shrinkWrap',
  'itemCount',
  'itemBuilder',
  'findChildIndexCallback',
  'addAutomaticKeepAlives',
  'addRepaintBoundaries',
  'addSemanticIndexes',
  'scrollCacheExtent',
  'semanticChildCount',
  'dragStartBehavior',
  'keyboardDismissBehavior',
  'restorationId',
  'clipBehavior',
  'focusable',
  'semanticsLabel',
  'scrollFocusStyle',
];

/// The params `CustomScrollViewLayout` takes, in constructor order.
const _customKnobs = [
  'style',
  'slivers',
  'children',
  'controller',
  'scrollDirection',
  'reverse',
  'shrinkWrap',
  'physics',
  'showScrollbar',
  'focusable',
  'semanticsLabel',
  'scrollFocusStyle',
];

/// The params `NestedScrollViewLayout` takes, in constructor order.
const _nestedKnobs = [
  'style',
  'controller',
  'scrollDirection',
  'reverse',
  'physics',
  'showScrollbar',
  'headerSliverBuilder',
  'body',
  'dragStartBehavior',
  'floatHeaderSlivers',
  'clipBehavior',
  'hitTestBehavior',
  'restorationId',
];

/// The params `PageViewLayout.builder` takes, in constructor order.
const _pageKnobs = [
  'style',
  'scrollDirection',
  'reverse',
  'controller',
  'physics',
  'pageSnapping',
  'onPageChanged',
  'itemBuilder',
  'findChildIndexCallback',
  'itemCount',
  'dragStartBehavior',
  'allowImplicitScrolling',
  'scrollCacheExtent',
  'restorationId',
  'clipBehavior',
  'hitTestBehavior',
  'padEnds',
  'showScrollbar',
  'focusable',
  'semanticsLabel',
  'scrollFocusStyle',
];

/// The params `ReorderableListViewLayout.builder` takes, in constructor
/// order.
const _reorderKnobs = [
  'style',
  'scrollDirection',
  'reverse',
  'controller',
  'primary',
  'physics',
  'showScrollbar',
  'shrinkWrap',
  'itemExtent',
  'itemExtentBuilder',
  'prototypeItem',
  'itemCount',
  'itemBuilder',
  'onReorderItem',
  'onReorderStart',
  'onReorderEnd',
  'dragStyle',
  'longPressDrag',
  'itemsController',
  'itemTransitionBuilder',
  'scrollCacheExtent',
  'dragStartBehavior',
  'keyboardDismissBehavior',
  'restorationId',
  'clipBehavior',
  'autoScrollerVelocityScalar',
  'focusable',
  'semanticsLabel',
  'scrollFocusStyle',
  'findChildIndexCallback',
  'moveAnnouncement',
  'atStartAnnouncement',
  'atEndAnnouncement',
];

/// The count every count-knob test sets over the default 3.
const pageCount = 5;

/// One scroll page and what its stories paint.
class _Page {
  const _Page({
    required this.name,
    required this.type,
    required this.component,
    required this.knobs,
    required this.expectedKnobs,
    required this.example,
    required this.slots,
    required this.knobChange,
    required this.expectChanged,
    this.countKnob = 'itemCount',
  });

  /// The page name, equal to the layout class.
  final String name;
  final Type type;
  final Component component;

  /// The Playground's knob names.
  final List<String?> knobs;
  final List<String> expectedKnobs;

  /// The use the page's `Example: ` story shows.
  final String example;

  /// The slot names the Playground paints.
  final List<String> slots;

  /// One layout knob and a value that keeps the slot count.
  final MapEntry<String, String> knobChange;

  /// Expects the built layout to carry the [knobChange] value.
  final void Function(WidgetTester tester) expectChanged;

  /// The knob that sets how many slots the Playground builds, over the
  /// count [pageCount] it then carries.
  final String countKnob;

  String get playground => 'Layout/$name/Playground';

  /// Opens the story at [path] on the desktop window size unless [toolbar]
  /// says otherwise: the test font is wider than the catalog's, so the
  /// layouts overflow the mobile width here and not in the catalog.
  Future<void> open(
    WidgetTester tester,
    String path, {
    Map<String, String> knobs = const {},
    Map<String, Map<String, String>> toolbar = const {},
  }) => openStory<StratumSlot>(
    tester,
    path,
    knobs: knobs,
    toolbar: {
      'viewport': {'name': WindowSize.desktop.name},
      ...toolbar,
    },
  );
}

final _pages = <_Page>[
  _Page(
    name: 'ListViewLayout',
    type: ListViewLayout,
    component: list.ListViewLayoutComponent,
    knobs: [for (final arg in list.$Playground.args.list) arg?.name],
    expectedKnobs: _listKnobs,
    example: 'styled list',
    slots: ['item 1', 'item 2', 'item 3'],
    knobChange: const MapEntry('scrollDirection', 'horizontal'),
    expectChanged: (tester) => expect(
      tester
          .widget<ListViewLayout>(find.byType(ListViewLayout))
          .scrollDirection,
      Axis.horizontal,
    ),
  ),
  _Page(
    name: 'GridViewLayout',
    type: GridViewLayout,
    component: grid.GridViewLayoutComponent,
    knobs: [for (final arg in grid.$Playground.args.list) arg?.name],
    expectedKnobs: _gridKnobs,
    example: 'photo grid',
    slots: ['item 1', 'item 2', 'item 3'],
    knobChange: const MapEntry('gridDelegate', '4 columns'),
    expectChanged: (tester) {
      final delegate = tester
          .widget<GridViewLayout>(find.byType(GridViewLayout))
          .gridDelegate;
      expect(delegate, isA<SliverGridDelegateWithFixedCrossAxisCount>());
      expect(
        (delegate as SliverGridDelegateWithFixedCrossAxisCount).crossAxisCount,
        4,
      );
    },
  ),
  _Page(
    name: 'CustomScrollViewLayout',
    type: CustomScrollViewLayout,
    component: custom.CustomScrollViewLayoutComponent,
    knobs: [for (final arg in custom.$Playground.args.list) arg?.name],
    expectedKnobs: _customKnobs,
    example: 'pinned header list',
    slots: ['child 1', 'child 2', 'child 3'],
    knobChange: const MapEntry('scrollDirection', 'horizontal'),
    expectChanged: (tester) => expect(
      tester
          .widget<CustomScrollViewLayout>(find.byType(CustomScrollViewLayout))
          .scrollDirection,
      Axis.horizontal,
    ),
    countKnob: 'children',
  ),
  _Page(
    name: 'NestedScrollViewLayout',
    type: NestedScrollViewLayout,
    component: nested.NestedScrollViewLayoutComponent,
    knobs: [for (final arg in nested.$Playground.args.list) arg?.name],
    expectedKnobs: _nestedKnobs,
    example: 'collapsing header',
    slots: ['header', 'body'],
    knobChange: const MapEntry('floatHeaderSlivers', 'true'),
    expectChanged: (tester) => expect(
      tester
          .widget<NestedScrollViewLayout>(find.byType(NestedScrollViewLayout))
          .floatHeaderSlivers,
      isTrue,
    ),
    countKnob: '',
  ),
  _Page(
    name: 'PageViewLayout',
    type: PageViewLayout,
    component: page.PageViewLayoutComponent,
    knobs: [for (final arg in page.$Playground.args.list) arg?.name],
    expectedKnobs: _pageKnobs,
    example: 'paged sections',
    slots: ['item 1'],
    knobChange: const MapEntry('scrollDirection', 'vertical'),
    expectChanged: (tester) => expect(
      tester
          .widget<PageViewLayout>(find.byType(PageViewLayout))
          .scrollDirection,
      Axis.vertical,
    ),
  ),
  _Page(
    name: 'ReorderableListViewLayout',
    type: ReorderableListViewLayout,
    component: reorder.ReorderableListViewLayoutComponent,
    knobs: [for (final arg in reorder.$Playground.args.list) arg?.name],
    expectedKnobs: _reorderKnobs,
    example: 'reorderable settings',
    slots: ['item 1', 'item 2', 'item 3'],
    knobChange: const MapEntry('longPressDrag', 'false'),
    expectChanged: (tester) => expect(
      tester
          .widget<ReorderableListViewLayout>(
            find.byType(ReorderableListViewLayout),
          )
          .longPressDrag,
      isFalse,
    ),
  ),
];

/// The slot names painted on screen, pages scrolled out of view included.
Finder _slot(String name) => find.text('❖ $name', skipOffstage: false);

/// The item count the Playground's layout carries, which the count knob
/// sets: the `itemCount` of a builder page, the children the one sliver of
/// a custom view holds, or the pages a page view counts.
int _countOf(WidgetTester tester, _Page page) => switch (page.type) {
  ListViewLayout =>
    tester.widget<ListViewLayout>(find.byType(ListViewLayout)).itemCount!,
  GridViewLayout =>
    tester.widget<GridViewLayout>(find.byType(GridViewLayout)).itemCount!,
  CustomScrollViewLayout =>
    tester
        .widget<CustomScrollViewLayout>(find.byType(CustomScrollViewLayout))
        .children!
        .length,
  PageViewLayout =>
    tester.widget<PageViewLayout>(find.byType(PageViewLayout)).itemCount!,
  ReorderableListViewLayout =>
    tester
        .widget<ReorderableListViewLayout>(
          find.byType(ReorderableListViewLayout),
        )
        .itemCount,
  _ => throw StateError('no count for ${page.type}'),
};

/// Long-presses the slot [name] and drags it down past its neighbors in
/// 10 px steps; the returned gesture is still down.
Future<TestGesture> _liftAndDrag(WidgetTester tester, String name) async {
  final gesture = await tester.startGesture(tester.getCenter(_slot(name)));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  for (var i = 0; i < 15; i++) {
    await gesture.moveBy(const Offset(0, 10));
    await tester.pump(const Duration(milliseconds: 16));
  }
  return gesture;
}

/// The reorder report knobs, all off: a test turns on the one it checks, so
/// the single report line on screen is that callback's.
const _reportsOff = {
  'onReorderItem': 'false',
  'onReorderStart': 'false',
  'onReorderEnd': 'false',
};

/// The knob pair that makes Flutter's `ScrollView` assert: an explicit
/// controller beside `primary` = true.
const _controllerPlusPrimary = {
  'controller': 'Start at item 2',
  'primary': 'true',
};

void main() {
  for (final page in _pages) {
    group(page.name, () {
      test('fo11/us04/fr01: one knob per constructor param', () {
        expect(page.knobs, page.expectedKnobs);
      });

      test('fo11/us03/fr01: the docs follow INV-3 with no Figma node', () {
        final blocks = page.component.docsBuilder!([]);

        expect(blocks.map((b) => b.runtimeType), [
          ComponentNameDocBlock,
          FigmaLinkDocBlock,
          DartCommentDocBlock,
          UsageDocBlock,
          AccessibilityNotesDocBlock,
          ArgsDocBlock,
        ]);
        expect((blocks[1] as FigmaLinkDocBlock).figma, isNull);
      });

      test('fo11/us01/fr02: the page sits under Layout with the layout '
          'story set', () {
        expect(page.component.path, 'Layout');
        expect(components, contains(page.component));
        expect(
          [for (final story in page.component.stories) story.name],
          [
            StoryNames.playground,
            ...StoryNames.recipes,
            StoryNames.responsive,
            StoryNames.accessibility,
            StoryNames.example(page.example),
          ],
        );
        expect(storySetProblems(page.component), isEmpty);
      });

      if (page.name == 'ReorderableListViewLayout') {
        testWidgets('fo11/us03/fr02: a dropped item in the Example stays where '
            'it lands', (tester) async {
          await page.open(
            tester,
            'Layout/${page.name}/${StoryNames.example(page.example)}',
          );
          double top(String name) => tester.getTopLeft(_slot(name)).dy;
          expect(top('item 1'), lessThan(top('item 2')));

          final gesture = await tester.startGesture(
            tester.getCenter(_slot('item 1')),
          );
          await tester.pump(
            kLongPressTimeout + const Duration(milliseconds: 50),
          );
          for (var i = 0; i < 12; i++) {
            await gesture.moveBy(const Offset(0, 12));
            await tester.pump(const Duration(milliseconds: 16));
          }
          await gesture.up();
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(top('item 1'), greaterThan(top('item 2')));
        });
      }

      testWidgets('fo11/us06/fr01, fo11/us06/s1: the Playground children '
          'are named slots', (tester) async {
        await page.open(tester, page.playground);

        expect(find.byType(page.type), findsWidgets);
        for (final name in page.slots) {
          expect(_slot(name), findsOneWidget, reason: name);
        }
      });

      testWidgets('fo11/us06/fr01/e01: a knob change reaches the layout and '
          'keeps the slot names', (tester) async {
        await page.open(
          tester,
          page.playground,
          knobs: {page.knobChange.key: page.knobChange.value},
        );

        expect(tester.takeException(), isNull);
        page.expectChanged(tester);
        for (final name in page.slots) {
          expect(_slot(name), findsOneWidget, reason: name);
        }
      });

      if (page.countKnob.isNotEmpty) {
        testWidgets('fo11/us06/fr01/e01: the count knob arranges the slots '
            'again', (tester) async {
          await page.open(
            tester,
            page.playground,
            knobs: {page.countKnob: '$pageCount'},
          );

          // The count reaches the layout: itemCount (or the children the
          // one sliver holds) equals the knob. A lazy view then builds only
          // the items near the viewport and a page view only the page it
          // shows, so the painted names come by as the view scrolls.
          expect(_countOf(tester, page), pageCount);
        });
      }

      testWidgets('fo11/us06/fr02/e01: a recipe renders again at a new '
          'window size', (tester) async {
        for (final size in [WindowSize.mobile, WindowSize.desktop]) {
          await page.open(
            tester,
            'Layout/${page.name}/Recipe: card',
            toolbar: {
              'viewport': {'name': size.name},
            },
          );

          expect(tester.takeException(), isNull, reason: size.name);
          expect(
            WindowSizeScope.of(tester.element(find.byType(CardRecipe))),
            size,
            reason: 'the window size reaches the recipe',
          );
          for (final name in ['media', 'title', 'body', 'action']) {
            expect(_slot(name), findsOneWidget, reason: '$name at $size');
          }
        }
      });

      testWidgets('fo11/us03/fr02: every ${page.name} story opens without an '
          'error', (tester) async {
        for (final story in page.component.stories) {
          await page.open(tester, 'Layout/${page.name}/${story.name}');
          expect(tester.takeException(), isNull, reason: story.name);
        }
      });

      testWidgets('fo11/us03/fr02: Responsive shows one frame per window '
          'size and Accessibility shows no Disabled frame', (tester) async {
        await page.open(tester, 'Layout/${page.name}/Responsive');
        for (final size in WindowSize.values) {
          expect(find.text(size.name), findsOneWidget, reason: size.name);
        }

        await page.open(tester, 'Layout/${page.name}/Accessibility');
        expect(find.text('200% text'), findsOneWidget);
        expect(find.text('Right to left'), findsOneWidget);
        expect(find.text('Disabled'), findsNothing);
      });
    });
  }

  testWidgets('fo11/us04/fr03/e01: a page change reports onPageChanged '
      'called', (tester) async {
    final page = _pages.firstWhere((page) => page.name == 'PageViewLayout');
    await page.open(tester, page.playground);

    await tester.drag(find.byType(PageViewLayout), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('onPageChanged called'), findsOneWidget);
  });

  group('knob guards and presets', () {
    final list = _pages.firstWhere((page) => page.name == 'ListViewLayout');
    final custom = _pages.firstWhere(
      (page) => page.name == 'CustomScrollViewLayout',
    );
    final reorder = _pages.firstWhere(
      (page) => page.name == 'ReorderableListViewLayout',
    );

    for (final conflict in const [
      MapEntry('itemExtent', '60.0'),
      MapEntry('prototypeItem', 'slot'),
      MapEntry('semanticChildCount', '3'),
    ]) {
      testWidgets('fo11/us06/fr01/e01: gap drops beside ${conflict.key}, so '
          'the layout assert does not fire', (tester) async {
        await list.open(
          tester,
          list.playground,
          knobs: {'gap': '8.0', conflict.key: conflict.value},
        );

        expect(tester.takeException(), isNull);
        expect(
          tester.widget<ListViewLayout>(find.byType(ListViewLayout)).gap,
          isNull,
        );
      });
    }

    testWidgets('fo11/us06/fr01: the Header and slots slivers paint named '
        'slots', (tester) async {
      await custom.open(
        tester,
        custom.playground,
        knobs: {'slivers': 'Header and slots'},
      );

      expect(tester.takeException(), isNull);
      for (final name in ['header', 'body', 'footer']) {
        expect(_slot(name), findsOneWidget, reason: name);
      }
    });

    testWidgets('fo11/us06/fr01/e01: a padded style drops beside slivers, so '
        'the layout assert does not fire', (tester) async {
      await custom.open(
        tester,
        custom.playground,
        knobs: {'slivers': 'Header and slots', 'style': 'Padded'},
      );

      expect(tester.takeException(), isNull);
      expect(_slot('header'), findsOneWidget);
      expect(
        tester
            .widget<CustomScrollViewLayout>(find.byType(CustomScrollViewLayout))
            .style,
        isNull,
      );
    });

    final grid = _pages.firstWhere((page) => page.name == 'GridViewLayout');

    for (final page in [list, grid]) {
      testWidgets('fo11/us04/fr01/e01: ${page.name} drops primary beside an '
          'explicit controller, so the ScrollView assert does not fire', (
        tester,
      ) async {
        await page.open(tester, page.playground, knobs: _controllerPlusPrimary);

        expect(tester.takeException(), isNull);
        expect(_slot('item 1'), findsOneWidget, reason: page.name);
      });
    }

    testWidgets('fo11/us04/fr01/e01: the list drops prototypeItem beside '
        'itemExtent, so the builder assert does not fire', (tester) async {
      await list.open(
        tester,
        list.playground,
        knobs: {'itemExtent': '60.0', 'prototypeItem': 'slot'},
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.widget<ListViewLayout>(find.byType(ListViewLayout)).itemExtent,
        60.0,
      );
    });

    testWidgets('fo11/us04/fr01/e01: the list clamps semanticChildCount to '
        'itemCount, so the builder assert does not fire', (tester) async {
      await list.open(
        tester,
        list.playground,
        knobs: {'itemCount': '3', 'semanticChildCount': '5'},
      );

      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<ListViewLayout>(find.byType(ListViewLayout))
            .semanticChildCount,
        3,
      );
    });

    testWidgets('fo11/us04/fr01/e01: the grid clamps semanticChildCount to '
        'itemCount, so the builder assert does not fire', (tester) async {
      await grid.open(
        tester,
        grid.playground,
        knobs: {'itemCount': '3', 'semanticChildCount': '5'},
      );

      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<GridViewLayout>(find.byType(GridViewLayout))
            .semanticChildCount,
        3,
      );
    });

    for (final case_ in [
      (
        knobs: {'itemExtent': '60.0', 'itemExtentBuilder': 'Fixed 64 px'},
        keepsExtent: true,
        keepsBuilder: false,
      ),
      (
        knobs: {'itemExtent': '60.0', 'prototypeItem': 'slot'},
        keepsExtent: true,
        keepsBuilder: false,
      ),
      (
        knobs: {'itemExtentBuilder': 'Fixed 64 px', 'prototypeItem': 'slot'},
        keepsExtent: false,
        keepsBuilder: true,
      ),
    ]) {
      testWidgets('fo11/us04/fr01/e01: the reorderable list keeps one of '
          'itemExtent, itemExtentBuilder, and prototypeItem '
          '(${case_.knobs.keys.join(' + ')})', (tester) async {
        await reorder.open(tester, reorder.playground, knobs: case_.knobs);

        final layout = tester.widget<ReorderableListViewLayout>(
          find.byType(ReorderableListViewLayout),
        );
        expect(tester.takeException(), isNull);
        expect(_slot('item 1'), findsOneWidget);
        expect(layout.itemExtent, case_.keepsExtent ? 60.0 : null);
        expect(
          layout.itemExtentBuilder,
          case_.keepsBuilder ? isNotNull : isNull,
        );
      });
    }

    for (final name in ['ListViewLayout', 'GridViewLayout', 'PageViewLayout']) {
      testWidgets('fo11/us06/fr01: $name offers a slot builder that counts '
          'from zero', (tester) async {
        final page = _pages.firstWhere((page) => page.name == name);
        await page.open(
          tester,
          page.playground,
          knobs: {'itemBuilder': 'Slot builder from 0'},
        );

        expect(tester.takeException(), isNull);
        expect(_slot('item 0'), findsOneWidget);
      });
    }

    testWidgets('fo11/us06/fr01: the second header preset paints its own '
        'slot', (tester) async {
      final nested = _pages.firstWhere(
        (page) => page.name == 'NestedScrollViewLayout',
      );
      await nested.open(
        tester,
        nested.playground,
        knobs: {'headerSliverBuilder': 'Second slot'},
      );

      expect(tester.takeException(), isNull);
      expect(_slot('second header'), findsOneWidget);
      expect(_slot('header'), findsNothing);
    });

    testWidgets('fo11/us04/fr03/e01: a reorder drop reports onReorderItem '
        'called', (tester) async {
      await reorder.open(
        tester,
        reorder.playground,
        knobs: {..._reportsOff, 'onReorderItem': 'true'},
      );

      final gesture = await _liftAndDrag(tester, 'item 1');
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('onReorderItem called'), findsOneWidget);
    });

    testWidgets('fo11/us04/fr03/e01: a reorder lift reports onReorderStart '
        'called', (tester) async {
      await reorder.open(
        tester,
        reorder.playground,
        knobs: {..._reportsOff, 'onReorderStart': 'true'},
      );

      final gesture = await _liftAndDrag(tester, 'item 1');

      expect(tester.takeException(), isNull);
      expect(find.text('onReorderStart called'), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('fo11/us04/fr03/e01: a reorder drop reports onReorderEnd '
        'called', (tester) async {
      await reorder.open(
        tester,
        reorder.playground,
        knobs: {..._reportsOff, 'onReorderEnd': 'true'},
      );

      final gesture = await _liftAndDrag(tester, 'item 1');
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('onReorderEnd called'), findsOneWidget);
    });
  });
}
