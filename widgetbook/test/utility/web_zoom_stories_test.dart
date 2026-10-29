import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/components.g.dart';
import 'package:stratum_ui_widgetbook/kit/docs/accessibility_notes_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/figma_link_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/usage_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/slot_preset.dart';
import 'package:stratum_ui_widgetbook/utility/web_zoom.stories.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../support/open_story.dart';

void main() {
  test('fo11/us04/fr01: the Web zoom Playground has one knob per constructor '
      'param', () {
    expect(
      [for (final arg in $Playground.args.list) arg?.name],
      ['minScale', 'maxScale', 'child'],
    );
  });

  test('fo11/us04/fr01/e03: slot, callback, and style params take their kit '
      'knobs', () {
    expect($Playground.args.childArg, isA<EnumArg<SlotPreset>>());
    expect($Playground.args.childArg.value, SlotPreset.slot);
  });

  test('fo11/us03/fr01: the Web zoom docs follow INV-3', () {
    final blocks = StratumWebZoomComponent.docsBuilder!([]);

    expect(blocks.map((b) => b.runtimeType), [
      ComponentNameDocBlock,
      FigmaLinkDocBlock,
      DartCommentDocBlock,
      UsageDocBlock,
      AccessibilityNotesDocBlock,
      ArgsDocBlock,
    ]);
  });

  test('fo11/us03/fr01/e03: Web zoom has no Figma node', () {
    final blocks = StratumWebZoomComponent.docsBuilder!([]);

    expect((blocks[1] as FigmaLinkDocBlock).figma, isNull);
  });

  test('fo11/us01/fr02: the Web zoom page sits under Utility', () {
    expect(StratumWebZoomComponent.path, 'Utility');
    expect(components, contains(StratumWebZoomComponent));
  });

  testWidgets('fo11/us04/s2: the Web zoom Playground shows the content '
      'slot', (tester) async {
    await openStory<StratumWebZoom>(tester, 'Utility/Web zoom/Playground');

    expect(find.text('❖ content'), findsOneWidget);
  });

  testWidgets('fo11/us03/fr02: every Web zoom story opens without an error', (
    tester,
  ) async {
    expect(StratumWebZoomComponent.stories, hasLength(5));

    for (final story in StratumWebZoomComponent.stories) {
      await openStory<StratumWebZoom>(tester, 'Utility/Web zoom/${story.name}');
      expect(tester.takeException(), isNull, reason: story.name);
    }
  });
}
