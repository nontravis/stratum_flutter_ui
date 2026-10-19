import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/model/widget_setting/widget_setting_key.dart';
import 'package:stratum_ui/src/components/common/widget_settings/setting_key_codec.dart';

void main() {
  test('fo10/us02/s1: fo10/us02/fr02/e01: a key is a fixed literal string', () {
    expect(
      storageSettingKey(
        null,
        logicalSettingKey(
          'stratum.page_layout',
          const WidgetSettingKey.id('mail'),
          'left_width',
        ),
      ),
      'stratum/d/stratum.page_layout/i/mail/left_width',
    );
    expect(
      storageSettingKey(
        'user-42',
        logicalSettingKey(
          'acme.inbox_filter',
          const WidgetSettingKey.global(),
          'unread_only',
        ),
      ),
      'stratum/u/user-42/acme.inbox_filter/g/unread_only',
    );
  });

  test(
    'RF1: fo10/us02/fr02/e02: a separator inside a segment cannot collide',
    () {
      expect(
        logicalSettingKey('a/b', const WidgetSettingKey.id('c%d'), 'e f'),
        'a%2Fb/i/c%25d/e%20f',
      );
      expect(
        storageSettingKey('a/b', 'n/g/x').startsWith(userSettingPrefix('a')),
        isFalse,
      );
      expect(userSettingPrefix('a/b'), 'stratum/u/a%2Fb/');
      expect(logicalIdPrefix('n', 'mail'), 'n/i/mail/');
      expect(logicalNamespacePrefix('n'), 'n/');
    },
  );

  test('fo10/us02/fr02: an empty segment fails an assert', () {
    expect(
      () => logicalSettingKey('', const WidgetSettingKey.global(), 'x'),
      throwsAssertionError,
    );
    expect(() => userSettingPrefix(''), throwsAssertionError);
    expect(
      () => logicalSettingKey('n', const WidgetSettingKey.id(''), 'x'),
      throwsAssertionError,
    );
  });

  test('fo10/us02/fr03: only the five storable types pass the value check', () {
    for (final v in <Object>[
      true,
      1,
      1.5,
      's',
      <String>['a'],
    ]) {
      expect(isSettingValue(v), isTrue);
    }
    expect(isSettingValue(<int>[1]), isFalse);
  });
}
