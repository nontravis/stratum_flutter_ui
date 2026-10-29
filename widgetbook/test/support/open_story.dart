import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/components.g.dart';
import 'package:stratum_ui_widgetbook/shell/catalog_config.dart';
import 'package:widgetbook/src/core/widgetbook_app.dart';
import 'package:widgetbook/src/core/workbench/workbench.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import 'catalog_theme.dart';

/// Opens the story at [path] in the whole catalog with the knob values
/// [knobs] (arg name to field value), and asserts that a [T] shows, so a
/// test never runs against a story that did not open.
///
/// [toolbar] sets toolbar addons by their query key, each to that addon's own
/// query fields: `{'viewport': {'name': 'desktop'}}`,
/// `{'locale': {'name': 'th'}}`, `{'right-to-left': {'enabled': 'true'}}`.
///
/// [catalog] replaces the generated components, for a test-only story.
///
/// Fails right after the story opens, and on any later frame the test pumps,
/// when a route sits on Widgetbook's root navigator (see
/// [expectNoRootRoute]). A frame callback does the later check, as a test
/// teardown runs after the tree is gone; so a route opened by a test's last
/// action shows only if the test pumps after it. A test that expects the
/// failure takes it with `tester.takeException()`.
///
/// Uses `dart:io` through the theme loader, so it runs on the VM only.
Future<void> openStory<T extends Widget>(
  WidgetTester tester,
  String path, {
  Map<String, String> knobs = const {},
  Map<String, Map<String, String>> toolbar = const {},
  List<Component>? catalog,
}) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final set = await loadDefaultThemeSet();
  final route = Uri(
    path: '/',
    queryParameters: {
      'path': path,
      for (final MapEntry(:key, :value) in knobs.entries)
        key: QueryGroup({'value': value}).toParam(),
      for (final MapEntry(:key, :value) in toolbar.entries)
        key: QueryGroup(value).toParam(),
    },
  ).toString();
  final config = catalogConfig(
    components: catalog ?? components,
    themes: {'default': set},
    initialRoute: route,
  );
  NavigatorState? rootNavigator;
  var watching = true;
  var reported = false;
  tester.binding.addPersistentFrameCallback((_) {
    final navigator = rootNavigator;
    if (!watching || reported || navigator == null) return;
    if (!navigator.mounted || !navigator.canPop()) return;
    reported = true;
    expectNoRootRoute(navigator, path);
  });
  addTearDown(() => watching = false);
  await tester.pumpWidget(WidgetbookApp(key: UniqueKey(), config: config));
  await tester.pumpAndSettle();

  expect(find.byType(T), findsWidgets);
  final story = tester.element(find.byType(T).first);
  // Workbench is the one page of the root navigator and holds the story; no
  // public widget sits in that page.
  rootNavigator = Navigator.of(
    // ignore: invalid_use_of_internal_member
    tester.element(find.byType(Workbench)),
    rootNavigator: true,
  );
  _expectApplied(
    WidgetbookState.of(story),
    config.addons ?? const [],
    knobs: knobs,
    toolbar: toolbar,
  );
  expectNoRootRoute(rootNavigator, path);
}

/// Fails when a route sits on Widgetbook's [rootNavigator] above its one
/// page, for the story at [path].
///
/// A route pushed there (a `showDialog` with the default root navigator)
/// escapes every toolbar setting, and no wrapper can intercept it, so a story
/// opens its routes with `useRootNavigator: false`. A [rootNavigator] no
/// longer mounted passes, as it holds no route.
void expectNoRootRoute(NavigatorState rootNavigator, String path) {
  if (!rootNavigator.mounted) return;
  if (rootNavigator.canPop()) {
    fail(
      'Story "$path" left a route on the root navigator. Open it with '
      '`useRootNavigator: false` so it stays under the toolbar settings.',
    );
  }
}

/// Fails when a knob or toolbar value passed to [openStory] did not reach the
/// story: Widgetbook ignores a key that names no knob or addon and decodes a
/// value it does not know as the default, so the story would open at its
/// defaults and a test would pass against them.
void _expectApplied(
  WidgetbookState state,
  List<Addon<dynamic>> toolbarAddons, {
  required Map<String, String> knobs,
  required Map<String, Map<String, String>> toolbar,
}) {
  final args = {for (final arg in state.story!.args.safeList) arg.name: arg};
  for (final MapEntry(:key, :value) in knobs.entries) {
    final arg = args[key];
    if (arg == null) {
      fail('openStory: no knob "$key"; the story has ${args.keys.toList()}');
    }
    expect(
      arg.toQueryGroup()?.toParam(),
      QueryGroup({'value': value}).toParam(),
      reason: 'openStory: knob "$key" did not decode "$value"',
    );
  }
  final addons = {for (final addon in toolbarAddons) addon.groupName: addon};
  for (final MapEntry(:key, :value) in toolbar.entries) {
    final addon = addons[key];
    if (addon == null) {
      fail('openStory: no toolbar addon "$key"; there are ${addons.keys}');
    }
    final group = QueryGroup(value);
    expect(
      addon.valueToQueryGroup(addon.valueFromQueryGroup(group)).toParam(),
      group.toParam(),
      reason: 'openStory: toolbar "$key" did not decode $value',
    );
  }
}
