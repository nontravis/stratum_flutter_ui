import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:stratum_ui/src/components/common/responsive/keyboard_visibility_scope.dart';

void main() {
  // Scoped to this file: `flutter test` runs each file in its own process.
  LeakTesting.enable();

  void setInsets(WidgetTester tester, double height) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.viewInsets = FakeViewPadding(bottom: height);
  }

  Widget readVisibility(void Function(bool isVisible) onBuild) => Builder(
    builder: (context) {
      onBuild(KeyboardVisibilityScope.of(context));
      return const SizedBox();
    },
  );

  testWidgets('fo07/us04/fr02/e04: of reads true while a test forces the '
      'keyboard shown and the keyboard height reads 0', (tester) async {
    addTearDown(() => KeyboardVisibilityScope.setVisibleForTesting(false));
    KeyboardVisibilityScope.setVisibleForTesting(true);
    late bool isVisible;

    await tester.pumpWidget(
      KeyboardVisibilityScope(
        child: Builder(
          builder: (context) => MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: readVisibility((v) => isVisible = v),
          ),
        ),
      ),
    );

    expect(isVisible, isTrue);
  });

  testWidgets('fo07/us04/s2: fo07/us04/fr02/e02: dependents rebuild once '
      'when the keyboard opens and once when it closes', (tester) async {
    addTearDown(() => KeyboardVisibilityScope.setVisibleForTesting(false));
    addTearDown(tester.view.reset);
    var dependentBuilds = 0;
    late bool isVisible;

    await tester.pumpWidget(
      KeyboardVisibilityScope(
        child: readVisibility((v) {
          dependentBuilds++;
          isVisible = v;
        }),
      ),
    );
    dependentBuilds = 0;

    KeyboardVisibilityScope.setVisibleForTesting(true);
    var firstPumpAfterFlip = true;
    for (var height = 10.0; height <= 300; height += 10) {
      setInsets(tester, height);
      await tester.pump();
      if (firstPumpAfterFlip) {
        // One pump() shows the forced flip.
        expect(isVisible, isTrue);
        firstPumpAfterFlip = false;
      }
    }
    KeyboardVisibilityScope.setVisibleForTesting(false);
    firstPumpAfterFlip = true;
    for (var height = 290.0; height >= 0; height -= 10) {
      setInsets(tester, height);
      await tester.pump();
      if (firstPumpAfterFlip) {
        expect(isVisible, isFalse);
        firstPumpAfterFlip = false;
      }
    }

    // Opens once and closes once across 60 animation frames.
    expect(dependentBuilds, 2);
  });

  testWidgets(
    'fo07/us04/fr02: forcing the same value twice on a mounted scope holds '
    'the value and rebuilds the reader only once',
    (tester) async {
      addTearDown(() => KeyboardVisibilityScope.setVisibleForTesting(false));
      var builds = 0;
      late bool isVisible;

      await tester.pumpWidget(
        KeyboardVisibilityScope(
          child: readVisibility((v) {
            builds++;
            isVisible = v;
          }),
        ),
      );
      builds = 0;

      KeyboardVisibilityScope.setVisibleForTesting(true);
      await tester.pump();
      expect(isVisible, isTrue);
      expect(builds, 1);

      KeyboardVisibilityScope.setVisibleForTesting(true);
      await tester.pump();

      expect(isVisible, isTrue);
      expect(builds, 1);
    },
  );

  testWidgets('fo07/us04/s4: fo07/us04/fr02/e03: of throws a FlutterError '
      'that names how to wrap the app', (tester) async {
    await tester.pumpWidget(readVisibility((_) {}));

    expect(
      tester.takeException(),
      isA<FlutterError>().having(
        (error) => error.message,
        'message',
        allOf(
          contains('No KeyboardVisibilityScope found in context'),
          contains('Wrap the app with KeyboardVisibilityScope'),
        ),
      ),
    );
  });

  testWidgets('fo07/us04/fr02/e08: a forced value outlives the test that '
      'set it (1 of 2)', (tester) async {
    KeyboardVisibilityScope.setVisibleForTesting(true);
    late bool isVisible;

    await tester.pumpWidget(
      KeyboardVisibilityScope(child: readVisibility((v) => isVisible = v)),
    );

    expect(isVisible, isTrue);
  });

  testWidgets('fo07/us04/fr02/e08: a forced value outlives the test that '
      'set it (2 of 2)', (tester) async {
    addTearDown(() => KeyboardVisibilityScope.setVisibleForTesting(false));
    late bool isVisible;

    await tester.pumpWidget(
      KeyboardVisibilityScope(child: readVisibility((v) => isVisible = v)),
    );
    // Carried over from the test above, which forced true with no reset.
    expect(isVisible, isTrue);

    KeyboardVisibilityScope.setVisibleForTesting(false);
    await tester.pump();
    expect(isVisible, isFalse);
  });

  testWidgets('fo07/us04/fr02/e09: hasScope reports a scope above and '
      'registers no dependency', (tester) async {
    addTearDown(() => KeyboardVisibilityScope.setVisibleForTesting(false));
    late bool hasScopeWithNoScope;
    late bool hasScopeWithScope;
    var builds = 0;

    await tester.pumpWidget(
      Builder(
        builder: (context) {
          hasScopeWithNoScope = KeyboardVisibilityScope.hasScope(context);
          return const SizedBox();
        },
      ),
    );
    expect(hasScopeWithNoScope, isFalse);

    await tester.pumpWidget(
      KeyboardVisibilityScope(
        child: Builder(
          builder: (context) {
            builds++;
            hasScopeWithScope = KeyboardVisibilityScope.hasScope(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(hasScopeWithScope, isTrue);
    expect(builds, 1);

    KeyboardVisibilityScope.setVisibleForTesting(true);
    await tester.pump();

    // hasScope registers no dependency: the Builder above does not rebuild.
    expect(builds, 1);
  });

  testWidgets('fo07/us04/fr02: a removed scope ignores later forced values', (
    tester,
  ) async {
    addTearDown(() => KeyboardVisibilityScope.setVisibleForTesting(false));

    await tester.pumpWidget(
      KeyboardVisibilityScope(child: readVisibility((_) {})),
    );
    await tester.pumpWidget(const SizedBox());

    KeyboardVisibilityScope.setVisibleForTesting(true);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'fo07/us04/fr02: a mounted, forced, and disposed scope leaks no object',
    (tester) async {
      addTearDown(() => KeyboardVisibilityScope.setVisibleForTesting(false));

      await tester.pumpWidget(
        KeyboardVisibilityScope(child: readVisibility((_) {})),
      );
      KeyboardVisibilityScope.setVisibleForTesting(true);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
    },
  );

  // Build Gate NFR-U01: n/a — a non-visual context read paints no color,
  // text, border, focus ring, or icon.
  // Build Gate NFR-U02: n/a — a non-visual context read holds no focusable
  // node and sits in no Tab order.
  // Build Gate NFR-U03: n/a — a non-visual context read runs no animation of
  // its own; it only forwards the value the operating system reports.
  // Build Gate NFR-U04: n/a — a non-visual context read renders no text.
  // Build Gate NFR-U05: n/a — a non-visual context read has no interactive
  // target.
  // Build Gate NFR-U06: n/a — a non-visual context read owns no semantics
  // node.
  // Build Gate NFR-U07: n/a — a non-visual context read paints no color,
  // text, border, focus ring, or icon.
  // Build Gate NFR-U08: n/a — a non-visual context read shows no state
  // through color or any other cue.
  // Build Gate NFR-U09: n/a — a non-visual context read has no gesture of
  // its own to trigger.
  // Build Gate NFR-E01: n/a — the scope has no look of its own to probe
  // across bundled themes.
  // Build Gate NFR-E02: n/a — the scope has no customStyle type.
}
