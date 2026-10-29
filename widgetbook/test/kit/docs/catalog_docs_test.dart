import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/kit/docs/accessibility_notes_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/catalog_docs.dart';
import 'package:stratum_ui_widgetbook/kit/docs/figma_link_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/stratum_docs.dart';
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

  test('fo11/us03/fr01: the page args reach the args block', () {
    final args = <Arg<dynamic>>[StringArg('hello', name: 'label')];

    final blocks = stratumDocs(_docs, args: args)([]);

    expect(blocks.last, isA<ArgsDocBlock>());
    expect((blocks.last as ArgsDocBlock).args, args);
  });

  testWidgets('fo11/us03/fr01/e03: a stub page shows "No Figma design" in the '
      'toolbar language', (tester) async {
    await _openDocs(tester, _docs, 'th');

    expect(find.text('ไม่มีแบบใน Figma'), findsOneWidget);
    expect(find.text('No Figma design'), findsNothing);
  });

  testWidgets('fo11/us03/s1: the page shows the name, the Figma link, and the '
      'doc-comment fallback', (tester) async {
    final withFigma = CatalogDocs(
      figma: Uri.parse('https://www.figma.com/design/key/file'),
      usage: _docs.usage,
      dos: _docs.dos,
      donts: _docs.donts,
      accessibility: _docs.accessibility,
    );

    await _openDocs(tester, withFigma, 'en');

    expect(find.text('Stub'), findsWidgets);
    expect(find.text('Open in Figma'), findsOneWidget);
    expect(find.text('No documentation available.'), findsOneWidget);

    await _openDocs(tester, withFigma, 'th');

    expect(find.text('เปิดใน Figma'), findsOneWidget);
  });
}

/// Opens the docs node of a stub page built from [docs] with the toolbar
/// set to [language], and asserts the node is open.
Future<void> _openDocs(
  WidgetTester tester,
  CatalogDocs docs,
  String language,
) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final set = await loadDefaultThemeSet();
  final component = Component(
    name: 'Stub',
    path: 'Foundation',
    docsBuilder: stratumDocs(docs),
    stories: [_StubStory()],
  );
  final route = Uri(
    path: '/',
    queryParameters: {
      'path': component.docsPath,
      'locale': QueryGroup({'name': language}).toParam(),
    },
  ).toString();

  await tester.pumpWidget(
    WidgetbookApp(
      key: UniqueKey(),
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

  expect(find.byType(UsageDocBlock), findsOneWidget);
}
