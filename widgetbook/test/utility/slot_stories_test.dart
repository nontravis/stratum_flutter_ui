import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/components.g.dart';
import 'package:stratum_ui_widgetbook/kit/docs/accessibility_notes_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/figma_link_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/usage_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/preset.dart';
import 'package:stratum_ui_widgetbook/shell/catalog_config.dart';
import 'package:stratum_ui_widgetbook/utility/slot.stories.dart';
import 'package:widgetbook/src/core/widgetbook_app.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../support/catalog_theme.dart';

final _figma = Uri.parse(
  'https://www.figma.com/design/wjRe9eL7863nMRfFats8jZ/'
  'Design-System-4-by-Nonthawit?node-id=40000310-9233',
);

/// Opens the Slot story [story] in the catalog and asserts it really opened.
Future<void> _open(WidgetTester tester, String story) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final set = await loadDefaultThemeSet();
  final route = Uri(
    path: '/',
    queryParameters: {'path': 'Utility/Slot/$story'},
  ).toString();
  await tester.pumpWidget(
    WidgetbookApp(
      key: UniqueKey(),
      config: Config(
        components: catalogConfig(
          components: components,
          themes: {'default': set},
        ).components,
        addons: catalogAddons({'default': set}),
        initialRoute: route,
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byType(StratumSlot), findsWidgets);
}

void main() {
  test('fo11/us04/fr01: the Slot Playground has one knob per constructor '
      'param', () {
    expect(
      [for (final arg in $Playground.args.list) arg?.name],
      ['height', 'width', 'padding', 'name'],
    );
  });

  test('fo11/us04/fr01/e02: a widget without size or disabled shows neither '
      'knob', () {
    final names = [for (final arg in $Playground.args.list) arg?.name];

    expect(names, isNot(contains('size')));
    expect(names, isNot(contains('disabled')));
  });

  test('fo11/us04/fr04: the padding param takes a preset knob', () {
    expect($Playground.args.paddingArg, isA<PresetArg<EdgeInsets>>());
    expect($Playground.args.nameArg, isA<StringArg>());
  });

  test('fo11/us03/fr01: the Slot docs follow INV-3', () {
    final blocks = StratumSlotComponent.docsBuilder!([]);

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

  test('fo11/us01/fr02: the Slot page sits under Utility', () {
    expect(StratumSlotComponent.path, 'Utility');
    expect(components, contains(StratumSlotComponent));
  });

  testWidgets('fo11/us03/fr02: the Slot Playground shows the placeholder '
      'named by the name knob', (tester) async {
    await _open(tester, 'Playground');

    expect(find.text('❖ Slot'), findsOneWidget);
  });

  testWidgets('fo11/us03/fr02: every Slot story opens without an error', (
    tester,
  ) async {
    expect(StratumSlotComponent.stories, hasLength(5));

    for (final story in StratumSlotComponent.stories) {
      await _open(tester, story.name);
      expect(tester.takeException(), isNull, reason: story.name);
    }
  });
}
