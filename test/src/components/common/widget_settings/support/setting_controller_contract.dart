import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/widget_settings/widget_setting_store.dart';
import 'package:stratum_ui/src/components/common/widget_settings/widget_settings_controller.dart';

/// Runs the [StratumWidgetSettingStore] contract (US-06 FR-01, FR-02) that
/// both the default store and the in-memory store must meet, over [make]'s
/// store seeded with raw storage entries.
///
/// [tag] and [store] name the group; each store under test runs this once.
void settingControllerContract(
  String tag,
  String store,
  StratumWidgetSettingStore Function(Map<String, Object> seed) make,
) {
  group('$tag: $store contract', () {
    test('read after write: the five types read back equal', () async {
      final backing = make({});
      final writer = await StratumWidgetSettingsController.preload(
        store: backing,
      );
      final writerPart = writer.box('acme.inbox').global;
      await writerPart.setBool('on', true);
      await writerPart.setInt('count', 2);
      await writerPart.setDouble('w', 400.0);
      await writerPart.setString('label', 'x');
      await writerPart.setStringList('tags', ['a', 'b']);

      final reader = await StratumWidgetSettingsController.preload(
        store: backing,
      );
      final readerPart = reader.box('acme.inbox').global;
      expect(readerPart.getBool('on'), isTrue);
      expect(readerPart.getInt('count'), 2);
      expect(readerPart.getDouble('w'), 400.0);
      expect(readerPart.getString('label'), 'x');
      expect(readerPart.getStringList('tags'), ['a', 'b']);
    });

    test(
      'fo10/us02/s2: fo10/us02/fr03/e01: another type reads as none',
      () async {
        final controller = await StratumWidgetSettingsController.preload(
          store: make({}),
        );
        final part = controller.box('acme.inbox').global;

        await part.setString('w', 'x');
        expect(part.getDouble('w'), isNull);

        await part.setInt('w', 1);
        expect(part.getBool('w'), isNull);

        await part.setString('w', 'x');
        expect(part.getStringList('w'), isNull);

        await part.setStringList('w', ['a']);
        expect(part.getString('w'), isNull);
      },
    );

    test(
      'prefix isolation: a host key and another user key stay put',
      () async {
        final backing = make({
          'host.theme': 'dark',
          'stratum/u/b/acme.inbox/g/w': 2.0,
        });
        final controller = await StratumWidgetSettingsController.preload(
          store: backing,
        );

        expect(controller.box('acme.inbox').global.getDouble('w'), isNull);

        await controller.resetAll();

        expect(await backing.read(''), {
          'host.theme': 'dark',
          'stratum/u/b/acme.inbox/g/w': 2.0,
        });
      },
    );

    test('reset scopes: by id, by type, and all', () async {
      final backing = make({});
      final controller = await StratumWidgetSettingsController.preload(
        store: backing,
      );
      final inbox = controller.box('acme.inbox');
      final other = controller.box('acme.other');
      await inbox.global.setDouble('w', 1);
      await inbox.id('mail').setDouble('w', 2);
      await inbox.id('team').setDouble('w', 3);
      await other.global.setDouble('w', 4);

      await controller.resetId('acme.inbox', 'mail');
      expect(inbox.id('mail').getDouble('w'), isNull);
      expect(inbox.global.getDouble('w'), 1);
      expect(inbox.id('team').getDouble('w'), 3);
      expect(other.global.getDouble('w'), 4);

      await controller.resetType('acme.inbox');
      expect(inbox.global.getDouble('w'), isNull);
      expect(inbox.id('team').getDouble('w'), isNull);
      expect(other.global.getDouble('w'), 4);

      await controller.resetAll();
      expect(other.global.getDouble('w'), isNull);
    });
  });
}
