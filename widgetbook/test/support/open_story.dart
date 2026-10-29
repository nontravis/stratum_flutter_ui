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
/// [toolbar] sets toolbar addons by their query key (`viewport` to a window
/// size name, `locale` to a language code).
///
/// Uses `dart:io` through the theme loader, so it runs on the VM only.
Future<void> openStory<T extends Widget>(
  WidgetTester tester,
  String path, {
  Map<String, String> knobs = const {},
  Map<String, String> toolbar = const {},
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
        key: QueryGroup({'name': value}).toParam(),
    },
  ).toString();
  await tester.pumpWidget(
    WidgetbookApp(
      key: UniqueKey(),
      config: Config(
        components: catalogConfig(
          components: components,
          themes: {'default': set},
        ).components,
        addons: catalogAddons({'default': set}),
        initialRoute: route,
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byType(T), findsWidgets);
}
