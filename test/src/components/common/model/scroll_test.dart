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

    test('R1: equal fields and the same controller are equal', () {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      // Built at run time from a parameter, so the checks read `==`.
      Scroll make({required bool reverse}) =>
          Scroll(controller: controller, reverse: reverse);

      expect(make(reverse: false), make(reverse: false));
      expect(make(reverse: false).hashCode, make(reverse: false).hashCode);
      expect(make(reverse: false), isNot(make(reverse: true)));
    });

    test('R1: controllers compare by identity', () {
      final a = ScrollController();
      final b = ScrollController();
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      expect(Scroll(controller: a), isNot(Scroll(controller: b)));
    });

    test(
      'R1, fo06/us02/fr01/e01: copyWith keeps the controller and the primary '
      'assertion',
      () {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final copy = Scroll(controller: controller).copyWith(reverse: true);

        expect(copy.controller, same(controller));
        expect(copy.reverse, isTrue);
        expect(() => copy.copyWith(primary: true), throwsAssertionError);
      },
    );

    test("R4 Q2: takes freezed's toString", () {
      expect(const Scroll().toString(), startsWith('Scroll('));
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
