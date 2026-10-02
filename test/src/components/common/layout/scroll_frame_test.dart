import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/layout/scroll_frame.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

class _BouncingBehavior extends ScrollBehavior {
  const new();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics();
}

List<Type> _physicsChain(WidgetTester tester) {
  final state = tester.state<ScrollableState>(find.byType(Scrollable).first);
  final chain = <Type>[];
  for (
    ScrollPhysics? physics = state.position.physics;
    physics != null;
    physics = physics.parent
  ) {
    chain.add(physics.runtimeType);
  }
  return chain;
}

Widget _framed({bool? showScrollbar}) {
  return SizedBox(
    width: 200,
    height: 300,
    child: ScrollFrame(
      showScrollbar: showScrollbar,
      child: ListView(children: const [SizedBox(height: 2000)]),
    ),
  );
}

/// [MaterialScrollBehavior] reads the platform from [Theme], and the
/// fallback theme keeps the platform of the first test, so desktop cases
/// set it here.
Widget _macOSTheme(Widget child) {
  return Theme(
    data: ThemeData(platform: TargetPlatform.macOS),
    child: child,
  );
}

Widget _bouncingOutside(Widget child) {
  return ScrollConfiguration(behavior: const _BouncingBehavior(), child: child);
}

FocusNode _node() {
  final node = FocusNode();
  addTearDown(node.dispose);
  return node;
}

ScrollController _controller() {
  final controller = ScrollController();
  addTearDown(controller.dispose);
  return controller;
}

void _useTraditionalHighlight() {
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );
}

/// [child], 200 by 300, after a focusable box, under the app's default
/// Tab, arrow, and activation keys.
Widget _keyboardHost(Widget child, {required FocusNode before}) {
  return Shortcuts(
    shortcuts: WidgetsApp.defaultShortcuts,
    child: Actions(
      actions: WidgetsApp.defaultActions,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Focus(
            focusNode: before,
            child: const SizedBox(width: 10, height: 10),
          ),
          SizedBox(width: 200, height: 300, child: child),
        ],
      ),
    ),
  );
}

Widget _item(BuildContext context, int index) {
  return SizedBox(key: ValueKey(index), height: 40);
}

/// Tabs from [before] to the next stop: the viewport of the scroll view.
Future<void> _tabIn(WidgetTester tester, FocusNode before) async {
  before.requestFocus();
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
}

bool _viewportFocused() =>
    FocusManager.instance.primaryFocus?.debugLabel == 'ScrollFocus';

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

double _pixels(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable).first)
    .position
    .pixels;

/// Whether the ring of the box around a tap surface shows.
bool _boxRing(WidgetTester tester) => tester
    .widget<FocusSpread>(
      find.ancestor(
        of: find.byType(StratumInkWell).first,
        matching: find.byType(FocusSpread),
      ),
    )
    .focus;

/// The own node of the only [ScrollFocus] on screen.
FocusNode _scrollFocusNode(WidgetTester tester) => tester
    .widget<Focus>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Focus && widget.focusNode?.debugLabel == 'ScrollFocus',
      ),
    )
    .focusNode!;

/// The keys of `WidgetsApp.defaultShortcuts` on web that the Tab order
/// cases press: Tab and Shift+Tab move focus, and the arrows scroll
/// ([ScrollIntent]) instead of moving it.
const _webShortcuts = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.tab): NextFocusIntent(),
  SingleActivator(LogicalKeyboardKey.tab, shift: true): PreviousFocusIntent(),
  SingleActivator(LogicalKeyboardKey.arrowUp): ScrollIntent(
    direction: AxisDirection.up,
  ),
  SingleActivator(LogicalKeyboardKey.arrowDown): ScrollIntent(
    direction: AxisDirection.down,
  ),
};

/// [page], filling the 800 by 600 window, under [_webShortcuts].
Widget _webHost(Widget page) {
  return themedHost(
    Shortcuts(
      shortcuts: _webShortcuts,
      child: Actions(
        actions: WidgetsApp.defaultActions,
        child: SizedBox.expand(child: page),
      ),
    ),
  );
}

List<FocusNode> _nodes(int count) => [for (var i = 0; i < count; i++) _node()];

/// A row of tappable items, 48 px high, that is one focus group (K3).
Widget _groupRow(List<FocusNode> items) {
  return RowLayout(
    mainAxisSize: MainAxisSize.min,
    gap: 8,
    focusGroup: const StratumFocusGroup(),
    children: [
      for (final item in items)
        ContainerLayout(
          style: const WidgetStyle(width: 64, height: 48),
          interaction: StratumInteraction(onTap: () {}, focusNode: item),
        ),
    ],
  );
}

