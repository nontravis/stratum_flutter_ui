import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:stratum_ui/src/components/common/widget_settings/shared_preferences_setting_store.dart';
import 'package:stratum_ui/src/components/common/widget_settings/widget_setting_store.dart';
import 'package:stratum_ui/src/components/common/widget_settings/widget_settings_controller.dart';

import 'support/counting_setting_store.dart';
import 'support/setting_controller_contract.dart';

void main() {
  settingControllerContract(
    'fo10/us06/fr02/e01',
    'memory',
    (seed) => StratumMemorySettingStore(values: seed),
  );
  settingControllerContract('fo10/us06/fr01/e01', 'shared_preferences', (seed) {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData(seed);
    return StratumSharedPreferencesSettingStore();
  });

  test('fo10/us05/s1: fo10/us05/fr01/e01: reset-all keeps the host key and '
      'another user', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          'host.theme': 'dark',
          'stratum/u/b/stratum.page_layout/g/left_width': 300.0,
          'stratum/d/stratum.page_layout/g/left_width': 400.0,
          'stratum/d/stratum.page_layout/i/mail/left_width': 410.0,
          'stratum/d/acme.inbox/g/unread_only': true,
        });
    final settings = await StratumWidgetSettingsController.preload();

    await settings.resetAll();

    expect(await SharedPreferencesAsync().getAll(), {
      'host.theme': 'dark',
      'stratum/u/b/stratum.page_layout/g/left_width': 300.0,
    });
  });

  test('fo10/us05/fr01/e02: reset by id clears only that id', () async {
    final backing = StratumMemorySettingStore(
      values: {
        'stratum/d/stratum.page_layout/g/left_width': 400.0,
        'stratum/d/stratum.page_layout/i/mail/left_width': 410.0,
      },
    );
    final settings = await StratumWidgetSettingsController.preload(
      store: backing,
    );

    await settings.resetId('stratum.page_layout', 'mail');

    expect(backing.values, {
      'stratum/d/stratum.page_layout/g/left_width': 400.0,
    });
  });

  test('fo10/us05/fr01/e03: reset by type clears only that type', () async {
    final backing = StratumMemorySettingStore(
      values: {
        'stratum/d/stratum.page_layout/g/left_width': 400.0,
        'stratum/d/stratum.page_layout/i/mail/left_width': 410.0,
        'stratum/d/acme.inbox/g/unread_only': true,
      },
    );
    final settings = await StratumWidgetSettingsController.preload(
      store: backing,
    );

    await settings.resetType('stratum.page_layout');

    expect(backing.values, {'stratum/d/acme.inbox/g/unread_only': true});
  });

  test(
    'fo10/us02/fr01/e03: the global part and an id part stay apart',
    () async {
      final settings = await StratumWidgetSettingsController.preload(
        store: StratumMemorySettingStore(),
      );
      final box = settings.box('acme.inbox');

      await box.global.setDouble('w', 1);
      expect(box.id('mail').getDouble('w'), isNull);

      await box.id('mail').setDouble('w', 2);
      expect(box.global.getDouble('w'), 1);
      expect(box.id('mail').getDouble('w'), 2);
    },
  );

  test('RF2: fo10/us02/fr03/e02: a whole number reads as a double', () async {
    final settings = await StratumWidgetSettingsController.preload(
      store: StratumMemorySettingStore(
        values: {'stratum/d/acme.inbox/g/w': 400},
      ),
    );
    final part = settings.box('acme.inbox').global;

    expect(part.getDouble('w'), 400.0);

    await part.setDouble('w', 400.5);
    expect(part.getInt('w'), isNull);
  });

  test('fo10/us03/fr03/e01: a failed write keeps the session value and '
      'reports once', () async {
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
    final store = CountingSettingStore();
    final settings = await StratumWidgetSettingsController.preload(
      store: store,
    );
    final part = settings.box('acme.inbox').global;
    store.failWrites = true;

    await part.setDouble('w', 400);

    expect(part.getDouble('w'), 400);
    expect(reported.single.library, 'stratum_ui');
  });

  test('fo10/us03/s2: fo10/us03/fr03/e02: a failed read at load gives '
      'defaults and one report', () async {
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
    final store = CountingSettingStore({'stratum/d/acme.inbox/g/w': 1.0})
      ..failReads = true;

    final settings = await StratumWidgetSettingsController.preload(
      store: store,
    );

    expect(settings.isLoaded, isTrue);
    expect(settings.box('acme.inbox').global.getDouble('w'), isNull);
    expect(reported, hasLength(1));
  });

  test('fo10/us06/s2: fo10/us06/fr01/e02: no platform store gives defaults '
      'and one report', () async {
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
    SharedPreferencesAsyncPlatform.instance = null;

    final settings = await StratumWidgetSettingsController.preload();

    expect(settings.isLoaded, isTrue);
    expect(reported.single.exception, isA<StateError>());
  });

  test('fo10/us05/s2: fo10/us05/fr01/e04: a failed removal keeps the reset '
      'and reports once', () async {
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
    final store = CountingSettingStore({'stratum/d/acme.inbox/g/w': 1.0});
    final settings = await StratumWidgetSettingsController.preload(
      store: store,
    );
    store.failRemoves = true;

    await settings.resetAll();

    expect(settings.box('acme.inbox').global.getDouble('w'), isNull);
    expect(reported, hasLength(1));
  });

  test('fo10/us03/fr02/e01: a read before load fails a debug assert', () {
    final settings = StratumWidgetSettingsController(
      store: StratumMemorySettingStore(),
    );

    expect(
      () => settings.box('n').global.getBool('a'),
      throwsA(
        isA<AssertionError>().having(
          (error) => error.message,
          'message',
          contains('before load'),
        ),
      ),
    );
  });

  test('fo10/us02/fr03: an equal write neither notifies nor writes', () async {
    final store = CountingSettingStore();
    final settings = await StratumWidgetSettingsController.preload(
      store: store,
    );
    final part = settings.box('acme.inbox').global;
    var notifies = 0;
    settings.addListener(() => notifies++);

    await part.setDouble('w', 400);
    await part.setDouble('w', 400);

    expect(store.writes, 1);
    expect(notifies, 1);
  });

  test(
    'fo10/us02/fr04: a write marks exactly its logical key changed',
    () async {
      final settings = await StratumWidgetSettingsController.preload(
        store: StratumMemorySettingStore(),
      );
      Set<String>? changed;
      settings.addListener(() => changed = settings.changedKeys);

      await settings.box('acme.inbox').global.setDouble('w', 1);

      expect(changed, {'acme.inbox/g/w'});
    },
  );

  test(
    'fo10/us05/fr01: a reset after a write removes it from the store',
    () async {
      final backing = StratumMemorySettingStore();
      final settings = await StratumWidgetSettingsController.preload(
        store: backing,
      );

      unawaited(settings.box('acme.inbox').global.setDouble('w', 1));
      await settings.resetAll();

      expect(backing.values, isEmpty);
    },
  );
}
