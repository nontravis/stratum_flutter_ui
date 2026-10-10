import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  group('Scroll', () {
    test('defaults to the layout axis, no stretch, and no reverse', () {
      const scroll = Scroll();

      expect(scroll.direction, isNull);
      expect(scroll.fillViewport, isFalse);
      expect(scroll.reverse, isFalse);
      expect(scroll.primary, isNull);
      expect(scroll.showScrollbar, isNull);
    });

    test('a controller with primary: true fails its assertion', () {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      expect(
        () => Scroll(controller: controller, primary: true),
        throwsAssertionError,
      );
    });
  });

  group('renames', () {
    test('renames: a StratumScroll is a Scroll', () {
      // Testing the deprecated alias itself, so ignore the deprecation
      // warning.
      // ignore: deprecated_member_use_from_same_package
      const scroll = StratumScroll(reverse: true);

      expect(scroll, isA<Scroll>());
      expect(scroll.reverse, isTrue);
    });
  });
}
