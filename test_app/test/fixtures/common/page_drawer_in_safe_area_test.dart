import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart'
    show ContainerLayout, PageLayout, StratumThemeController;
import 'package:stratum_ui_test_app/fixture_app.dart';

const _fixtureId = 'common/page_drawer_in_safe_area';
const _boxId = 'page_drawer_in_safe_area.box';
const _linkAId = 'page_drawer_in_safe_area.link_a';
const _openNow = 'Open drawer';

Future<void> _openFixture(WidgetTester tester) async {
  // A phone-landscape view whose right side holds an 84 px system bar.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(466, 1000);
  tester.view.padding = const FakeViewPadding(right: 84);
  addTearDown(tester.view.reset);

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
  testWidgets('fo06/us19/fr04/e09: the host SafeArea narrows the PageLayout '
      'box to 382', (tester) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    expect(
      find.ancestor(
        of: find.byType(PageLayout),
        matching: find.byType(SafeArea),
      ),
      findsOneWidget,
    );
    const box = Rect.fromLTWH(0, 0, 382, 1000);
    expect(tester.getRect(find.byType(PageLayout)), box);
    final boxNode = find.bySemanticsIdentifier(_boxId);
    expect(boxNode, findsOneWidget);
    expect(tester.getRect(boxNode), box);
    handle.dispose();
  });

  testWidgets('fo06/us19/fr04/e09: Open drawer opens a drawer 80% of the box '
      'wide', (tester) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    await tester.tap(find.text(_openNow));
    await tester.pumpAndSettle();

    final drawer = find.ancestor(
      of: find.bySemanticsIdentifier(_linkAId),
      matching: find.byType(ContainerLayout),
    );
    expect(drawer, findsWidgets);
    expect(tester.getSize(drawer.first).width, moreOrLessEquals(305.6));
    handle.dispose();
  });
}
