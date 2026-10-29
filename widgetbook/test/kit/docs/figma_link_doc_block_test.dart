import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui_widgetbook/kit/docs/figma_link_doc_block.dart';
import 'package:url_launcher/link.dart';

import '../../support/knob_probe.dart';

final _figma = Uri.parse('https://www.figma.com/design/key/file?node-id=1-2');

void main() {
  testWidgets('fo11/us03/fr01/e02: the Figma link opens the component page', (
    tester,
  ) async {
    await tester.pumpWidget(probeApp(child: FigmaLinkDocBlock(_figma)));

    expect(find.text('Open in Figma'), findsOneWidget);
    final link = tester.widget<Link>(find.byType(Link));
    expect(link.uri, _figma);
    expect(link.target, LinkTarget.blank);
  });

  testWidgets('fo11/us03/fr01/e03: a widget with no Figma node shows "No Figma '
      'design" in the toolbar language', (tester) async {
    await tester.pumpWidget(
      probeApp(
        locale: const Locale('th'),
        child: const FigmaLinkDocBlock(null),
      ),
    );

    expect(find.text('ไม่มีแบบใน Figma'), findsOneWidget);
    expect(find.byType(Link), findsNothing);
  });
}
