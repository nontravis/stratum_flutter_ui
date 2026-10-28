import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/kit/docs/accessibility_notes_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/catalog_docs.dart';
import 'package:stratum_ui_widgetbook/kit/docs/usage_doc_block.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../../support/knob_probe.dart';

/// Records the `text` of every `Clipboard.setData` call.
List<String> _recordClipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}

CatalogDocs _docs(String usage) => CatalogDocs(
  figma: null,
  usage: usage,
  dos: const ['Keep it short'],
  donts: const ['Nest it'],
  accessibility: const ['Reads as a button', 'Focus ring on keyboard focus'],
);

void main() {
  testWidgets('fo11/us03/fr01/e01: the copy action puts the shown code on the '
      'clipboard', (tester) async {
    final copied = _recordClipboard(tester);
    await tester.pumpWidget(
      probeApp(child: UsageDocBlock(_docs('Stub(label: 1)'))),
    );

    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pump();

    expect(copied, ['Stub(label: 1)']);
  });

  testWidgets('fo11/us03/fr01/e01: Review Focus 5', (tester) async {
    const usage = "StratumPlaceholderPage(\n  title: 'หน้านี้ยังไม่พร้อม',\n)";
    final copied = _recordClipboard(tester);
    await tester.pumpWidget(probeApp(child: UsageDocBlock(_docs(usage))));

    await tester.tap(find.text('Copy'));
    await tester.pump();

    expect(copied, [usage]);
  });

  testWidgets('fo11/us03/s1: the docs show every part', (tester) async {
    await tester.pumpWidget(
      probeApp(
        child: ColumnLayout(
          children: [
            UsageDocBlock(_docs('Stub()')),
            const AccessibilityNotesDocBlock(['Reads as a button']),
            const ArgsDocBlock(args: []),
          ],
        ),
      ),
    );

    expect(find.text('Stub()'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Do'), findsOneWidget);
    expect(find.text("Don't"), findsOneWidget);
    expect(find.text('Accessibility'), findsOneWidget);
    expect(find.text('Reads as a button'), findsOneWidget);
  });

  testWidgets('fo11/us03/s1: under Thai the labels read in Thai', (
    tester,
  ) async {
    await tester.pumpWidget(
      probeApp(
        locale: const Locale('th'),
        child: ColumnLayout(
          children: [
            UsageDocBlock(_docs('Stub()')),
            const AccessibilityNotesDocBlock(['x']),
          ],
        ),
      ),
    );

    for (final label in ['คัดลอก', 'ควรทำ', 'ไม่ควรทำ', 'การเข้าถึง']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });
}
