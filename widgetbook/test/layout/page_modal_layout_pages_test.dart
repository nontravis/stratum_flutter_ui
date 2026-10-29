import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/components.g.dart';
import 'package:stratum_ui_widgetbook/kit/docs/accessibility_notes_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/figma_link_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/usage_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/story_set.dart';
import 'package:stratum_ui_widgetbook/layout/modal_layout.stories.dart'
    as modal;
import 'package:stratum_ui_widgetbook/layout/page_layout.stories.dart' as page;
import 'package:stratum_ui_widgetbook/shell/window_size_addon.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../support/open_story.dart';

/// One page of this task: the facts the shared tests check.
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
  });

  final String name;
  final Type type;
  final Component component;

  /// The Playground's knob names.
  final List<String?> knobs;

  /// The constructor params of the widget, in order.
  final List<String> expectedKnobs;

  /// The use the page's `Example: ` story shows.
  final String example;

  /// The slot names the Playground paints.
  final List<String> slots;

  /// One knob and a value that keeps the slot names.
  final MapEntry<String, String> knobChange;

  String get playground => 'Layout/$name/Playground';

  Future<void> open(
    WidgetTester tester,
    String path, {
    Map<String, String> knobs = const {},
    String viewport = 'desktop',
  }) => openStory<StratumSlot>(
    tester,
    path,
    knobs: knobs,
    toolbar: {
      'viewport': {'name': viewport},
    },
  );
}

final _pages = <_Page>[
  _Page(
    name: 'PageLayout',
    type: PageLayout,
    component: page.PageLayoutComponent,
    knobs: [for (final arg in page.$Playground.args.list) arg?.name],
    expectedKnobs: const [
      'header',
      'left',
      'top',
      'tab',
      'body',
      'bottom',
      'right',
      'footer',
      'snack',
      'safeArea',
      'resizeToAvoidKeyboard',
      'loading',
      'loadingBuilder',
      'controller',
      'leftSide',
      'rightSide',
      'drawerCut',
      'rightAsOverlay',
      'minCenterWidth',
      'leftDividerBuilder',
      'rightDividerBuilder',
      'edgeSwipe',
      'onDrawerChanged',
      'customStyle',
      'systemStyle',
      'setting',
    ],
    example: 'screen with a bottom bar',
    slots: [
      'header',
      'left',
      'top',
      'tab',
      'body',
      'bottom',
      'right',
      'footer',
      'snack',
    ],
    knobChange: const MapEntry('resizeToAvoidKeyboard', 'false'),
  ),
  _Page(
    name: 'ModalLayout',
    type: ModalLayout,
    component: modal.ModalLayoutComponent,
    knobs: [for (final arg in modal.$Playground.args.list) arg?.name],
    expectedKnobs: const [
      'top',
      'tab',
      'body',
      'type',
      'size',
      'showClose',
      'onClose',
      'borderRadius',
      'safeArea',
      'fullHeight',
      'scrollBody',
      'customStyle',
    ],
    example: 'confirmation',
    slots: ['top', 'tab', 'body'],
    knobChange: const MapEntry('showClose', 'false'),
  ),
];

/// The slot placeholder named [name], hidden ones included.
Finder _slot(String name) => find.text('❖ $name', skipOffstage: false);

/// Every slot placeholder painted on screen.
Finder get _anySlot => find.textContaining('❖', skipOffstage: false);

