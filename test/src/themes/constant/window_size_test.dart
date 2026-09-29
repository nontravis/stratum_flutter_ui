import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/constant/window_size.dart';

void main() {
  group('WindowSize.fromSize', () {
    const cases = [
      // Wear OS round screens and the 300 shortest-side boundary.
      (Size(192, 192), WindowSize.watch),
      (Size(240, 240), WindowSize.watch),
      (Size(299.9, 640), WindowSize.watch),
      (Size(300, 640), WindowSize.mobile),
      // Phones stay mobile in both orientations.
      (Size(393, 852), WindowSize.mobile),
      (Size(852, 393), WindowSize.mobile),
      (Size(599.9, 1000), WindowSize.mobile),
      // Tablets from a 600 shortest side, in both orientations.
      (Size(600, 960), WindowSize.tablet),
      (Size(820, 1180), WindowSize.tablet),
      (Size(1180, 820), WindowSize.tablet),
      (Size(1199.9, 800), WindowSize.tablet),
      // Width 1200 and up is desktop, whatever the shortest side.
      (Size(1200, 800), WindowSize.desktop),
      (Size(1210, 834), WindowSize.desktop),
      (Size(1280, 500), WindowSize.desktop),
      (Size(1300, 250), WindowSize.desktop),
      (Size(1599.9, 900), WindowSize.desktop),
      (Size(1600, 900), WindowSize.bigDesktop),
      (Size(1920, 1080), WindowSize.bigDesktop),
      (Size(3840, 2160), WindowSize.bigDesktop),
    ];

    for (final (size, expected) in cases) {
      test('maps $size to $expected', () {
        expect(WindowSize.fromSize(size), expected);
      });
    }
  });
  group('WindowSize comparison operators', () {
    test('>= is true for the same or a larger size only', () {
      expect(WindowSize.tablet >= WindowSize.mobile, isTrue);
      expect(WindowSize.tablet >= WindowSize.tablet, isTrue);
      expect(WindowSize.mobile >= WindowSize.tablet, isFalse);
    });

    test('> is true for a strictly larger size only', () {
      expect(WindowSize.bigDesktop > WindowSize.desktop, isTrue);
      expect(WindowSize.desktop > WindowSize.desktop, isFalse);
    });

    test('<= is true for the same or a smaller size only', () {
      expect(WindowSize.watch <= WindowSize.mobile, isTrue);
      expect(WindowSize.mobile <= WindowSize.mobile, isTrue);
      expect(WindowSize.bigDesktop <= WindowSize.desktop, isFalse);
    });

    test('< is true for a strictly smaller size only', () {
      expect(WindowSize.watch < WindowSize.mobile, isTrue);
      expect(WindowSize.watch < WindowSize.watch, isFalse);
    });
  });

  test('each is-getter matches only its own value', () {
    for (final size in WindowSize.values) {
      expect(size.isWatch, size == WindowSize.watch);
      expect(size.isMobile, size == WindowSize.mobile);
      expect(size.isTablet, size == WindowSize.tablet);
      expect(size.isDesktop, size == WindowSize.desktop);
      expect(size.isBigDesktop, size == WindowSize.bigDesktop);
    }
  });
}
