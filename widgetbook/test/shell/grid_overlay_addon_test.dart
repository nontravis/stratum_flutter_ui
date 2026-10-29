import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/shell/grid_overlay_addon.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../support/catalog_theme.dart';

/// A tappable probe that sits under the overlays.
class _Probe extends StatelessWidget {
  const _Probe(this.onTap);

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: const SizedBox(width: 120, height: 80, child: Text('probe')),
  );
}

/// Whether the probe sits under a `CustomPaint` whose foreground painter
/// paints paragraphs: the screen-reader view's labels, drawn with a
/// `TextPainter`, so no text finder sees them.
bool _paintsLabels(WidgetTester tester) {
  final overProbe = find.ancestor(
    of: find.byType(_Probe),
    matching: find.byType(CustomPaint),
  );
  return overProbe.evaluate().any((element) {
    final paint = element.widget as CustomPaint;
    // The painter type names the screen-reader view: `paints` also records
    // the paragraphs of descendants such as the probe's own text.
    if (paint.foregroundPainter.runtimeType.toString() !=
        'SemanticsDebuggerPainter') {
      return false;
    }
    try {
      expect(element.renderObject, paints..paragraph());
      return true;
    } on TestFailure {
      return false;
    }
  });
}

/// Builds the grid and the semantics addons around a probe, in the order
/// [catalogAddons] puts them in.
Widget _chain(
  StratumThemeSet set, {
  required bool grid,
  required bool semantics,
  required VoidCallback onTap,
}) => MaterialApp(
  home: Center(
    child: StratumThemeApplication(
      themes: set,
      themeMode: ThemeMode.light,
      child: Builder(
        builder: (context) => GridOverlayAddon().apply(
          context,
          Builder(
            builder: (context) => SemanticsAddon().apply(
              context,
              Semantics(label: 'probe label', child: _Probe(onTap)),
              semantics,
            ),
          ),
          grid,
        ),
      ),
    ),
  ),
);

void main() {
  test('fo11/us02/fr03: the grid addon is one boolean field', () {
    final addon = GridOverlayAddon();

    expect(addon.name, 'Grid');
    expect(addon.initialValue, isFalse);
    expect(addon.fields.single.name, 'enabled');
  });

  testWidgets('fo11/us02/fr03, fo11/us02/s3: the screen-reader view paints '
      'each label over the story', (tester) async {
    final handle = tester.ensureSemantics();
    final set = await loadDefaultThemeSet();

    await tester.pumpWidget(
      _chain(set, grid: false, semantics: true, onTap: () {}),
    );
    await tester.pumpAndSettle();
    expect(_paintsLabels(tester), isTrue);

    await tester.pumpWidget(
      _chain(set, grid: false, semantics: false, onTap: () {}),
    );
    await tester.pumpAndSettle();
    expect(_paintsLabels(tester), isFalse);
    handle.dispose();
  });

  testWidgets('fo11/us02/fr03: the grid draws over the story when on', (
    tester,
  ) async {
    final set = await loadDefaultThemeSet();
    var taps = 0;

    await tester.pumpWidget(
      _chain(set, grid: false, semantics: false, onTap: () => taps++),
    );
    expect(find.byType(GridPaper), findsNothing);

    await tester.pumpWidget(
      _chain(set, grid: true, semantics: false, onTap: () => taps++),
    );
    expect(find.byType(GridPaper), findsOneWidget);

    final stack = tester.widget<Stack>(
      find
          .ancestor(of: find.byType(GridPaper), matching: find.byType(Stack))
          .first,
    );
    final probeIndex = stack.children.indexWhere(
      (child) => child is! Positioned,
    );
    final gridIndex = stack.children.indexWhere((child) => child is Positioned);
    expect(gridIndex, greaterThan(probeIndex));

    final stackSize = tester.getSize(
      find
          .ancestor(of: find.byType(GridPaper), matching: find.byType(Stack))
          .first,
    );
    expect(tester.getSize(find.byType(GridPaper)), stackSize);
    expect(tester.getSize(find.byType(GridPaper)), isNot(Size.zero));

    await tester.tap(find.byType(_Probe));
    expect(taps, 1);
  });

  testWidgets('fo11/us02/fr03/e01: both overlays together', (tester) async {
    final handle = tester.ensureSemantics();
    final set = await loadDefaultThemeSet();
    var taps = 0;

    await tester.pumpWidget(
      _chain(set, grid: true, semantics: true, onTap: () => taps++),
    );
    await tester.pumpAndSettle();

    expect(_paintsLabels(tester), isTrue);
    expect(find.byType(GridPaper), findsOneWidget);
    expect(tester.getSize(find.byType(GridPaper)), isNot(Size.zero));
    await tester.tap(find.byType(_Probe));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('fo11/us02/fr03: the grid leaves the story constraints '
      'unchanged', (tester) async {
    final set = await loadDefaultThemeSet();

    Future<BoxConstraints> constraintsWith({required bool grid}) async {
      late BoxConstraints seen;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 300,
              height: 200,
              child: StratumThemeApplication(
                themes: set,
                themeMode: ThemeMode.light,
                child: Builder(
                  builder: (context) => GridOverlayAddon().apply(
                    context,
                    LayoutBuilder(
                      builder: (_, constraints) {
                        seen = constraints;
                        return const SizedBox.shrink();
                      },
                    ),
                    grid,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return seen;
    }

    final off = await constraintsWith(grid: false);
    final on = await constraintsWith(grid: true);

    expect(off, BoxConstraints.tight(const Size(300, 200)));
    expect(on, off);
  });
}