void main() {
  for (final p in _pages) {
    group(p.name, () {
      test('fo11/us04/fr01: one knob per constructor param', () {
        expect(p.knobs, p.expectedKnobs);
      });

      test('fo11/us03/fr01: the docs follow INV-3 with no Figma node', () {
        final blocks = p.component.docsBuilder!([]);

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
        expect(p.component.path, 'Layout');
        expect(components, contains(p.component));
        expect(
          [for (final story in p.component.stories) story.name],
          [
            StoryNames.playground,
            ...StoryNames.recipes,
            StoryNames.responsive,
            StoryNames.accessibility,
            StoryNames.example(p.example),
          ],
        );
        expect(storySetProblems(p.component), isEmpty);
      });

      testWidgets('fo11/us06/fr01, fo11/us06/s1: the Playground children '
          'are named slots', (tester) async {
        await p.open(tester, p.playground);

        expect(find.byType(p.type), findsWidgets);
        for (final name in p.slots) {
          expect(_slot(name), findsOneWidget, reason: name);
        }
        expect(_anySlot, findsNWidgets(p.slots.length));
      });

      testWidgets('fo11/us06/fr01/e01: a knob change keeps the slot names', (
        tester,
      ) async {
        await p.open(
          tester,
          p.playground,
          knobs: {p.knobChange.key: p.knobChange.value},
        );

        expect(tester.takeException(), isNull);
        for (final name in p.slots) {
          expect(_slot(name), findsOneWidget, reason: name);
        }
        expect(_anySlot, findsNWidgets(p.slots.length));
      });

      testWidgets('fo11/us06/fr02/e01: a recipe renders again at a new '
          'window size', (tester) async {
        for (final size in [WindowSize.mobile, WindowSize.desktop]) {
          await p.open(
            tester,
            'Layout/${p.name}/Recipe: card',
            viewport: size.name,
          );

          expect(tester.takeException(), isNull, reason: size.name);
          expect(
            WindowSizeScope.of(tester.element(find.byType(StratumSlot).first)),
            size,
            reason: 'the window size reaches the recipe',
          );
        }
      });

      testWidgets('fo11/us03/fr02: every ${p.name} story opens without an '
          'error', (tester) async {
        for (final story in p.component.stories) {
          await p.open(tester, 'Layout/${p.name}/${story.name}');
          expect(tester.takeException(), isNull, reason: story.name);
        }
      });

      testWidgets('fo11/us03/fr02: Responsive shows one frame per window '
          'size and Accessibility shows no Disabled frame', (tester) async {
        await p.open(tester, 'Layout/${p.name}/Responsive');
        for (final size in WindowSize.values) {
          expect(find.text(size.name), findsOneWidget, reason: size.name);
        }

        await p.open(tester, 'Layout/${p.name}/Accessibility');
        expect(find.text('200% text'), findsOneWidget);
        expect(find.text('Right to left'), findsOneWidget);
        expect(find.text('Disabled'), findsNothing);
        expect(
          find.text('Loading'),
          p.name == 'PageLayout' ? findsOneWidget : findsNothing,
        );
      });
    });
  }

  group('PageLayout', () {
    final pageLayout = _pages.first;

    testWidgets('fo11/us06/fr03, fo11/us06/s3: the page layout follows the '
        'toolbar window size', (tester) async {
      await pageLayout.open(
        tester,
        pageLayout.playground,
        viewport: WindowSize.mobile.name,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('❖ left').hitTestable(), findsNothing);

      await pageLayout.open(tester, pageLayout.playground);
      expect(tester.takeException(), isNull);
      expect(find.text('❖ left').hitTestable(), findsOneWidget);
    });

    for (final knob in const [
      MapEntry('controller', 'Story controller'),
      MapEntry('setting', 'Catalog id'),
    ]) {
      testWidgets('fo11/us06/fr01/e01: the ${knob.key} preset '
          '"${knob.value}" opens with its slots painted', (tester) async {
        await pageLayout.open(
          tester,
          pageLayout.playground,
          knobs: {knob.key: knob.value},
        );

        expect(tester.takeException(), isNull);
        for (final name in ['header', 'body', 'footer']) {
          expect(find.text('❖ $name'), findsOneWidget, reason: name);
        }
      });
    }
  });

  group('ModalLayout', () {
    final modalLayout = _pages.last;

    testWidgets('fo11/us04/fr03/e01: the close button reports onClose '
        'called', (tester) async {
      await modalLayout.open(tester, modalLayout.playground);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('onClose called'), findsOneWidget);
    });

    testWidgets('fo11/us06/fr03/e01: the modal layout rearranges from mobile '
        'to tablet', (tester) async {
      await modalLayout.open(
        tester,
        modalLayout.playground,
        viewport: WindowSize.mobile.name,
      );
      expect(tester.takeException(), isNull);
      final mobile = tester.getSize(find.byType(ModalLayout)).width;
      expect(
        mobile,
        catalogWindowSizes[WindowSize.mobile]!.width,
        reason: 'a bottom sheet spans the window',
      );

      await modalLayout.open(
        tester,
        modalLayout.playground,
        viewport: WindowSize.tablet.name,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(ModalLayout)).width,
        lessThan(catalogWindowSizes[WindowSize.tablet]!.width),
        reason: 'a modal is narrower than the window',
      );
    });
  });

  group('SplitLayout', () {
    testWidgets('fo11/us04/fr01: the Start pane 30% preset holds at three '
        'panes', (tester) async {
      await openStory<StratumSlot>(
        tester,
        'Layout/SplitLayout/Playground',
        knobs: {'panes': '3', 'controller': 'Start pane 30%'},
        toolbar: {
          'viewport': {'name': WindowSize.desktop.name},
        },
      );

      expect(tester.takeException(), isNull);
      final widths = [
        for (var i = 1; i <= 3; i++)
          tester
              .getSize(
                find.ancestor(
                  of: find.text('❖ child $i'),
                  matching: find.byType(StratumSlot),
                ),
              )
              .width,
      ];
      final total = widths.reduce((a, b) => a + b);
      expect(widths.first / total, closeTo(0.3, 0.01));
    });
  });
}
