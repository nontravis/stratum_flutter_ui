import 'package:stratum_ui_widgetbook/kit/docs/accessibility_notes_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/figma_link_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/usage_doc_block.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

/// The hand-written docs of one component page (fo11/us03/fr01).
final class CatalogDocs {
  const CatalogDocs({
    required this.figma,
    required this.usage,
    required this.dos,
    required this.donts,
    required this.accessibility,
  });

  /// The component's Figma page, or null exactly when it has no Figma node.
  final Uri? figma;

  /// Code that compiles against the package barrel, shown copyable.
  final String usage;

  final List<String> dos;
  final List<String> donts;

  /// One line per accessibility note.
  final List<String> accessibility;
}

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
