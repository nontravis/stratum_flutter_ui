import 'dart:async';

import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import 'open_story.dart';

const _playground = 'Feedback/Placeholder page/Playground';
const _opener = 'Foundation/Opener/OpenerStory';
const _openKey = Key('open-dialog');
const _dialogKey = Key('dialog-body');

/// Story args of [_OpenerStory].
class _NoArgs extends StoryArgs<_Opener> {
  const _NoArgs();

  @override
  List<Arg?> get list => const [];
}

/// A story whose button opens a dialog, on the root navigator or not.
class _OpenerStory extends Story<_Opener, _NoArgs> {
  _OpenerStory({required bool useRootNavigator})
    : super(
        name: 'OpenerStory',
        args: const _NoArgs(),
        builder: (_, _) => _Opener(useRootNavigator: useRootNavigator),
      );
}

class _Opener extends StatelessWidget {
  const _Opener({required this.useRootNavigator});

  final bool useRootNavigator;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: _openKey,
      onPressed: () => unawaited(
        showDialog<void>(
          context: context,
          useRootNavigator: useRootNavigator,
          builder: (_) => const SizedBox(key: _dialogKey),
        ),
      ),
      child: const Text('open'),
    );
  }
}

List<Component> _catalog({required bool useRootNavigator}) => [
  Component(
    name: 'Opener',
    path: 'Foundation',
    stories: [_OpenerStory(useRootNavigator: useRootNavigator)],
  ),
];

NavigatorState _root(WidgetTester tester) =>
    Navigator.of(tester.element(find.byType(_Opener)), rootNavigator: true);

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

  testWidgets('fo11/us06/fr01/e01: a story that opens a dialog on the root '
      'navigator fails the test', (tester) async {
    await openStory<_Opener>(
      tester,
      _opener,
      catalog: _catalog(useRootNavigator: true),
    );
    final root = _root(tester);

    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isA<TestFailure>().having(
        (f) => f.message,
        'message',
        allOf(contains(_opener), contains('useRootNavigator: false')),
      ),
    );
    root.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('fo11/us06/fr01/e01: a story that opens a dialog with '
      'useRootNavigator: false passes the root route guard', (tester) async {
    await openStory<_Opener>(
      tester,
      _opener,
      catalog: _catalog(useRootNavigator: false),
    );

    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();

    expect(find.byKey(_dialogKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
