import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';

import 'open_story.dart';

const _playground = 'Feedback/Placeholder page/Playground';

void main() {
  testWidgets('fo11/us06/fr01/e01: openStory fails on a knob the story does '
      'not have', (tester) async {
    await expectLater(
      openStory<StratumPlaceholderPage>(
        tester,
        _playground,
        knobs: {'titel': 'Title'},
      ),
      throwsA(isA<TestFailure>()),
    );
  });

  testWidgets('fo11/us06/fr01/e01: openStory fails on a preset value the '
      'knob does not offer', (tester) async {
    await expectLater(
      openStory<StratumPlaceholderPage>(
        tester,
        _playground,
        knobs: {'title': 'No such preset'},
      ),
      throwsA(isA<TestFailure>()),
    );
  });

  testWidgets('fo11/us06/fr01/e01: openStory fails on a toolbar addon or '
      'value it does not know', (tester) async {
    await expectLater(
      openStory<StratumPlaceholderPage>(
        tester,
        _playground,
        toolbar: {
          'no-such-addon': {'name': 'x'},
        },
      ),
      throwsA(isA<TestFailure>()),
    );
  });

  testWidgets('fo11/us06/fr01/e01: openStory accepts a knob and a toolbar '
      'value that decode', (tester) async {
    await openStory<StratumPlaceholderPage>(
      tester,
      _playground,
      knobs: {'title': 'Title'},
      toolbar: {
        'locale': {'name': 'th'},
      },
    );

    expect(tester.takeException(), isNull);
  });
}
