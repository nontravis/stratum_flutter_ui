/// One top-level section of the catalog tree, in the fixed display order
/// Foundation to Overlay (fo11/us01/fr02; s03 INV-1).
enum CatalogSection {
  foundation('Foundation'),
  layout('Layout'),
  utility('Utility'),
  control('Control'),
  disclosure('Disclosure'),
  display('Display'),
  feedback('Feedback'),
  form('Form'),
  navigation('Navigation'),
  overlay('Overlay');

  const CatalogSection(this.label);

  /// The section's tree-folder name, equal to the first path segment every
  /// page under it carries (s03 INV-2).
  final String label;

  /// The section whose [label] equals [segment], or null when the segment is
  /// no section label.
  static CatalogSection? fromLabel(String segment) {
    for (final section in values) {
      if (section.label == segment) return section;
    }
    return null;
  }
}
