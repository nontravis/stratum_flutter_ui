import 'package:flutter/rendering.dart' show ViewportOffset;
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
bool _boxRing(WidgetTester tester) =>
    tester
        .widget<StratumFocusBorder>(
          find.ancestor(
            of: find.byType(StratumInkWell).first,
            matching: find.byType(StratumFocusBorder),
          ),
        )
        .state ==
    FullWidgetState.focused;

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
    Widget item(FocusNode node) =>
        Focus(focusNode: node, child: const SizedBox(width: 200, height: 40));
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

/// A reading-order policy that records each [changedScope] call.
class _ScopeSpy extends ReadingOrderTraversalPolicy {
  final calls = <(FocusNode?, FocusScopeNode?)>[];

  @override
  void changedScope({FocusNode? node, FocusScopeNode? oldScope}) {
    super.changedScope(node: node, oldScope: oldScope);
    calls.add((node, oldScope));
  }
}

/// A lazy cell, 300 px high, with [row] at its top.
Widget _cell(Widget row) {
  return SizedBox(
    height: 300,
    child: Align(alignment: Alignment.topLeft, child: row),
  );
}

/// The side the ring of the only [ScrollFocus] paints, from the
/// [DecoratedBox] right below its [StratumFocusBorder]; null when no ring
/// shows.
BorderSide? _visibleRing(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(StratumFocusBorder),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  final shape = (box.decoration as ShapeDecoration).shape;
  final side = (shape as RoundedRectangleBorder).side;
  return side.color.a > 0 ? side : null;
}

