import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/kit/docs/accessibility_notes_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/catalog_docs.dart';
import 'package:stratum_ui_widgetbook/kit/docs/figma_link_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/usage_doc_block.dart';
import 'package:stratum_ui_widgetbook/shell/catalog_config.dart';
import 'package:widgetbook/src/core/widgetbook_app.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../../support/catalog_theme.dart';

const _docs = CatalogDocs(
  figma: null,
  usage: 'Stub()',
  dos: ['Keep it short'],
  donts: ['Nest it'],
  accessibility: ['Reads as a button'],
);

class _NoArgs extends StoryArgs<_Stub> {
  const _NoArgs();

  @override
  List<Arg?> get list => const [];
}

class _Stub extends StatelessWidget {
  const _Stub();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _StubStory extends Story<_Stub, _NoArgs> {
  _StubStory()
    : super(name: 'Story', args: const _NoArgs(), builder: (_, _) => _Stub());
}

void main() {
  test('fo11/us03/fr01: the docs open in the INV-3 order', () {
    final blocks = stratumDocs(_docs)([]);

    expect(blocks.map((b) => b.runtimeType), [
      ComponentNameDocBlock,
      FigmaLinkDocBlock,
      DartCommentDocBlock,
      UsageDocBlock,
      AccessibilityNotesDocBlock,
      ArgsDocBlock,
    ]);
  });

  testWidgets('fo11/us03/fr01/e03: a stub page shows "No Figma design" in the '
      'toolbar language', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final set = await loadDefaultThemeSet();
    final component = Component(
      name: 'Stub',
      path: 'Foundation',
      docsBuilder: stratumDocs(_docs),
      stories: [_StubStory()],
    );
    final route = Uri(
      path: '/',
      queryParameters: {
        'path': component.docsPath,
        'locale': QueryGroup({'name': 'th'}).toParam(),
      },
    ).toString();

    await tester.pumpWidget(
      WidgetbookApp(
        config: Config(
          components: catalogConfig(
            components: [component],
            themes: {'default': set},
          ).components,
          addons: catalogAddons({'default': set}),
          initialRoute: route,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Precondition: the docs node is open.
    expect(find.byType(UsageDocBlock), findsOneWidget);
    expect(find.text('ไม่มีแบบใน Figma'), findsOneWidget);
    expect(find.text('No Figma design'), findsNothing);
  });
}
