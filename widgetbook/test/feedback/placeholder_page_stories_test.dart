import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/components.g.dart';
import 'package:stratum_ui_widgetbook/feedback/placeholder_page.stories.dart';
import 'package:stratum_ui_widgetbook/kit/docs/accessibility_notes_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/figma_link_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/usage_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/preset.dart';
import 'package:stratum_ui_widgetbook/kit/sample_text.dart';
import 'package:stratum_ui_widgetbook/kit/slot_preset.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../support/open_story.dart';

void main() {
  test('fo11/us04/fr01: the Placeholder page Playground has one knob per '
      'constructor param', () {
    expect(
      [for (final arg in $Playground.args.list) arg?.name],
      ['title', 'message', 'icon'],
    );
  });

  test('fo11/us04/fr01/e02: a widget without size or disabled shows neither '
      'knob', () {
    final names = [for (final arg in $Playground.args.list) arg?.name];

    expect(names, isNot(contains('size')));
    expect(names, isNot(contains('disabled')));
  });

  test('fo11/us04/fr01/e03: the title, message, and icon take their kit '
      'knobs', () {
    final title = $Playground.args.titleArg;

    expect(title, isA<PresetArg<String>>());
    expect(
      [for (final p in (title as PresetArg<String>).values) p.name],
      ['None', 'Title'],
    );
    expect($Playground.args.iconArg, isA<EnumArg<SlotPreset>>());
  });

  test('fo11/us03/fr01: the Placeholder page docs follow INV-3', () {
    final blocks = StratumPlaceholderPageComponent.docsBuilder!([]);

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

  testWidgets('fo11/us04/fr05: the placeholder page title follows the '
      'toolbar language', (tester) async {
    await openStory<StratumPlaceholderPage>(
      tester,
      'Feedback/Placeholder page/Playground',
      knobs: {'title': 'Title'},
      toolbar: {
        'locale': {'name': 'th'},
      },
    );

    expect(find.text(SampleTexts.title.th), findsOneWidget);
  });

  testWidgets('fo11/us03/fr02: Review Focus 2: the Thai placeholder page '
      'holds 200% text in its Accessibility frames', (tester) async {
    await openStory<StratumPlaceholderPage>(
      tester,
      'Feedback/Placeholder page/Accessibility',
      toolbar: {
        'locale': {'name': 'th'},
      },
    );

    expect(tester.takeException(), isNull);
    expect(find.text(SampleTexts.title.th), findsWidgets);
  });

  testWidgets('fo11/us03/fr02: the Variants story shows seven frames, each '
      'with the params its label names', (tester) async {
    await openStory<StratumPlaceholderPage>(
      tester,
      'Feedback/Placeholder page/Variants',
    );

    const labels = [
      'title + message + icon',
      'message + icon',
      'title + icon',
      'title + message',
      'icon',
      'message',
      'title',
    ];
    final pages = tester
        .widgetList<StratumPlaceholderPage>(find.byType(StratumPlaceholderPage))
        .toList();
    expect(pages, hasLength(labels.length));
    for (final label in labels) {
      expect(find.text(label), findsOneWidget, reason: label);
      final page = tester.widget<StratumPlaceholderPage>(
        find.descendant(
          of: find
              .ancestor(
                of: find.text(label),
                matching: find.byType(ColumnLayout),
              )
              .first,
          matching: find.byType(StratumPlaceholderPage),
        ),
      );
      expect(page.title != null, label.contains('title'), reason: label);
      expect(page.message != null, label.contains('message'), reason: label);
      expect(page.icon != null, label.contains('icon'), reason: label);
    }
  });

  test('fo11/us01/fr02: the Placeholder page sits under Feedback', () {
    expect(StratumPlaceholderPageComponent.path, 'Feedback');
    expect(components, contains(StratumPlaceholderPageComponent));
  });

  testWidgets('fo11/us03/fr02: every Placeholder page story opens without '
      'an error', (tester) async {
    expect(StratumPlaceholderPageComponent.stories, hasLength(5));

    for (final story in StratumPlaceholderPageComponent.stories) {
      await openStory<StratumPlaceholderPage>(
        tester,
        'Feedback/Placeholder page/${story.name}',
      );
      expect(tester.takeException(), isNull, reason: story.name);
    }
  });
}
