@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';

void main() {
  test('D6: the three stubs are gone and unexported', () {
    const deletedPaths = [
      'lib/src/components/common/in_app_update.dart',
      'lib/src/components/common/utility/todo.dart',
      'lib/src/components/common/page/page.dart',
    ];
    for (final path in deletedPaths) {
      expect(File(path).existsSync(), isFalse, reason: path);
    }

    final common = File('lib/src/components/common/common.dart')
        .readAsStringSync();
    final utility = File('lib/src/components/common/utility/utility.dart')
        .readAsStringSync();
    expect(common, isNot(contains('in_app_update.dart')));
    expect(common, isNot(contains('page/page.dart')));
    expect(utility, isNot(contains('todo.dart')));
  });

  test('fo06/us01/fr01, fo08/us01/fr01: the debug prop and the performance '
      'monitor are gone', () {
    expect(
      File('lib/src/components/common/widget_performance_monitor.dart')
          .existsSync(),
      isFalse,
    );
    expect(
      File('lib/src/components/common/common.dart').readAsStringSync(),
      isNot(contains('widget_performance_monitor.dart')),
    );
    const sources = [
      'lib/src/components/common/base/widget_props.dart',
      'lib/src/components/common/base/stateless_widget.dart',
      'lib/src/components/common/base/stateful_widget.dart',
      'lib/src/components/common/layout/box_layout.dart',
      'lib/src/components/common/layout/flex_layout.dart',
      'lib/src/components/common/layout/wrap_layout.dart',
      'lib/src/components/common/layout/column_layout.dart',
      'lib/src/components/common/layout/indexed_stack_layout.dart',
      'lib/src/components/common/layout/stack_layout.dart',
      'lib/src/components/common/layout/container_layout.dart',
      'lib/src/components/common/layout/row_layout.dart',
      'lib/src/components/common/utility/caret.dart',
    ];
    for (final path in sources) {
      final text = File(path).readAsStringSync();
      for (final debugProp in const [
        'bool get debug',
        'final bool debug',
        'this.debug',
        'super.debug',
        'widget.debug',
        'WidgetPerformanceMonitor',
      ]) {
        expect(text, isNot(contains(debugProp)), reason: '$path: $debugProp');
      }
    }
  });

  test('the package exports Show and StratumWebZoom', () {
    expect(const Show(visible: true, child: SizedBox()), isA<StatefulWidget>());
    expect(ShowTransition.values, hasLength(4));
    expect(ShowSlideDirection.values, hasLength(4));
    expect(const StratumWebZoom(child: SizedBox()), isA<StatelessWidget>());
  });

  test('us12/fr01: the package exports StratumSplashScreen and its four '
      'states, which a switch covers', () {
    String nameOf(StratumSplashState<int> state) => switch (state) {
      StratumSplashLoadingTheme() => 'loading theme',
      StratumSplashLoadingApp() => 'loading app',
      StratumSplashFailed() => 'failed',
      StratumSplashDone() => 'done',
    };

    expect(
      StratumSplashScreen<int>(
        postload: (context, controller) async => 1,
        builder: (context, state) => Text(nameOf(state)),
      ),
      isA<StatefulWidget>(),
    );
    expect(nameOf(const StratumSplashLoadingTheme<int>()), 'loading theme');
    expect(StratumSplashPhase.values, [
      StratumSplashPhase.theme,
      StratumSplashPhase.postload,
    ]);
  });

  test('R7, (g): layout.dart exports ScrollFocus and ScrollFocusMode, so an '
      'app names the scrolling area level 2 key', () {
    const key = ScrollFocus;
    expect(key, ScrollFocus);
    expect(ScrollFocusMode.values, hasLength(2));
  });

  test('fo10/us02/fr01: fo10/us06/fr01: the package exports the widget '
      'setting API', () {
    const key = WidgetSettingKey.id('a');
    expect(key, isA<WidgetSettingKey>());
    expect(StratumMemorySettingStore(), isA<StratumWidgetSettingStore>());
    expect(
      StratumSharedPreferencesSettingStore(),
      isA<StratumWidgetSettingStore>(),
    );
    expect(StratumWidgetSettingsController(), isA<ChangeNotifier>());
    expect(
      StratumWidgetSettings(
        controller: StratumWidgetSettingsController(),
        child: const SizedBox(),
      ),
      isA<StatefulWidget>(),
    );

    final source = File(
      'lib/src/components/common/widget_settings/widget_settings.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('setting_key_codec')));
    expect(source, isNot(contains('setting_binding')));
  });
}
