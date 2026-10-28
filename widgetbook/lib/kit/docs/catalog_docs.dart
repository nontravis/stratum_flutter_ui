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
