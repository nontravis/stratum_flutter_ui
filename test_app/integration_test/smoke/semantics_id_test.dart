import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui_test_app/fixture_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('smoke fixture keeps its semantics identifiers on device', (
    tester,
  ) async {
    await binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(const FixtureApp(fixtureId: 'smoke/semantics_id'));

    expect(find.bySemanticsIdentifier('smoke.button'), findsOneWidget);
    expect(find.bySemanticsIdentifier('smoke.taps'), findsOneWidget);

    await tester.tap(find.bySemanticsIdentifier('smoke.button'));
    await tester.pump();

    expect(find.text('taps: 1'), findsOneWidget);
  });
}
