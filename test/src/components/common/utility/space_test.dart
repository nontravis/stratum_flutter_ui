import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  group('Space', () {
    test('fo06/us13/fr01, fo06/us13/s1, fo06/us13/s3: a 16 px box and gap take '
        '16 px, insetAll16 equals EdgeInsets.all(16), and the any-value '
        'constructor keeps a step outside the fixed set', () {
      final box = Space.box16 as SizedBox;
      expect(box.width, 16.0);
      expect(box.height, 16.0);

      final gap = Space.gap16 as Gap;
      expect(gap.mainAxisExtent, 16.0);

      expect(Space.insetAll16, const EdgeInsets.all(16));
      expect(Space.insetOnly(left: 3), const EdgeInsets.only(left: 3));
    });
  });
}