/// Presses the arrows, under [_webShortcuts], until [item] lies wholly
/// above [viewport]'s top edge.
Future<void> _scrollAbove(
  WidgetTester tester,
  FocusNode item,
  FocusNode viewport,
) async {
  for (var i = 0; i < 10 && item.rect.bottom >= viewport.rect.top; i++) {
    await _key(tester, LogicalKeyboardKey.arrowDown);
  }
  expect(item.rect.bottom, lessThan(viewport.rect.top));
  expect(item.hasPrimaryFocus, isTrue);
}

Future<void> _shiftTab(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pumpAndSettle();
}

/// Whether [node] lies wholly inside [viewport] along the vertical axis.
bool _revealed(FocusNode node, FocusNode viewport) =>
    node.rect.top >= viewport.rect.top &&
    node.rect.bottom <= viewport.rect.bottom;

/// Focus nodes on both sides of a 200 by 200 desktop scroller and inside
/// it: [above], the scroller's items [first] and [second], and [below],
/// each 200 by 40, under `WidgetsApp.defaultShortcuts`.
class _Edge {
  final FocusNode above = _node();
  final FocusNode first = _node();
  final FocusNode second = _node();
  final FocusNode below = _node();
  final _names = <FocusNode, String>{};

  /// The name of the node that holds primary focus; the scroller's own
  /// stop is `box`.
  String get focused => _names[FocusManager.instance.primaryFocus] ?? '-';

  /// Pumps the nodes around the scroller that [scroller] builds from the
  /// items, and focuses [above].
  Future<void> pump(
    WidgetTester tester,
    Widget Function(List<Widget> items) scroller,
  ) async {
    Widget item(FocusNode node) => Focus(
      focusNode: node,
      child: const SizedBox(width: 200, height: 40),
    );
    await tester.pumpWidget(
      themedHost(
        Shortcuts(
          shortcuts: WidgetsApp.defaultShortcuts,
          child: Actions(
            actions: WidgetsApp.defaultActions,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                item(above),
                SizedBox(
                  width: 200,
                  height: 200,
                  child: scroller([item(first), item(second)]),
                ),
                item(below),
              ],
            ),
          ),
        ),
      ),
    );
    _names.addAll({
      above: 'above',
      first: 'first',
      second: 'second',
      below: 'below',
      _scrollFocusNode(tester): 'box',
    });
    above.requestFocus();
    await tester.pumpAndSettle();
  }

  /// Presses [keys] in turn and returns the focused node after each.
  Future<List<String>> press(
    WidgetTester tester,
    List<LogicalKeyboardKey> keys,
  ) async {
    final path = <String>[];
    for (final key in keys) {
      await _key(tester, key);
      path.add(focused);
    }
    return path;
  }
}

/// A lazy cell, 300 px high, with [row] at its top.
Widget _cell(Widget row) {
  return SizedBox(
    height: 300,
    child: Align(alignment: Alignment.topLeft, child: row),
  );
}

/// Where the ring of the only [ScrollFocus] shows, and its side: the
/// non-transparent border of the [FocusSpread]'s container; null when no
/// ring shows.
(DecorationPosition, BorderSide)? _visibleRing(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(
    find
        .descendant(
          of: find.byType(FocusSpread),
          matching: find.byType(AnimatedContainer),
        )
        .first,
  );
  final layers = {
    DecorationPosition.foreground: container.foregroundDecoration,
    DecorationPosition.background: container.decoration,
  };
  for (final MapEntry(key: position, value: decoration) in layers.entries) {
    if (decoration is! BoxDecoration) continue;
    final border = decoration.border;
    if (border is Border && border.top.color.a > 0) {
      return (position, border.top);
    }
  }
  return null;
}

