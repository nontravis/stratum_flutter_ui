import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'perf/perf_host.dart';
import 'perf/perf_kit.dart';
import 'perf/perf_scenes.dart';

/// Traces every scene of the catalog with the current layouts.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  const kit = CurrentKit();

  for (final scene in perfScenes) {
    testWidgets(scene.key, (tester) async {
      await tester.pumpWidget(perfHost(scene.build(kit)));
      await scene.check?.call(tester, kit);
      await binding.traceAction(
        () => scene.drive(tester),
        streams: perfStreams,
        reportKey: scene.key,
      );
      expect(tester.takeException(), isNull);
    }, semanticsEnabled: false);
  }
}
