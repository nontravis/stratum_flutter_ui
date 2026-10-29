import 'package:flutter/material.dart';
import 'package:stratum_ui_widgetbook/kit/callback_report.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../support/knob_probe.dart';

/// Test-only story args whose one value tells two [reportingSetup] keys
/// apart.
class _Args extends StoryArgs<KnobProbe> {
  _Args(bool on) : _on = BoolArg(on, name: 'on');

  final BoolArg _on;

  @override
  List<Arg?> get list => [_on];
}

/// A probe wired to report its callbacks, built under [reportingSetup].
Widget _story(BuildContext context, _Args args) => reportingSetup(
  context,
  Builder(
    builder: (inner) => KnobProbe(
      onPressed: reportCallback(inner, 'onPressed'),
      onChanged: reportValue<String>(inner, 'onChanged'),
    ),
  ),
  args,
);

void main() {
  testWidgets('fo11/us04/fr03, fo11/us04/s3: a tap reports onPressed called', (
    tester,
  ) async {
    await tester.pumpWidget(
      probeApp(
        child: Builder(builder: (context) => _story(context, _Args(true))),
      ),
    );
    expect(find.byType(CallbackReport), findsOneWidget);
    expect(find.textContaining('called'), findsNothing);

    await tester.tap(find.byKey(probePressKey));
    await tester.pump();

    expect(find.text('onPressed called'), findsOneWidget);
  });

  testWidgets('fo11/us04/fr03/e01: a change callback reports by its name', (
    tester,
  ) async {
    await tester.pumpWidget(
      probeApp(
        child: Builder(builder: (context) => _story(context, _Args(true))),
      ),
    );

    await tester.tap(find.byKey(probeChangeKey));
    await tester.pump();

    expect(find.text('onChanged called'), findsOneWidget);
    expect(find.text('onPressed called'), findsNothing);
  });

  testWidgets("fo11/us04/fr03: reportingSetup still resets the story's state "
      'on a knob change', (tester) async {
    Widget app(_Args args) =>
        probeApp(child: Builder(builder: (context) => _story(context, args)));

    await tester.pumpWidget(app(_Args(true)));
    await tester.tap(find.byKey(probeBumpKey));
    await tester.tap(find.byKey(probePressKey));
    await tester.pump();
    expect(find.text('count 1'), findsOneWidget);
    expect(find.text('onPressed called'), findsOneWidget);

    await tester.pumpWidget(app(_Args(false)));

    expect(find.text('count 0'), findsOneWidget);
    expect(find.text('onPressed called'), findsOneWidget);
  });

  testWidgets(
    'fo11/us04/fr03: a callback made before a knob change still reports '
    'after it',
    (tester) async {
      late VoidCallback made;
      Widget app(_Args args) => probeApp(
        child: Builder(
          builder: (context) => reportingSetup(
            context,
            Builder(
              builder: (inner) {
                made = reportCallback(inner, 'onPressed');
                return const SizedBox.shrink();
              },
            ),
            args,
          ),
        ),
      );

      await tester.pumpWidget(app(_Args(true)));
      final before = made;
      await tester.pumpWidget(app(_Args(false)));

      before();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('onPressed called'), findsOneWidget);
    },
  );

  testWidgets('fo11/us04/fr03: reporting without reportingSetup fails loudly', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      probeApp(
        child: Builder(
          builder: (inner) {
            context = inner;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      () => CallbackReport.report(context, 'onPressed'),
      throwsAssertionError,
    );
  });

  testWidgets('fo11/us04/fr03: the report passes a bounded height to a story '
      'that needs one', (tester) async {
    await tester.pumpWidget(
      probeApp(
        child: SizedBox(
          height: 300,
          child: Builder(
            builder: (context) => reportingSetup(
              context,
              ListView(children: const [Text('row')]),
              _Args(true),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('row'), findsOneWidget);
  });

  testWidgets('fo11/us04/fr03: the report lays out under an unbounded '
      'height', (tester) async {
    await tester.pumpWidget(
      probeApp(
        child: SingleChildScrollView(
          child: Builder(
            builder: (context) =>
                reportingSetup(context, const Text('row'), _Args(true)),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('row'), findsOneWidget);
  });
}
