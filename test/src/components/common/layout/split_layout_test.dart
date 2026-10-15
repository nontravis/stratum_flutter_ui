import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/l10n/built_in_labels.dart';
import 'package:stratum_ui/src/components/common/layout/split_layout.dart'
    show splitStep;
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

// NFR-U01 and NFR-U07 n/a: the divider draws no text and no line of its
// own (R17); its one non-text look, the FO-06 focus ring, has its token
// pair measured in the theme yaml test (US-04 NF-01).
// NFR-U03 n/a: the divider runs no size or position animation; a drag
// follows the pointer and a key step jumps. Only the ring's fade animates.
// NFR-U04 n/a: the divider carries no text; each pane's content wraps or
// scrolls inside its pane.
// NFR-E02 n/a: SplitLayout takes no per-instance customStyle, since it
// paints nothing of its own but the FO-06 ring (US-21 FR-05); the app
// paints a divider through dividerBuilder (us21/fr05/e04), and the ring
// takes the app-wide StratumFocusBorder style, proven below.

/// A 1000 x 400 test view, so a 300 px list pane is 30% of the split;
/// reset after the test.
void _view(WidgetTester tester, [Size size = const Size(1000, 400)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A pane that shows [label], a Tab stop of its own when [node] is set.
Widget _pane(String label, [FocusNode? node]) =>
    node == null ? Text(label) : Focus(focusNode: node, child: Text(label));

/// The list pane: 300 px, from 200 to [max].
SplitPane _list({double? max = 500, FocusNode? node}) =>
    SplitPane(size: 300, min: 200, max: max, child: _pane('List', node));

/// The detail pane: the rest of the split, at least 300 px.
SplitPane _detail({FocusNode? node}) =>
    SplitPane(flex: 1, min: 300, child: _pane('Detail', node));

/// A list and detail split under the app's default Tab and activation
/// keys, in a focused scope so the first Tab press reaches the keys.
Widget _split({
  List<SplitPane?>? panes,
  bool resizable = true,
  bool detail = true,
  bool endPrimary = false,
  String? label,
  SplitDividerBuilder? dividerBuilder,
  SplitLayoutController? controller,
  TextDirection direction = TextDirection.ltr,
  Axis axis = Axis.horizontal,
  StratumThemeData? theme,
  bool highContrast = false,
  Map<Type, WidgetStyle> componentStyles = const {},
}) => (highContrast ? _highContrastHost : themedHost)(
  StratumComponentDefaults(
    styles: componentStyles,
    child: Shortcuts(
      shortcuts: WidgetsApp.defaultShortcuts,
      child: Actions(
        actions: WidgetsApp.defaultActions,
        child: FocusScope(
          autofocus: true,
          child: SplitLayout(
            axis: axis,
            resizable: resizable,
            endPrimary: endPrimary,
            dividerLabel: label,
            dividerBuilder: dividerBuilder,
            controller: controller,
            panes: panes ?? [_list(), if (detail) _detail() else null],
          ),
        ),
      ),
    ),
  ),
  textDirection: direction,
  theme: theme,
);

/// [child] under the package default's high-contrast light theme.
Widget _highContrastHost(
  Widget child, {
  StratumThemeData? theme,
  TextDirection textDirection = TextDirection.ltr,
}) => StratumThemeApplication(
  themes: defaultThemeSet,
  themeMode: ThemeMode.light,
  highContrast: StratumHighContrastMode.on,
  child: Directionality(
    textDirection: textDirection,
    child: Center(child: child),
  ),
);

double _listWidth(WidgetTester tester) =>
    tester.getSize(find.text('List')).width;

Finder get _divider => find.bySemanticsLabel('Resize panes');

/// The divider's hit area: the box the seam's builder, ring, and node fill.
Finder get _hitArea =>
    find.ancestor(of: _divider, matching: find.byType(Positioned)).first;

/// The color the divider's focus ring paints, alpha 0 while hidden.
Color _ring(WidgetTester tester) {
  Color? color;
  expect(
    tester.renderObject(
      find.descendant(of: _divider, matching: find.byType(DecoratedBox)).first,
    ),
    paints..everything((method, arguments) {
      color ??= arguments.whereType<Paint>().firstOrNull?.color;
      return true;
    }),
  );
  return color!;
}

/// Whether every paint call under [finder] paints a clear color.
bool _paintsNothingVisible(WidgetTester tester, Finder finder) {
  var visible = false;
  expect(
    tester.renderObject(finder),
    paints..everything((method, arguments) {
      for (final paint in arguments.whereType<Paint>()) {
        if (paint.color.a > 0) visible = true;
      }
      return true;
    }),
  );
  return !visible;
}

/// A painted 1 px line, keyed [_lineKey], that records each state it gets.
SplitDividerBuilder _line(List<SplitDividerState> states) => (context, state) {
  states.add(state);
  return Center(
    child: SizedBox(
      key: _lineKey,
      width: 1,
      height: double.infinity,
      child: ColoredBox(
        color: StratumTheme.of(context).color.border.defaults.normal,
      ),
    ),
  );
};

const ValueKey<String> _lineKey = ValueKey('line');

/// A controller that counts its notifications in [notifies], disposed
/// after the test.
SplitLayoutController _counted(List<int> notifies, {List<double>? fractions}) {
  final controller = SplitLayoutController(fractions: fractions)
    ..addListener(() => notifies[0]++);
  addTearDown(controller.dispose);
  return controller;
}

/// Kept values that are no finite number of at least 0, as storage can hand
/// back: NaN, both infinities, a negative, and a JSON number past the
/// double range.
final _unusable = <double>[
  double.nan,
  double.infinity,
  double.negativeInfinity,
  -0.5,
  (jsonDecode('1e309') as num).toDouble(),
];

/// A controller whose getter hands the split [raw] unchecked, as a subclass
/// may, so a test reaches the split's own read of the fractions.
class _Unchecked extends SplitLayoutController {
  new(this.raw);

  final List<double?> raw;

  @override
  List<double?>? get fractions => raw;
}

/// The divider's own focus node.
FocusNode _dividerNode(WidgetTester tester) => tester
    .widget<Focus>(
      find.descendant(of: _divider, matching: find.byType(Focus)).first,
    )
    .focusNode!;

/// Presses Tab, which reaches the divider first when no pane holds a Tab
/// stop.
Future<void> _tab(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
}

/// Presses [key] while Shift is held.
Future<void> _shift(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

/// Presses [key] and lets the frame build.
Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

void main() {
  group('splitStep', () {
    test('fo06/us21/fr03/e03: a step stops at the start pane maximum', () {
      expect(splitStep(start: 490, end: 510, delta: 16, startMax: 500), 500);
    });

    test('fo06/us21/fr02/e02: a step stops at the neighbor minimum', () {
      expect(splitStep(start: 600, end: 310, delta: 64, endMin: 300), 610);
    });

    test('fo06/us21/fr03/e03: a step stops at the start pane minimum', () {
      expect(splitStep(start: 210, end: 790, delta: -64, startMin: 200), 200);
    });

    test('fo06/us21/fr02/e02: a step stops at the neighbor maximum', () {
      expect(splitStep(start: 600, end: 400, delta: -64, endMax: 450), 550);
    });

    test('fo06/us21/fr03: a free step moves by the whole delta', () {
      expect(splitStep(start: 300, end: 700, delta: 16), 316);
    });
  });

  group('SplitLayout panes', () {
    test('fo06/us21/fr01: SplitPane has value equality and copyWith', () {
      // Built at run time from a parameter, so no const canonicalization
      // makes them one instance and the check reads `==`, not identity.
      SplitPane make(double min) =>
          SplitPane(child: const SizedBox(), size: 100, min: min);
      final a = make(50);
      final b = make(50);
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      final c = a.copyWith(min: 60);
      expect(c.min, 60);
      expect(c.size, 100);
    });

    test('fo06/us21/fr01: SplitPane copyWith honors the min-max assert', () {
      const pane = SplitPane(child: SizedBox(), min: 50);
      expect(() => pane.copyWith(max: 10), throwsA(isA<AssertionError>()));
    });

    testWidgets('fo06/us21/fr01/e01: two panes side by side with one divider', (
      tester,
    ) async {
      _view(tester);
      await tester.pumpWidget(_split());
      expect(_listWidth(tester), 300);
      expect(tester.getSize(find.text('Detail')).width, 700);
      expect(
        tester.getTopLeft(find.text('Detail')).dx,
        tester.getTopRight(find.text('List')).dx,
      );
      expect(_divider, findsOneWidget);
    });

    testWidgets(
      'fo06/us21/s6: fo06/us21/fr01/e02: a null pane leaves no divider',
      (tester) async {
        _view(tester);
        await tester.pumpWidget(_split(detail: false));
        expect(_divider, findsNothing);
        expect(_listWidth(tester), 1000);
      },
    );

    testWidgets('fo06/us21/fr01/e03: RTL puts the first pane on the right', (
      tester,
    ) async {
      _view(tester);
      await tester.pumpWidget(_split(direction: TextDirection.rtl));
      expect(tester.getTopRight(find.text('List')).dx, 1000);
      expect(_listWidth(tester), 300);
      expect(tester.getTopLeft(find.text('Detail')).dx, 0);
    });

    testWidgets(
      'fo06/us21/fr01: a vertical split stacks the first pane on top',
      (tester) async {
        _view(tester);
        await tester.pumpWidget(
          _split(
            axis: Axis.vertical,
            panes: [
              SplitPane(size: 100, child: _pane('List')),
              SplitPane(child: _pane('Detail')),
            ],
          ),
        );
        expect(tester.getSize(find.text('List')).height, 100);
        expect(tester.getTopLeft(find.text('Detail')).dy, 100);
      },
    );

    testWidgets(
      'fo06/us21/fr01/e02: a pane keeps its State when its neighbor hides and shows',
      (tester) async {
        _view(tester);
        await tester.pumpWidget(_split());
        final list = tester.element(find.text('List'));
        await tester.pumpWidget(_split(detail: false));
        await tester.pumpWidget(_split());
        expect(tester.element(find.text('List')), same(list));
      },
    );
  });

  group('SplitLayout keyboard', () {
    testWidgets(
      'fo06/us21/s2: fo06/us21/fr03: Tab reaches the divider and the right '
      'arrow steps 16',
      (tester) async {
        _view(tester);
        await tester.pumpWidget(_split());
        await _tab(tester);
        expect(_dividerNode(tester).hasPrimaryFocus, isTrue);
        await _press(tester, LogicalKeyboardKey.arrowRight);
        expect(_listWidth(tester), closeTo(316, 1));
      },
    );

    testWidgets('fo06/us21/fr03/e06: Shift with an arrow steps 64', (
      tester,
    ) async {
      _view(tester);
      await tester.pumpWidget(_split());
      await _tab(tester);
      await _shift(tester, LogicalKeyboardKey.arrowRight);
      expect(_listWidth(tester), closeTo(364, 1));
    });

    testWidgets(
      'fo06/us21/s3: End takes the start pane maximum, Home its minimum',
      (tester) async {
        _view(tester);
        await tester.pumpWidget(_split());
        await _tab(tester);
        await _press(tester, LogicalKeyboardKey.end);
        expect(_listWidth(tester), closeTo(500, 1));
        await _press(tester, LogicalKeyboardKey.home);
        expect(_listWidth(tester), closeTo(200, 1));
      },
    );

    for (final direction in TextDirection.values) {
      testWidgets('fo06/us19/fr06/e02: with the end pane primary under '
          '${direction.name}, End takes the end pane to its maximum and Home '
          'to its minimum, and the arrows still move by screen direction', (
        tester,
      ) async {
        _view(tester);
        await tester.pumpWidget(_split(endPrimary: true, direction: direction));
        await _tab(tester);
        await _press(tester, LogicalKeyboardKey.end);
        expect(_listWidth(tester), closeTo(200, 1));
        await _press(tester, LogicalKeyboardKey.home);
        expect(_listWidth(tester), closeTo(500, 1));
        // From its maximum the list narrows toward the divider's side.
        final ltr = direction == TextDirection.ltr;
        final before = tester.getCenter(_divider).dx;
        await _press(
          tester,
          ltr ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight,
        );
        expect(
          tester.getCenter(_divider).dx,
          closeTo(before + (ltr ? -16 : 16), 1),
        );
        expect(_listWidth(tester), closeTo(484, 1));
      });
    }

    testWidgets(
      'fo06/us21/fr03: End stops at the neighbor minimum when the start '
      'pane has no '
      'maximum',
      (tester) async {
        _view(tester);
        await tester.pumpWidget(_split(panes: [_list(max: null), _detail()]));
        await _tab(tester);
        await _press(tester, LogicalKeyboardKey.end);
        expect(_listWidth(tester), closeTo(700, 1));
      },
    );

    testWidgets('fo06/us21/fr03/e03: an arrow step past a limit stops there', (
      tester,
    ) async {
      _view(tester);
      await tester.pumpWidget(_split());
      await _tab(tester);
      await _press(tester, LogicalKeyboardKey.end);
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_listWidth(tester), closeTo(500, 1));
    });

    testWidgets(
      'fo06/us21/s5: under RTL the left arrow moves the divider left on '
      'screen and Shift stops at the limit',
      (tester) async {
        _view(tester);
        await tester.pumpWidget(_split(direction: TextDirection.rtl));
        final before = tester.getCenter(_divider).dx;
        await _tab(tester);
        await _press(tester, LogicalKeyboardKey.arrowLeft);
        expect(tester.getCenter(_divider).dx, closeTo(before - 16, 1));
        for (var i = 0; i < 10; i++) {
          await _shift(tester, LogicalKeyboardKey.arrowLeft);
        }
        expect(_listWidth(tester), closeTo(500, 1));
      },
    );

    testWidgets(
      'fo06/us21/fr03/e02: under RTL the right arrow moves the divider '
      'right on screen',
      (tester) async {
        _view(tester);
        await tester.pumpWidget(_split(direction: TextDirection.rtl));
        final before = tester.getCenter(_divider).dx;
        await _tab(tester);
        await _press(tester, LogicalKeyboardKey.arrowRight);
        expect(tester.getCenter(_divider).dx, closeTo(before + 16, 1));
        expect(_listWidth(tester), closeTo(284, 1));
      },
    );

    testWidgets(
      'fo06/us21/fr03/e04: the up arrow on a horizontal split passes on',
      (tester) async {
        _view(tester);
        final upKeys = <KeyEvent>[];
        await tester.pumpWidget(
          Focus(
            onKeyEvent: (node, event) {
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                upKeys.add(event);
              }
              return KeyEventResult.ignored;
            },
            child: _split(),
          ),
        );
        await _tab(tester);
        expect(_dividerNode(tester).hasPrimaryFocus, isTrue);
        await _press(tester, LogicalKeyboardKey.arrowUp);
        expect(_listWidth(tester), closeTo(300, 1));
        expect(upKeys, isNotEmpty);
      },
    );

    testWidgets(
      'fo06/us21/fr03/e04: a vertical split steps by the down arrow and '
      'passes the '
      'left arrow on',
      (tester) async {
        _view(tester);
        await tester.pumpWidget(
          _split(
            axis: Axis.vertical,
            panes: [
              SplitPane(size: 100, child: _pane('List')),
              SplitPane(child: _pane('Detail')),
            ],
          ),
        );
        await _tab(tester);
        await _press(tester, LogicalKeyboardKey.arrowDown);
        expect(tester.getSize(find.text('List')).height, closeTo(116, 1));
        await _press(tester, LogicalKeyboardKey.arrowLeft);
        expect(tester.getSize(find.text('List')).height, closeTo(116, 1));
      },
    );

    testWidgets(
      'fo06/us21/fr03/e01: Tab visits the start pane, the divider, then '
      'the end pane',
      (tester) async {
        _view(tester);
        final list = FocusNode();
        final detail = FocusNode();
        addTearDown(list.dispose);
        addTearDown(detail.dispose);
        await tester.pumpWidget(
          _split(
            panes: [
              _list(node: list),
              _detail(node: detail),
            ],
          ),
        );
        await _tab(tester);
        expect(list.hasPrimaryFocus, isTrue);
        await _tab(tester);
        expect(_dividerNode(tester).hasPrimaryFocus, isTrue);
        await _tab(tester);
        expect(detail.hasPrimaryFocus, isTrue);
      },
    );

    for (final direction in TextDirection.values) {
      testWidgets('fo06/us21/fr03/e01: Tab finishes the start pane before the '
          'divider and the end pane, two stops a pane, ${direction.name}', (
        tester,
      ) async {
        _view(tester);
        final nodes = [for (var i = 0; i < 4; i++) FocusNode()];
        for (final node in nodes) {
          addTearDown(node.dispose);
        }
        Widget rows(String label, FocusNode top, FocusNode bottom) => Column(
          children: [
            Focus(
              focusNode: top,
              child: SizedBox(height: 50, child: Text('$label 1')),
            ),
            Focus(
              focusNode: bottom,
              child: SizedBox(height: 50, child: Text('$label 2')),
            ),
          ],
        );
        await tester.pumpWidget(
          _split(
            direction: direction,
            panes: [
              SplitPane(size: 300, child: rows('List', nodes[0], nodes[1])),
              SplitPane(child: rows('Detail', nodes[2], nodes[3])),
            ],
          ),
        );
        final order = <String>[];
        for (var i = 0; i < 5; i++) {
          await _tab(tester);
          order.add(
            _dividerNode(tester).hasPrimaryFocus
                ? 'divider'
                : 'pane ${nodes.indexWhere((node) => node.hasPrimaryFocus)}',
          );
        }
        expect(order, ['pane 0', 'pane 1', 'divider', 'pane 2', 'pane 3']);
      });
    }

    testWidgets('fo06/us21/fr03/e05: with resizing off Tab never stops on a '
        'divider', (tester) async {
      _view(tester);
      final list = FocusNode();
      final detail = FocusNode();
      addTearDown(list.dispose);
      addTearDown(detail.dispose);
      await tester.pumpWidget(
        _split(
          resizable: false,
          panes: [
            _list(node: list),
            _detail(node: detail),
          ],
        ),
      );
      await _tab(tester);
      expect(list.hasPrimaryFocus, isTrue);
      await _tab(tester);
      expect(detail.hasPrimaryFocus, isTrue);
    });
  });

  group('SplitLayout slider node', () {
    testWidgets(
      'NFR-U06: fo06/us21/s4: fo06/us21/fr04/e01: a slider node with label, '
      'percent, focus, and step actions',
      (tester) async {
        _view(tester);
        await tester.pumpWidget(_split());
        expect(
          tester.getSemantics(_divider),
          matchesSemantics(
            label: 'Resize panes',
            value: '30%',
            increasedValue: '32%',
            decreasedValue: '28%',
            isSlider: true,
            isFocusable: true,
            hasFocusAction: true,
            hasIncreaseAction: true,
            hasDecreaseAction: true,
          ),
        );
        await _tab(tester);
        expect(
          tester.getSemantics(_divider),
          matchesSemantics(
            label: 'Resize panes',
            value: '30%',
            increasedValue: '32%',
            decreasedValue: '28%',
            isSlider: true,
            isFocusable: true,
            isFocused: true,
            hasFocusAction: true,
            hasIncreaseAction: true,
            hasDecreaseAction: true,
          ),
        );
        tester.semantics.performAction(
          find.semantics.byLabel('Resize panes'),
          SemanticsAction.increase,
        );
        await tester.pump();
        expect(_listWidth(tester), closeTo(316, 1));
        expect(tester.getSemantics(_divider).value, '32%');
      },
    );

    testWidgets(
      'fo06/us19/fr06: with the end pane primary the slider reads the '
      "end pane's share, and increase widens the end pane",
      (tester) async {
        _view(tester);
        await tester.pumpWidget(_split(endPrimary: true));
        expect(
          tester.getSemantics(_divider),
          matchesSemantics(
            label: 'Resize panes',
            value: '70%',
            increasedValue: '72%',
            decreasedValue: '68%',
            isSlider: true,
            isFocusable: true,
            hasFocusAction: true,
            hasIncreaseAction: true,
            hasDecreaseAction: true,
          ),
        );
        tester.semantics.performAction(
          find.semantics.byLabel('Resize panes'),
          SemanticsAction.increase,
        );
        await tester.pump();
        expect(_listWidth(tester), closeTo(284, 1));
        expect(tester.getSemantics(_divider).value, '72%');
        tester.semantics.performAction(
          find.semantics.byLabel('Resize panes'),
          SemanticsAction.decrease,
        );
        await tester.pump();
        expect(_listWidth(tester), closeTo(300, 1));
      },
    );

    testWidgets(
      'fo06/us21/fr04: the decrease action steps the divider toward the start',
      (tester) async {
        _view(tester);
        await tester.pumpWidget(_split());
        tester.semantics.performAction(
          find.semantics.byLabel('Resize panes'),
          SemanticsAction.decrease,
        );
        await tester.pump();
        expect(_listWidth(tester), closeTo(284, 1));
      },
    );

    testWidgets(
      'fo06/us21/fr04/e04: increase at the start pane maximum keeps the '
      'divider and its value',
      (tester) async {
        _view(tester);
        await tester.pumpWidget(_split());
        await _tab(tester);
        await _press(tester, LogicalKeyboardKey.end);
        tester.semantics.performAction(
          find.semantics.byLabel('Resize panes'),
          SemanticsAction.increase,
        );
        await tester.pump();
        expect(_listWidth(tester), closeTo(500, 1));
        expect(tester.getSemantics(_divider).value, '50%');
      },
    );

    testWidgets('fo06/us21/fr04/e03: an app label replaces the built-in one', (
      tester,
    ) async {
      _view(tester);
      await tester.pumpWidget(_split(label: 'List width'));
      expect(find.bySemanticsLabel('List width'), findsOneWidget);
      expect(_divider, findsNothing);
    });

    testWidgets('fo06/us21/fr04/e02: in Thai the node reads the Thai built-in '
        'label', (tester) async {
      _view(tester);
      await tester.pumpWidget(
        Localizations(
          locale: const Locale('th'),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: _split(),
        ),
      );
      expect(
        find.bySemanticsLabel(
          builtInLabelsFor(const Locale('th')).dividerLabel,
        ),
        findsOneWidget,
      );
      expect(_divider, findsNothing);
    });
  });

  group('SplitLayout divider look', () {
    test(
      'fo06/us21/fr05: SplitDividerState has value equality and copyWith',
      () {
        // Built at run time from a parameter, so no const canonicalization
        // makes them one instance and the check reads `==`, not identity.
        SplitDividerState make(bool hovered) =>
            SplitDividerState(hovered: hovered, focused: true);
        final a = make(true);
        final b = make(true);
        expect(identical(a, b), isFalse);
        expect(a, b);
        expect(a.hashCode, b.hashCode);
        final c = a.copyWith(focused: false);
        expect(c.focused, isFalse);
        expect(c.hovered, isTrue);
      },
    );

    testWidgets(
      'fo06/us21/fr05/e02: with no dividerBuilder nothing paints, yet '
      'the hit area and focus ring work',
      (tester) async {
        _view(tester);
        await tester.pumpWidget(_split());
        expect(_paintsNothingVisible(tester, _hitArea), isTrue);
        expect(tester.getSize(_divider).width, greaterThanOrEqualTo(48));
        await _tab(tester);
        await tester.pumpAndSettle();
        expect(_ring(tester).a, greaterThan(0));
      },
    );

    testWidgets(
      'fo06/us21/fr05: a painted divider overlays the seam and takes no '
      'layout space',
      (tester) async {
        _view(tester);
        await tester.pumpWidget(_split(dividerBuilder: _line([])));
        expect(_listWidth(tester), 300);
        expect(tester.getTopLeft(find.text('Detail')).dx, 300);
        expect(tester.getCenter(find.byKey(_lineKey)).dx, 300);
        expect(tester.getSize(find.byKey(_lineKey)).height, 400);
      },
    );

    testWidgets('R17: the builder receives hovered, dragging, and focused', (
      tester,
    ) async {
      _view(tester);
      final states = <SplitDividerState>[];
      await tester.pumpWidget(_split(dividerBuilder: _line(states)));
      expect(states.last, const SplitDividerState());

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(100, 100));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(_divider));
      await tester.pump();
      expect(states.last, const SplitDividerState(hovered: true));
      await mouse.moveTo(const Offset(100, 100));
      await tester.pump();
      expect(states.last, const SplitDividerState());

      final touch = await tester.startGesture(tester.getCenter(_divider));
      await touch.moveBy(const Offset(30, 0));
      await tester.pump();
      expect(states.last.dragging, isTrue);
      await touch.up();
      await tester.pumpAndSettle();
      expect(states.last.dragging, isFalse);

      await _tab(tester);
      expect(states.last, const SplitDividerState(focused: true));
    });

    testWidgets('fo06/us21/fr05: a resize cursor shows on hover', (
      tester,
    ) async {
      _view(tester);
      await tester.pumpWidget(_split());
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(_divider));
      addTearDown(mouse.removePointer);
      await tester.pump();
      expect(
        tester.binding.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.resizeColumn,
      );
    });

    testWidgets(
      'fo06/us21/fr05/e03: with resizing off the painted divider stays, '
      'with no focus ring or slider node',
      (tester) async {
        _view(tester);
        final states = <SplitDividerState>[];
        await tester.pumpWidget(
          _split(resizable: false, dividerBuilder: _line(states)),
        );
        expect(find.byKey(_lineKey), findsOneWidget);
        expect(states.last, const SplitDividerState());
        expect(
          find.descendant(
            of: find.byType(SplitLayout),
            matching: find.byType(StratumFocusBorder),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('fo06/us21/fr05/e04: a painted divider restyles with the theme '
        'token its builder reads', (tester) async {
      _view(tester);
      Color line() => tester
          .widget<ColoredBox>(
            find.descendant(
              of: find.byKey(_lineKey),
              matching: find.byType(ColoredBox),
            ),
          )
          .color;
      await tester.pumpWidget(
        _split(dividerBuilder: _line([]), theme: defaultThemeSet.light),
      );
      final light = line();
      await tester.pumpWidget(
        _split(dividerBuilder: _line([]), theme: defaultThemeSet.dark),
      );
      expect(line(), isNot(light));
    });
  });

  group('SplitLayoutController', () {
    testWidgets('fo06/us21/fr02/e03: a kept fraction opens the pane at it', (
      tester,
    ) async {
      _view(tester);
      final notifies = [0];
      final controller = _counted(notifies, fractions: [0.4, 0.6]);
      await tester.pumpWidget(_split(controller: controller));
      expect(_listWidth(tester), closeTo(400, 1));
      expect(notifies.single, 0);
    });

    test(
      'fo06/us21/fr02/e06: a kept fraction that is NaN, infinite, or negative '
      'reads as none, from the constructor and from a set',
      () {
        for (final bad in _unusable) {
          final controller = SplitLayoutController(fractions: [bad, 0.6]);
          addTearDown(controller.dispose);
          expect(controller.fractions, [null, 0.6], reason: '$bad');
          controller.fractions = [0.4, bad];
          expect(controller.fractions, [0.4, null], reason: '$bad');
        }
      },
    );

    testWidgets('fo06/us21/fr02/e06: a pane whose kept fraction is not finite '
        'opens as if none were chosen', (tester) async {
      _view(tester);
      for (final bad in _unusable) {
        final controller = SplitLayoutController(fractions: [bad, 0.6]);
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          KeyedSubtree(
            key: ValueKey(controller),
            child: _split(controller: controller),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$bad');
        expect(_listWidth(tester), closeTo(300, 1), reason: '$bad');
      }
    });

    testWidgets('fo06/us21/fr02/e06: the split reads an unusable fraction a '
        'controller hands it as none, and a key step stays finite', (
      tester,
    ) async {
      _view(tester);
      final controller = _Unchecked([double.infinity, double.nan]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_split(controller: controller));
      expect(tester.takeException(), isNull);
      expect(_listWidth(tester), closeTo(300, 1));
      await _tab(tester);
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(tester.takeException(), isNull);
      expect(_listWidth(tester), closeTo(316, 1));
    });

    testWidgets('R22: a drag notifies once at its end and never during its '
        'frames', (tester) async {
      _view(tester);
      final notifies = [0];
      final controller = _counted(notifies);
      // The app rebuilds on each notification, as the SKILL text shows:
      // a notification during a build would assert here.
      var appBuilds = 0;
      late StateSetter rebuildApp;
      controller.addListener(() => rebuildApp(() {}));
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            appBuilds++;
            rebuildApp = setState;
            return _split(controller: controller);
          },
        ),
      );
      final gesture = await tester.startGesture(tester.getCenter(_divider));
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      expect(notifies.single, 0);
      expect(_listWidth(tester), closeTo(350, 1));
      await gesture.up();
      await tester.pump();
      expect(notifies.single, 1);
      expect(tester.takeException(), isNull);
      expect(appBuilds, 2);
      expect(controller.fractions![0], closeTo(0.35, 1e-3));
      expect(controller.fractions![1], closeTo(0.65, 1e-3));
    });

    testWidgets('R22: each arrow-key step and slider action notifies once', (
      tester,
    ) async {
      _view(tester);
      final notifies = [0];
      final controller = _counted(notifies);
      await tester.pumpWidget(_split(controller: controller));
      await _tab(tester);
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(notifies.single, 1);
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(notifies.single, 2);
      expect(controller.fractions![0], closeTo(0.332, 1e-3));
      tester.semantics.performAction(
        find.semantics.byLabel('Resize panes'),
        SemanticsAction.decrease,
      );
      await tester.pump();
      expect(notifies.single, 3);
      expect(controller.fractions![0], closeTo(0.316, 1e-3));
    });

    testWidgets('R22: a key at a limit moves nothing and notifies nothing', (
      tester,
    ) async {
      _view(tester);
      final notifies = [0];
      final controller = _counted(notifies);
      await tester.pumpWidget(_split(controller: controller));
      await _tab(tester);
      await _press(tester, LogicalKeyboardKey.end);
      expect(notifies.single, 1);
      await _press(tester, LogicalKeyboardKey.end);
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(notifies.single, 1);
    });

    testWidgets(
      'fo06/us21/fr02/e05: a window clamp changes only the drawn size '
      'and notifies nothing',
      (tester) async {
        _view(tester);
        final notifies = [0];
        final controller = _counted(notifies);
        await tester.pumpWidget(_split(controller: controller));
        await tester.dragFrom(tester.getCenter(_divider), const Offset(50, 0));
        await tester.pumpAndSettle();
        expect(notifies.single, 1);
        final chosen = controller.fractions;

        tester.view.physicalSize = const Size(560, 400);
        await tester.pumpAndSettle();
        expect(_listWidth(tester), closeTo(200, 1));
        expect(tester.getSize(find.text('Detail')).width, closeTo(360, 1));
        expect(notifies.single, 1);
        expect(controller.fractions, chosen);

        tester.view.physicalSize = const Size(1000, 400);
        await tester.pumpAndSettle();
        expect(_listWidth(tester), closeTo(350, 1));
        expect(notifies.single, 1);
      },
    );

    testWidgets('R22: fractions the app sets in code move the panes', (
      tester,
    ) async {
      _view(tester);
      final notifies = [0];
      final controller = _counted(notifies);
      await tester.pumpWidget(_split(controller: controller));
      controller.fractions = [0.25, 0.75];
      await tester.pump();
      expect(_listWidth(tester), closeTo(250, 1));
      expect(notifies.single, 1);
    });

    testWidgets('fo06/us21/fr02: fractions keep each pane inside its limits', (
      tester,
    ) async {
      _view(tester);
      final notifies = [0];
      final controller = _counted(notifies, fractions: [0.9, 0.1]);
      await tester.pumpWidget(_split(controller: controller));
      expect(_listWidth(tester), closeTo(500, 1));
      expect(controller.fractions, [0.9, 0.1]);
    });

    testWidgets(
      'fo06/us21/fr02/e04: with resizing off a drag notifies nothing',
      (tester) async {
        _view(tester);
        final notifies = [0];
        final controller = _counted(notifies);
        await tester.pumpWidget(
          _split(resizable: false, controller: controller),
        );
        await tester.dragFrom(const Offset(300, 200), const Offset(50, 0));
        await tester.pumpAndSettle();
        expect(notifies.single, 0);
        expect(controller.fractions, isNull);
      },
    );

    testWidgets(
      'fo06/us21/fr02: a parent rebuild during a drag keeps the dragged size',
      (tester) async {
        _view(tester);
        await tester.pumpWidget(_split());
        final gesture = await tester.startGesture(tester.getCenter(_divider));
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();
        await gesture.moveBy(const Offset(20, 0));
        await tester.pump();
        await tester.pumpWidget(_split());
        expect(_listWidth(tester), closeTo(350, 1));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(_listWidth(tester), closeTo(350, 1));
      },
    );

    testWidgets(
      'fo06/us21/fr02: a hidden pane keeps its fraction for when it shows again',
      (tester) async {
        _view(tester);
        final notifies = [0];
        final controller = _counted(notifies, fractions: [0.2, 0.3, 0.5]);
        Widget three({required bool last}) => _split(
          controller: controller,
          panes: [
            SplitPane(child: _pane('List')),
            SplitPane(child: _pane('Detail')),
            if (last) SplitPane(child: _pane('Extra')) else null,
          ],
        );
        await tester.pumpWidget(three(last: false));
        expect(_listWidth(tester), closeTo(400, 1));
        await tester.dragFrom(tester.getCenter(_divider), const Offset(100, 0));
        await tester.pumpAndSettle();
        expect(controller.fractions![0], closeTo(0.25, 1e-3));
        expect(controller.fractions![1], closeTo(0.25, 1e-3));
        expect(controller.fractions![2], 0.5);
        await tester.pumpWidget(three(last: true));
        expect(_listWidth(tester), closeTo(250, 1));
        expect(tester.getSize(find.text('Extra')).width, closeTo(500, 1));
        expect(notifies.single, 1);
      },
    );

    testWidgets(
      'fo06/us21/fr02/e05: a drag under a window clamp stores only the '
      'two moved panes; a clamped third pane keeps its fraction',
      (tester) async {
        _view(tester, const Size(600, 400));
        final notifies = [0];
        final controller = _counted(notifies, fractions: [0.2, 0.5, 0.3]);
        await tester.pumpWidget(
          _split(
            controller: controller,
            panes: [
              SplitPane(min: 200, child: _pane('List')),
              SplitPane(min: 100, child: _pane('Detail')),
              SplitPane(size: 300, min: 250, child: _pane('Extra')),
            ],
          ),
        );
        expect(_listWidth(tester), closeTo(200, 1));
        expect(tester.getSize(find.text('Extra')).width, closeTo(250, 1));
        await tester.dragFrom(
          tester.getCenter(_divider.first),
          const Offset(10, 0),
        );
        await tester.pumpAndSettle();
        expect(notifies.single, 1);
        expect(
          controller.fractions![0]! + controller.fractions![1]!,
          closeTo(0.7, 1e-9),
        );
        expect(controller.fractions![0], closeTo(0.42, 1e-3));
        expect(controller.fractions![2], 0.3);

        tester.view.physicalSize = const Size(1000, 400);
        await tester.pumpAndSettle();
        expect(tester.getSize(find.text('Extra')).width, closeTo(300, 1));
        expect(notifies.single, 1);
      },
    );

    testWidgets('fo06/us21/fr02/e03: a pane collapsed to 0 stays collapsed on '
        'resize and on restore', (tester) async {
      _view(tester);
      final notifies = [0];
      final controller = _counted(notifies);
      final panes = [
        SplitPane(size: 300, child: _pane('List')),
        SplitPane(child: _pane('Detail')),
      ];
      await tester.pumpWidget(_split(controller: controller, panes: panes));
      await _tab(tester);
      await _press(tester, LogicalKeyboardKey.end);
      expect(_listWidth(tester), closeTo(1000, 1));
      expect(controller.fractions, [1.0, 0.0]);

      tester.view.physicalSize = const Size(900, 400);
      await tester.pumpAndSettle();
      expect(_listWidth(tester), closeTo(900, 1));

      final kept = SplitLayoutController(fractions: controller.fractions);
      addTearDown(kept.dispose);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_split(controller: kept, panes: panes));
      expect(_listWidth(tester), closeTo(900, 1));
    });

    testWidgets(
      'fo06/us21/fr02: a pane hidden at the first settle opens at its own '
      'size and leaves the chosen panes their ratio',
      (tester) async {
        _view(tester);
        final notifies = [0];
        final controller = _counted(notifies);
        Widget three({required bool extra}) => _split(
          controller: controller,
          panes: [
            _list(),
            _detail(),
            if (extra) SplitPane(size: 200, child: _pane('Extra')) else null,
          ],
        );
        await tester.pumpWidget(three(extra: false));
        await tester.dragFrom(tester.getCenter(_divider), const Offset(50, 0));
        await tester.pumpAndSettle();
        expect(controller.fractions![2], isNull);
        await tester.pumpWidget(three(extra: true));
        expect(tester.getSize(find.text('Extra')).width, closeTo(200, 1));
        expect(_listWidth(tester), closeTo(280, 1));
        expect(tester.getSize(find.text('Detail')).width, closeTo(520, 1));
        expect(notifies.single, 1);
      },
    );

    testWidgets('R22: a passed controller outlives the layout', (tester) async {
      _view(tester);
      final controller = SplitLayoutController();
      await tester.pumpWidget(_split(controller: controller));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(() => controller.addListener(() {}), returnsNormally);
      controller.dispose();
    });

    testWidgets('fo06/us21/fr02: a controller swapped in drives the panes, and '
        'dropping it '
        'keeps its fractions', (tester) async {
      _view(tester);
      final first = SplitLayoutController(fractions: [0.4, 0.6]);
      final second = SplitLayoutController(fractions: [0.45, 0.55]);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await tester.pumpWidget(_split(controller: first));
      await tester.pumpWidget(_split(controller: second));
      expect(_listWidth(tester), closeTo(450, 1));
      first.fractions = [0.3, 0.7];
      await tester.pump();
      expect(_listWidth(tester), closeTo(450, 1));
      await tester.pumpWidget(_split());
      expect(_listWidth(tester), closeTo(450, 1));
    });
  });

  group('SplitLayout accessibility gate', () {
    testWidgets('NFR-U02: Tab reaches the divider and shows its focus ring', (
      tester,
    ) async {
      _view(tester);
      await tester.pumpWidget(_split());
      final idle = _ring(tester);
      expect(idle.a, 0);
      await _tab(tester);
      await tester.pumpAndSettle();
      expect(_dividerNode(tester).hasPrimaryFocus, isTrue);
      expect(_ring(tester), isNot(isSameColorAs(idle)));
    });

    testWidgets('NFR-U05: fo06/us21/fr05/e01: the hit area spans the platform '
        'minimum centered on the seam, and a drag beside the seam moves it', (
      tester,
    ) async {
      _view(tester);
      await tester.pumpWidget(_split());
      final minimum = TapTargetSize.minimumFor(defaultTargetPlatform);
      expect(tester.getSize(_divider).width, minimum.width);
      expect(tester.getCenter(_divider).dx, 300);
      await tester.dragFrom(
        tester.getCenter(_divider) + const Offset(8, 0),
        const Offset(30, 0),
      );
      await tester.pumpAndSettle();
      expect(_listWidth(tester), closeTo(330, 1));
    }, variant: TargetPlatformVariant.all());

    testWidgets('NFR-U08: the focused divider shows the ring shape under '
        'high contrast', (tester) async {
      _view(tester);
      await tester.pumpWidget(_split(highContrast: true));
      await _tab(tester);
      await tester.pumpAndSettle();
      expect(_ring(tester).a, greaterThan(0));
    });

    testWidgets('NFR-U09: the drag action completes by key alone', (
      tester,
    ) async {
      _view(tester);
      final notifies = [0];
      final controller = _counted(notifies);
      await tester.pumpWidget(_split(controller: controller));
      await _tab(tester);
      await _press(tester, LogicalKeyboardKey.end);
      expect(_listWidth(tester), closeTo(500, 1));
      expect(notifies.single, 1);
    });

    testWidgets('NFR-E01: the focus ring follows the theme', (tester) async {
      _view(tester);
      Future<Color> focusedRing(StratumThemeData theme) async {
        await tester.pumpWidget(_split(theme: theme));
        await _tab(tester);
        await tester.pumpAndSettle();
        return _ring(tester);
      }

      final light = await focusedRing(defaultThemeSet.light);
      await tester.pumpWidget(const SizedBox.shrink());
      final dark = await focusedRing(defaultThemeSet.dark!);
      expect(dark, isNot(isSameColorAs(light)));
    });

    testWidgets(
      'fo06/us21/fr05: the app-wide StratumFocusBorder style restyles the ring',
      (tester) async {
        _view(tester);
        const red = Color(0xFFFF0000);
        await tester.pumpWidget(
          _split(
            componentStyles: const {
              StratumFocusBorder: WidgetStyle(
                border: Border.fromBorderSide(BorderSide(color: red, width: 3)),
              ),
            },
          ),
        );
        await _tab(tester);
        await tester.pumpAndSettle();
        expect(_ring(tester), isSameColorAs(red));
      },
    );
  });

  group('SplitLayout presses near the seam', () {
    /// A list pane with a 20 px button at its end edge, inside the
    /// divider's hit band, over a vertical list that scrolls.
    Widget band({
      required VoidCallback onTap,
      required ScrollController scroll,
      bool resizable = true,
      SplitDividerBuilder? dividerBuilder,
    }) => _split(
      resizable: resizable,
      dividerBuilder: dividerBuilder,
      panes: [
        SplitPane(
          size: 300,
          min: 200,
          max: 500,
          child: Stack(
            children: [
              ListView(
                controller: scroll,
                children: [
                  for (var i = 0; i < 40; i++)
                    SizedBox(height: 50, child: Text('Row $i')),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: GestureDetector(
                  onTap: onTap,
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: Text('List'),
                  ),
                ),
              ),
            ],
          ),
        ),
        _detail(),
      ],
    );

    double paneWidth(WidgetTester tester) =>
        tester.getSize(find.byType(ListView)).width;

    testWidgets(
      'fo06/us21/fr05/e01: a tap on a pane button inside the hit band '
      'reaches the button',
      (tester) async {
        _view(tester);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        var taps = 0;
        await tester.pumpWidget(band(onTap: () => taps++, scroll: scroll));
        await tester.tapAt(const Offset(290, 200));
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(paneWidth(tester), 300);
      },
    );

    testWidgets(
      'fo06/us21/fr05/e01: a vertical drag inside the hit band scrolls '
      'the pane',
      (tester) async {
        _view(tester);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        await tester.pumpWidget(band(onTap: () {}, scroll: scroll));
        await tester.dragFrom(const Offset(285, 300), const Offset(0, -150));
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThan(0));
        expect(paneWidth(tester), 300);
      },
    );

    testWidgets('fo06/us21/fr05/e01: a horizontal drag inside the hit band '
        'resizes the panes', (tester) async {
      _view(tester);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(band(onTap: () {}, scroll: scroll));
      await tester.dragFrom(const Offset(290, 300), const Offset(40, 0));
      await tester.pumpAndSettle();
      expect(paneWidth(tester), closeTo(340, 1));
      expect(scroll.offset, 0);
    });

    testWidgets(
      'fo06/us21/fr05/e03: with resizing off a painted divider takes no '
      'press',
      (tester) async {
        _view(tester);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        var taps = 0;
        await tester.pumpWidget(
          band(
            onTap: () => taps++,
            scroll: scroll,
            resizable: false,
            dividerBuilder: (context, state) =>
                const ColoredBox(color: Color(0xFF000000)),
          ),
        );
        await tester.tapAt(const Offset(290, 200));
        await tester.pumpAndSettle();
        expect(taps, 1);
      },
    );
  });

  group('SplitLayout drag interrupted', () {
    /// A list pane with a tap target in its middle beside the detail pane.
    Widget host({
      required SplitLayoutController controller,
      required VoidCallback onTap,
      bool resizable = true,
      bool detail = true,
    }) => _split(
      controller: controller,
      resizable: resizable,
      panes: [
        SplitPane(
          size: 300,
          min: 200,
          max: 500,
          child: Center(
            child: GestureDetector(
              onTap: onTap,
              child: const SizedBox(width: 40, height: 40, child: Text('Tap')),
            ),
          ),
        ),
        if (detail) _detail() else null,
      ],
    );

    double detailWidth(WidgetTester tester) =>
        tester.getSize(find.text('Detail')).width;

    /// Starts a drag on the divider and moves it 40 px toward the end.
    Future<TestGesture> dragHalfway(WidgetTester tester) async {
      final gesture = await tester.startGesture(tester.getCenter(_divider));
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      expect(detailWidth(tester), closeTo(660, 1));
      return gesture;
    }

    /// Expects the split to take a tap and a divider drag again, the drag
    /// notifying once more than [before].
    Future<void> expectAlive(
      WidgetTester tester,
      List<int> notifies,
      int before,
    ) async {
      await tester.dragFrom(tester.getCenter(_divider), const Offset(50, 0));
      await tester.pumpAndSettle();
      expect(detailWidth(tester), closeTo(650, 1));
      expect(notifies.single, before + 1);
    }

    testWidgets(
      'fo06/us21/fr02/e04: resizing turned off mid-drag ends the drag '
      'with no notify, and the split takes taps and drags again',
      (tester) async {
        _view(tester);
        final notifies = [0];
        final controller = _counted(notifies);
        var taps = 0;
        await tester.pumpWidget(
          host(controller: controller, onTap: () => taps++),
        );
        final gesture = await dragHalfway(tester);
        await tester.pumpWidget(
          host(controller: controller, onTap: () => taps++, resizable: false),
        );
        await tester.pump();
        expect(detailWidth(tester), closeTo(700, 1));
        await tester.tap(find.text('Tap'));
        expect(taps, 1);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(notifies.single, 0);
        await tester.pumpWidget(
          host(controller: controller, onTap: () => taps++),
        );
        await tester.tap(find.text('Tap'));
        expect(taps, 2);
        await expectAlive(tester, notifies, 0);
      },
    );

    testWidgets(
      'fo06/us21/fr01/e02: the end pane hiding mid-drag ends the drag '
      'with no notify, and the split takes taps and drags again',
      (tester) async {
        _view(tester);
        final notifies = [0];
        final controller = _counted(notifies);
        var taps = 0;
        await tester.pumpWidget(
          host(controller: controller, onTap: () => taps++),
        );
        final gesture = await dragHalfway(tester);
        await tester.pumpWidget(
          host(controller: controller, onTap: () => taps++, detail: false),
        );
        await tester.pump();
        await tester.tap(find.text('Tap'));
        expect(taps, 1);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(notifies.single, 0);
        await tester.pumpWidget(
          host(controller: controller, onTap: () => taps++),
        );
        await tester.tap(find.text('Tap'));
        expect(taps, 2);
        await expectAlive(tester, notifies, 0);
      },
    );

    testWidgets(
      'fo06/us21/fr02: a split unmounted mid-drag notifies nothing, and '
      'a new one takes taps and drags',
      (tester) async {
        _view(tester);
        final notifies = [0];
        final controller = _counted(notifies);
        var taps = 0;
        await tester.pumpWidget(
          host(controller: controller, onTap: () => taps++),
        );
        final gesture = await dragHalfway(tester);
        await tester.pumpWidget(const SizedBox.shrink());
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(notifies.single, 0);
        await tester.pumpWidget(
          host(controller: controller, onTap: () => taps++),
        );
        await tester.tap(find.text('Tap'));
        expect(taps, 1);
        await expectAlive(tester, notifies, 0);
      },
    );

    testWidgets(
      'fo06/us21/fr02: a pane before the dragged divider hiding keeps '
      'the drag on its pair, from the new layout',
      (tester) async {
        _view(tester);
        final notifies = [0];
        final controller = _counted(notifies);
        Widget three({required bool first}) => _split(
          controller: controller,
          panes: [
            if (first) SplitPane(size: 200, child: _pane('A')) else null,
            SplitPane(child: _pane('B')),
            SplitPane(child: _pane('C')),
          ],
        );
        await tester.pumpWidget(three(first: true));
        final gesture = await tester.startGesture(
          tester.getCenter(_divider.last),
        );
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();
        expect(tester.getSize(find.text('B')).width, closeTo(430, 1));
        await tester.pumpWidget(three(first: false));
        expect(tester.getSize(find.text('B')).width, closeTo(500, 1));
        await gesture.moveBy(const Offset(20, 0));
        await tester.pump();
        final b = tester.getSize(find.text('B')).width;
        final c = tester.getSize(find.text('C')).width;
        expect(b + c, closeTo(1000, 1));
        expect(b, closeTo(520, 1));
        await gesture.up();
        await tester.pump();
        expect(notifies.single, 1);
        expect(controller.fractions![1], closeTo(0.52, 1e-3));
      },
    );
  });

  group('SplitLayout drag', () {
    testWidgets('fo06/us21/s1: fo06/us21/fr02: a drag resizes both panes', (
      tester,
    ) async {
      _view(tester);
      await tester.pumpWidget(_split());
      await tester.dragFrom(tester.getCenter(_divider), const Offset(50, 0));
      await tester.pumpAndSettle();
      expect(_listWidth(tester), closeTo(350, 1));
      expect(tester.getSize(find.text('Detail')).width, closeTo(650, 1));
    });

    testWidgets(
      'fo06/us21/s8: fo06/us21/fr02/e01: a drag past the maximum stops there',
      (tester) async {
        _view(tester);
        await tester.pumpWidget(_split());
        await tester.dragFrom(tester.getCenter(_divider), const Offset(400, 0));
        await tester.pumpAndSettle();
        expect(_listWidth(tester), closeTo(500, 1));
      },
    );

    testWidgets(
      'fo06/us21/fr02/e02: a drag past the neighbor minimum stops there',
      (tester) async {
        _view(tester);
        await tester.pumpWidget(_split(panes: [_list(max: null), _detail()]));
        await tester.dragFrom(tester.getCenter(_divider), const Offset(600, 0));
        await tester.pumpAndSettle();
        expect(_listWidth(tester), closeTo(700, 1));
        expect(tester.getSize(find.text('Detail')).width, closeTo(300, 1));
      },
    );

    testWidgets(
      'fo06/us21/fr02: a drag under RTL moves the divider with the pointer',
      (tester) async {
        _view(tester);
        await tester.pumpWidget(_split(direction: TextDirection.rtl));
        await tester.dragFrom(tester.getCenter(_divider), const Offset(-50, 0));
        await tester.pumpAndSettle();
        expect(_listWidth(tester), closeTo(350, 1));
      },
    );

    testWidgets(
      'fo06/us21/s7: fo06/us21/fr01/e04: resizing off takes no drag, focus, '
      'or slider node',
      (tester) async {
        _view(tester);
        await tester.pumpWidget(_split(resizable: false));
        expect(_divider, findsNothing);
        await tester.dragFrom(const Offset(300, 200), const Offset(50, 0));
        await tester.pumpAndSettle();
        expect(_listWidth(tester), 300);
      },
    );
  });
}
