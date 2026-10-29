import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../support/open_story.dart';

/// One Playground whose controller preset the story must own: where it opens,
/// the preset to pick, a knob to change beside it, and the controller the
/// built layout holds.
class _ControllerPage<T extends Widget> {
  const _ControllerPage({
    required this.name,
    required this.preset,
    required this.knob,
    required this.value,
    required this.controllerOf,
  });

  final String name;
  final String preset;
  final String knob;
  final String value;
  final ChangeNotifier? Function(T layout) controllerOf;

  String get path => 'Layout/$name/Playground';

  Future<void> open(WidgetTester tester) => openStory<T>(
    tester,
    path,
    knobs: {'controller': preset},
    toolbar: {
      'viewport': {'name': WindowSize.desktop.name},
    },
  );

  ChangeNotifier controller(WidgetTester tester) =>
      controllerOf(tester.widget<T>(find.byType(T)))!;

  /// Changes [knob] to [value] through the toolbar state, as the knob panel
  /// does.
  Future<void> change(WidgetTester tester) async {
    WidgetbookState.of(
      tester.element(find.byType(T)),
    ).updateQueryField(groupName: knob, fieldName: 'value', fieldValue: value);
    await tester.pump();
  }
}

final _pages = <_ControllerPage<Widget>>[
  _ControllerPage<ListViewLayout>(
    name: 'ListViewLayout',
    preset: 'Start at item 2',
    knob: 'reverse',
    value: 'true',
    controllerOf: (layout) => layout.controller,
  ),
  _ControllerPage<GridViewLayout>(
    name: 'GridViewLayout',
    preset: 'Start at item 2',
    knob: 'reverse',
    value: 'true',
    controllerOf: (layout) => layout.controller,
  ),
  _ControllerPage<CustomScrollViewLayout>(
    name: 'CustomScrollViewLayout',
    preset: 'Start at item 2',
    knob: 'reverse',
    value: 'true',
    controllerOf: (layout) => layout.controller,
  ),
  _ControllerPage<PageViewLayout>(
    name: 'PageViewLayout',
    preset: 'Start at page 2',
    knob: 'reverse',
    value: 'true',
    controllerOf: (layout) => layout.controller,
  ),
  _ControllerPage<SplitLayout>(
    name: 'SplitLayout',
    preset: 'Start pane 30%',
    knob: 'dividerLabel',
    value: 'Label',
    controllerOf: (layout) => layout.controller,
  ),
  _ControllerPage<PageLayout>(
    name: 'PageLayout',
    preset: 'Story controller',
    knob: 'rightAsOverlay',
    value: 'true',
    controllerOf: (layout) => layout.controller,
  ),
];

void main() {
  for (final page in _pages) {
    testWidgets('fo11/us06/fr01: the ${page.name} controller preset keeps one '
        'controller across a knob change', (tester) async {
      await page.open(tester);
      final before = page.controller(tester);

      await page.change(tester);

      expect(page.controller(tester), same(before));
    });

    testWidgets('fo11/us06/fr01: the ${page.name} controller preset disposes '
        'its controller with the story', (tester) async {
      await page.open(tester);
      final controller = page.controller(tester);

      await tester.pumpWidget(const SizedBox.shrink());

      expect(() => controller.addListener(() {}), throwsFlutterError);
    });
  }

  testWidgets('fo11/us06/fr01: a knob change keeps the divider position the '
      'EndUser dragged the SplitLayout to', (tester) async {
    final split = _pages.firstWhere((page) => page.name == 'SplitLayout');
    await split.open(tester);
    final controller = split.controller(tester) as SplitLayoutController;
    expect(controller.fractions, [0.3, 0.7]);
    controller.fractions = const [0.5, 0.5];
    await tester.pump();

    await split.change(tester);

    expect((split.controller(tester) as SplitLayoutController).fractions, [
      0.5,
      0.5,
    ]);
  });

  testWidgets('fo11/us06/fr01: the SplitLayout preset refits its fractions '
      'when the pane count changes', (tester) async {
    final split = _pages.firstWhere((page) => page.name == 'SplitLayout');
    await split.open(tester);
    final controller = split.controller(tester) as SplitLayoutController;
    controller.fractions = const [0.5, 0.5];
    await tester.pump();

    WidgetbookState.of(
      tester.element(find.byType(SplitLayout)),
    ).updateQueryField(groupName: 'panes', fieldName: 'value', fieldValue: '3');
    await tester.pump();

    final refit =
        (split.controller(tester) as SplitLayoutController).fractions!;
    expect(refit.length, 3);
    expect(refit.first, 0.3);
  });

  for (final setting in const ['Global', 'Catalog id']) {
    testWidgets('fo11/us06/fr01/e01: the SplitLayout setting preset '
        '"$setting" opens under the story settings', (tester) async {
      await openStory<SplitLayout>(
        tester,
        'Layout/SplitLayout/Playground',
        knobs: {'setting': setting},
        toolbar: {
          'viewport': {'name': WindowSize.desktop.name},
        },
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SplitLayout), findsOneWidget);
    });
  }
}
