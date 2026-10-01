import 'package:flutter_test/flutter_test.dart';
// The public library, to prove the guard is exported.
import 'package:stratum_ui/stratum_ui.dart';

void main() {
  group('primaryFocusInEditableText', () {
    testWidgets('is false while a button has focus', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: TextButton(
              focusNode: node,
              onPressed: () {},
              child: const Text('a'),
            ),
          ),
        ),
      );
      node.requestFocus();
      await tester.pump();

      expect(primaryFocusInEditableText(), isFalse);
    });

    testWidgets('is true while a TextField has focus', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Material(child: TextField(focusNode: node)),
        ),
      );
      node.requestFocus();
      await tester.pump();

      expect(primaryFocusInEditableText(), isTrue);
    });
  });
}
