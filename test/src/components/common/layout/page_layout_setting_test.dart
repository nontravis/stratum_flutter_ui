import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';
import '../widget_settings/support/counting_setting_store.dart';

/// The device box of `PageLayout`'s settings namespace (PD2, PD11).
const String _box = 'stratum/d/stratum.page_layout/';

/// The storage key of the left width under the global part.
const String _globalLeft = '${_box}g/left_width';

/// The storage key of the left width under the id `mail`.
const String _mailLeft = '${_box}i/mail/left_width';

const WidgetSettingKey _mailKey = WidgetSettingKey.id('mail');

/// A 1400 x 900 desktop test view, reset after the test.
void _view(WidgetTester tester, [Size size = const Size(1400, 900)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A settings controller over [store], loaded and disposed after the test.
Future<StratumWidgetSettingsController> _settings(
  CountingSettingStore store,
) async {
  final settings = await StratumWidgetSettingsController.preload(store: store);
  addTearDown(settings.dispose);
  return settings;
}

/// [child] under [settings] and the app's default Tab keys, in a focused
/// scope so the first Tab press reaches the left divider.
Widget _host(StratumWidgetSettingsController settings, Widget child) =>
    themedHost(
      StratumWidgetSettings(
        controller: settings,
        child: Shortcuts(
          shortcuts: WidgetsApp.defaultShortcuts,
          child: Actions(
            actions: WidgetsApp.defaultActions,
            child: FocusScope(autofocus: true, child: child),
          ),
        ),
      ),
    );

/// A page with a `left` inline pane and a `body`, remembering its side
/// widths under [setting]; `right` renders nothing, so the one divider
/// this page draws reads as the only "Resize panes" node.
PageLayout _page({
  WidgetSettingKey? setting,
  PageLayoutController? controller,
  String id = '',
}) => PageLayout(
  setting: setting,
  controller: controller,
  left: SizedBox.expand(key: Key('left$id')),
  body: SizedBox.expand(key: Key('body$id')),
);

double _leftWidth(WidgetTester tester, [String id = '']) =>
    tester.getSize(find.byKey(Key('left$id'))).width;

Finder get _divider => find.bySemanticsLabel('Resize panes').first;

/// An app controller starting at [left] and [right], disposed after the
/// test.
PageLayoutController _appController({double? left, double? right}) {
  final controller = PageLayoutController(leftWidth: left, rightWidth: right);
  addTearDown(controller.dispose);
  return controller;
}

/// Presses Tab, which reaches the left divider when no pane holds a Tab
/// stop.
Future<void> _tab(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
}

/// Presses [key] and lets the frame build.
Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

void main() {
  testWidgets(
    'fo10/us01/fr02/e01: the first frame shows the stored left width',
    (tester) async {
      _view(tester);
      final store = CountingSettingStore({_mailLeft: 400.0});
      final settings = await _settings(store);
      await tester.pumpWidget(_host(settings, _page(setting: _mailKey)));
      expect(_leftWidth(tester), 400);
    },
  );

  testWidgets('fo10/us01/fr03/e01: fo10/us01/fr03/e02: fo10/us01/fr03/e03: '
      'fo10/us01/fr03/e04: fo10/us01/fr03/e05: a page writes once per '
      'settled resize and never on a window resize', (tester) async {
    _view(tester);
    final store = CountingSettingStore();
    final settings = await _settings(store);
    final controller = _appController();
    await tester.pumpWidget(
      _host(settings, _page(setting: _mailKey, controller: controller)),
    );

    final gesture = await tester.startGesture(tester.getCenter(_divider));
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
    }
    expect(store.writes, 0);
    await gesture.up();
    await tester.pump();
    expect(store.writes, 1);

    await _tab(tester);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(store.writes, 2);

    tester.semantics.performAction(
      find.semantics.byLabel('Resize panes'),
      SemanticsAction.increase,
    );
    await tester.pump();
    expect(store.writes, 3);

    controller.leftWidth = 300;
    await tester.pump();
    expect(store.writes, 4);

    tester.view.physicalSize = const Size(1300, 900);
    await tester.pump();
    expect(store.writes, 4);
  });

  testWidgets('fo10/us01/s3: fo10/us01/fr02/e04: a bad stored width reads '
      'as none', (tester) async {
    _view(tester);
    for (final bad in <Object>[double.nan, double.infinity, -1.0, 'wide']) {
      final store = CountingSettingStore({_mailLeft: bad});
      final settings = await _settings(store);
      await tester.pumpWidget(_host(settings, _page(setting: _mailKey)));
      expect(_leftWidth(tester), 260, reason: '$bad');
      expect(tester.takeException(), isNull, reason: '$bad');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('RF2: a stored whole number opens the pane at that width', (
    tester,
  ) async {
    _view(tester);
    final store = CountingSettingStore({_mailLeft: 400});
    final settings = await _settings(store);
    await tester.pumpWidget(_host(settings, _page(setting: _mailKey)));
    expect(_leftWidth(tester), 400);
  });

  testWidgets('fo10/us01/fr03/e06: the clamp draws while the store keeps', (
    tester,
  ) async {
    final store = CountingSettingStore({_mailLeft: 400.0});
    final settings = await _settings(store);
    _view(tester, const Size(700, 900));
    await tester.pumpWidget(_host(settings, _page(setting: _mailKey)));
    expect(_leftWidth(tester), lessThan(400));
    expect(store.values[_mailLeft], 400.0);
    expect(store.writes, 0);

    tester.view.physicalSize = const Size(1400, 900);
    await tester.pump();
    expect(_leftWidth(tester), 400);
  });

  testWidgets('fo10/us02/fr01/e01: two pages with one id share a width', (
    tester,
  ) async {
    _view(tester);
    final store = CountingSettingStore({_mailLeft: 400.0});
    final settings = await _settings(store);
    await tester.pumpWidget(
      _host(
        settings,
        Column(
          children: [
            Expanded(
              child: _page(setting: _mailKey, id: '1'),
            ),
            Expanded(
              child: _page(setting: _mailKey, id: '2'),
            ),
          ],
        ),
      ),
    );
    expect(_leftWidth(tester, '1'), 400);
    expect(_leftWidth(tester, '2'), 400);
  });

  testWidgets('fo10/us02/fr01/e02: one id on a page and a split stays apart', (
    tester,
  ) async {
    _view(tester);
    final store = CountingSettingStore({_mailLeft: 400.0});
    final settings = await _settings(store);
    await tester.pumpWidget(
      _host(
        settings,
        Column(
          children: [
            Expanded(child: _page(setting: _mailKey)),
            const Expanded(
              child: SplitLayout(
                setting: _mailKey,
                panes: [
                  SplitPane(size: 300, min: 200, max: 500, child: Text('List')),
                  SplitPane(flex: 1, min: 300, child: Text('Detail')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    expect(_leftWidth(tester), 400);
    expect(tester.getSize(find.text('List')).width, 300);
  });

  testWidgets(
    'fo10/us01/fr01/e01: a page with no setting reads and writes nothing',
    (tester) async {
      _view(tester);
      final store = CountingSettingStore({_globalLeft: 400.0});
      final settings = await _settings(store);
      await tester.pumpWidget(_host(settings, _page()));
      expect(_leftWidth(tester), 260);

      await _tab(tester);
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(store.writes, 0);
      final resized = _leftWidth(tester);

      await settings
          .box('stratum.page_layout')
          .global
          .setDouble('left_width', 380);
      await tester.pump();
      expect(_leftWidth(tester), resized);
    },
  );

  testWidgets(
    'fo10/us01/fr02/e02: a stored width wins over the app controller, '
    'else the app width shows',
    (tester) async {
      _view(tester);
      final stored = CountingSettingStore({_mailLeft: 400.0});
      final controller = _appController(left: 300);
      await tester.pumpWidget(
        _host(
          await _settings(stored),
          _page(setting: _mailKey, controller: controller),
        ),
      );
      expect(_leftWidth(tester), 400);
      expect(controller.leftWidth, 400);

      await tester.pumpWidget(const SizedBox());
      final empty = CountingSettingStore();
      final second = _appController(left: 300);
      await tester.pumpWidget(
        _host(
          await _settings(empty),
          _page(setting: _mailKey, controller: second),
        ),
      );
      expect(_leftWidth(tester), 300);
      expect(empty.writes, 0);

      await tester.pumpWidget(const SizedBox());
      final leftOnly = CountingSettingStore({_mailLeft: 400.0});
      final third = _appController(right: 300);
      await tester.pumpWidget(
        _host(
          await _settings(leftOnly),
          _page(setting: _mailKey, controller: third),
        ),
      );
      expect(third.rightWidth, 300);
    },
  );

  testWidgets(
    'fo10/us01/fr01/e02: fo10/us01/fr01/e03: a new key re-reads, an empty '
    'key keeps the size, null stops saving',
    (tester) async {
      _view(tester);
      final store = CountingSettingStore({
        _globalLeft: 400.0,
        _mailLeft: 350.0,
      });
      final settings = await _settings(store);
      final controller = _appController();
      await tester.pumpWidget(
        _host(
          settings,
          _page(
            setting: const WidgetSettingKey.global(),
            controller: controller,
          ),
        ),
      );
      expect(_leftWidth(tester), 400);

      await tester.pumpWidget(
        _host(settings, _page(setting: _mailKey, controller: controller)),
      );
      expect(_leftWidth(tester), 350);

      await tester.pumpWidget(
        _host(
          settings,
          _page(
            setting: const WidgetSettingKey.id('none'),
            controller: controller,
          ),
        ),
      );
      expect(_leftWidth(tester), 350);
      expect(store.writes, 0);

      await tester.pumpWidget(_host(settings, _page(controller: controller)));
      controller.leftWidth = 320;
      await tester.pump();
      expect(_leftWidth(tester), 320);
      expect(store.writes, 0);
    },
  );

  testWidgets('fo10/us01/fr02: a new app controller takes the stored width', (
    tester,
  ) async {
    _view(tester);
    final store = CountingSettingStore({_mailLeft: 400.0});
    final settings = await _settings(store);
    await tester.pumpWidget(
      _host(settings, _page(setting: _mailKey, controller: _appController())),
    );
    final swapped = _appController(left: 300);
    await tester.pumpWidget(
      _host(settings, _page(setting: _mailKey, controller: swapped)),
    );
    expect(swapped.leftWidth, 400);
    expect(_leftWidth(tester), 400);
  });

  testWidgets(
    'RF3: an app listener on its own controller sees no build-time notify',
    (tester) async {
      _view(tester);
      final store = CountingSettingStore({_mailLeft: 400.0});
      final settings = await _settings(store);
      final controller = _appController();
      await tester.pumpWidget(
        _host(
          settings,
          Column(
            children: [
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) => Text('width ${controller.leftWidth}'),
              ),
              Expanded(
                child: _page(setting: _mailKey, controller: controller),
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(controller.leftWidth, 400);
    },
  );
}
