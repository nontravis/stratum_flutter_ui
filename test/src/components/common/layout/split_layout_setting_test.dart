import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';
import '../widget_settings/support/counting_setting_store.dart';

/// The device box of `SplitLayout`'s settings namespace (PD2, PD11).
const String _box = 'stratum/d/stratum.split_layout/';

/// The storage key of the fractions under the id `mail`.
const String _mail = '${_box}i/mail/fractions';

const WidgetSettingKey _mailKey = WidgetSettingKey.id('mail');

/// A 1000 x 400 test view, so a 300 px list pane is 30% of the split;
/// reset after the test.
void _view(WidgetTester tester, [Size size = const Size(1000, 400)]) {
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
/// scope so the first Tab press reaches the first divider.
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

/// A list pane showing [list], 300 px from 200 to 500, beside a detail pane
/// of at least 300 px, then [extra].
SplitLayout _split({
  WidgetSettingKey? setting,
  SplitLayoutController? controller,
  bool resizable = true,
  String list = 'List',
  SplitPane? extra,
}) => SplitLayout(
  setting: setting,
  controller: controller,
  resizable: resizable,
  panes: [
    SplitPane(size: 300, min: 200, max: 500, child: Text(list)),
    const SplitPane(flex: 1, min: 300, child: Text('Detail')),
    ?extra,
  ],
);

double _listWidth(WidgetTester tester, [String list = 'List']) =>
    tester.getSize(find.text(list)).width;

Finder get _divider => find.bySemanticsLabel('Resize panes');

/// An app controller starting at [fractions], disposed after the test.
SplitLayoutController _appController([List<double?>? fractions]) {
  final controller = SplitLayoutController(fractions: fractions);
  addTearDown(controller.dispose);
  return controller;
}

/// Presses Tab, which reaches the first divider when no pane holds a Tab
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

/// Expects the stored fractions to be one text per pane of the two panes
/// whose numbers sum to the whole split.
void _expectStoredWhole(CountingSettingStore store) {
  final stored = store.values[_mail];
  expect(stored, isA<List<String>>().having((l) => l.length, 'length', 2));
  final sum = (stored! as List<String>).fold(
    0.0,
    (total, entry) => total + double.parse(entry),
  );
  expect(sum, closeTo(1, 1e-9));
}

void main() {
  testWidgets(
    'fo10/us01/s1: fo10/us01/fr02/e01: the first frame shows the stored '
    'fractions',
    (tester) async {
      _view(tester);
      final store = CountingSettingStore({
        _mail: ['0.4', '0.6'],
      });
      final settings = await _settings(store);
      await tester.pumpWidget(_host(settings, _split(setting: _mailKey)));
      expect(_listWidth(tester), 400);
    },
  );

  testWidgets('fo10/us01/s3: fo10/us01/fr02/e04: a bad stored list reads as '
      'none', (tester) async {
    _view(tester);
    for (final bad in <Object>[
      ['NaN', ''],
      ['Infinity', ''],
      ['-1', ''],
      ['0.4'],
      '0.4',
    ]) {
      final store = CountingSettingStore({_mail: bad});
      final settings = await _settings(store);
      await tester.pumpWidget(_host(settings, _split(setting: _mailKey)));
      expect(_listWidth(tester), 300, reason: '$bad');
      expect(tester.takeException(), isNull, reason: '$bad');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('fo10/us01/fr02/e02: fo10/us01/fr02/e03: stored fractions '
      'replace the app list whole', (tester) async {
    _view(tester);
    final stored = CountingSettingStore({
      _mail: ['', '0.6'],
    });
    final controller = _appController([0.5, null]);
    await tester.pumpWidget(
      _host(
        await _settings(stored),
        _split(setting: _mailKey, controller: controller),
      ),
    );
    expect(controller.fractions, [null, 0.6]);

    await tester.pumpWidget(const SizedBox());
    final empty = CountingSettingStore();
    final second = _appController([0.5, null]);
    await tester.pumpWidget(
      _host(
        await _settings(empty),
        _split(setting: _mailKey, controller: second),
      ),
    );
    await tester.pump();
    expect(second.fractions, [0.5, null]);
    expect(empty.writes, 0);
  });

  testWidgets('fo10/us01/fr03/e01: fo10/us01/fr03/e02: fo10/us01/fr03/e03: '
      'fo10/us01/fr03/e04: fo10/us01/fr03/e05: '
      'a split writes once per settled move and never on a resize', (
    tester,
  ) async {
    _view(tester);
    final store = CountingSettingStore();
    final controller = _appController();
    await tester.pumpWidget(
      _host(
        await _settings(store),
        _split(setting: _mailKey, controller: controller),
      ),
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
    _expectStoredWhole(store);

    await _tab(tester);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(store.writes, 2);

    tester.semantics.performAction(
      find.semantics.byLabel('Resize panes'),
      SemanticsAction.increase,
    );
    await tester.pump();
    expect(store.writes, 3);

    controller.fractions = [0.45, 0.55];
    await tester.pump();
    expect(store.writes, 4);
    _expectStoredWhole(store);

    tester.view.physicalSize = const Size(800, 400);
    await tester.pump();
    expect(_listWidth(tester), closeTo(360, 1));
    expect(store.writes, 4);
  });

  testWidgets(
    'fo10/us01/fr03/e04: a code set of no fractions on an app controller '
    'removes the stored list and keeps none',
    (tester) async {
      _view(tester);
      final store = CountingSettingStore({
        _mail: ['0.4', '0.6'],
      });
      final controller = _appController([0.5, null]);
      await tester.pumpWidget(
        _host(
          await _settings(store),
          _split(setting: _mailKey, controller: controller),
        ),
      );
      expect(_listWidth(tester), 400);

      controller.fractions = null;
      await tester.pump();
      expect(controller.fractions, isNull);
      expect(store.values.containsKey(_mail), isFalse);
      expect(store.removes, 1);
      expect(_listWidth(tester), 300);
    },
  );

  testWidgets(
    'fo10/us01/fr02/e05: with resizing off a split restores and saves '
    'nothing',
    (tester) async {
      _view(tester);
      final store = CountingSettingStore({
        _mail: ['0.4', '0.6'],
      });
      await tester.pumpWidget(
        _host(
          await _settings(store),
          _split(setting: _mailKey, resizable: false),
        ),
      );
      expect(_listWidth(tester), 400);
      await _tab(tester);
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_listWidth(tester), 400);
      expect(store.writes, 0);
    },
  );

  testWidgets('fo10/us01/fr01/e02: fo10/us01/fr01/e03: a new key re-reads and '
      'a null key stops saving', (tester) async {
    _view(tester);
    final store = CountingSettingStore({
      '${_box}i/a/fractions': ['0.4', '0.6'],
      '${_box}i/b/fractions': ['0.35', '0.65'],
    });
    final settings = await _settings(store);
    await tester.pumpWidget(
      _host(settings, _split(setting: const WidgetSettingKey.id('a'))),
    );
    expect(_listWidth(tester), 400);

    await tester.pumpWidget(
      _host(settings, _split(setting: const WidgetSettingKey.id('b'))),
    );
    expect(_listWidth(tester), 350);

    await tester.pumpWidget(
      _host(settings, _split(setting: const WidgetSettingKey.id('c'))),
    );
    expect(_listWidth(tester), 350);

    await tester.pumpWidget(_host(settings, _split()));
    expect(_listWidth(tester), 350);
    await _tab(tester);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_listWidth(tester), closeTo(366, 1));
    expect(store.writes, 0);
  });

  testWidgets('fo10/us01/fr04/e01: a write by another split moves this one '
      'with no extra write', (tester) async {
    _view(tester);
    final store = CountingSettingStore();
    await tester.pumpWidget(
      _host(
        await _settings(store),
        Column(
          children: [
            Expanded(child: _split(setting: _mailKey)),
            Expanded(
              child: _split(setting: _mailKey, list: 'Second'),
            ),
          ],
        ),
      ),
    );
    await _tab(tester);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_listWidth(tester), closeTo(316, 1));
    expect(_listWidth(tester, 'Second'), _listWidth(tester));
    expect(store.writes, 1);
  });

  testWidgets('fo10/us01/fr04/e02: a reset returns an app controller to its '
      'own starting list', (tester) async {
    _view(tester);
    final store = CountingSettingStore({
      _mail: ['0.4', '0.6'],
    });
    final settings = await _settings(store);
    final controller = _appController([0.5, null]);
    await tester.pumpWidget(
      _host(settings, _split(setting: _mailKey, controller: controller)),
    );
    expect(_listWidth(tester), 400);

    await settings.resetId('stratum.split_layout', 'mail');
    await tester.pump();
    expect(controller.fractions, [0.5, null]);
    expect(store.writes, 0);
  });

  testWidgets('fo10/us01/fr02/e02: fo10/us01/fr04/e02: a swapped-in app '
      'controller takes the stored list, and a reset returns it to its own', (
    tester,
  ) async {
    _view(tester);
    final store = CountingSettingStore({
      _mail: ['0.4', '0.6'],
    });
    final settings = await _settings(store);
    await tester.pumpWidget(
      _host(settings, _split(setting: _mailKey, controller: _appController())),
    );
    final swapped = _appController([0.5, null]);
    await tester.pumpWidget(
      _host(settings, _split(setting: _mailKey, controller: swapped)),
    );
    expect(swapped.fractions, [0.4, 0.6]);
    expect(_listWidth(tester), 400);

    await settings.resetId('stratum.split_layout', 'mail');
    await tester.pump();
    expect(swapped.fractions, [0.5, null]);
    expect(store.writes, 0);
  });

  testWidgets('RF5: a third pane under a stored two-entry list lays out at '
      'own sizes and writes nothing', (tester) async {
    _view(tester);
    final store = CountingSettingStore({
      _mail: ['0.4', '0.6'],
    });
    final settings = await _settings(store);
    await tester.pumpWidget(_host(settings, _split(setting: _mailKey)));
    expect(_listWidth(tester), 400);

    await tester.pumpWidget(
      _host(
        settings,
        _split(
          setting: _mailKey,
          extra: const SplitPane(size: 200, child: Text('Third')),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(_listWidth(tester), 300);
    expect(tester.getSize(find.text('Third')).width, 200);
    expect(store.writes, 0);

    await _tab(tester);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(store.writes, 1);
    expect(store.values[_mail], hasLength(3));
  });

  testWidgets('fo10/us04/fr01: a split removed during a user switch hears '
      'nothing after', (tester) async {
    _view(tester);
    final store = CountingSettingStore({
      _mail: ['0.4', '0.6'],
      'stratum/u/u1/stratum.split_layout/i/mail/fractions': ['0.35', '0.65'],
    });
    final settings = await _settings(store);
    await tester.pumpWidget(_host(settings, _split(setting: _mailKey)));
    expect(_listWidth(tester), 400);

    final hold = store.holdNextRead();
    final switching = settings.switchUser('u1');
    await tester.pumpWidget(const SizedBox());
    hold.complete();
    await switching;
    await tester.pump();
    expect(settings.userId, 'u1');
    expect(tester.takeException(), isNull);
  });
}
