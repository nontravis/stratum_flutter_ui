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
}
