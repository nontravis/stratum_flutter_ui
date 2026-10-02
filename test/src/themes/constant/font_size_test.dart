import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  test('every size has its value in logical pixels and no custom entry', () {
    expect(
      {for (final size in FontSize.values) size.name: size.value},
      {
        's10': 10,
        's12': 12,
        's14': 14,
        's16': 16,
        's18': 18,
        's20': 20,
        's24': 24,
        's36': 36,
        's48': 48,
        's56': 56,
      },
    );
  });
}
