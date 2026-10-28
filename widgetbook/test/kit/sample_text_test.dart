import 'package:stratum_ui/stratum_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui_widgetbook/kit/sample_text.dart';

import '../support/knob_probe.dart';

/// Shows every sample text, resolved against the locale the story sees.
class _AllTexts extends StatelessWidget {
  const _AllTexts();

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return ColumnLayout(
      children: [
        for (final text in [
          SampleTexts.label,
          SampleTexts.title,
          SampleTexts.message,
          SampleTexts.close,
        ])
          Text(text.resolve(locale)),
      ],
    );
  }
}

final _thai = RegExp('[฀-๿]');

void main() {
  testWidgets('fo11/us04/fr05, fo11/us04/s5: sample text follows the toolbar '
      'language', (tester) async {
    await tester.pumpWidget(
      probeApp(locale: const Locale('th'), child: const _AllTexts()),
    );

    expect(find.text('ป้ายกำกับ'), findsOneWidget);
    expect(find.text(SampleTexts.label.th), findsOneWidget);
    expect(find.text('หัวข้อ'), findsOneWidget);
    expect(
      find.text('ข้อความตัวอย่างสำหรับดูการตัดบรรทัดของภาษาไทยในพื้นที่แคบ'),
      findsOneWidget,
    );
    expect(find.text('ปิด'), findsOneWidget);
  });

  testWidgets('fo11/us04/fr05/e01: switching the language switches every '
      'sample text', (tester) async {
    await tester.pumpWidget(
      probeApp(locale: const Locale('th'), child: const _AllTexts()),
    );
    expect(find.text('ปิด'), findsOneWidget);

    await tester.pumpWidget(
      probeApp(locale: const Locale('en'), child: const _AllTexts()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Label'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(
      find.text('A sample message to see how text wraps in a narrow space'),
      findsOneWidget,
    );
    expect(find.text('Close'), findsOneWidget);
    final shown = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .join();
    expect(shown, isNot(matches(_thai)));
  });

  test('fo11/us04/fr05: a locale other than Thai resolves to English', () {
    expect(SampleTexts.title.resolve(const Locale('fr')), 'Title');
  });
}
