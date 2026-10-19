import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  group('SpaceDirectional', () {
    test('fo06/us13/fr02: insetStart16 resolves to the right under '
        'right-to-left text and to the left under left-to-right text', () {
      final start = SpaceDirectional.insetStart16;

      expect(
        start.resolve(TextDirection.rtl),
        const EdgeInsets.only(right: 16),
      );
      expect(start.resolve(TextDirection.ltr), const EdgeInsets.only(left: 16));
    });
  });
}
