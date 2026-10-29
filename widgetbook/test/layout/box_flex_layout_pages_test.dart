import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/components.g.dart';
import 'package:stratum_ui_widgetbook/kit/docs/accessibility_notes_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/figma_link_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/usage_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/story_set.dart';
import 'package:stratum_ui_widgetbook/layout/column_layout.stories.dart'
    as column;
import 'package:stratum_ui_widgetbook/layout/container_layout.stories.dart'
    as container;
import 'package:stratum_ui_widgetbook/layout/flex_layout.stories.dart' as flex;
import 'package:stratum_ui_widgetbook/layout/indexed_stack_layout.stories.dart'
    as indexed;
import 'package:stratum_ui_widgetbook/layout/recipes.dart';
import 'package:stratum_ui_widgetbook/layout/row_layout.stories.dart' as row;
import 'package:stratum_ui_widgetbook/layout/split_layout.stories.dart'
    as split;
import 'package:stratum_ui_widgetbook/layout/stack_layout.stories.dart'
    as stack;
import 'package:stratum_ui_widgetbook/layout/wrap_layout.stories.dart' as wrap;
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../support/open_story.dart';

/// The params every `BoxLayout` takes, in constructor order.
const _boxKnobs = [
  'style',
  'ratio',
  'rotate',
  'transform',
  'transformAlignment',
  'keepAlive',
  'repaintBoundary',
  'semantics',
  'onEndAnimate',
  'interaction',
  'scroll',
];

/// The params `FlexLayout` takes after `direction`, in constructor order.
const _flexKnobs = [
  'mainAxisAlignment',
  'mainAxisSize',
  'crossAxisAlignment',
  'textDirection',
  'verticalDirection',
  'textBaseline',
  'crossAxisIntrinsic',
  'gap',
  'focusGroup',
  'children',
];

/// One layout page and what its stories paint.
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
    this.countKnob = 'children',
    this.count = 5,
    this.hidesSlots = false,
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

  /// The knob that sets how many slots the Playground arranges, and a count
  /// it accepts that differs from the default.
  final String countKnob;
  final int count;

  /// Whether the layout paints one child only (an indexed stack).
  final bool hidesSlots;

  String get playground => 'Layout/$name/Playground';

  /// Opens the story at [path] on the desktop window size unless [toolbar]
  /// says otherwise: the test font is wider than the catalog's, so the row
  /// layouts overflow the mobile width here and not in the catalog.
  Future<void> open(
    WidgetTester tester,
    String path, {
    Map<String, String> knobs = const {},
    Map<String, String> toolbar = const {},
  }) => openStory<StratumSlot>(
    tester,
    path,
    knobs: knobs,
    toolbar: {'viewport': WindowSize.desktop.name, ...toolbar},
  );
}

final _pages = <_Page>[
  _Page(
    name: 'ContainerLayout',
    type: ContainerLayout,
    component: container.ContainerLayoutComponent,
    knobs: [for (final arg in container.$Playground.args.list) arg?.name],
    expectedKnobs: [..._boxKnobs, 'fit', 'child', 'builder'],
    example: 'fitted media',
    slots: ['content'],
    knobChange: const MapEntry('rotate', '10.0'),
    countKnob: '',
  ),
  _Page(
    name: 'ColumnLayout',
    type: ColumnLayout,
    component: column.ColumnLayoutComponent,
    knobs: [for (final arg in column.$Playground.args.list) arg?.name],
    expectedKnobs: [..._boxKnobs, ..._flexKnobs],
    example: 'styled column',
    slots: ['child 1', 'child 2', 'child 3'],
    knobChange: const MapEntry('gap', '24.0'),
  ),
  _Page(
    name: 'RowLayout',
    type: RowLayout,
    component: row.RowLayoutComponent,
    knobs: [for (final arg in row.$Playground.args.list) arg?.name],
    expectedKnobs: [..._boxKnobs, ..._flexKnobs],
    example: 'plain row',
    slots: ['child 1', 'child 2', 'child 3'],
    knobChange: const MapEntry('gap', '24.0'),
  ),
  _Page(
    name: 'FlexLayout',
    type: FlexLayout,
    component: flex.FlexLayoutComponent,
    knobs: [for (final arg in flex.$Playground.args.list) arg?.name],
    expectedKnobs: [..._boxKnobs, 'direction', ..._flexKnobs],
    example: 'direction by window size',
    slots: ['child 1', 'child 2', 'child 3'],
    knobChange: const MapEntry('direction', 'horizontal'),
  ),
  _Page(
    name: 'StackLayout',
    type: StackLayout,
    component: stack.StackLayoutComponent,
    knobs: [for (final arg in stack.$Playground.args.list) arg?.name],
    expectedKnobs: [
      ..._boxKnobs,
      'alignment',
      'fit',
      'textDirection',
      'clipBehavior',
      'children',
    ],
    example: 'badge over avatar',
    slots: ['child 1', 'child 2', 'child 3'],
    knobChange: const MapEntry('alignment', 'center'),
  ),
  _Page(
    name: 'WrapLayout',
    type: WrapLayout,
    component: wrap.WrapLayoutComponent,
    knobs: [for (final arg in wrap.$Playground.args.list) arg?.name],
    expectedKnobs: [
      ..._boxKnobs,
      'direction',
      'alignment',
      'gap',
      'runGap',
      'runAlignment',
      'crossAxisAlignment',
      'textDirection',
      'verticalDirection',
      'clipBehavior',
      'focusGroup',
      'maxRuns',
      'maxChildren',
      'overflowBuilder',
      'children',
    ],
    example: 'tags cut to two runs',
    slots: ['child 1', 'child 2', 'child 3'],
    knobChange: const MapEntry('direction', 'vertical'),
  ),
  _Page(
    name: 'SplitLayout',
    type: SplitLayout,
    component: split.SplitLayoutComponent,
    knobs: [for (final arg in split.$Playground.args.list) arg?.name],
    expectedKnobs: [
      'panes',
      'axis',
      'resizable',
      'controller',
      'dividerLabel',
      'dividerBuilder',
      'customStyle',
      'setting',
    ],
    example: 'list beside detail',
    slots: ['child 1', 'child 2'],
    knobChange: const MapEntry('resizable', 'false'),
    countKnob: 'panes',
    count: 4,
  ),
  _Page(
    name: 'IndexedStackLayout',
    type: IndexedStackLayout,
    component: indexed.IndexedStackLayoutComponent,
    knobs: [for (final arg in indexed.$Playground.args.list) arg?.name],
    expectedKnobs: [
      ..._boxKnobs,
      'index',
      'alignment',
      'sizing',
      'textDirection',
      'clipBehavior',
      'children',
    ],
    example: 'switch stacked views',
    slots: ['child 1', 'child 2', 'child 3'],
    knobChange: const MapEntry('alignment', 'center'),
    hidesSlots: true,
  ),
];

