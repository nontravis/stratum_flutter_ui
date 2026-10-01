// ignore_for_file: implementation_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../../integration_test/perf/perf_host.dart';
import '../../integration_test/perf/perf_kit.dart';
import '../../integration_test/perf/perf_scenes.dart';

/// A kit that fails the test when a scene draws through it.
class _RefusingKit implements PerfKit {
  const new();

  @override
  Widget row({
    WidgetStyle? style,
    VoidCallback? onTap,
    required MainAxisAlignment mainAxisAlignment,
    required List<Widget> children,
  }) => throw StateError('row called');

  @override
  Widget column({
    required MainAxisSize mainAxisSize,
    required CrossAxisAlignment crossAxisAlignment,
    required List<Widget> children,
  }) => throw StateError('column called');

  @override
  Widget container({WidgetStyle? style, Widget? child}) =>
      throw StateError('container called');
}

void main() {
  group('perfScenes', () {
    test('lists the scenes of spec section 9.1 in table order', () {
      expect(
        [for (final scene in perfScenes) scene.key],
        ['S1', 'S1-fast', 'S2', 'S2-box', 'S2-plain', 'S3', 'S4', 'S5'],
      );
    });

    for (final kit in const <PerfKit>[CurrentKit(), BaselineKit()]) {
      for (final scene in perfScenes) {
        testWidgets('${scene.key} builds and passes its check with '
            '${kit.runtimeType}', (tester) async {
          await tester.pumpWidget(perfHost(scene.build(kit)));
          await scene.check?.call(tester, kit);
          expect(tester.takeException(), isNull);
          // Unmounts S4, whose periodic timer must not outlive the test.
          await tester.pumpWidget(const SizedBox());
        });
      }
    }

    testWidgets('S2-plain never calls the kit', (tester) async {
      await tester.pumpWidget(
        perfHost(perfScene('S2-plain').build(const _RefusingKit())),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(AnimatedStyledBox), findsNothing);
    });
  });
}
