import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/shell/stage_addon.dart';

/// Builds the stage around [child], the way Widgetbook applies an addon.
Widget _staged(Widget child) => MaterialApp(
  home: Builder(builder: (context) => StageAddon().apply(context, child, null)),
);

void main() {
  test('fo11/us02/fr01: the stage has no field, so the toolbar leaves it '
      'off', () {
    expect(StageAddon().fields, isEmpty);
  });

  testWidgets('fo11/us02/fr01: an overlay entry a story inserts builds on '
      'the stage', (tester) async {
    final story = GlobalKey();
    await tester.pumpWidget(_staged(SizedBox(key: story)));

    final stage = tester.state<NavigatorState>(find.byType(Navigator).last);
    expect(Overlay.of(story.currentContext!), same(stage.overlay));
  });

  testWidgets('fo11/us02/fr01: the stage shows the story of its latest '
      'build', (tester) async {
    await tester.pumpWidget(_staged(const Text('first')));
    await tester.pumpWidget(_staged(const Text('second')));

    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
  });
}
