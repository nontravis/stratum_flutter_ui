import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/components.g.dart';
import 'package:stratum_ui_widgetbook/shell/catalog_config.dart';
import 'package:widgetbook/src/core/widgetbook_app.dart';
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
/// Uses `dart:io` through the theme loader, so it runs on the VM only.
Future<void> openStory<T extends Widget>(
  WidgetTester tester,
  String path, {
  Map<String, String> knobs = const {},
  Map<String, Map<String, String>> toolbar = const {},
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
    components: components,
    themes: {'default': set},
    initialRoute: route,
  );
  await tester.pumpWidget(WidgetbookApp(key: UniqueKey(), config: config));
  await tester.pumpAndSettle();

  expect(find.byType(T), findsWidgets);
  _expectApplied(
    WidgetbookState.of(tester.element(find.byType(T).first)),
    config.addons ?? const [],
    knobs: knobs,
    toolbar: toolbar,
  );
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
