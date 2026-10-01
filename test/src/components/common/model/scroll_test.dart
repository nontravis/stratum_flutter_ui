import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  group('StratumScroll', () {
    test('defaults to the layout axis, no stretch, and no reverse', () {
      const scroll = StratumScroll();

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
        () => StratumScroll(controller: controller, primary: true),
        throwsAssertionError,
      );
    });
  });
}