void main() {
  group('ScrollFrame', () {
    testWidgets('lets theme physics win over an outer ScrollConfiguration', (
      tester,
    ) async {
      await tester.pumpWidget(themedHost(_bouncingOutside(_framed())));

      final chain = _physicsChain(tester);
      expect(chain, contains(ClampingScrollPhysics));
      expect(chain, isNot(contains(BouncingScrollPhysics)));
    });

    testWidgets('uses the outer ScrollConfiguration without a theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: _bouncingOutside(_framed())),
        ),
      );

      expect(_physicsChain(tester), contains(BouncingScrollPhysics));
    });

    testWidgets('removes the scrollbar when showScrollbar is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        themedHost(_macOSTheme(_framed(showScrollbar: false))),
      );

      expect(find.byType(Scrollbar), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('keeps the desktop scrollbar when showScrollbar is null', (
      tester,
    ) async {
      await tester.pumpWidget(themedHost(_macOSTheme(_framed())));

      expect(find.byType(Scrollbar), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  group('ScrollFrame.boxStyle', () {
    test('moves the padding out of the box', () {
      final box = ScrollFrame.boxStyle(
        const WidgetStyle(
          padding: EdgeInsets.all(8),
          backgroundColor: Color(0xFF000000),
        ),
      );

      expect(box.padding, isNull);
      expect(box.backgroundColor, const Color(0xFF000000));
      expect(box.clipBehavior, isNull);
    });

    test('clips a rounded box with antiAlias', () {
      final box = ScrollFrame.boxStyle(
        const WidgetStyle(borderRadius: BorderRadius.all(Radius.circular(8))),
      );

      expect(box.clipBehavior, Clip.antiAlias);
    });

    test('keeps an explicit clipBehavior on a rounded box', () {
      final box = ScrollFrame.boxStyle(
        const WidgetStyle(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          clipBehavior: Clip.none,
        ),
      );

      expect(box.clipBehavior, Clip.none);
    });
  });

  group('defaultScrollFocusable', () {
    test('is true on web and desktop and false on mobile', () {
      expect(
        defaultScrollFocusable(isWeb: true, platform: TargetPlatform.android),
        isTrue,
      );
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        expect(
          defaultScrollFocusable(isWeb: false, platform: platform),
          isTrue,
        );
      }
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.fuchsia,
      ]) {
        expect(
          defaultScrollFocusable(isWeb: false, platform: platform),
          isFalse,
        );
      }
    });
  });

  group('ScrollFocus', () {
    testWidgets(
      'the viewport takes focus, carries its label, and shows an unclipped '
      'ring',
      (tester) async {
        _useTraditionalHighlight();
        final handle = tester.ensureSemantics();
        final before = _node();
        await tester.pumpWidget(
          themedHost(
            _keyboardHost(
              const ListViewLayout.builder(
                style: WidgetStyle(
                  backgroundColor: Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                semanticsLabel: 'Results',
                itemCount: 50,
                itemBuilder: _item,
              ),
              before: before,
            ),
          ),
        );

        await _tabIn(tester, before);

        expect(_viewportFocused(), isTrue);
        expect(
          tester.widget<FocusSpread>(find.byType(FocusSpread)).focus,
          isTrue,
        );
        expect(
          find.ancestor(
            of: find.byType(FocusSpread),
            matching: find.byType(ClipRRect),
          ),
          findsNothing,
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel('Results')),
          isSemantics(label: 'Results', isFocusable: true, isFocused: true),
        );
        handle.dispose();
      },
      variant: TargetPlatformVariant.desktop(),
    );

    testWidgets(
      'arrows, Page Down, Home, and End scroll the focused viewport',
      (tester) async {
        final before = _node();
        await tester.pumpWidget(
          themedHost(
            _keyboardHost(
              const ListViewLayout.builder(itemCount: 50, itemBuilder: _item),
              before: before,
            ),
          ),
        );
        await _tabIn(tester, before);

        await _key(tester, LogicalKeyboardKey.arrowDown);
        expect(_pixels(tester), 50);
        await _key(tester, LogicalKeyboardKey.pageDown);
        expect(_pixels(tester), 50 + 0.8 * 300);
        await _key(tester, LogicalKeyboardKey.arrowUp);
        expect(_pixels(tester), 0.8 * 300);
        await _key(tester, LogicalKeyboardKey.end);
        expect(_pixels(tester), 50 * 40 - 300);
        await _key(tester, LogicalKeyboardKey.home);
        expect(_pixels(tester), 0);
      },
      variant: TargetPlatformVariant.desktop(),
    );

    testWidgets('Home goes to the first item of a reversed list', (
      tester,
    ) async {
      final before = _node();
      await tester.pumpWidget(
        themedHost(
          _keyboardHost(
            const ListViewLayout.builder(
              reverse: true,
              itemCount: 50,
              itemBuilder: _item,
            ),
            before: before,
          ),
        ),
      );
      await _tabIn(tester, before);

      await _key(tester, LogicalKeyboardKey.end);
      expect(_pixels(tester), 50 * 40 - 300);
      await _key(tester, LogicalKeyboardKey.home);
      expect(_pixels(tester), 0);
      expect(find.byKey(const ValueKey(0)), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('End reaches the true end of a lazy list', (tester) async {
      final before = _node();
      await tester.pumpWidget(
        themedHost(
          _keyboardHost(
            ListViewLayout.builder(
              itemCount: 200,
              itemBuilder: (context, index) =>
                  SizedBox(key: ValueKey(index), height: index < 20 ? 20 : 200),
            ),
            before: before,
          ),
        ),
      );
      await _tabIn(tester, before);

      await _key(tester, LogicalKeyboardKey.end);

      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      expect(position.pixels, position.maxScrollExtent);
      expect(find.byKey(const ValueKey(199)), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('Page Down scrolls while a button item holds focus', (
      tester,
    ) async {
      final before = _node();
      final button = _node();
      await tester.pumpWidget(
        themedHost(
          _keyboardHost(
            ListViewLayout.builder(
              itemCount: 50,
              itemBuilder: (context, index) => index == 0
                  ? StratumInkWell(
                      onTap: () {},
                      focusNode: button,
                      child: const SizedBox(height: 40),
                    )
                  : _item(context, index),
            ),
            before: before,
          ),
        ),
      );
      button.requestFocus();
      await tester.pump();

      await _key(tester, LogicalKeyboardKey.pageDown);

      expect(_pixels(tester), 0.8 * 300);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets(
      'Home and End inside a TextField item leave the list where it is',
      (tester) async {
        final field = _node();
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: themedHost(
                SizedBox(
                  width: 200,
                  height: 300,
                  child: ListViewLayout.builder(
                    itemCount: 50,
                    itemBuilder: (context, index) => index == 0
                        ? TextField(focusNode: field)
                        : _item(context, index),
                  ),
                ),
              ),
            ),
          ),
        );
        field.requestFocus();
        await tester.pump();

        await _key(tester, LogicalKeyboardKey.end);
        await _key(tester, LogicalKeyboardKey.pageDown);

        expect(_pixels(tester), 0);
        expect(field.hasPrimaryFocus, isTrue);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'a list with primary: null on iOS scrolls the PrimaryScrollController',
      (tester) async {
        final before = _node();
        final primary = _controller();
        await tester.pumpWidget(
          themedHost(
            PrimaryScrollController(
              controller: primary,
              child: _keyboardHost(
                const ListViewLayout.builder(
                  focusable: true,
                  itemCount: 50,
                  itemBuilder: _item,
                ),
                before: before,
              ),
            ),
          ),
        );
        await _tabIn(tester, before);

        await _key(tester, LogicalKeyboardKey.end);

        expect(primary.hasClients, isTrue);
        expect(primary.position.pixels, 50 * 40 - 300);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets("a box layout's keys scroll through StratumScroll.controller", (
      tester,
    ) async {
      final before = _node();
      final controller = _controller();
      await tester.pumpWidget(
        themedHost(
          _keyboardHost(
            ColumnLayout(
              style: const WidgetStyle(backgroundColor: Color(0xFFFFFFFF)),
              scroll: StratumScroll(controller: controller),
              children: const [SizedBox(height: 2000)],
            ),
            before: before,
          ),
        ),
      );
      await _tabIn(tester, before);

      await _key(tester, LogicalKeyboardKey.arrowDown);

      expect(_viewportFocused(), isTrue);
      expect(controller.offset, 50);
    }, variant: TargetPlatformVariant.desktop());

    testWidgets(
      'Left and Right scroll a horizontal box layout; Down does not',
      (tester) async {
        final before = _node();
        await tester.pumpWidget(
          themedHost(
            _keyboardHost(
              const RowLayout(
                scroll: StratumScroll(),
                children: [SizedBox(width: 2000, height: 20)],
              ),
              before: before,
            ),
          ),
        );
        await _tabIn(tester, before);

        await _key(tester, LogicalKeyboardKey.arrowRight);
        expect(_pixels(tester), 50);
        await _key(tester, LogicalKeyboardKey.arrowDown);
        expect(_pixels(tester), 50);
        await _key(tester, LogicalKeyboardKey.arrowLeft);
        expect(_pixels(tester), 0);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets('a tappable scrolling box scrolls by keys on its tap surface', (
      tester,
    ) async {
      final before = _node();
      final surface = _node();
      await tester.pumpWidget(
        themedHost(
          _keyboardHost(
            ColumnLayout(
              style: const WidgetStyle(),
              interaction: StratumInteraction(onTap: () {}, focusNode: surface),
              scroll: const StratumScroll(),
              children: const [SizedBox(height: 2000)],
            ),
            before: before,
          ),
        ),
      );
      await _tabIn(tester, before);

      await _key(tester, LogicalKeyboardKey.arrowDown);

      expect(surface.hasPrimaryFocus, isTrue);
      expect(_pixels(tester), 50);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Focus && widget.focusNode?.debugLabel == 'ScrollFocus',
        ),
        findsNothing,
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('an onHover-only scrolling box is a Tab stop that scrolls', (
      tester,
    ) async {
      final before = _node();
      await tester.pumpWidget(
        themedHost(
          _keyboardHost(
            ColumnLayout(
              style: const WidgetStyle(),
              interaction: StratumInteraction(onHover: (_) {}),
              scroll: const StratumScroll(),
              children: const [SizedBox(height: 2000)],
            ),
            before: before,
          ),
        ),
      );
      await _tabIn(tester, before);

      expect(_viewportFocused(), isTrue);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_pixels(tester), 50);
    }, variant: TargetPlatformVariant.desktop());

    testWidgets('a disabled tappable scrolling box is a Tab stop and scrolls', (
      tester,
    ) async {
      final before = _node();
      await tester.pumpWidget(
        themedHost(
          _keyboardHost(
            ColumnLayout(
              style: const WidgetStyle(),
              interaction: StratumInteraction(onTap: () {}, disabled: true),
              scroll: const StratumScroll(),
              children: const [SizedBox(height: 2000)],
            ),
            before: before,
          ),
        ),
      );
      await _tabIn(tester, before);

      expect(_viewportFocused(), isTrue);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_pixels(tester), 50);
      await _key(tester, LogicalKeyboardKey.pageDown);
      expect(_pixels(tester), 50 + 0.8 * 300);
    }, variant: TargetPlatformVariant.desktop());

    testWidgets(
      'toggling disabled on a scrolling box keeps the surface, the content '
      'State, and the scroll offset',
      (tester) async {
        final controller = _controller();
        Widget box({required bool disabled}) {
          return themedHost(
            SizedBox(
              width: 200,
              height: 300,
              child: ColumnLayout(
                style: const WidgetStyle(),
                interaction: StratumInteraction(
                  onTap: () {},
                  disabled: disabled,
                ),
                scroll: StratumScroll(controller: controller),
                children: const [_Probe()],
              ),
            ),
          );
        }

        await tester.pumpWidget(box(disabled: false));
        controller.jumpTo(120);
        await tester.pump();
        final surface = tester.state(find.byType(StratumInkWell));
        final content = tester.state(find.byType(_Probe));

        await tester.pumpWidget(box(disabled: true));
        expect(tester.state(find.byType(StratumInkWell)), same(surface));
        expect(tester.state(find.byType(_Probe)), same(content));
        expect(controller.offset, 120);

        await tester.pumpWidget(box(disabled: false));
        expect(tester.state(find.byType(StratumInkWell)), same(surface));
        expect(tester.state(find.byType(_Probe)), same(content));
        expect(controller.offset, 120);
      },
      variant: TargetPlatformVariant.desktop(),
    );

    testWidgets(
      'disabling a focused tappable scrolling box hands focus to the box, '
      'and enabling it hands focus back to the surface',
      (tester) async {
        _useTraditionalHighlight();
        final before = _node();
        final surface = _node();
        var taps = 0;
        Widget box({required bool disabled}) {
          return themedHost(
            _keyboardHost(
              ColumnLayout(
                style: const WidgetStyle(),
                interaction: StratumInteraction(
                  onTap: () => taps++,
                  focusNode: surface,
                  disabled: disabled,
                ),
                scroll: const StratumScroll(),
                children: const [SizedBox(height: 2000)],
              ),
              before: before,
            ),
          );
        }

        await tester.pumpWidget(box(disabled: false));
        await _tabIn(tester, before);
        expect(surface.hasPrimaryFocus, isTrue);

        await tester.pumpWidget(box(disabled: true));
        await tester.pump();
        expect(_viewportFocused(), isTrue);
        expect(_boxRing(tester), isTrue);
        await _key(tester, LogicalKeyboardKey.arrowDown);
        expect(_pixels(tester), 50);

        await tester.pumpWidget(box(disabled: false));
        await tester.pump();
        expect(surface.hasPrimaryFocus, isTrue);
        expect(_boxRing(tester), isFalse);
        await _key(tester, LogicalKeyboardKey.enter);
        expect(taps, 1);
      },
      variant: TargetPlatformVariant.desktop(),
    );

    testWidgets(
      'a scrolling box that does not hold focus leaves it in place when '
      'disabled flips',
      (tester) async {
        final before = _node();
        final surface = _node();
        final item = _node();
        Widget box({required bool disabled}) {
          return themedHost(
            _keyboardHost(
              ColumnLayout(
                style: const WidgetStyle(),
                interaction: StratumInteraction(
                  onTap: () {},
                  focusNode: surface,
                  disabled: disabled,
                ),
                scroll: const StratumScroll(),
                children: [
                  StratumInkWell(
                    onTap: () {},
                    focusNode: item,
                    child: const SizedBox(height: 40),
                  ),
                  const SizedBox(height: 2000),
                ],
              ),
              before: before,
            ),
          );
        }

        await tester.pumpWidget(box(disabled: false));
        before.requestFocus();
        await tester.pump();
        await tester.pumpWidget(box(disabled: true));
        await tester.pump();
        expect(before.hasPrimaryFocus, isTrue);
        await tester.pumpWidget(box(disabled: false));
        await tester.pump();
        expect(before.hasPrimaryFocus, isTrue);

        // An item inside the box holds focus of its own.
        item.requestFocus();
        await tester.pump();
        await tester.pumpWidget(box(disabled: true));
        await tester.pump();
        expect(item.hasPrimaryFocus, isTrue);
        await tester.pumpWidget(box(disabled: false));
        await tester.pump();
        expect(item.hasPrimaryFocus, isTrue);
      },
      variant: TargetPlatformVariant.desktop(),
    );

    testWidgets('Page Down scrolls a horizontal box layout right by 0.8 of the '
        'viewport; Page Up scrolls back', (tester) async {
      final before = _node();
      await tester.pumpWidget(
        themedHost(
          _keyboardHost(
            const RowLayout(
              scroll: StratumScroll(),
              children: [SizedBox(width: 2000, height: 20)],
            ),
            before: before,
          ),
        ),
      );
      await _tabIn(tester, before);

      await _key(tester, LogicalKeyboardKey.pageDown);
      expect(_pixels(tester), 0.8 * 200);
      await _key(tester, LogicalKeyboardKey.pageUp);
      expect(_pixels(tester), 0);
    }, variant: TargetPlatformVariant.desktop());

    testWidgets(
      'a desktop list without a theme takes focus and builds no ring',
      (tester) async {
        final before = _node();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: _keyboardHost(
                const ListViewLayout.builder(itemCount: 50, itemBuilder: _item),
                before: before,
              ),
            ),
          ),
        );
        await _tabIn(tester, before);

        await _key(tester, LogicalKeyboardKey.arrowDown);

        expect(tester.takeException(), isNull);
        expect(_viewportFocused(), isTrue);
        expect(find.byType(FocusSpread), findsNothing);
        expect(_pixels(tester), 50);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets(
      '(pin) a mobile list is no Tab stop and keeps its own controller',
      (tester) async {
        await tester.pumpWidget(
          themedHost(
            const SizedBox(
              width: 200,
              height: 300,
              child: ListViewLayout.builder(itemCount: 50, itemBuilder: _item),
            ),
          ),
        );

        expect(find.byType(FocusSpread), findsNothing);
        expect(
          tester.widget<ListView>(find.byType(ListView)).controller,
          isNull,
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  });

  group('Tab order inside a focusable scroller', () {
    testWidgets(
      'Tab from a row scrolled wholly above a scrolling page reaches the '
      'next row and reveals it; Shift+Tab walks back to the page stop',
      (tester) async {
        final row1 = _nodes(3);
        final row2 = _nodes(3);
        await tester.pumpWidget(
          _webHost(
            ColumnLayout(
              style: const WidgetStyle(padding: EdgeInsets.all(24)),
              scroll: const StratumScroll(),
              crossAxisAlignment: CrossAxisAlignment.start,
              gap: 16,
              children: [
                _groupRow(row1),
                const SizedBox(height: 1600),
                _groupRow(row2),
                const SizedBox(height: 600),
              ],
            ),
          ),
        );
        final page = _scrollFocusNode(tester);
        row1.first.requestFocus();
        await tester.pump();
        await _scrollAbove(tester, row1.first, page);

        await _key(tester, LogicalKeyboardKey.tab);

        expect(row2.first.hasPrimaryFocus, isTrue);
        expect(_revealed(row2.first, page), isTrue);

        await _shiftTab(tester);
        expect(row1.first.hasPrimaryFocus, isTrue);
        expect(_revealed(row1.first, page), isTrue);
        await _shiftTab(tester);
        expect(page.hasPrimaryFocus, isTrue);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    final lazyLayouts = <String, Widget Function(List<Widget> cells)>{
      'ListViewLayout': (cells) => ListViewLayout.builder(
        itemCount: cells.length,
        itemBuilder: (context, index) => cells[index],
      ),
      'GridViewLayout': (cells) => GridViewLayout.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1,
          mainAxisExtent: 300,
        ),
        itemCount: cells.length,
        itemBuilder: (context, index) => cells[index],
      ),
      'CustomScrollViewLayout': (cells) =>
          CustomScrollViewLayout(children: cells),
    };
    for (final MapEntry(key: name, value: layout) in lazyLayouts.entries) {
      testWidgets(
        'Tab from a row scrolled wholly above a focusable $name reaches the '
        'next row; Shift+Tab walks back to the list stop',
        (tester) async {
          final row1 = _nodes(3);
          final row2 = _nodes(3);
          await tester.pumpWidget(
            _webHost(
              layout([
                _cell(_groupRow(row1)),
                _cell(_groupRow(row2)),
                _cell(const SizedBox.shrink()),
              ]),
            ),
          );
          final list = _scrollFocusNode(tester);
          row1.first.requestFocus();
          await tester.pump();
          await _scrollAbove(tester, row1.first, list);

          await _key(tester, LogicalKeyboardKey.tab);

          expect(row2.first.hasPrimaryFocus, isTrue);
          expect(_revealed(row2.first, list), isTrue);

          await _shiftTab(tester);
          expect(row1.first.hasPrimaryFocus, isTrue);
          expect(_revealed(row1.first, list), isTrue);
          await _shiftTab(tester);
          expect(list.hasPrimaryFocus, isTrue);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.macOS),
      );
    }

    final scrollers = <String, Widget Function(List<Widget> items)>{
      'ColumnLayout': (items) => ColumnLayout(
        scroll: const StratumScroll(),
        children: [...items, const SizedBox(height: 400)],
      ),
      'ListViewLayout': (items) => ListViewLayout.builder(
        itemCount: items.length + 1,
        itemBuilder: (context, index) =>
            index < items.length ? items[index] : const SizedBox(height: 400),
      ),
    };
    for (final MapEntry(key: name, value: scroller) in scrollers.entries) {
      testWidgets(
        '(pin) desktop arrows walk from above a $name through its items '
        'onto its stop',
        (tester) async {
          final edge = _Edge();
          await edge.pump(tester, scroller);

          final path = await edge.press(tester, [
            LogicalKeyboardKey.arrowDown,
            LogicalKeyboardKey.arrowDown,
            LogicalKeyboardKey.arrowDown,
          ]);

          expect(path, ['first', 'second', 'box']);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.macOS),
      );

      testWidgets(
        'desktop arrows keep their history across the content of a $name: '
        'Down, Up, Down, Down from above ends on the second item',
        (tester) async {
          final edge = _Edge();
          await edge.pump(tester, scroller);

          final path = await edge.press(tester, [
            LogicalKeyboardKey.arrowDown,
            LogicalKeyboardKey.arrowUp,
            LogicalKeyboardKey.arrowDown,
            LogicalKeyboardKey.arrowDown,
          ]);

          expect(path, ['first', 'above', 'first', 'second']);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.macOS),
      );

      testWidgets(
        'Tab inside a $name clears the arrow history around it: Down, '
        'Tab, Tab, Up from above ends on the stop',
        (tester) async {
          final edge = _Edge();
          await edge.pump(tester, scroller);

          final path = await edge.press(tester, [
            LogicalKeyboardKey.arrowDown,
            LogicalKeyboardKey.tab,
            LogicalKeyboardKey.tab,
            LogicalKeyboardKey.arrowUp,
          ]);

          expect(path, ['first', 'second', 'below', 'box']);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.macOS),
      );

      testWidgets(
        'Tab walks above, the stop of a $name, its items, and below; '
        'Shift+Tab walks back',
        (tester) async {
          final edge = _Edge();
          await edge.pump(tester, scroller);

          final forward = await edge.press(tester, [
            for (var i = 0; i < 4; i++) LogicalKeyboardKey.tab,
          ]);
          final back = <String>[];
          for (var i = 0; i < 4; i++) {
            await _shiftTab(tester);
            back.add(edge.focused);
          }

          expect(forward, ['box', 'first', 'second', 'below']);
          expect(back, ['second', 'first', 'box', 'above']);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.macOS),
      );
    }
  });

  group('ScrollFocus ring placement', () {
    const fullWindow = SizedBox.expand(
      child: ColumnLayout(
        scroll: StratumScroll(),
        children: [SizedBox(height: 2000)],
      ),
    );
    const smallBox = SizedBox(
      width: 200,
      height: 300,
      child: ColumnLayout(
        scroll: StratumScroll(),
        children: [SizedBox(height: 2000)],
      ),
    );

    testWidgets(
      'a scrolling box that fills the window draws its ring inside its '
      'edge, over the content and unclipped',
      (tester) async {
        _useTraditionalHighlight();
        await tester.pumpWidget(themedHost(fullWindow));

        _scrollFocusNode(tester).requestFocus();
        await tester.pumpAndSettle();

        final (position, side) = _visibleRing(tester)!;
        expect(position, DecorationPosition.foreground);
        expect(side.strokeAlign, BorderSide.strokeAlignInside);
        expect(side.width, 4);
        expect(
          find.ancestor(
            of: find.byType(FocusSpread),
            matching: find.byWidgetPredicate(
              (widget) => widget is ClipRect || widget is ClipRRect,
            ),
          ),
          findsNothing,
        );
      },
      variant: TargetPlatformVariant.desktop(),
    );

    testWidgets(
      'a small box in the middle of the window keeps its ring around it',
      (tester) async {
        _useTraditionalHighlight();
        await tester.pumpWidget(themedHost(smallBox));

        _scrollFocusNode(tester).requestFocus();
        await tester.pumpAndSettle();

        final (position, side) = _visibleRing(tester)!;
        expect(position, DecorationPosition.background);
        expect(side.strokeAlign, BorderSide.strokeAlignOutside);
      },
      variant: TargetPlatformVariant.desktop(),
    );

    testWidgets(
      'the ring moves inside when the window shrinks to the box and back '
      'around it when the window grows',
      (tester) async {
        _useTraditionalHighlight();
        addTearDown(tester.view.reset);
        await tester.pumpWidget(themedHost(smallBox));
        _scrollFocusNode(tester).requestFocus();
        await tester.pumpAndSettle();
        expect(
          _visibleRing(tester)!.$2.strokeAlign,
          BorderSide.strokeAlignOutside,
        );

        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(200, 300);
        await tester.pumpAndSettle();
        expect(
          _visibleRing(tester)!.$2.strokeAlign,
          BorderSide.strokeAlignInside,
        );

        tester.view.reset();
        await tester.pumpAndSettle();
        expect(
          _visibleRing(tester)!.$2.strokeAlign,
          BorderSide.strokeAlignOutside,
        );
      },
      variant: TargetPlatformVariant.desktop(),
    );

    testWidgets(
      'flipping the ring inside keeps the content State and the scroll '
      'offset',
      (tester) async {
        _useTraditionalHighlight();
        addTearDown(tester.view.reset);
        final controller = _controller();
        await tester.pumpWidget(
          themedHost(
            SizedBox(
              width: 200,
              height: 300,
              child: ColumnLayout(
                scroll: StratumScroll(controller: controller),
                children: const [_Probe()],
              ),
            ),
          ),
        );
        _scrollFocusNode(tester).requestFocus();
        await tester.pumpAndSettle();
        controller.jumpTo(120);
        await tester.pump();
        final content = tester.state(find.byType(_Probe));

        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(200, 300);
        await tester.pumpAndSettle();

        expect(
          _visibleRing(tester)!.$2.strokeAlign,
          BorderSide.strokeAlignInside,
        );
        expect(tester.state(find.byType(_Probe)), same(content));
        expect(controller.offset, 120);
        expect(_scrollFocusNode(tester).hasPrimaryFocus, isTrue);
      },
      variant: TargetPlatformVariant.desktop(),
    );
  });
}

/// A stateful leaf, so a test can tell a kept State from a new one.
class _Probe extends StatefulWidget {
  const new();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) => const SizedBox(height: 2000);
}
