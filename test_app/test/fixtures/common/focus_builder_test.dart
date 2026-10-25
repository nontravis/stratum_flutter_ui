import 'package:flutter/rendering.dart' show MatrixUtils;
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart' show StratumThemeController;
import 'package:stratum_ui_test_app/fixture_app.dart';

const _fixtureId = 'common/focus_builder';
const _headingId = 'focus_builder.heading';
const _group = 'ที่อยู่จัดส่ง';
const _field = 'ถนน';

Future<void> _openFixture(WidgetTester tester) async {
  // The theme preload reads assets, which needs real time, not fake async.
  final controller = await tester.runAsync(
    () => StratumThemeController.preload(googleFontsTimeout: Duration.zero),
  );
  addTearDown(controller!.dispose);
  await tester.pumpWidget(
    FixtureApp(fixtureId: _fixtureId, themeController: controller),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the heading is found by its id', (tester) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    expect(find.bySemanticsIdentifier(_headingId), findsOneWidget);
    expect(find.text('Delivery form'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the group label and the street field read at one stop, the '
      'group label first', (tester) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    final node = tester.getSemantics(find.bySemanticsLabel(RegExp(_group)));

    // The group label first, then the field's, in one node.
    expect(node.label, '$_group\n$_field');
    expect(
      node.getSemanticsData().flagsCollection.isTextField,
      isTrue,
      reason: 'the stop is the street text field',
    );
    // No stop of its own for the street field.
    expect(find.bySemanticsLabel(RegExp('^$_field\$')), findsNothing);
    handle.dispose();
  });

  testWidgets('the heading sits above the group', (tester) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    final heading = tester.getSemantics(find.bySemanticsIdentifier(_headingId));
    final group = tester.getSemantics(find.bySemanticsLabel(RegExp(_group)));

    expect(_globalRect(heading).top, lessThan(_globalRect(group).top));
    handle.dispose();
  });
}

/// [node]'s rect in the root's coordinates, through every ancestor transform.
Rect _globalRect(SemanticsNode node) {
  var rect = node.rect;
  for (SemanticsNode? up = node; up != null; up = up.parent) {
    final transform = up.transform;
    if (transform != null) rect = MatrixUtils.transformRect(transform, rect);
  }
  return rect;
}
