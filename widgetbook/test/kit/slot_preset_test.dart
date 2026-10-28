import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/kit/sample_text.dart';
import 'package:stratum_ui_widgetbook/kit/slot_preset.dart';

import '../support/knob_probe.dart';

/// Pumps the probe with the slot [preset] picked.
Future<void> _pump(WidgetTester tester, SlotPreset preset) => tester.pumpWidget(
  probeApp(
    child: Builder(
      builder: (context) =>
          KnobProbe(slot: slotFor(context, preset, name: 'leading')),
    ),
  ),
);

void main() {
  testWidgets('fo11/us04/fr02, fo11/us04/s2: the slot knob shows each '
      'preset', (tester) async {
    await _pump(tester, SlotPreset.icon);
    expect(find.byIcon(Icons.star_outline), findsOneWidget);
    expect(find.text('Label'), findsNothing);

    await _pump(tester, SlotPreset.text);
    expect(find.text(SampleTexts.label.en), findsOneWidget);
    expect(find.byIcon(Icons.star_outline), findsNothing);
  });

  testWidgets('fo11/us04/fr02/e01: none leaves the slot empty', (tester) async {
    await _pump(tester, SlotPreset.none);

    expect(find.byType(KnobProbe), findsOneWidget);
    expect(find.byType(StratumSlot), findsNothing);
    expect(find.byIcon(Icons.star_outline), findsNothing);
    expect(find.text('Label'), findsNothing);
  });

  testWidgets('fo11/us04/fr02/e02: slot placeholder shows a slot '
      'placeholder', (tester) async {
    await _pump(tester, SlotPreset.slot);

    expect(find.text('❖ leading'), findsOneWidget);
    expect(find.byType(StratumSlot), findsOneWidget);
    expect(find.byIcon(Icons.star_outline), findsNothing);
    expect(find.text('Label'), findsNothing);
  });

  testWidgets('fo11/us04/fr05: the text preset follows the toolbar language', (
    tester,
  ) async {
    await tester.pumpWidget(
      probeApp(
        locale: const Locale('th'),
        child: Builder(
          builder: (context) => KnobProbe(
            slot: slotFor(
              context,
              SlotPreset.text,
              name: 'leading',
              text: SampleTexts.close,
            ),
          ),
        ),
      ),
    );

    expect(find.text(SampleTexts.close.th), findsOneWidget);
  });
}
