import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/components.g.dart';
import 'package:stratum_ui_widgetbook/feedback/toast.stories.dart';
import 'package:stratum_ui_widgetbook/kit/docs/accessibility_notes_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/figma_link_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/usage_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/preset.dart';
import 'package:stratum_ui_widgetbook/kit/slot_preset.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../support/open_story.dart';

const _playground = 'Feedback/Toast/Playground';

final _figma = Uri.parse(
  'https://www.figma.com/design/wjRe9eL7863nMRfFats8jZ/'
  'Design-System-4-by-Nonthawit?node-id=935-17178',
);

const _message = 'A sample message to see how text wraps in a narrow space';

/// Taps the story's `Show toast` trigger and lets the notice animate in,
/// well inside its 4 s close time.
Future<void> _showToast(WidgetTester tester) async {
  await tester.tap(find.text('Show toast'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1));
}

/// Closes the story so the open notice's close timer goes with it.
Future<void> _closeStory(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 10));
}

void main() {
  test('fo11/us04/fr01: one knob per host param and showToast param', () {
    expect(
      [for (final arg in $Playground.args.list) arg?.name],
      [
        'child',
        'builder',
        'closeButtonLabel',
        'kindLabels',
        'focusShortcuts',
        'focusShortcutHint',
        'message',
        'action',
        'kind',
        'placement',
        'customStyle',
      ],
    );
  });

  test('fo11/us04/fr01/e02: a widget without size or disabled shows neither '
      'knob', () {
    final names = [for (final arg in $Playground.args.list) arg?.name];

    expect(names, isNot(contains('size')));
    expect(names, isNot(contains('disabled')));
  });

  test('fo11/us04/fr01/e03: each knob takes its kit knob', () {
    final args = $Playground.args;

    expect(args.childArg, isA<EnumArg<SlotPreset>>());
    expect(args.kindArg, isA<EnumArg<FeedbackState>>());
    expect(args.builderArg, isA<PresetArg<StratumToastBuilder>>());
    expect(args.closeButtonLabelArg, isA<PresetArg<String>>());
    expect(args.kindLabelsArg, isA<PresetArg<Map<FeedbackState, String>>>());
    expect(args.focusShortcutsArg, isA<PresetArg<List<SingleActivator>>>());
    expect(args.focusShortcutHintArg, isA<PresetArg<String>>());
    expect(args.messageArg, isA<PresetArg<String>>());
    expect(args.actionArg, isA<PresetArg<StratumToastAction>>());
    expect(args.placementArg, isA<PresetArg<StratumToastPlacement>>());
    expect(args.customStyleArg, isA<PresetArg<WidgetStyle>>());
    expect(
      [for (final p in (args.placementArg as PresetArg).values) p.name],
      [
        'None',
        'float topStart',
        'float topCenter',
        'float topEnd',
        'float bottomStart',
        'float bottomCenter',
        'float bottomEnd',
        'solid top',
        'solid bottom',
      ],
    );
  });

  test('fo11/us03/fr01: the Toast docs follow INV-3', () {
    final blocks = StratumToastHostComponent.docsBuilder!([]);

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

  test('fo11/us01/fr02: the Toast page sits under Feedback', () {
    expect(StratumToastHostComponent.path, 'Feedback');
    expect(StratumToastHostComponent.name, 'Toast');
    expect(components, contains(StratumToastHostComponent));
  });

  testWidgets('fo11/us04/fr03: the action reports onPressed called', (
    tester,
  ) async {
    await openStory<StratumToastHost>(
      tester,
      _playground,
      knobs: {'action': 'With action'},
    );
    await _showToast(tester);

    expect(find.text('onPressed called'), findsNothing);
    await tester.tap(find.text('Label'));
    await tester.pump();

    expect(find.text('onPressed called'), findsOneWidget);
    await _closeStory(tester);
  });

  testWidgets('fo11/us04/fr04: a style preset restyles the notice', (
    tester,
  ) async {
    BoxBorder? noticeBorder() => tester
        .widget<ContainerLayout>(
          find
              .ancestor(
                of: find.text(_message),
                matching: find.byType(ContainerLayout),
              )
              .first,
        )
        .style
        ?.border;

    await openStory<StratumToastHost>(tester, _playground);
    await _showToast(tester);
    final plain = noticeBorder();
    await _closeStory(tester);

    await openStory<StratumToastHost>(
      tester,
      _playground,
      knobs: {'customStyle': 'Outlined'},
    );
    await _showToast(tester);

    expect(plain, isNotNull);
    expect(noticeBorder(), isNot(plain));
    await _closeStory(tester);
  });

  testWidgets('fo11/us03/fr03/e01: the toast\'s own close button is built, '
      'never stood in', (tester) async {
    await openStory<StratumToastHost>(tester, _playground);
    await _showToast(tester);

    expect(find.text(_message), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byType(StratumSlot), findsOneWidget);
    expect(find.text('❖ app'), findsOneWidget);
    await _closeStory(tester);
  });

  testWidgets('fo11/us02/fr02: Review Focus 3: a notice follows dark mode and '
      'right-to-left', (tester) async {
    await openStory<StratumToastHost>(
      tester,
      _playground,
      toolbar: {
        'theme': {'name': 'default · Dark'},
        'right-to-left': {'enabled': 'true'},
      },
    );
    await _showToast(tester);

    final notice = tester.element(find.text(_message));
    expect(Directionality.of(notice), TextDirection.rtl);
    expect(StratumThemeApplication.of(notice).themeMode, ThemeMode.dark);
    await _closeStory(tester);
  });

  testWidgets('fo11/us02/fr01/e01: Review Focus 4: a notice reads the dark '
      'data after the theme switches', (tester) async {
    await openStory<StratumToastHost>(tester, _playground);
    await _showToast(tester);
    expect(
      StratumThemeApplication.of(tester.element(find.text(_message))).themeMode,
      ThemeMode.light,
    );

    WidgetbookState.of(tester.element(find.text('Show toast')))
        .updateQueryField(
          groupName: 'theme',
          fieldName: 'name',
          fieldValue: 'default · Dark',
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(
      StratumThemeApplication.of(tester.element(find.text(_message))).themeMode,
      ThemeMode.dark,
    );
    await _closeStory(tester);
  });

  testWidgets('fo11/us03/fr02: every Toast story opens without an error', (
    tester,
  ) async {
    expect(StratumToastHostComponent.stories, isNotEmpty);

    for (final story in StratumToastHostComponent.stories) {
      final path = 'Feedback/Toast/${story.name}';
      if (story.name == 'Variants') {
        await openStory<StratumToastPlainLook>(tester, path);
      } else {
        await openStory<StratumToastHost>(tester, path);
      }
      expect(tester.takeException(), isNull, reason: story.name);
    }
  });

  testWidgets('fo11/us03/fr02: the Toast Responsive frames each show a '
      'trigger under one root host', (tester) async {
    await openStory<StratumToastHost>(tester, 'Feedback/Toast/Responsive');

    expect(find.text('Show toast'), findsNWidgets(WindowSize.values.length));
    expect(tester.takeException(), isNull);
  });

  testWidgets('fo11/us03/fr02: the Toast Variants paint all eight notices, '
      'each with its kind label, and none disappears', (tester) async {
    final semantics = tester.ensureSemantics();
    await openStory<StratumToastPlainLook>(tester, 'Feedback/Toast/Variants');

    const labels = {
      FeedbackState.info: 'Info',
      FeedbackState.negative: 'Error',
      FeedbackState.warning: 'Warning',
      FeedbackState.positive: 'Success',
    };
    expect(find.byType(StratumToastPlainLook), findsNWidgets(8));
    for (final MapEntry(:key, :value) in labels.entries) {
      for (final frame in [key.name, '${key.name} with action']) {
        expect(find.text(frame), findsOneWidget, reason: frame);
        expect(
          find.descendant(
            of: find
                .ancestor(
                  of: find.text(frame),
                  matching: find.byType(ColumnLayout),
                )
                .first,
            matching: find.bySemanticsLabel(value),
          ),
          findsOneWidget,
          reason: frame,
        );
      }
    }
    expect(find.text('Label'), findsNWidgets(4));

    await tester.pump(const Duration(seconds: 10));

    expect(find.byType(StratumToastPlainLook), findsNWidgets(8));
    expect(find.text(_message), findsNWidgets(8));
    semantics.dispose();
  });

  testWidgets('fo11/us04/fr03: the Variants close button reports close '
      'called', (tester) async {
    await openStory<StratumToastPlainLook>(tester, 'Feedback/Toast/Variants');
    expect(find.text('close called'), findsNothing);

    await tester.ensureVisible(find.byIcon(Icons.close).first);
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump();
    expect(find.text('close called'), findsOneWidget);
  });

  testWidgets('fo11/us03/fr02: the Accessibility 200% text frame draws its '
      'notice at twice the text scale', (tester) async {
    await openStory<StratumToastHost>(tester, 'Feedback/Toast/Accessibility');

    await tester.tap(find.text('Show toast').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    final notice = tester.element(find.text(_message));
    expect(MediaQuery.textScalerOf(notice).scale(10), 20);
    await _closeStory(tester);
  });

  testWidgets('fo11/us03/fr02: the Accessibility 200% text frame draws its '
      'notice wider than zero', (tester) async {
    await openStory<StratumToastHost>(
      tester,
      'Feedback/Toast/Accessibility',
      toolbar: const {
        'viewport': {'name': 'desktop'},
      },
    );

    await tester.tap(find.text('Show toast').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    final size = tester.getSize(find.text(_message));
    expect(size.width, greaterThan(0), reason: 'the notice must be visible');
    expect(size.height, greaterThan(0), reason: 'the notice must be visible');
    await _closeStory(tester);
  });

  testWidgets('fo11/us03/fr02: the Accessibility right-to-left frame draws '
      'its notice right to left', (tester) async {
    await openStory<StratumToastHost>(tester, 'Feedback/Toast/Accessibility');

    await tester.tap(find.text('Show toast').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    final notice = tester.element(find.text(_message));
    expect(Directionality.of(notice), TextDirection.rtl);
    expect(MediaQuery.textScalerOf(notice).scale(10), 10);
    await _closeStory(tester);
  });
}
