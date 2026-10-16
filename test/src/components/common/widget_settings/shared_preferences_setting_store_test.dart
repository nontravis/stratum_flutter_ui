import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:stratum_ui/src/components/common/widget_settings/shared_preferences_setting_store.dart';

void main() {
  test('fo10/us06/s1: fo10/us06/fr01: a read returns the prefixed keys and '
      'never a host key', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          'host.theme': 'dark',
          'stratum/d/n/g/a': true,
          'stratum/u/b/n/g/a': 2,
        });
    final store = StratumSharedPreferencesSettingStore();

    expect(await store.read('stratum/d/'), {'stratum/d/n/g/a': true});
  });

  test(
    'fo10/us06/fr01: each of the five types writes and reads back',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({});
      final store = StratumSharedPreferencesSettingStore();

      await store.write('stratum/d/n/g/bool', true);
      await store.write('stratum/d/n/g/int', 2);
      await store.write('stratum/d/n/g/double', 0.4);
      await store.write('stratum/d/n/g/string', 'x');
      await store.write('stratum/d/n/g/list', ['0.4', '']);

      expect(await SharedPreferencesAsync().getAll(), {
        'stratum/d/n/g/bool': true,
        'stratum/d/n/g/int': 2,
        'stratum/d/n/g/double': 0.4,
        'stratum/d/n/g/string': 'x',
        'stratum/d/n/g/list': ['0.4', ''],
      });
    },
  );

  test(
    'fo10/us05/fr01: a removal leaves every other key, the host key included',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'host.theme': 'dark',
            'a': 0,
            'b': 1,
          });
      final store = StratumSharedPreferencesSettingStore();

      await store.remove({'a'});

      expect(await SharedPreferencesAsync().getAll(), {
        'host.theme': 'dark',
        'b': 1,
      });
    },
  );

  test('fo10/us06/fr01: an empty removal clears nothing', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({'host.theme': 'dark'});
    final store = StratumSharedPreferencesSettingStore();

    await store.remove({});

    expect(await SharedPreferencesAsync().getAll(), {'host.theme': 'dark'});
  });

  test(
    'fo10/us06/fr01: with no platform store a read throws a StateError',
    () async {
      SharedPreferencesAsyncPlatform.instance = null;
      final store = StratumSharedPreferencesSettingStore();

      expect(store.read('stratum/d/'), throwsStateError);
    },
  );

  test('fo10/us02/fr03: a value outside the five types throws and writes '
      'nothing', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({});
    final store = StratumSharedPreferencesSettingStore();

    await expectLater(
      () => store.write('stratum/d/n/g/bad', <int>[1]),
      throwsArgumentError,
    );

    expect(await SharedPreferencesAsync().getAll(), isEmpty);
  });
}
