import 'package:widgetbook/widgetbook.dart';

import 'catalog_section.dart';

/// Sorts [components] into the fixed section order (s03 INV-1), stable within
/// a section by name, so the tree lists every page under its one section
/// (fo11/us01/fr02; s03 INV-2).
///
/// Throws an [ArgumentError] naming a component whose path's first segment is
/// no section label, so a page cannot sit outside the ten sections; one whose
/// path and name repeat another's; or one with two stories of one name.
/// Widgetbook's tree keeps the first node of a name and drops the second
/// without an error.
List<Component> orderBySection(List<Component> components) {
  // Validate every component up front: `sort` never compares a one-element
  // list, so a bad path would slip through a comparator-only check.
  final seen = <String>{};
  for (final component in components) {
    _sectionIndex(component);
    if (!seen.add(component.fullPath)) {
      throw ArgumentError(
        'Two pages share "${component.fullPath}": the tree keeps only the '
        'first (s03 INV-2).',
      );
    }
    final storyNames = <String>{};
    for (final story in component.stories) {
      if (!storyNames.add(story.name)) {
        throw ArgumentError(
          'Page "${component.name}" has two stories named "${story.name}": '
          'the tree keeps only the first (s03 INV-2).',
        );
      }
    }
  }
  return [...components]..sort((a, b) {
    final bySection = _sectionIndex(a).compareTo(_sectionIndex(b));
    if (bySection != 0) return bySection;
    return a.name.compareTo(b.name);
  });
}

int _sectionIndex(Component component) {
  final firstSegment = component.path.split('/').first;
  final index = CatalogSection.fromLabel(firstSegment)?.index;
  if (index == null) {
    throw ArgumentError(
      'Component "${component.name}" sits outside the ten sections: '
      '"$firstSegment" is no section label (s03 INV-2).',
    );
  }
  return index;
}
