@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/utility/web_zoom.stories.dart';

void main() {
  testWidgets('fo11/us03/fr02: on the web the Web zoom Playground zooms its '
      'child', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) =>
                $Playground.builder(context, $Playground.args),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('❖ content'), findsOneWidget);
  });
}
