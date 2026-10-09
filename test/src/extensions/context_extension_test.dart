import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/extensions/context_extension.dart';

void main() {
  group('context.reducesMotion', () {
    void useFeatures(WidgetTester tester, FakeAccessibilityFeatures features) {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          features;
      addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }

    /// The result of `context.reducesMotion` below [data], or below no
    /// [MediaQuery] of the test's own when [data] is null.
    Future<bool> read(WidgetTester tester, {MediaQueryData? data}) async {
      late bool result;
      Widget probe = Builder(
        builder: (context) {
          result = context.reducesMotion;
          return const SizedBox();
        },
      );
      if (data != null) probe = MediaQuery(data: data, child: probe);
      await tester.pumpWidget(probe);
      return result;
    }

    testWidgets('is false when neither the app nor the platform asks', (
      tester,
    ) async {
      expect(await read(tester, data: const MediaQueryData()), isFalse);
    });

    testWidgets('is false without a flag and no MediaQuery of its own', (
      tester,
    ) async {
      expect(await read(tester), isFalse);
    });

    testWidgets("is true for the app's MediaQuery disableAnimations", (
      tester,
    ) async {
      expect(
        await read(tester, data: const MediaQueryData(disableAnimations: true)),
        isTrue,
      );
    });

    testWidgets('is true for the platform reduceMotion', (tester) async {
      useFeatures(tester, const FakeAccessibilityFeatures(reduceMotion: true));

      expect(await read(tester, data: const MediaQueryData()), isTrue);
    });

    testWidgets("lets the app's MediaQuery override the platform "
        'disableAnimations', (tester) async {
      useFeatures(
        tester,
        const FakeAccessibilityFeatures(disableAnimations: true),
      );

      expect(await read(tester, data: const MediaQueryData()), isFalse);
    });
  });
}
