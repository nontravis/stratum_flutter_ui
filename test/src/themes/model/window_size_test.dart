import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/model/window_size.dart';

void main() {
  group('WindowSize.fromWidth', () {
    const cases = [
      (0.0, WindowSize.compact),
      (599.9, WindowSize.compact),
      (600.0, WindowSize.medium),
      (839.9, WindowSize.medium),
      (840.0, WindowSize.expanded),
      (1199.9, WindowSize.expanded),
      (1200.0, WindowSize.large),
      (1599.9, WindowSize.large),
      (1600.0, WindowSize.extraLarge),
      (3840.0, WindowSize.extraLarge),
    ];

    for (final (width, expected) in cases) {
      test('maps $width to $expected', () {
        expect(WindowSize.fromWidth(width), expected);
      });
    }
  });
  group('WindowSize comparison operators', () {
    test('>= is true for the same or a larger size only', () {
      expect(WindowSize.expanded >= WindowSize.medium, isTrue);
      expect(WindowSize.expanded >= WindowSize.expanded, isTrue);
      expect(WindowSize.medium >= WindowSize.expanded, isFalse);
    });

    test('> is true for a strictly larger size only', () {
      expect(WindowSize.large > WindowSize.expanded, isTrue);
      expect(WindowSize.large > WindowSize.large, isFalse);
    });

    test('<= is true for the same or a smaller size only', () {
      expect(WindowSize.compact <= WindowSize.medium, isTrue);
      expect(WindowSize.medium <= WindowSize.medium, isTrue);
      expect(WindowSize.extraLarge <= WindowSize.large, isFalse);
    });

    test('< is true for a strictly smaller size only', () {
      expect(WindowSize.compact < WindowSize.medium, isTrue);
      expect(WindowSize.compact < WindowSize.compact, isFalse);
    });
  });
}
