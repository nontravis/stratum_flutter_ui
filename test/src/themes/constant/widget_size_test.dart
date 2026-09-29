import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/constant/widget_size.dart';

void main() {
  test('values run from smallest to largest', () {
    expect(WidgetSize.values, [
      WidgetSize.tiny,
      WidgetSize.extraSmall,
      WidgetSize.small,
      WidgetSize.medium,
      WidgetSize.large,
      WidgetSize.extraLarge,
      WidgetSize.huge,
    ]);
  });

  group('comparison operators order sizes by value', () {
    test('<', () {
      expect(WidgetSize.small < WidgetSize.medium, isTrue);
      expect(WidgetSize.medium < WidgetSize.medium, isFalse);
      expect(WidgetSize.huge < WidgetSize.tiny, isFalse);
    });

    test('<=', () {
      expect(WidgetSize.small <= WidgetSize.medium, isTrue);
      expect(WidgetSize.medium <= WidgetSize.medium, isTrue);
      expect(WidgetSize.large <= WidgetSize.medium, isFalse);
    });

    test('>', () {
      expect(WidgetSize.huge > WidgetSize.extraLarge, isTrue);
      expect(WidgetSize.medium > WidgetSize.medium, isFalse);
      expect(WidgetSize.tiny > WidgetSize.huge, isFalse);
    });

    test('>=', () {
      expect(WidgetSize.large >= WidgetSize.medium, isTrue);
      expect(WidgetSize.medium >= WidgetSize.medium, isTrue);
      expect(WidgetSize.extraSmall >= WidgetSize.small, isFalse);
    });
  });

  test('each is-getter matches only its own value', () {
    for (final size in WidgetSize.values) {
      expect(size.isTiny, size == WidgetSize.tiny);
      expect(size.isExtraSmall, size == WidgetSize.extraSmall);
      expect(size.isSmall, size == WidgetSize.small);
      expect(size.isMedium, size == WidgetSize.medium);
      expect(size.isLarge, size == WidgetSize.large);
      expect(size.isExtraLarge, size == WidgetSize.extraLarge);
      expect(size.isHuge, size == WidgetSize.huge);
    }
  });
}
