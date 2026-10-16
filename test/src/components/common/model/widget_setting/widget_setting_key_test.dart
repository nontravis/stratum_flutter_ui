import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/model/widget_setting/widget_setting_key.dart';

void main() {
  test('fo10/us02/fr01: a key is the global part or one id, by value', () {
    final a = WidgetSettingKey.id(['ma', 'il'].join());
    final b = WidgetSettingKey.id(['ma', 'il'].join());
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(const WidgetSettingKey.global(), const WidgetSettingKey.global());
    expect(a, isNot(const WidgetSettingKey.id('inbox')));
    expect(a, isNot(const WidgetSettingKey.global()));
  });
}
