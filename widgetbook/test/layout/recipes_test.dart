import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/layout/recipes.dart';

import '../support/catalog_theme.dart';

/// Pumps [child] under the default theme on a 1000 by 800 surface.
Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1000, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final themes = await loadDefaultThemeSet();
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en')],
      home: StratumThemeApplication(
        themes: themes,
        themeMode: ThemeMode.light,
        child: child,
      ),
    ),
  );
}

/// The widget [recipe]'s `build` returns, read from its configuration.
Widget _built(WidgetTester tester, Type recipe) {
  final element = tester.element(find.byType(recipe));
  // ignore: invalid_use_of_protected_member, the test reads the configuration `build` returns, not the element tree.
  return (element.widget as StatelessWidget).build(element);
}

/// Every widget configuration under [node] that a recipe holds, found through
/// the `child`, `children`, and slot arguments of the layouts.
Iterable<Widget> _configuration(Widget? node) sync* {
  if (node == null) return;
  yield node;
  final next = switch (node) {
    ContainerLayout(:final child) => [child],
    FlexLayout(:final children) => children,
    PageLayout() => [
      node.header,
      node.left,
      node.top,
      node.tab,
      node.body,
      node.bottom,
      node.right,
      node.footer,
      node.snack,
    ],
    _ => const <Widget?>[],
  };
  for (final child in next) {
    yield* _configuration(child);
  }
}

/// The names of the slot placeholders under [node].
List<String> _slotNames(Widget node) => [
  for (final widget in _configuration(node))
    if (widget is StratumSlot) widget.name,
];

/// Whether [node] is a layout or a slot placeholder.
bool _isLayoutOrSlot(Widget node) =>
    node is StratumSlot || node is BoxLayout || node is PageLayout;

void main() {
  final recipes = <String, ({Widget recipe, List<String> slots})>{
    'form row': (recipe: const FormRowRecipe(), slots: ['label', 'field']),
    'card': (
      recipe: const CardRecipe(),
      slots: ['media', 'title', 'body', 'action'],
    ),
    'list item': (
      recipe: const ListItemRecipe(),
      slots: ['leading', 'title', 'subtitle', 'trailing'],
    ),
    'toolbar': (
      recipe: const ToolbarRecipe(),
      slots: ['leading', 'title', 'actions'],
    ),
    'page with drawer': (
      recipe: const PageWithDrawerRecipe(),
      slots: ['header', 'drawer', 'body'],
    ),
  };

  for (final entry in recipes.entries) {
    testWidgets('fo11/us06/fr02: the ${entry.key} recipe holds only layouts '
        'and named slots', (tester) async {
      await _pump(tester, entry.value.recipe);

      final built = _built(tester, entry.value.recipe.runtimeType);
      final nodes = _configuration(built).toList();

      expect(
        nodes.where((node) => !_isLayoutOrSlot(node)),
        isEmpty,
        reason: 'every node is a layout or a StratumSlot',
      );
      expect(_slotNames(built), entry.value.slots);
      for (final name in entry.value.slots) {
        expect(find.text('❖ $name'), findsOneWidget);
      }
    });
  }

  testWidgets('fo11/us06/fr02: the card recipe sits in a Card styled box', (
    tester,
  ) async {
    await _pump(tester, const CardRecipe());

    final built = _built(tester, CardRecipe) as ContainerLayout;
    expect(built.style?.backgroundColor, isNotNull);
    expect(built.child, isA<ColumnLayout>());
  });

  testWidgets('fo11/us06/s2: the five recipes show', (tester) async {
    await _pump(
      tester,
      ColumnLayout(
        children: [
          const FormRowRecipe(),
          const CardRecipe(),
          const ListItemRecipe(),
          const ToolbarRecipe(),
          SizedBox(height: 300, child: const PageWithDrawerRecipe()),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(StratumSlot), findsNWidgets(2 + 4 + 4 + 3 + 3));
  });
}
