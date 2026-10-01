import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'perf/perf_host.dart';
import 'perf/perf_kit.dart';
import 'perf/perf_scene.dart';
import 'perf/perf_scenes.dart';

/// The scene group this invocation traces (spec section 9.4).
const _group = int.fromEnvironment('PERF_GROUP', defaultValue: 1);

/// Traces one scene group in ABBA blocks of the frozen baseline and the
/// current layouts, after an untraced warm-up (spec section 9.4).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  for (final step in abbaSteps(perfGroup(_group))) {
    testWidgets(step.name, (tester) async {
      final PerfKit kit = step.baseline
          ? const BaselineKit()
          : const CurrentKit();
      final scene = step.scene;
      await tester.pumpWidget(perfHost(scene.build(kit)));
      await scene.check?.call(tester, kit);
      await tester.pump(settleTime);
      if (step.traced) {
        await binding.traceAction(
          () => scene.drive(tester),
          streams: perfStreams,
          reportKey: step.reportKey,
        );
      } else {
        await scene.drive(tester);
      }
      expect(tester.takeException(), isNull);
    }, semanticsEnabled: false);
  }
}
