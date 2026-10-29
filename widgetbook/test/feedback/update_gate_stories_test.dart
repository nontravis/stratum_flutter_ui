import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/components.g.dart';
import 'package:stratum_ui_widgetbook/feedback/update_gate.stories.dart';
import 'package:stratum_ui_widgetbook/kit/docs/accessibility_notes_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/figma_link_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/usage_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/preset.dart';
import 'package:stratum_ui_widgetbook/kit/slot_preset.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../support/open_story.dart';

void main() {
  test('fo11/us04/fr01: the Update gate Playground has one knob per '
      'constructor param', () {
    expect(
      [for (final arg in $Playground.args.list) arg?.name],
      ['checker', 'builder', 'child'],
    );
  });

  test('fo11/us04/fr01/e02: a widget without size or disabled shows neither '
      'knob', () {
    final names = [for (final arg in $Playground.args.list) arg?.name];

    expect(names, isNot(contains('size')));
    expect(names, isNot(contains('disabled')));
  });

  test('fo11/us04/fr01/e03: the checker, builder, and child take their kit '
      'knobs', () {
    final checker = $Playground.args.checkerArg;

    expect(checker, isA<PresetArg<UpdateChecker>>());
    expect(
      [for (final p in (checker as PresetArg<UpdateChecker>).values) p.name],
      [for (final status in UpdateStatus.values) status.name],
    );
    expect($Playground.args.builderArg, isA<PresetArg<UpdateGateBuilder>>());
    expect($Playground.args.childArg, isA<EnumArg<SlotPreset>>());
  });

  test('fo11/us03/fr01: the Update gate docs follow INV-3', () {
    final blocks = StratumUpdateGateComponent.docsBuilder!([]);

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

  testWidgets('fo11/us03/fr03, fo11/us03/s3: the update gate\'s screens '
      'stand in as slots: required paints the force update screen slot', (
    tester,
  ) async {
    await openStory<StratumUpdateGate>(
      tester,
      'Feedback/Update gate/Playground',
      knobs: {'checker': 'required'},
    );

    expect(find.text('❖ force update screen'), findsOneWidget);
    expect(find.text('❖ app'), findsNothing);
  });

  testWidgets('fo11/us03/fr03, fo11/us03/s3: the update gate\'s screens '
      'stand in as slots: maintenance paints the maintenance screen slot', (
    tester,
  ) async {
    await openStory<StratumUpdateGate>(
      tester,
      'Feedback/Update gate/Playground',
      knobs: {'checker': 'maintenance'},
    );

    expect(find.text('❖ maintenance screen'), findsOneWidget);
  });

  testWidgets('fo11/us03/fr03, fo11/us03/s3: the update gate\'s screens '
      'stand in as slots: available paints the update dialog slot above the '
      'app slot', (tester) async {
    await openStory<StratumUpdateGate>(
      tester,
      'Feedback/Update gate/Playground',
      knobs: {'checker': 'available'},
    );

    final dialogRoute = ModalRoute.of(
      tester.element(find.text('❖ update dialog')),
    );
    final appRoute = ModalRoute.of(tester.element(find.text('❖ app')));
    expect(dialogRoute, isNotNull);
    expect(appRoute, isNotNull);
    expect(dialogRoute, isNot(same(appRoute)));
    expect(dialogRoute!.isCurrent, isTrue);
    expect(appRoute!.isCurrent, isFalse);
  });

  testWidgets('fo11/us02/fr02: Review Focus 3: the available dialog follows '
      'dark mode and right-to-left', (tester) async {
    await openStory<StratumUpdateGate>(
      tester,
      'Feedback/Update gate/Playground',
      knobs: {'checker': 'available'},
      toolbar: {
        'theme': {'name': 'default · Dark'},
        'right-to-left': {'enabled': 'true'},
        'viewport': {'name': 'desktop'},
      },
    );

    final dialog = tester.element(find.text('❖ update dialog'));
    expect(Directionality.of(dialog), TextDirection.rtl);
    expect(StratumThemeApplication.of(dialog).themeMode, ThemeMode.dark);
  });

  testWidgets('fo11/us03/fr02: the Update gate Variants show one frame per '
      'status', (tester) async {
    await openStory<StratumUpdateGate>(tester, 'Feedback/Update gate/Variants');
    await tester.pumpAndSettle();

    for (final status in UpdateStatus.values) {
      expect(find.text(status.name), findsOneWidget, reason: status.name);
    }
    expect(find.byType(StratumUpdateGate), findsNWidgets(4));
    expect(find.text('❖ force update screen'), findsOneWidget);
    expect(find.text('❖ maintenance screen'), findsOneWidget);
    expect(find.text('❖ update dialog'), findsOneWidget);
  });

  test('fo11/us01/fr02: the Update gate page sits under Feedback', () {
    expect(StratumUpdateGateComponent.path, 'Feedback');
    expect(components, contains(StratumUpdateGateComponent));
  });

  testWidgets('fo11/us03/fr02: every Update gate story opens without an '
      'error', (tester) async {
    expect(StratumUpdateGateComponent.stories, hasLength(5));

    for (final story in StratumUpdateGateComponent.stories) {
      await openStory<StratumUpdateGate>(
        tester,
        'Feedback/Update gate/${story.name}',
      );
      expect(tester.takeException(), isNull, reason: story.name);
    }
  });
}
