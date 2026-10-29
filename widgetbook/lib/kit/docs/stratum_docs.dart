import 'package:stratum_ui_widgetbook/kit/docs/accessibility_notes_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/catalog_docs.dart';
import 'package:stratum_ui_widgetbook/kit/docs/figma_link_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/usage_doc_block.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

/// Returns the docs node of a component page in the order of s03 INV-3.
///
/// Pass the page's Playground args as [args].
DocsBuilderFunction stratumDocs(
  CatalogDocs docs, {
  List<Arg<dynamic>> args = const [],
}) =>
    (_) => [
      const ComponentNameDocBlock(),
      FigmaLinkDocBlock(docs.figma),
      const DartCommentDocBlock(),
      UsageDocBlock(docs),
      AccessibilityNotesDocBlock(docs.accessibility),
      ArgsDocBlock(args: args),
    ];
