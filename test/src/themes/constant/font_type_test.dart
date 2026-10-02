import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  test('lists the six text roles; mono is a modifier, not a type', () {
    expect(
      [for (final type in FontType.values) type.name],
      ['header', 'paragraph', 'number', 'code', 'body', 'table'],
    );
  });
}