/// Whether the shown ring of the only [ScrollFocus] lies on the box's
/// inner edge.
bool _ringInside(WidgetTester tester) =>
    _visibleRing(tester)!.strokeAlign == BorderSide.strokeAlignInside;

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

    test('keeps the padding on the box with scrollsPadding: false', () {
      final box = ScrollFrame.boxStyle(
        const WidgetStyle(
          padding: EdgeInsets.all(8),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        scrollsPadding: false,
      );

      expect(box.padding, const EdgeInsets.all(8));
      expect(box.clipBehavior, Clip.antiAlias);
    });
  });

  group('ScrollViewBox', () {
    const style = WidgetStyle(
      padding: EdgeInsets.all(8),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    );

    /// A [ScrollViewBox] around a [ListView] that records what the builder
    /// receives in [received].
    Widget box({
      WidgetStyle? style,
      bool? focusable = true,
      ScrollController? controller,
      bool scrollsPadding = true,
      List<Object?>? received,
    }) {
      return SizedBox(
        width: 200,
        height: 300,
        child: ScrollViewBox(
          style: style,
          focusable: focusable,
          axis: Axis.vertical,
          controller: controller,
          scrollsPadding: scrollsPadding,
          builder: (context, controller, padding) {
            received
              ?..clear()
              ..addAll([controller, padding]);
            return ListView(
              controller: controller,
              padding: padding,
              children: const [SizedBox(height: 2000)],
            );
          },
        ),
      );
    }

    testWidgets('builds the phase 4 tree: focus, box, content group, frame, '
        'and the view with the padding', (tester) async {
      final received = <Object?>[];
      await tester.pumpWidget(
        themedHost(box(style: style, received: received)),
      );

      final scrollFocus = find.byType(ScrollFocus);
      final container = find.descendant(
        of: scrollFocus,
        matching: find.byType(ContainerLayout),
      );
      final group = find.descendant(
        of: container,
        matching: find.byType(FocusTraversalGroup),
      );
      final frame = find.descendant(
        of: group.first,
        matching: find.byType(ScrollFrame),
      );
      expect(scrollFocus, findsOneWidget);
      expect(tester.widget<ScrollFocus>(scrollFocus).focusable, isTrue);
      expect(
        tester.widget<ScrollFocus>(scrollFocus).borderRadius,
        style.borderRadius,
      );
      expect(container, findsOneWidget);
      expect(tester.widget<ContainerLayout>(container).style!.padding, isNull);
      expect(frame, findsOneWidget);
      expect(
        find.descendant(of: frame, matching: find.byType(ListView)),
        findsOneWidget,
      );
      expect(received, [isA<ScrollController>(), style.padding]);
    });

    testWidgets('builds no box without a style and no content group when '
        'not focusable', (tester) async {
      await tester.pumpWidget(themedHost(box(focusable: false)));

      expect(find.byType(ContainerLayout), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ScrollFocus),
          matching: find.byType(FocusTraversalGroup),
        ),
        findsNothing,
      );
      expect(
        tester.widget<ScrollFocus>(find.byType(ScrollFocus)).focusable,
        isFalse,
      );
    });

    testWidgets("hands the builder the caller's controller", (tester) async {
      final controller = _controller();
      final received = <Object?>[];
      await tester.pumpWidget(
        themedHost(box(controller: controller, received: received)),
      );

      expect(received.first, same(controller));
    });

    testWidgets('scrollsPadding: false keeps the padding on the box', (
      tester,
    ) async {
      final received = <Object?>[];
      await tester.pumpWidget(
        themedHost(
          box(style: style, scrollsPadding: false, received: received),
        ),
      );

      expect(
        tester
            .widget<ContainerLayout>(find.byType(ContainerLayout))
            .style!
            .padding,
        style.padding,
      );
      expect(received.last, isNull);
    });

    testWidgets('resolves a null focusable to true on macOS', (tester) async {
      await tester.pumpWidget(themedHost(box(focusable: null)));

      expect(
        tester.widget<ScrollFocus>(find.byType(ScrollFocus)).focusable,
        isTrue,
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('resolves a null focusable to false on Android', (
      tester,
    ) async {
      await tester.pumpWidget(themedHost(box(focusable: null)));

      expect(
        tester.widget<ScrollFocus>(find.byType(ScrollFocus)).focusable,
        isFalse,
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
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
      'us07/fr03/e04: the viewport takes focus, carries its label, and shows '
      'an unclipped ring',
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
          tester
              .widget<StratumFocusBorder>(find.byType(StratumFocusBorder))
              .state,
          FullWidgetState.focused,
        );
        expect(
          find.ancestor(
            of: find.byType(StratumFocusBorder),
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

    testWidgets('us07/s1: arrows, Page Down, Home, and End scroll the focused '
        'viewport', (tester) async {
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
    }, variant: TargetPlatformVariant.desktop());

    testWidgets('us07/s2: Down scrolls a focused list by 50 px', (
      tester,
    ) async {
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
    }, variant: TargetPlatformVariant.desktop());

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

    testWidgets('us07/s3: End reaches the true end of a lazy list', (
      tester,
    ) async {
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

    testWidgets('us07/s4: Page Down scrolls while a button item holds focus', (
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
      'us07/s6: Home and End inside a TextField item leave the list where it '
      'is',
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
      'us07/fr03/e03: a desktop list without a theme takes focus and builds '
      'no ring',
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
        expect(find.byType(StratumFocusBorder), findsNothing);
        expect(_pixels(tester), 50);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets('us07/s7: (pin) a mobile list is no Tab stop and keeps its own '
        'controller', (tester) async {
      await tester.pumpWidget(
        themedHost(
          const SizedBox(
            width: 200,
            height: 300,
            child: ListViewLayout.builder(itemCount: 50, itemBuilder: _item),
          ),
        ),
      );

      expect(find.byType(StratumFocusBorder), findsNothing);
      expect(tester.widget<ListView>(find.byType(ListView)).controller, isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('ScrollFocus lines mode motion', () {
    /// Pumps a focusable list of 50 rows of 40 px in a 200 by 300 view,
    /// under [theme] or [data] when set, and Tabs onto its viewport.
    Future<void> focusList(
      WidgetTester tester, {
      MediaQueryData? data,
      StratumThemeData? theme,
    }) async {
      final before = _node();
      var host = themedHost(
        _keyboardHost(
          const ListViewLayout.builder(itemCount: 50, itemBuilder: _item),
          before: before,
        ),
        theme: theme,
      );
      if (data != null) host = MediaQuery(data: data, child: host);
      await tester.pumpWidget(host);
      await _tabIn(tester, before);
      expect(_viewportFocused(), isTrue);
    }

    testWidgets(
      "an arrow jumps 50 px under the app's reduced motion (us07/fr04)",
      (tester) async {
        await focusList(
          tester,
          data: const MediaQueryData(disableAnimations: true),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();

        expect(_pixels(tester), 50);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets("us07/s8: Page Down jumps under the platform's reduceMotion", (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await focusList(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(_pixels(tester), 50);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();
      expect(_pixels(tester), 50 + 0.8 * 300);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets(
      "an arrow moves over the theme's fast level on its curve (us07/fr04)",
      (tester) async {
        final theme = motionTheme(
          standard: const StratumNamedCurve('easeInOutQuad'),
        );
        final fast = theme.animation.fast;
        final duration = fast.duration!;
        const step = Duration(milliseconds: 25);
        await focusList(tester, theme: theme);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        await tester.pump(step);
        final progress = step.inMicroseconds / duration.inMicroseconds;
        expect(
          _pixels(tester),
          closeTo(50 * fast.curve!.transform(progress), 0.01),
        );
        await tester.pump(duration - step);
        expect(_pixels(tester), 50);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    /// A focusable list after [before], under [theme], or under no theme
    /// at all when [themed] is false.
    Widget list(
      FocusNode before, {
      StratumThemeData? theme,
      bool themed = true,
    }) {
      final host = _keyboardHost(
        const ListViewLayout.builder(itemCount: 50, itemBuilder: _item),
        before: before,
      );
      return themed
          ? themedHost(host, theme: theme)
          : Directionality(
              textDirection: TextDirection.ltr,
              child: Center(child: host),
            );
    }

    /// Pumps [build]'s host, tabs into the list, and presses Arrow Down.
    Future<void> arrowDown(
      WidgetTester tester,
      Widget Function(FocusNode before) build,
    ) async {
      final before = _node();
      await tester.pumpWidget(build(before));
      await _tabIn(tester, before);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }

    testWidgets("us11/fr01: an arrow moves over the theme's fast level", (
      tester,
    ) async {
      await arrowDown(tester, (before) => list(before, theme: motionTheme()));

      await tester.pump(const Duration(milliseconds: 38));
      expect(_pixels(tester), greaterThan(0));
      expect(_pixels(tester), lessThan(50));
      await tester.pump(const Duration(milliseconds: 40));
      expect(_pixels(tester), 50);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets("us11/fr01: with no theme an arrow takes the package default's "
        'fast level', (tester) async {
      await arrowDown(tester, (before) => list(before, themed: false));

      await tester.pump(const Duration(milliseconds: 100));
      expect(_pixels(tester), lessThan(50));
      await tester.pump(const Duration(milliseconds: 26));
      expect(_pixels(tester), 50);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });

  group('ScrollFocus pages mode', () {
    /// A focusable page view of [count] pages, 200 by 300 each, through
    /// [ScrollViewBox] in pages mode; [count] null builds pages without
    /// end. The builder's controller lands in [received].
    Widget pages({
      Axis axis = Axis.horizontal,
      bool reverse = false,
      int? count = 5,
      PageController? controller,
      List<ScrollController?>? received,
    }) {
      return SizedBox(
        width: 200,
        height: 300,
        child: ScrollViewBox(
          mode: ScrollFocusMode.pages,
          pageCount: count,
          focusable: true,
          axis: axis,
          controller: controller,
          builder: (context, controller, padding) {
            received?.add(controller);
            return PageView.builder(
              controller: controller as PageController?,
              scrollDirection: axis,
              reverse: reverse,
              itemCount: count,
              itemBuilder: (context, index) => Text('page $index'),
            );
          },
        ),
      );
    }

    /// The page the view shows, from its offset.
    double page(WidgetTester tester) {
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      return position.pixels / position.viewportDimension;
    }

    /// Pumps [view] and focuses its own node.
    Future<void> focusView(WidgetTester tester, Widget view) async {
      await tester.pumpWidget(view);
      _scrollFocusNode(tester).requestFocus();
      await tester.pump();
    }

    for (final (axis, next, previous, across) in const [
      (
        Axis.horizontal,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowDown,
      ),
      (
        Axis.vertical,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowRight,
      ),
    ]) {
      testWidgets('$axis: arrows, Page Up, Page Down, Home, and End move '
          'whole pages', (tester) async {
        await focusView(tester, themedHost(pages(axis: axis)));

        await _key(tester, next);
        expect(page(tester), 1);
        await _key(tester, previous);
        expect(page(tester), 0);
        await _key(tester, LogicalKeyboardKey.pageDown);
        await _key(tester, LogicalKeyboardKey.pageDown);
        expect(page(tester), 2);
        await _key(tester, LogicalKeyboardKey.pageUp);
        expect(page(tester), 1);
        await _key(tester, LogicalKeyboardKey.end);
        expect(page(tester), 4);
        await _key(tester, LogicalKeyboardKey.home);
        expect(page(tester), 0);
        expect(await tester.sendKeyEvent(across), isFalse);
        await tester.pumpAndSettle();
        expect(page(tester), 0);
      }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
    }

    testWidgets('Left goes to the next page under right-to-left text', (
      tester,
    ) async {
      await focusView(
        tester,
        themedHost(pages(), textDirection: TextDirection.rtl),
      );

      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(page(tester), 1);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(page(tester), 0);
      await _key(tester, LogicalKeyboardKey.pageDown);
      expect(page(tester), 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('Left goes to the next page with reverse', (tester) async {
      await focusView(tester, themedHost(pages(reverse: true)));

      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(page(tester), 1);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(page(tester), 0);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('a page change slides over 300 ms with easeInOutSine', (
      tester,
    ) async {
      await focusView(tester, themedHost(pages()));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(page(tester), closeTo(Curves.easeInOutSine.transform(0.5), 0.01));
      await tester.pump(const Duration(milliseconds: 150));
      expect(page(tester), 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets("us11/fr01: a page change slides over the theme's slow "
        'level', (tester) async {
      await focusView(tester, themedHost(pages(), theme: motionTheme()));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      expect(page(tester), greaterThan(0));
      expect(page(tester), lessThan(1));
      // Past the package default's 300 ms: still short of the theme's
      // 333 ms, so the package default would already read 1 here.
      await tester.pump(const Duration(milliseconds: 150));
      expect(page(tester), lessThan(1));
      await tester.pump(const Duration(milliseconds: 23));
      expect(page(tester), 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets("us10/fr01/e07: a page change jumps when the theme's slow "
        'level has no duration', (tester) async {
      await focusView(
        tester,
        themedHost(pages(), theme: motionTheme(slow: Duration.zero)),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(page(tester), 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('us10/fr01/e07: a page change jumps when the slow level has no '
        'fields at all', (tester) async {
      final theme = fakeTheme.copyWith(
        animation: StratumAnimation(
          veryFast: StratumAnimation.packageDefault.veryFast,
          fast: StratumAnimation.packageDefault.fast,
          normal: StratumAnimation.packageDefault.normal,
          slow: const AnimationStyle(),
          verySlow: StratumAnimation.packageDefault.verySlow,
          appear: StratumAnimation.packageDefault.appear,
          defaultLevel: StratumMotionLevel.fast,
        ),
      );
      await focusView(tester, themedHost(pages(), theme: theme));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(page(tester), 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('reduced motion jumps to the page', (tester) async {
      await focusView(
        tester,
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: themedHost(pages()),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(page(tester), 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('a key during a slide counts from its target page', (
      tester,
    ) async {
      await focusView(tester, themedHost(pages()));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(page(tester), 2);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('a key past the first or last page is not handled', (
      tester,
    ) async {
      await focusView(tester, themedHost(pages()));

      expect(await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft), isFalse);
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.pageUp), isFalse);
      await _key(tester, LogicalKeyboardKey.end);
      expect(page(tester), 4);
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight), isFalse);
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.pageDown), isFalse);
      await tester.pumpAndSettle();
      expect(page(tester), 4);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('End is ignored when the page count is unknown', (
      tester,
    ) async {
      await focusView(tester, themedHost(pages(count: null)));

      await _key(tester, LogicalKeyboardKey.pageDown);
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.end), isFalse);
      await tester.pumpAndSettle();

      expect(page(tester), 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets("the caller's PageController drives the keys", (tester) async {
      final controller = PageController();
      addTearDown(controller.dispose);
      final received = <ScrollController?>[];
      await focusView(
        tester,
        themedHost(pages(controller: controller, received: received)),
      );

      await _key(tester, LogicalKeyboardKey.arrowRight);

      expect(received.last, same(controller));
      expect(controller.page, 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('pages mode creates a PageController and never inherits the '
        'primary controller', (tester) async {
      final primary = _controller();
      final received = <ScrollController?>[];
      await focusView(
        tester,
        themedHost(
          PrimaryScrollController(
            controller: primary,
            automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
            child: pages(axis: Axis.vertical, received: received),
          ),
        ),
      );

      expect(received.last, isA<PageController>());
      expect(received.last, isNot(same(primary)));
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(page(tester), 1);
      expect(primary.hasClients, isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
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

      testWidgets('Tab walks above, the stop of a $name, its items, and below; '
          'Shift+Tab walks back', (tester) async {
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
      }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
    }
  });

  group('Reveal by the edge of each viewport', () {
    /// Ten 100 px cards, each a Tab stop, in a 200 px wide scrolling row
    /// without a focus group, at 300 to 350 between two 300 px fillers in a
    /// 200 by 200 vertical page on [page], under the app's default keys.
    Future<List<FocusNode>> pumpRow(
      WidgetTester tester,
      ScrollController page,
    ) async {
      final cards = _nodes(10);
      await tester.pumpWidget(
        themedHost(
          Shortcuts(
            shortcuts: WidgetsApp.defaultShortcuts,
            child: Actions(
              actions: WidgetsApp.defaultActions,
              child: SizedBox(
                width: 200,
                height: 200,
                child: SingleChildScrollView(
                  controller: page,
                  child: Column(
                    children: [
                      const SizedBox(height: 300),
                      SizedBox(
                        width: 200,
                        height: 50,
                        child: RowLayout(
                          style: const WidgetStyle(),
                          scroll: const StratumScroll(),
                          children: [
                            for (final card in cards)
                              Focus(
                                focusNode: card,
                                child: const SizedBox(width: 100, height: 50),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 300),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return cards;
    }

    Finder rowScrollable() => find.descendant(
      of: find.byType(RowLayout),
      matching: find.byType(Scrollable),
    );

    ScrollPosition row(WidgetTester tester) =>
        tester.state<ScrollableState>(rowScrollable()).position;

    /// Focuses [card], then scrolls the row to [rowAt] and the page to
    /// [pageAt].
    Future<void> place(
      WidgetTester tester,
      FocusNode card,
      ScrollController page, {
      required double rowAt,
      required double pageAt,
    }) async {
      card.requestFocus();
      await tester.pump();
      row(tester).jumpTo(rowAt);
      page.jumpTo(pageAt);
      await tester.pump();
    }

    /// Expects focus on [card], wholly inside the row and the page.
    void expectShown(WidgetTester tester, FocusNode card) {
      expect(card.hasPrimaryFocus, isTrue);
      final rect = card.rect;
      final inRow = tester.getRect(rowScrollable());
      final inPage = tester.getRect(
        find.byType(SingleChildScrollView).first,
      );
      expect(
        rect.left >= inRow.left - 0.5 &&
            rect.right <= inRow.right + 0.5 &&
            rect.top >= inPage.top - 0.5 &&
            rect.bottom <= inPage.bottom + 0.5,
        isTrue,
        reason: 'card at $rect, row $inRow, page $inPage',
      );
    }

    testWidgets(
      'Tab reveals the next card at the end of the row and at the start of '
      'the page, then Shift+Tab at the start of the row and the end of the '
      'page',
      (tester) async {
        final page = _controller();
        final cards = await pumpRow(tester, page);
        // Card 4 lies past the row's end; the row extends past the page's
        // top.
        await place(tester, cards[3], page, rowAt: 200, pageAt: 320);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        expectShown(tester, cards[4]);
        expect(row(tester).pixels, 300);
        expect(page.offset, 300);

        // Card 3 lies before the row's start; the row extends past the
        // page's bottom.
        await place(tester, cards[4], page, rowAt: 400, pageAt: 130);

        await _shiftTab(tester);

        expectShown(tester, cards[3]);
        expect(row(tester).pixels, 300);
        expect(page.offset, 350 - 200);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      "Flutter's Right arrow reveals the next card by the edge of each "
      'viewport',
      (tester) async {
        final page = _controller();
        final cards = await pumpRow(tester, page);
        await place(tester, cards[3], page, rowAt: 200, pageAt: 320);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();

        expectShown(tester, cards[4]);
        expect(row(tester).pixels, 300);
        expect(page.offset, 300);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'Tab reveals the next cell of a two-dimensional view in its own '
      'viewport, below its visible rows',
      (tester) async {
        final page = _controller();
        final rows = _controller();
        final cells = _nodes(12);
        await tester.pumpWidget(
          themedHost(
            Shortcuts(
              shortcuts: WidgetsApp.defaultShortcuts,
              child: Actions(
                actions: WidgetsApp.defaultActions,
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: ColumnLayout(
                    scroll: StratumScroll(controller: page),
                    children: [
                      const SizedBox(height: 50),
                      SizedBox(
                        width: 200,
                        height: 100,
                        child: _Grid(
                          delegate: _cellsOf(cells),
                          verticalDetails: ScrollableDetails.vertical(
                            controller: rows,
                          ),
                        ),
                      ),
                      const SizedBox(height: 300),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        // The grid shows rows 0 and 1; cell 3 ends row 1, and cell 4
        // starts row 2, below them.
        cells[3].requestFocus();
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        expect(cells[4].hasPrimaryFocus, isTrue);
        expect(rows.offset, 50);
        expect(page.offset, 0);
        final rect = cells[4].rect;
        final grid = tester.getRect(find.byType(_Grid));
        expect(
          rect.top >= grid.top - 0.5 && rect.bottom <= grid.bottom + 0.5,
          isTrue,
          reason: 'cell at $rect, grid $grid',
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'Tab to a chip of a scroller in a cell below the visible rows of a '
      'two-dimensional view reveals that cell',
      (tester) async {
        final page = _controller();
        final rows = _controller();
        final cells = _nodes(12);
        final chips = _nodes(3);
        // Cell 4, which starts row 2 below the visible rows, holds a
        // scroller of three 60 px chips.
        final scroller = RowLayout(
          style: const WidgetStyle(),
          scroll: const StratumScroll(),
          children: [
            for (final chip in chips)
              Focus(
                focusNode: chip,
                child: const SizedBox(width: 60, height: 50),
              ),
          ],
        );
        await tester.pumpWidget(
          themedHost(
            Shortcuts(
              shortcuts: WidgetsApp.defaultShortcuts,
              child: Actions(
                actions: WidgetsApp.defaultActions,
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: ColumnLayout(
                    scroll: StratumScroll(controller: page),
                    children: [
                      const SizedBox(height: 50),
                      SizedBox(
                        width: 200,
                        height: 100,
                        child: _Grid(
                          delegate: _cellsOf(cells, replaced: {4: scroller}),
                          verticalDetails: ScrollableDetails.vertical(
                            controller: rows,
                          ),
                        ),
                      ),
                      const SizedBox(height: 300),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        tester
            .widget<Focus>(
              find.descendant(
                of: find.byType(RowLayout),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Focus &&
                      widget.focusNode?.debugLabel == 'ScrollFocus',
                ),
              ),
            )
            .focusNode!
            .requestFocus();
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        expect(chips[0].hasPrimaryFocus, isTrue);
        expect(rows.offset, 50);
        expect(page.offset, 0);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      "Flutter's Down arrow into a nested FocusScope reveals the focused "
      "leaf, not the scope's start",
      (tester) async {
        final view = _controller();
        final first = _node();
        final leaf = _node();
        await tester.pumpWidget(
          themedHost(
            Shortcuts(
              shortcuts: WidgetsApp.defaultShortcuts,
              child: Actions(
                actions: WidgetsApp.defaultActions,
                child: FocusTraversalGroup(
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: ColumnLayout(
                      scroll: StratumScroll(controller: view),
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                const SizedBox(height: 300),
                                Focus(
                                  focusNode: first,
                                  child: const SizedBox(width: 100, height: 40),
                                ),
                              ],
                            ),
                            FocusScope(
                              child: Column(
                                children: [
                                  const SizedBox(height: 360),
                                  Focus(
                                    focusNode: leaf,
                                    child: const SizedBox(
                                      width: 100,
                                      height: 40,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 200),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        first.requestFocus();
        await tester.pump();
        // The view shows 200 to 400: first at 300 to 340, and the leaf at
        // 360 to 400 at the bottom of its scope, which starts at 0.
        view.jumpTo(200);
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();

        expect(leaf.hasPrimaryFocus, isTrue);
        expect(view.offset, 200);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      "Flutter's Down arrow keeps the animated, centered reveal of an "
      "enclosing policy's own requestFocusCallback",
      (tester) async {
        final view = _controller();
        final items = _nodes(10);
        void centered(
          FocusNode node, {
          ScrollPositionAlignmentPolicy? alignmentPolicy,
          double? alignment,
          Duration? duration,
          Curve? curve,
        }) {
          node.requestFocus();
          Scrollable.ensureVisible(
            node.context!,
            alignment: 0.5,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOutSine,
          );
        }

        await tester.pumpWidget(
          themedHost(
            Shortcuts(
              shortcuts: WidgetsApp.defaultShortcuts,
              child: Actions(
                actions: WidgetsApp.defaultActions,
                child: FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(
                    requestFocusCallback: centered,
                  ),
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: ColumnLayout(
                      scroll: StratumScroll(controller: view),
                      children: [
                        for (final item in items)
                          Focus(
                            focusNode: item,
                            child: const SizedBox(width: 200, height: 40),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        // Item 4 ends the view at 200; item 5, at 200 to 240, lies past it.
        items[4].requestFocus();
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();

        expect(items[5].hasPrimaryFocus, isTrue);
        expect(view.offset, 220 - 100);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  });

  group('ScrollFocus content group policy', () {
    testWidgets(
      'forwards changedScope to the enclosing policy when a focused node '
      'moves to another scope',
      (tester) async {
        final spy = _ScopeSpy();
        final first = FocusScopeNode(debugLabel: 'first');
        final second = FocusScopeNode(debugLabel: 'second');
        addTearDown(first.dispose);
        addTearDown(second.dispose);
        final item = _node();
        final key = GlobalKey();
        // A focusable list in each scope; the item sits in the first list,
        // or, with [moved], in the second.
        Widget scopes({required bool moved}) {
          Widget list({required bool holds}) => SizedBox(
            width: 200,
            height: 100,
            child: ListViewLayout.builder(
              focusable: true,
              itemCount: holds ? 1 : 0,
              itemBuilder: (context, index) => Focus(
                key: key,
                focusNode: item,
                child: const SizedBox(height: 40),
              ),
            ),
          );
          return themedHost(
            FocusTraversalGroup(
              policy: spy,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FocusScope(node: first, child: list(holds: !moved)),
                  FocusScope(node: second, child: list(holds: moved)),
                ],
              ),
            ),
          );
        }

        await tester.pumpWidget(scopes(moved: false));
        item.requestFocus();
        await tester.pump();
        expect(item.hasPrimaryFocus, isTrue);
        spy.calls.clear();

        await tester.pumpWidget(scopes(moved: true));

        expect(item.nearestScope, second);
        expect(spy.calls, [(item, first)]);
      },
    );
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
      'us07/s5: a scrolling box that fills the window draws its ring inside '
      'its edge, over the content and unclipped',
      (tester) async {
        _useTraditionalHighlight();
        await tester.pumpWidget(themedHost(fullWindow));

        _scrollFocusNode(tester).requestFocus();
        await tester.pumpAndSettle();

        final side = _visibleRing(tester)!;
        expect(side.strokeAlign, BorderSide.strokeAlignInside);
        expect(side.width, 3);
        expect(side.color, isSameColorAs(fakeTheme.color.border.subtle.blue));
        expect(
          find.ancestor(
            of: find.byType(StratumFocusBorder),
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
      'us07/fr03: a small box in the middle of the window keeps its ring '
      'around it',
      (tester) async {
        _useTraditionalHighlight();
        await tester.pumpWidget(themedHost(smallBox));

        _scrollFocusNode(tester).requestFocus();
        await tester.pumpAndSettle();

        final side = _visibleRing(tester)!;
        expect(side.strokeInset, moreOrLessEquals(-2));
        expect(side.width, 3);
      },
      variant: TargetPlatformVariant.desktop(),
    );

    testWidgets(
      'us07/fr03/e02: the ring moves inside when the window shrinks to the '
      'box and back around it when the window grows',
      (tester) async {
        _useTraditionalHighlight();
        addTearDown(tester.view.reset);
        await tester.pumpWidget(themedHost(smallBox));
        _scrollFocusNode(tester).requestFocus();
        await tester.pumpAndSettle();
        expect(_ringInside(tester), isFalse);

        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(200, 300);
        await tester.pumpAndSettle();
        expect(_ringInside(tester), isTrue);

        tester.view.reset();
        await tester.pumpAndSettle();
        expect(_ringInside(tester), isFalse);
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

        expect(_ringInside(tester), isTrue);
        expect(tester.state(find.byType(_Probe)), same(content));
        expect(controller.offset, 120);
        expect(_scrollFocusNode(tester).hasPrimaryFocus, isTrue);
      },
      variant: TargetPlatformVariant.desktop(),
    );

    testWidgets(
      "us07/fr03/e01: the window check grows the box by the ring's 2 px gap "
      'and 3 px width',
      (tester) async {
        _useTraditionalHighlight();
        // The 800 by 600 test window around a centered box: a 5 px margin
        // holds the gap and the ring, a 4 px margin does not.
        for (final (margin, inside) in [(5.0, false), (4.0, true)]) {
          await tester.pumpWidget(
            themedHost(
              SizedBox(
                key: ValueKey(margin),
                width: 800 - 2 * margin,
                height: 600 - 2 * margin,
                child: const ColumnLayout(
                  scroll: StratumScroll(),
                  children: [SizedBox(height: 2000)],
                ),
              ),
            ),
          );
          _scrollFocusNode(tester).requestFocus();
          await tester.pumpAndSettle();

          expect(_ringInside(tester), inside, reason: 'margin $margin');
        }
      },
      variant: TargetPlatformVariant.desktop(),
    );

    testWidgets("us07/nf01: a focused scrolling area's ring paints the theme's "
        'border.subtle.blue, 3 px after a 2 px gap', (tester) async {
      _useTraditionalHighlight();
      await tester.pumpWidget(themedHost(smallBox));

      _scrollFocusNode(tester).requestFocus();
      await tester.pumpAndSettle();

      final side = _visibleRing(tester)!;
      expect(side.color, isSameColorAs(fakeTheme.color.border.subtle.blue));
      expect(side.width, 3);
      expect(side.strokeInset, moreOrLessEquals(-2));
    }, variant: TargetPlatformVariant.desktop());
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

/// The size of each cell of a [_Grid].
const _gridCell = Size(100, 50);

/// Cells of a [_Grid], two to a row, each a Tab stop on one of [cells],
/// or the widget [replaced] holds for its index; disposed after the test.
TwoDimensionalChildBuilderDelegate _cellsOf(
  List<FocusNode> cells, {
  Map<int, Widget> replaced = const {},
}) {
  final delegate = TwoDimensionalChildBuilderDelegate(
    maxXIndex: 1,
    maxYIndex: cells.length ~/ 2 - 1,
    builder: (context, vicinity) {
      final index = vicinity.yIndex * 2 + vicinity.xIndex;
      return replaced[index] ??
          Focus(
            focusNode: cells[index],
            child: SizedBox.fromSize(size: _gridCell),
          );
    },
  );
  addTearDown(delegate.dispose);
  return delegate;
}

/// The least [TwoDimensionalScrollView] a reveal needs: a grid of
/// [_gridCell] cells that lays out every cell of its delegate.
class _Grid extends TwoDimensionalScrollView {
  const new({required super.delegate, super.verticalDetails});

  @override
  Widget buildViewport(
    BuildContext context,
    ViewportOffset verticalOffset,
    ViewportOffset horizontalOffset,
  ) {
    return _GridViewport(
      verticalOffset: verticalOffset,
      verticalAxisDirection: verticalDetails.direction,
      horizontalOffset: horizontalOffset,
      horizontalAxisDirection: horizontalDetails.direction,
      delegate: delegate,
      mainAxis: mainAxis,
    );
  }
}

class _GridViewport extends TwoDimensionalViewport {
  const new({
    required super.verticalOffset,
    required super.verticalAxisDirection,
    required super.horizontalOffset,
    required super.horizontalAxisDirection,
    required super.delegate,
    required super.mainAxis,
  });

  @override
  RenderTwoDimensionalViewport createRenderObject(BuildContext context) {
    return _RenderGrid(
      horizontalOffset: horizontalOffset,
      horizontalAxisDirection: horizontalAxisDirection,
      verticalOffset: verticalOffset,
      verticalAxisDirection: verticalAxisDirection,
      delegate: delegate,
      mainAxis: mainAxis,
      childManager: context as TwoDimensionalChildManager,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderTwoDimensionalViewport renderObject,
  ) {
    renderObject
      ..horizontalOffset = horizontalOffset
      ..horizontalAxisDirection = horizontalAxisDirection
      ..verticalOffset = verticalOffset
      ..verticalAxisDirection = verticalAxisDirection
      ..delegate = delegate
      ..mainAxis = mainAxis;
  }
}

class _RenderGrid extends RenderTwoDimensionalViewport {
  new({
    required super.horizontalOffset,
    required super.horizontalAxisDirection,
    required super.verticalOffset,
    required super.verticalAxisDirection,
    required super.delegate,
    required super.mainAxis,
    required super.childManager,
  });

  @override
  void layoutChildSequence() {
    final cells = delegate as TwoDimensionalChildBuilderDelegate;
    final columns = cells.maxXIndex! + 1;
    final rows = cells.maxYIndex! + 1;
    for (var x = 0; x < columns; x++) {
      for (var y = 0; y < rows; y++) {
        final vicinity = ChildVicinity(xIndex: x, yIndex: y);
        final child = buildOrObtainChildFor(vicinity)!
          ..layout(BoxConstraints.tight(_gridCell));
        parentDataOf(child).layoutOffset = Offset(
          x * _gridCell.width - horizontalOffset.pixels,
          y * _gridCell.height - verticalOffset.pixels,
        );
      }
    }
    double overflow(double content, double viewport) =>
        content > viewport ? content - viewport : 0;
    verticalOffset.applyContentDimensions(
      0,
      overflow(rows * _gridCell.height, viewportDimension.height),
    );
    horizontalOffset.applyContentDimensions(
      0,
      overflow(columns * _gridCell.width, viewportDimension.width),
    );
  }
}
