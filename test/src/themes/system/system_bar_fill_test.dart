// The Build Gate of `stratum-create-widget` for `SystemBarFill` (FO-03
// US-14; design `## Accessibility and UX`). One test per row below; the
// rows answered n/a, each with its reason:
// - NFR-U02 n/a: the fill holds no focusable node.
// - NFR-U03 n/a: the fill runs no animation.
// - NFR-U04 n/a: the fill draws no text.
// - NFR-U05 n/a: the fill holds no target.
// - NFR-U08 n/a: the fill shows no state.
// - NFR-U09 n/a: the fill handles no gesture.
// - NFR-E01 n/a: the fill draws no visual value of its own; its child
//   paints the color the caller declares.
// - NFR-E02 n/a: the fill has no style of its own; its one field is the
//   color its child paints.
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/system/system_bars.dart';

import 'system_style_fakes.dart';

/// A page whose 48 px Play button sits under the status bar inside
/// [wrap].
Widget _page(Widget Function(Widget child) wrap, {VoidCallback? onTap}) =>
    systemStyleApp(
      home: Align(
        alignment: Alignment.topCenter,
        child: wrap(
          Semantics(
            button: true,
            label: 'Play',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap ?? () {},
              child: const SizedBox(width: 48, height: 48),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('NFR-U06, us14/fr05/e04: the fill owns no semantics node and '
      'the child reads unchanged', (tester) async {
    systemBarsView(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_page((child) => child));
    final plain = semanticsTree(tester);

    await tester.pumpWidget(
      _page(
        (child) => SystemBarFill(color: const Color(0xFF000000), child: child),
      ),
    );

    expect(semanticsTree(tester), plain);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Play')),
      matchesSemantics(label: 'Play', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('us14/fr05: the fill paints nothing, takes no focus, and '
      'leaves a tap to its child', (tester) async {
    systemBarsView(tester);
    var taps = 0;
    await tester.pumpWidget(_page((child) => child, onTap: () => taps++));
    final focusNodes = FocusManager.instance.rootScope.descendants.length;

    await tester.pumpWidget(
      _page(
        (child) => SystemBarFill(color: const Color(0xFF000000), child: child),
        onTap: () => taps++,
      ),
    );
    await tester.tap(find.bySemanticsLabel('Play'));

    expect(taps, 1);
    expect(FocusManager.instance.rootScope.descendants, hasLength(focusNodes));
    expect(tester.renderObject(find.byType(SystemBarFill)), paintsNothing);
  });

  for (final fill in const [
    Color(0xFF000000),
    Color(0xFFFFFFFF),
    Color(0xFF3B82F6),
    Color(0xFF777777),
    Color(0xFFFFEB3B),
  ]) {
    testWidgets('NFR-U01, NFR-U07, us14/fr02: automatic icons hold 3:1 '
        'against the declared fill $fill', (tester) async {
      systemBarsView(tester);
      await tester.pumpWidget(systemStyleApp(home: headerPage(fill)));

      expect(
        contrastRatio(latestStatusIconColor(), fill),
        greaterThanOrEqualTo(3),
      );
    });
  }
}
