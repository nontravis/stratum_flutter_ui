import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../../../themes/theme_runtime_fakes.dart';
import '../fakes/fake_stratum_theme.dart';
import '../widget_settings/support/counting_setting_store.dart';

/// The device box of `PageLayout`'s settings namespace (PD2, PD11).
const String _box = 'stratum/d/stratum.page_layout/';

/// The storage key of the left width under the id `mail`.
const String _mailLeft = '${_box}i/mail/left_width';

const WidgetSettingKey _mailKey = WidgetSettingKey.id('mail');

/// A 1400 x 900 desktop test view, so `left` sits inline, reset after the
/// test.
void _view(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 900);
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

/// [child] under [settings].
Widget _host(StratumWidgetSettingsController settings, Widget child) =>
    themedHost(StratumWidgetSettings(controller: settings, child: child));

/// A page with a `left` inline pane and a `body`, remembering its side
/// widths under [setting]; [capture] gets the body's context, so a test can
/// reach the page's controller through [PageLayout.of].
PageLayout _page({
  WidgetSettingKey? setting,
  PageLayoutController? controller,
  String id = '',
  ValueChanged<BuildContext>? capture,
}) => PageLayout(
  setting: setting,
  controller: controller,
  left: SizedBox.expand(key: Key('left$id')),
  body: Builder(
    builder: (context) {
      capture?.call(context);
      return SizedBox.expand(key: Key('body$id'));
    },
  ),
);

double _leftWidth(WidgetTester tester, [String id = '']) =>
    tester.getSize(find.byKey(Key('left$id'))).width;

/// An app controller starting at [left], disposed after the test.
PageLayoutController _appController({double? left}) {
  final controller = PageLayoutController(leftWidth: left);
  addTearDown(controller.dispose);
  return controller;
}

/// A splash whose single app frame draws [page] once its postload ends.
Widget _splashWith(Widget page, StratumWidgetSettingsController settings) =>
    DefaultAssetBundle(
      bundle: FakeThemeBundle(),
      child: StratumSplashScreen<void>(
        widgetSettings: settings,
        postload: (context, controller) async {},
        builder: (context, state) =>
            state is StratumSplashDone<void> ? page : const SizedBox.expand(),
      ),
    );

/// An application whose `home` is [page].
Widget _applicationWith(
  Widget page,
  StratumWidgetSettingsController settings,
) => DefaultAssetBundle(
  bundle: FakeThemeBundle(),
  child: StratumApplication(
    widgetSettings: settings,
    appBuilder: (context, scope) =>
        MaterialApp(builder: scope.builder, home: page),
  ),
);

void main() {
  testWidgets(
    'fo10/us01/s1: fo10/us01/fr04/e01: fo10/us01/fr04/e02: a page under a '
    'route follows a save and a reset',
    (tester) async {
      _view(tester);
      final store = CountingSettingStore();
      final settings = await _settings(store);
      late BuildContext inboxContext;
      late BuildContext contactsContext;
      final navigator = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _host(
          settings,
          Navigator(
            key: navigator,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => _page(
                setting: _mailKey,
                id: '-inbox',
                capture: (context) => inboxContext = context,
              ),
            ),
          ),
        ),
      );

      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => _page(
            setting: _mailKey,
            id: '-contacts',
            capture: (context) => contactsContext = context,
          ),
        ),
      );
      await tester.pumpAndSettle();

      PageLayout.of(contactsContext).leftWidth = 300;
      await tester.pump();
      expect(store.writes, 1);

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(_leftWidth(tester, '-inbox'), 300);
      expect(store.writes, 1);

      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => _page(
            setting: _mailKey,
            id: '-contacts',
            capture: (context) => contactsContext = context,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await settings.resetId('stratum.page_layout', 'mail');
      await tester.pump();
      expect(PageLayout.of(contactsContext).leftWidth, isNull);
      expect(PageLayout.of(inboxContext).leftWidth, isNull);
      expect(_leftWidth(tester, '-contacts'), 260);

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(_leftWidth(tester, '-inbox'), 260);
    },
  );

  testWidgets(
    'fo10/us01/fr04/e02: a reset returns an app controller to its own '
    'starting width',
    (tester) async {
      _view(tester);
      final store = CountingSettingStore({_mailLeft: 400.0});
      final settings = await _settings(store);
      final controller = _appController(left: 320);
      await tester.pumpWidget(
        _host(settings, _page(setting: _mailKey, controller: controller)),
      );
      expect(_leftWidth(tester), 400);

      await settings.resetId('stratum.page_layout', 'mail');
      await tester.pump();
      expect(controller.leftWidth, 320);
      expect(_leftWidth(tester), 320);
    },
  );

  testWidgets(
    'fo10/us04/s1: fo10/us04/fr01/e01: no frame shows the default during a '
    'user switch',
    (tester) async {
      _view(tester);
      final store = CountingSettingStore({
        'stratum/u/a/stratum.page_layout/i/mail/left_width': 400.0,
        'stratum/u/b/stratum.page_layout/i/mail/left_width': 300.0,
      });
      final settings = await _settings(store);
      await settings.switchUser('a');
      await tester.pumpWidget(_host(settings, _page(setting: _mailKey)));
      expect(_leftWidth(tester), 400);

      final hold = store.holdNextRead();
      final switching = settings.switchUser('b');
      for (var i = 0; i < 3; i++) {
        await tester.pump();
        expect(_leftWidth(tester), 400);
      }
      hold.complete();
      await switching;
      await tester.pump();
      expect(_leftWidth(tester), 300);
    },
  );

  testWidgets(
    'fo10/us04/fr01: a route-replaced page stops writing after it leaves '
    'while its app controller lives on',
    (tester) async {
      _view(tester);
      final store = CountingSettingStore();
      final settings = await _settings(store);
      final shared = _appController();
      final navigator = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _host(
          settings,
          Navigator(
            key: navigator,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => _page(
                setting: const WidgetSettingKey.id('a'),
                controller: shared,
                id: '-a',
              ),
            ),
          ),
        ),
      );

      navigator.currentState!.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => _page(
            setting: const WidgetSettingKey.id('b'),
            controller: shared,
            id: '-b',
          ),
        ),
      );
      await tester.pumpAndSettle();

      shared.leftWidth = 350;
      await tester.pump();

      expect(store.values['${_box}i/a/left_width'], isNull);
      expect(store.values['${_box}i/b/left_width'], 350.0);
    },
  );

  testWidgets(
    'fo10/us01/s2: fo10/us01/fr02/e01: under StratumApplication the first '
    'frame with the page shows 400',
    (tester) async {
      _view(tester);
      final store = CountingSettingStore({_mailLeft: 400.0});
      final settings = StratumWidgetSettingsController(store: store);
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        _applicationWith(_page(setting: _mailKey), settings),
      );
      while (find.byType(PageLayout).evaluate().isEmpty) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_leftWidth(tester), 400);
    },
  );

  testWidgets(
    'fo10/us01/fr02/e01: under StratumSplashScreen the first frame with '
    'the page shows 400',
    (tester) async {
      _view(tester);
      final store = CountingSettingStore({_mailLeft: 400.0});
      final settings = StratumWidgetSettingsController(store: store);
      addTearDown(settings.dispose);
      await tester.pumpWidget(_splashWith(_page(setting: _mailKey), settings));
      while (find.byType(PageLayout).evaluate().isEmpty) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_leftWidth(tester), 400);
    },
  );
}
