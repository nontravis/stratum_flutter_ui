import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/app_lifecycle.dart';

void main() {
  testWidgets(
    'records a resumed OS state the engine reports before flutter_test '
    'resets the binding after this test',
    (tester) async {
      installLifecycleObserver();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      expect(WidgetsBinding.instance.lifecycleState, AppLifecycleState.resumed);
    },
  );

  testWidgets(
    'waitForResumed completes with no new event once flutter_test has '
    'reset the binding to null',
    (tester) async {
      expect(WidgetsBinding.instance.lifecycleState, isNull);

      await waitForResumed(tester);
    },
  );

  testWidgets(
    'waitForResumed fails naming the state when the last OS state was not '
    'resumed',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      await expectLater(
        () => waitForResumed(tester, timeout: const Duration(milliseconds: 50)),
        throwsA(
          isA<TestFailure>().having(
            (failure) => failure.message,
            'message',
            contains('AppLifecycleState.paused'),
          ),
        ),
      );
    },
  );
}
