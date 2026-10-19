import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/widget_settings/widget_setting_store.dart';
import 'package:stratum_ui/src/components/common/widget_settings/widget_settings_controller.dart';
import 'package:stratum_ui/src/components/common/widget_settings/widget_settings_scope.dart';

/// Counts how many times the widget it is passed to has built.
class _BuildCount {
  int value = 0;
}

/// Shows [namespace]'s global [name], counting its own builds into
/// [builds].
class _Reader extends StatelessWidget {
  const new({
    required this.namespace,
    required this.name,
    required this.builds,
  });

  final String namespace;
  final String name;
  final _BuildCount builds;

  @override
  Widget build(BuildContext context) {
    builds.value++;
    final value = StratumWidgetSettings.of(
      context,
      namespace: namespace,
    ).global.getBool(name);
    return Text('$value');
  }
}

/// Calls [StratumWidgetSettings.maybeControllerOf], counting its own
/// builds into [builds].
class _ControllerReader extends StatelessWidget {
  const new({required this.builds});

  final _BuildCount builds;

  @override
  Widget build(BuildContext context) {
    builds.value++;
    StratumWidgetSettings.maybeControllerOf(context);
    return const SizedBox();
  }
}

/// [child] under a [StratumWidgetSettings] over [controller], with a
/// [Directionality] for [Text] to read.
Widget _host(StratumWidgetSettingsController controller, Widget child) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: StratumWidgetSettings(controller: controller, child: child),
    );

void main() {
  testWidgets(
    'fo10/us02/s1: fo10/us02/fr04/e01: a write rebuilds only the readers '
    'of its key',
    (tester) async {
      final controller = await StratumWidgetSettingsController.preload(
        store: StratumMemorySettingStore(),
      );
      addTearDown(controller.dispose);
      final buildsA = _BuildCount();
      final buildsB = _BuildCount();

      await tester.pumpWidget(
        _host(
          controller,
          Column(
            children: [
              _Reader(namespace: 'n', name: 'a', builds: buildsA),
              _Reader(namespace: 'n', name: 'b', builds: buildsB),
            ],
          ),
        ),
      );
      expect(buildsA.value, 1);
      expect(buildsB.value, 1);

      await controller.box('n').global.setBool('a', true);
      await tester.pump();

      expect(buildsA.value, 2);
      expect(buildsB.value, 1);
      expect(find.text('true'), findsOneWidget);
    },
  );

  testWidgets(
    'RF4: fo10/us02/fr04/e02: two writes in one frame rebuild both readers',
    (tester) async {
      final controller = await StratumWidgetSettingsController.preload(
        store: StratumMemorySettingStore(),
      );
      addTearDown(controller.dispose);
      final buildsA = _BuildCount();
      final buildsB = _BuildCount();

      await tester.pumpWidget(
        _host(
          controller,
          Column(
            children: [
              _Reader(namespace: 'n', name: 'a', builds: buildsA),
              _Reader(namespace: 'n', name: 'b', builds: buildsB),
            ],
          ),
        ),
      );

      unawaited(controller.box('n').global.setBool('a', true));
      unawaited(controller.box('n').global.setBool('b', true));
      await tester.pump();

      expect(buildsA.value, 2);
      expect(buildsB.value, 2);
    },
  );

  testWidgets(
    'fo10/us03/s1: fo10/us03/fr01/e03: a main() preload shows the stored '
    'value on the first frame',
    (tester) async {
      final controller = await StratumWidgetSettingsController.preload(
        store: StratumMemorySettingStore(
          values: {'stratum/d/acme.inbox/g/a': true},
        ),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          controller,
          _Reader(namespace: 'acme.inbox', name: 'a', builds: _BuildCount()),
        ),
      );

      expect(find.text('true'), findsOneWidget);
    },
  );

  testWidgets('fo10/us04/fr01: a switch rebuilds every reader once', (
    tester,
  ) async {
    final controller = await StratumWidgetSettingsController.preload(
      store: StratumMemorySettingStore(),
    );
    addTearDown(controller.dispose);
    final buildsA = _BuildCount();
    final buildsB = _BuildCount();

    await tester.pumpWidget(
      _host(
        controller,
        Column(
          children: [
            _Reader(namespace: 'n', name: 'a', builds: buildsA),
            _Reader(namespace: 'n', name: 'b', builds: buildsB),
          ],
        ),
      ),
    );

    await controller.switchUser('someone');
    await tester.pump();

    expect(buildsA.value, 2);
    expect(buildsB.value, 2);
  });

  testWidgets(
    'fo10/us03/fr02/e01: of() with no scope above fails a debug assert',
    (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              StratumWidgetSettings.of(context, namespace: 'n');
              return const SizedBox();
            },
          ),
        ),
      );

      expect(
        tester.takeException(),
        isA<AssertionError>().having(
          (error) => error.message,
          'message',
          contains('StratumWidgetSettings'),
        ),
      );
    },
  );

  testWidgets('fo10/us02/fr04: a maybeControllerOf reader rebuilds on a new '
      'controller, never on a write or a switch', (tester) async {
    final first = await StratumWidgetSettingsController.preload(
      store: StratumMemorySettingStore(),
    );
    addTearDown(first.dispose);
    final second = await StratumWidgetSettingsController.preload(
      store: StratumMemorySettingStore(),
    );
    addTearDown(second.dispose);
    final builds = _BuildCount();

    await tester.pumpWidget(_host(first, _ControllerReader(builds: builds)));
    expect(builds.value, 1);

    await first.box('n').global.setBool('a', true);
    await tester.pump();
    expect(builds.value, 1);

    await first.switchUser('someone');
    await tester.pump();
    expect(builds.value, 1);

    await tester.pumpWidget(_host(second, _ControllerReader(builds: builds)));
    expect(builds.value, 2);
  });

  testWidgets(
    'fo10/us02/fr04: controllerOf throws a FlutterError with no scope above',
    (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            StratumWidgetSettings.controllerOf(context);
            return const SizedBox();
          },
        ),
      );

      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (error) => error.message,
          'message',
          contains('StratumWidgetSettings'),
        ),
      );
    },
  );
}
