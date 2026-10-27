import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart' show EditableText, Focus;
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart' show StratumThemeController;
import 'package:stratum_ui_test_app/fixture_app.dart';

const _fixtureId = 'feedback/toast_shortcut';
const _fieldLabel = 'Note';
const _showLabel = 'Show notice';
const _message = 'Note saved';
const _actionLabel = 'Undo';
const _typed = 'abc';

Future<void> _openFixture(WidgetTester tester) async {
  // The theme preload reads assets, which needs real time, not fake async.
  final controller = await tester.runAsync(
    () => StratumThemeController.preload(googleFontsTimeout: Duration.zero),
  );
  addTearDown(controller!.dispose);
  await tester.pumpWidget(
    FixtureApp(fixtureId: _fixtureId, themeController: controller),
  );
  await tester.pumpAndSettle();
}

/// Whether the primary focus sits on [finder]'s nearest focus scope owner or
/// inside it.
bool _focusIsInside(Finder finder) =>
    Focus.of(finder.evaluate().single).hasFocus;

bool _fieldHasFocus(WidgetTester tester) => tester
    .widget<EditableText>(find.byType(EditableText))
    .focusNode
    .hasPrimaryFocus;

String _fieldText(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller.text;

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets(
    'before any tap the field and the button show and no notice does',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _openFixture(tester);

      expect(find.bySemanticsLabel(_fieldLabel), findsOneWidget);
      expect(find.bySemanticsLabel(_showLabel), findsOneWidget);
      expect(find.text(_message), findsNothing);
      expect(find.text(_actionLabel), findsNothing);
      handle.dispose();
    },
  );

  testWidgets('Show notice shows Note saved with its Undo action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    await tester.tap(find.text(_showLabel));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text(_message), findsWidgets);
    expect(find.text(_actionLabel), findsOneWidget);
    handle.dispose();
    await tester.pumpAndSettle(const Duration(seconds: 9));
  });

  testWidgets(
    'on macOS Option+T then F8 move focus from Note into Undo, and Esc '
    'returns it with abc intact',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final handle = tester.ensureSemantics();
      await _openFixture(tester);
      await tester.enterText(find.byType(EditableText), _typed);

      for (final press in <Future<void> Function()>[
        () =>
            tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft).then((_) async {
              await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
              await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
            }),
        () => tester.sendKeyEvent(LogicalKeyboardKey.f8),
      ]) {
        await tester.tap(find.text(_showLabel));
        await tester.pump();
        await tester.pumpAndSettle();
        await tester.tap(find.byType(EditableText));
        await tester.pump();

        await press();
        await tester.pump();

        expect(_focusIsInside(find.text(_actionLabel)), isTrue);
        expect(_fieldText(tester), _typed);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(find.text(_actionLabel), findsNothing);
        expect(_fieldHasFocus(tester), isTrue);
        expect(_fieldText(tester), _typed);
      }
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
