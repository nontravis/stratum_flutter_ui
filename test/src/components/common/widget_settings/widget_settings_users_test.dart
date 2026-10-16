import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/widget_settings/widget_setting_store.dart';
import 'package:stratum_ui/src/components/common/widget_settings/widget_settings_controller.dart';

import 'support/captured_reports.dart';
import 'support/counting_setting_store.dart';

void main() {
  test('fo10/us04/fr01/e04: users and the device box stay apart', () async {
    final store = CountingSettingStore();
    final settings = await StratumWidgetSettingsController.preload(
      store: store,
    );
    final part = settings.box('n').global;

    await part.setDouble('w', 1);
    await settings.switchUser('a');
    expect(part.getDouble('w'), isNull);
    await part.setDouble('w', 2);
    await settings.switchUser('b');
    expect(part.getDouble('w'), isNull);
    await settings.switchUser(null);
    expect(part.getDouble('w'), 1);
    await settings.switchUser('a');
    expect(part.getDouble('w'), 2);
    expect(
      store.values.keys,
      containsAll(['stratum/d/n/g/w', 'stratum/u/a/n/g/w']),
    );
  });

  test('fo10/us04/fr01/e01: until the swap the old user shows, then one '
      'notify', () async {
    final store = CountingSettingStore({
      'stratum/u/a/n/g/w': 4.0,
      'stratum/u/b/n/g/w': 3.0,
    });
    final settings = await StratumWidgetSettingsController.preload(
      store: store,
    );
    await settings.switchUser('a');
    final part = settings.box('n').global;
    var notifies = 0;
    settings.addListener(() => notifies++);
    final hold = store.holdNextRead();

    final switching = settings.switchUser('b');
    expect(part.getDouble('w'), 4);
    expect(notifies, 0);

    hold.complete();
    await switching;

    expect(notifies, 1);
    expect(settings.changedKeys, isNull);
    expect(part.getDouble('w'), 3);
  });

  test('fo10/us04/s2: fo10/us04/fr01/e02: of two quick switches the last one '
      'wins', () async {
    final store = CountingSettingStore({
      'stratum/u/b/n/g/w': 3.0,
      'stratum/u/c/n/g/w': 4.0,
    });
    final settings = await StratumWidgetSettingsController.preload(
      store: store,
    );
    final part = settings.box('n').global;
    var notifies = 0;
    final seen = <double?>[];
    settings.addListener(() {
      notifies++;
      seen.add(part.getDouble('w'));
    });
    final holdB = store.holdNextRead();
    final holdC = store.holdNextRead();

    final switchingB = settings.switchUser('b');
    final switchingC = settings.switchUser('c');
    holdC.complete();
    holdB.complete();
    await switchingB;
    await switchingC;

    expect(settings.userId, 'c');
    expect(part.getDouble('w'), 4);
    expect(notifies, 1);
    expect(seen, isNot(contains(3.0)));
  });

  test(
    'fo10/us04/fr01/e05: a write during a load goes to the current user',
    () async {
      final store = CountingSettingStore({'stratum/u/b/n/g/w': 3.0});
      final settings = await StratumWidgetSettingsController.preload(
        store: store,
      );
      await settings.switchUser('a');
      final part = settings.box('n').global;
      final hold = store.holdNextRead();

      final switching = settings.switchUser('b');
      final write = part.setDouble('w', 5);
      hold.complete();
      await switching;
      await write;

      expect(store.values['stratum/u/a/n/g/w'], 5.0);
      expect(part.getDouble('w'), 3.0);
    },
  );

  test('fo10/us04/fr01/e06: a failed read on a switch swaps to defaults and '
      'reports once', () async {
    final reported = captureErrorReports();
    final store = CountingSettingStore({'stratum/u/b/n/g/w': 3.0});
    final settings = await StratumWidgetSettingsController.preload(
      store: store,
    );
    store.failReads = true;

    await settings.switchUser('b');

    expect(settings.userId, 'b');
    expect(settings.box('n').global.getDouble('w'), isNull);
    expect(reported, hasLength(1));
  });

  test('fo10/us04/fr01: a switch to the current user reads nothing', () async {
    final store = CountingSettingStore();
    final settings = await StratumWidgetSettingsController.preload(
      store: store,
    );
    final reads = store.reads;

    await settings.switchUser(null);

    expect(store.reads, reads);
  });

  test(
    'fo10/us04/fr01: a disposed controller swaps and notifies nothing',
    () async {
      final store = CountingSettingStore({'stratum/u/b/n/g/w': 3.0});
      final settings = await StratumWidgetSettingsController.preload(
        store: store,
      );
      var notifies = 0;
      settings
        ..addListener(() => notifies++)
        ..dispose();

      await settings.switchUser('b');

      expect(notifies, 0);
    },
  );

  test('fo10/us04/fr02/e01: clearing a user removes only that user', () async {
    final backing = StratumMemorySettingStore(
      values: {
        'stratum/d/n/g/w': 1.0,
        'stratum/u/a/n/g/w': 2.0,
        'stratum/u/b/n/g/w': 3.0,
      },
    );
    final settings = await StratumWidgetSettingsController.preload(
      store: backing,
    );

    await settings.clearUser('b');

    expect(backing.values, {'stratum/d/n/g/w': 1.0, 'stratum/u/a/n/g/w': 2.0});
  });

  test('fo10/us04/fr02: a clear pending at dispose notifies nothing and '
      'throws nothing', () async {
    final backing = StratumMemorySettingStore(
      values: {'stratum/u/a/n/g/w': 2.0},
    );
    final settings = await StratumWidgetSettingsController.preload(
      store: backing,
    );
    await settings.switchUser('a');
    var notifies = 0;
    settings
      ..addListener(() => notifies++)
      ..dispose();

    await settings.clearUser('a');

    expect(notifies, 0);
  });

  test('fo10/us04/fr02: clearing the current user clears the shown values and '
      'notifies once', () async {
    final backing = StratumMemorySettingStore(
      values: {'stratum/u/a/n/g/w': 2.0},
    );
    final settings = await StratumWidgetSettingsController.preload(
      store: backing,
    );
    await settings.switchUser('a');
    final part = settings.box('n').global;
    expect(part.getDouble('w'), 2);
    var notifies = 0;
    Set<String>? changed;
    settings.addListener(() {
      notifies++;
      changed = settings.changedKeys;
    });

    await settings.clearUser('a');

    expect(part.getDouble('w'), isNull);
    expect(notifies, 1);
    expect(changed, {'n/g/w'});
    expect(backing.values, isEmpty);
  });
}
