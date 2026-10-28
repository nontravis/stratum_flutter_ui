import 'package:widgetbook/widgetbook.dart';

import 'catalog_section.dart';

/// Sorts [components] into the fixed section order (s03 INV-1), stable within
/// a section by name, so the tree lists every page under its one section
/// (fo11/us01/fr02; s03 INV-2).
///
/// Throws an [ArgumentError] naming a component whose path's first segment is
/// no section label, so a page cannot sit outside the ten sections.
List<Component> orderBySection(List<Component> components) {
  final sections = <String, int>{
    for (final section in CatalogSection.values) section.label: section.index,
  };
  // Validate every component up front: `sort` never compares a one-element
  // list, so a bad path would slip through a comparator-only check.
  for (final component in components) {
    _sectionIndex(component, sections);
  }
  return [...components]..sort((a, b) {
    final bySection = _sectionIndex(
      a,
      sections,
    ).compareTo(_sectionIndex(b, sections));
    if (bySection != 0) return bySection;
    return a.name.compareTo(b.name);
  });
}

int _sectionIndex(Component component, Map<String, int> sections) {
  final firstSegment = component.path.split('/').first;
  final index = sections[firstSegment];
  if (index == null) {
    throw ArgumentError(
      'Component "${component.name}" sits outside the ten sections: '
      '"$firstSegment" is no section label (s03 INV-2).',
    );
  }
  return index;
}
