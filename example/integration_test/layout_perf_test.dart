import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'perf/perf_host.dart';
import 'perf/perf_kit.dart';
import 'perf/perf_scene.dart';
import 'perf/perf_scenes.dart';
import 'perf/perf_trace.dart';

/// The first run this invocation traces (spec section 9.4).
const _from = int.fromEnvironment('PERF_FROM', defaultValue: 1);

/// How many runs this invocation traces.
const _runs = int.fromEnvironment('PERF_RUNS', defaultValue: 1);

/// The scenes to trace, comma-separated; empty for the whole catalog.
const _scenes = String.fromEnvironment('PERF_SCENES');

/// Whether every timeline stays for the driver (`run --trace-full`).
const _full = bool.fromEnvironment('PERF_FULL');

/// Traces runs of ABBA blocks of the frozen baseline and the current
/// layouts in one app, after an untraced warm-up (spec section 9.4).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  final steps = runSteps(perfScenesNamed(_scenes), first: _from, count: _runs);
  for (final step in steps) {
    testWidgets(step.name, (tester) async {
      if (step.startsRun) printRunLine(step.run!);
      final PerfKit kit = step.baseline
          ? const BaselineKit()
          : const CurrentKit();
      final scene = step.scene;
      await tester.pumpWidget(perfHost(scene.build(kit)));
      await scene.check?.call(tester, kit);
      await tester.pump(settleTime);
      if (step.traced) {
        await traceStep(
          binding,
          step.reportKey,
          () => scene.drive(tester),
          full: _full,
        );
      } else {
        await scene.drive(tester);
      }
      expect(tester.takeException(), isNull);
      if (step.coolDown) {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(coolDownTime);
      }
    }, semanticsEnabled: false);
  }
}
