import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart' hide Config;
import 'package:stratum_ui_widgetbook/shell/catalog_section.dart';
import 'package:stratum_ui_widgetbook/shell/catalog_tree.dart';
import 'package:widgetbook/src/core/framework/config.dart';
import 'package:widgetbook/src/core/widgetbook_app.dart';
import 'package:widgetbook/widgetbook.dart'
    show Arg, Component, Story, StoryArgs;

/// One stub page per named section, each with one stub story (s03 INV-2).
Component _stub(String name, CatalogSection section) => Component(
  name: name,
  path: section.label,
  stories: [TestStory(name: 'Primary')],
);

/// Story args of [_stub]'s [TestStory].
class TestStoryArgs extends StoryArgs<SizedBox> {
  const TestStoryArgs();

  @override
  List<Arg?> get list => const [];
}

/// A stub story whose builder answers [builder], so a test can build a real
/// Stratum widget through it (mirrors Widgetbook's own `TestStory`).
class TestStory extends Story<SizedBox, TestStoryArgs> {
  TestStory({
    required super.name,
    SizedBox Function(BuildContext, TestStoryArgs)? builder,
  }) : super(
         args: const TestStoryArgs(),
         builder: builder ?? (_, _) => const SizedBox.shrink(),
       );
}

void main() {
  test(
    'fo11/us01/fr02: orderBySection puts shuffled pages in section order',
    () {
      final stubs = [
        _stub('Toast', CatalogSection.feedback),
        _stub('Nav', CatalogSection.navigation),
        _stub('Fold', CatalogSection.disclosure),
        _stub('Base', CatalogSection.foundation),
        _stub('Field', CatalogSection.form),
        _stub('Card', CatalogSection.display),
        _stub('Row', CatalogSection.layout),
        _stub('Btn', CatalogSection.control),
        _stub('ToastHost', CatalogSection.overlay),
        _stub('Slot', CatalogSection.utility),
      ];
      // Fixed seed: the same shuffle every run, so the order is reproducible.
      stubs.shuffle(Random(7));

      final ordered = orderBySection(stubs);

      expect(ordered.map((c) => c.path), [
        'Foundation',
        'Layout',
        'Utility',
        'Control',
        'Disclosure',
        'Display',
        'Feedback',
        'Form',
        'Navigation',
        'Overlay',
      ]);
    },
  );

  test(
    'fo11/us01/fr02: a page outside the ten sections is refused (s03 INV-2)',
    () {
      const name = 'Outside';
      expect(
        () => orderBySection([
          Component(
            name: name,
            path: 'Widgets',
            stories: [TestStory(name: 'P')],
          ),
        ]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            contains(name),
          ),
        ),
      );
    },
  );

  testWidgets(
    'fo11/us01/fr02/e01: nesting a component of another category adds no '
    'second entry',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final toastStory = TestStory(
        name: 'Primary',
        // The Toast story builds a StratumSlot, a Utility widget, inside the
        // Feedback section: nesting across categories must not add a second
        // tree entry (s03 INV-2).
        builder: (_, _) =>
            const SizedBox(child: StratumSlot(name: 'nested slot')),
      );
      final toast = Component(
        name: 'Toast',
        path: 'Feedback',
        stories: [toastStory],
      );
      final slot = _stub('Slot', CatalogSection.utility);

      await tester.pumpWidget(
        WidgetbookApp(
          config: Config(
            components: orderBySection([toast, slot]),
            initialRoute: 'Feedback/Toast/${toastStory.name}',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Toast'), findsOneWidget);
      expect(find.text('Slot'), findsOneWidget);
      // INV-1 order: Utility (third section) sits above Feedback (seventh).
      final utility = tester.getTopLeft(find.text('Utility')).dy;
      final slotDy = tester.getTopLeft(find.text('Slot')).dy;
      final feedback = tester.getTopLeft(find.text('Feedback')).dy;
      final toastDy = tester.getTopLeft(find.text('Toast')).dy;
      expect(utility, lessThan(slotDy));
      expect(slotDy, lessThan(feedback));
      expect(feedback, lessThan(toastDy));
    },
  );

  testWidgets(
    'fo11/us01/fr02/e03, fo11/us01/s1: a stub page in every section shows '
    'the ten sections in order',
    (tester) async {
      // Tall view: every folder and page tile must be onstage, or the lazily
      // built tree list never creates the later sections.
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final stubs = CatalogSection.values.map(_stubByName).toList();
      await tester.pumpWidget(
        WidgetbookApp(config: Config(components: orderBySection(stubs))),
      );
      await tester.pumpAndSettle();

      var previousDy = -1.0;
      for (final label in CatalogSection.values.map((s) => s.label)) {
        final dy = tester.getTopLeft(find.text(label)).dy;
        expect(dy, greaterThan(previousDy), reason: label);
        previousDy = dy;
      }
    },
  );

  testWidgets('fo11/us01/fr02/e02: a section with no page shows no entry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final stubs = [
      _stub('Token', CatalogSection.foundation),
      _stub('Slot', CatalogSection.utility),
      _stub('Toast', CatalogSection.feedback),
    ];
    await tester.pumpWidget(
      WidgetbookApp(config: Config(components: orderBySection(stubs))),
    );
    await tester.pumpAndSettle();

    var previousDy = -1.0;
    for (final label in ['Foundation', 'Utility', 'Feedback']) {
      final dy = tester.getTopLeft(find.text(label)).dy;
      expect(dy, greaterThan(previousDy), reason: label);
      previousDy = dy;
    }
    expect(find.text('Control'), findsNothing);
  });

  testWidgets('fo11/us01/s2: a Feedback page is listed under Feedback only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      WidgetbookApp(
        config: Config(
          components: orderBySection([_stub('Toast', CatalogSection.feedback)]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Toast'), findsOneWidget);
    expect(find.text('Feedback'), findsOneWidget);
    final feedbackDy = tester.getTopLeft(find.text('Feedback')).dy;
    final toastDy = tester.getTopLeft(find.text('Toast')).dy;
    expect(feedbackDy, lessThan(toastDy));
  });
}

/// [_stub] keyed by section, for the every-section test.
Component _stubByName(CatalogSection section) => _stub(section.name, section);
