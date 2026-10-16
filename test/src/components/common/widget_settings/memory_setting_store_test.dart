import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/widget_settings/widget_setting_store.dart';

void main() {
  test(
    'fo10/us06/fr02: a read returns only the keys under its prefix',
    () async {
      final store = StratumMemorySettingStore(
        values: {
          'stratum/d/n/g/a': 1,
          'stratum/u/b/n/g/a': 2,
          'host.theme': 'dark',
        },
      );
      expect(await store.read('stratum/d/'), {'stratum/d/n/g/a': 1});
    },
  );

  test('fo10/us06/fr02: a write and a removal touch only their keys', () async {
    final store = StratumMemorySettingStore(values: {'host.theme': 'dark'});
    await store.write('stratum/d/n/g/w', 400.0);
    await store.write('stratum/d/n/g/f', <String>['0.4', '']);
    await store.remove({'stratum/d/n/g/w'});
    expect(store.values, {
      'host.theme': 'dark',
      'stratum/d/n/g/f': ['0.4', ''],
    });
  });

  test('fo10/us06/fr02: the constructor copies its map', () {
    final seed = {'stratum/d/n/g/a': 1};
    final store = StratumMemorySettingStore(values: seed);
    seed['stratum/d/n/g/a'] = 2;
    expect(store.values, {'stratum/d/n/g/a': 1});
  });
}
