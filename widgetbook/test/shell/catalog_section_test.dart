import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui_widgetbook/shell/catalog_section.dart';

void main() {
  test('fo11/us01/fr02: the sections read Foundation to Overlay', () {
    expect(CatalogSection.values.map((s) => s.label), [
      'Foundation',
      'Layout',
      'Utility',
      'Control',
      'Disclosure',
      'Display',
      'Feedback',
      'Form',
      'Navigation',
      'Overlay',
    ]);
  });
}
