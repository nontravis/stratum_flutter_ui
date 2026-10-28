import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/components.g.dart';
import 'package:stratum_ui_widgetbook/kit/docs/accessibility_notes_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/figma_link_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/usage_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/preset.dart';
import 'package:stratum_ui_widgetbook/utility/caret.stories.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../support/open_story.dart';

final _figma = Uri.parse(
  'https://www.figma.com/design/wjRe9eL7863nMRfFats8jZ/'
  'Design-System-4-by-Nonthawit?node-id=56236-100390',
);

/// The caret's own box: the widget itself fills a tight parent.
final _glyphBox = find.descendant(
  of: find.byType(StratumCaret),
  matching: find.byType(ContainerLayout),
);

void main() {
  test('fo11/us04/fr01: the Caret Playground has one knob per constructor '
      'param', () {
    expect(
      [for (final arg in $Playground.args.list) arg?.name],
      [
        'style',
        'direction',
        'size',
        'customSize',
        'color',
        'customColor',
        'themeMode',
        'disabled',
        'customStyle',
      ],
    );
  });

  test('fo11/us04/fr01/e03: slot, callback, and style params take their kit '
      'knobs', () {
    final arg = $Playground.args.customStyleArg;

    expect(arg, isA<PresetArg<StratumCaretStyle>>());
    expect(
      [for (final p in (arg as PresetArg<StratumCaretStyle>).values) p.name],
      ['None', 'Filled box', 'Outlined box'],
    );
  });

  testWidgets('fo11/us04/fr01/e01: the disabled knob disables the caret', (
    tester,
  ) async {
    await openStory<StratumCaret>(
      tester,
      'Utility/Caret/Playground',
      knobs: {'disabled': 'true'},
    );

    expect(
      tester.widget<StratumCaret>(find.byType(StratumCaret)).disabled,
      true,
    );
  });

  testWidgets('fo11/us04/s1: the size knob resizes the caret', (tester) async {
    await openStory<StratumCaret>(
      tester,
      'Utility/Caret/Playground',
      knobs: {'size': 'small'},
    );
    final small = tester.getSize(_glyphBox);

    await openStory<StratumCaret>(
      tester,
      'Utility/Caret/Playground',
      knobs: {'size': 'large'},
    );
    final large = tester.getSize(_glyphBox);

    expect(small.width, lessThan(large.width));
    expect(small.height, lessThan(large.height));
  });

  testWidgets('fo11/us03/s2: the caret Variants show every glyph, direction, '
      'size, and state', (tester) async {
    await openStory<StratumCaret>(tester, 'Utility/Caret/Variants');

    expect(
      find.byType(StratumCaret),
      findsNWidgets(
        StratumCaretGlyph.values.length *
            StratumCaretDirection.values.length *
            WidgetSize.values.length *
            2,
      ),
    );
    final disabled = tester
        .widgetList<StratumCaret>(find.byType(StratumCaret))
        .where((caret) => caret.disabled);
    expect(disabled, hasLength(3 * 4 * 7));
  });

  test('fo11/us03/fr01: the Caret docs follow INV-3', () {
    final blocks = StratumCaretComponent.docsBuilder!([]);

    expect(blocks.map((b) => b.runtimeType), [
      ComponentNameDocBlock,
      FigmaLinkDocBlock,
      DartCommentDocBlock,
      UsageDocBlock,
      AccessibilityNotesDocBlock,
      ArgsDocBlock,
    ]);
    expect((blocks[1] as FigmaLinkDocBlock).figma, _figma);
  });

  test('fo11/us01/fr02: the Caret page sits under Utility', () {
    expect(StratumCaretComponent.path, 'Utility');
    expect(components, contains(StratumCaretComponent));
  });

  testWidgets('fo11/us03/fr02: every Caret story opens without an error', (
    tester,
  ) async {
    expect(StratumCaretComponent.stories, hasLength(5));

    for (final story in StratumCaretComponent.stories) {
      await openStory<StratumCaret>(tester, 'Utility/Caret/${story.name}');
      expect(tester.takeException(), isNull, reason: story.name);
    }
  });
}
