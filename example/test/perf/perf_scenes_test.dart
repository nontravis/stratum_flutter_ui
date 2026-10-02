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
    test('lists the scenes of spec section 9.1 in run order, the S2-plain '
        'null control first', () {
      expect(
        [for (final scene in perfScenes) scene.key],
        ['S2-plain', 'S1', 'S1-fast', 'S2', 'S2-box', 'S3', 'S4', 'S5'],
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

    testWidgets("S2-plain's check draws S2-box with the current kit on both "
        'sides', (tester) async {
      final scene = perfScene('S2-plain');
      await tester.pumpWidget(perfHost(scene.build(const _RefusingKit())));

      await scene.check!(tester, const _RefusingKit());

      expect(tester.takeException(), isNull);
      expect(find.byType(AnimatedStyledBox), findsNothing);
    });
  });

  group('perfScenesNamed', () {
    List<String> keys(String names) => [
      for (final scene in perfScenesNamed(names)) scene.key,
    ];

    test('gives every scene for an empty list', () {
      expect(keys(''), [for (final scene in perfScenes) scene.key]);
    });

    test('keeps the named scenes in catalog order', () {
      expect(keys('S5,S2-plain,S1'), ['S2-plain', 'S1', 'S5']);
    });

    test('rejects an unknown scene', () {
      expect(() => perfScenesNamed('S2-plain,S9'), throwsArgumentError);
    });
  });
}