/// The slot names painted on screen, hidden children of an indexed stack
/// included.
Finder _slot(String name) => find.text('❖ $name', skipOffstage: false);

/// Every slot placeholder painted on screen.
Finder get _anySlot => find.textContaining('❖', skipOffstage: false);

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

      testWidgets('fo11/us06/fr01, fo11/us06/s1: the Playground children '
          'are named slots', (tester) async {
        await page.open(tester, page.playground);

        expect(find.byType(page.type), findsWidgets);
        for (final name in page.slots) {
          expect(_slot(name), findsOneWidget, reason: name);
        }
        expect(_anySlot, findsNWidgets(page.slots.length));
      });

      testWidgets('fo11/us06/fr01/e01: a knob change keeps the slot names', (
        tester,
      ) async {
        await page.open(
          tester,
          page.playground,
          knobs: {page.knobChange.key: page.knobChange.value},
        );

        expect(tester.takeException(), isNull);
        for (final name in page.slots) {
          expect(_slot(name), findsOneWidget, reason: name);
        }
        expect(_anySlot, findsNWidgets(page.slots.length));
      });

      if (page.countKnob.isNotEmpty) {
        testWidgets('fo11/us06/fr01/e01: the count knob arranges the slots '
            'again', (tester) async {
          await page.open(
            tester,
            page.playground,
            knobs: {page.countKnob: '${page.count}'},
          );

          for (var i = 1; i <= page.count; i++) {
            expect(_slot('child $i'), findsOneWidget, reason: 'child $i');
          }
          expect(_anySlot, findsNWidgets(page.count));
        });
      }

      testWidgets('fo11/us06/fr02/e01: a recipe renders again at a new '
          'window size', (tester) async {
        for (final size in [WindowSize.mobile, WindowSize.desktop]) {
          await page.open(
            tester,
            'Layout/${page.name}/Recipe: card',
            toolbar: {'viewport': size.name},
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

  testWidgets('fo11/us06/fr01: an indexed stack paints the shown child only', (
    tester,
  ) async {
    final page = _pages.firstWhere((page) => page.hidesSlots);
    await page.open(tester, page.playground);

    expect(find.text('❖ child 1'), findsOneWidget);
    expect(find.text('❖ child 2'), findsNothing);

    await page.open(tester, page.playground, knobs: {'index': '1'});

    expect(find.text('❖ child 1'), findsNothing);
    expect(find.text('❖ child 2'), findsOneWidget);
  });

  testWidgets('fo11/us06/fr02: the page with drawer recipe shows its drawer '
      'slot from the tablet window size up', (tester) async {
    await openStory<StratumSlot>(
      tester,
      'Layout/ColumnLayout/Recipe: page with drawer',
      toolbar: {'viewport': WindowSize.desktop.name},
    );

    expect(tester.takeException(), isNull);
    for (final name in ['header', 'drawer', 'body']) {
      expect(_slot(name), findsOneWidget, reason: name);
    }
  });
}
