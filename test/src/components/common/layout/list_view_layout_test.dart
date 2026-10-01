import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

Widget _item(BuildContext context, int index) {
  return SizedBox(key: ValueKey(index), width: 40, height: 40);
}

Widget _sized(Widget child) {
  return SizedBox(width: 200, height: 300, child: child);
}

/// [MaterialScrollBehavior] reads the platform from [Theme], and the
/// fallback theme keeps the platform of the first test, so desktop cases
/// set it here.
Widget _macOSTheme(Widget child) {
  return Theme(data: ThemeData(platform: TargetPlatform.macOS), child: child);
}

List<Type> _physicsChain(WidgetTester tester) {
  final state = tester.state<ScrollableState>(find.byType(Scrollable).first);
  final chain = <Type>[];
  for (ScrollPhysics? physics = state.position.physics;
      physics != null;
      physics = physics.parent) {
    chain.add(physics.runtimeType);
  }
  return chain;
}

final _indicator = find.byWidgetPredicate(
  (widget) =>
      widget is StretchingOverscrollIndicator ||
      widget is GlowingOverscrollIndicator,
);

void main() {
  group('ListViewLayout', () {
    testWidgets('builds its items', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(ListViewLayout.builder(itemCount: 3, itemBuilder: _item)),
        ),
      );

      expect(find.byKey(const ValueKey(2)), findsOneWidget);
    });

    testWidgets('builds no box without a style', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(ListViewLayout.builder(itemCount: 3, itemBuilder: _item)),
        ),
      );

      expect(find.byType(AnimatedStyledBox), findsNothing);
    });

    testWidgets('scrolls style padding with the items and keeps the box',
        (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            ListViewLayout.builder(
              style: const WidgetStyle(
                padding: EdgeInsets.all(16),
                backgroundColor: Color(0xFFFFFFFF),
              ),
              itemCount: 50,
              itemBuilder: _item,
            ),
          ),
        ),
      );

      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.padding, const EdgeInsets.all(16));
      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.style?.padding, isNull);
      final boxTop = tester.getTopLeft(find.byType(AnimatedStyledBox));
      final itemTop = tester.getTopLeft(find.byKey(const ValueKey(0)));
      expect(itemTop.dy - boxTop.dy, 16);

      await tester.drag(find.byType(ListView), const Offset(0, -40));
      await tester.pump();

      expect(tester.getTopLeft(find.byType(AnimatedStyledBox)), boxTop);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey(0))).dy,
        lessThan(itemTop.dy),
      );
    });

    testWidgets('clips a rounded box with antiAlias', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            ListViewLayout.builder(
              style: const WidgetStyle(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              itemCount: 3,
              itemBuilder: _item,
            ),
          ),
        ),
      );

      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.style?.clipBehavior, Clip.antiAlias);
      expect(
        find.descendant(
          of: find.byType(AnimatedStyledBox),
          matching: find.byType(ClipRRect),
        ),
        findsOneWidget,
      );
    });

    testWidgets('applies the physics parameter on top of the theme',
        (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            ListViewLayout.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              itemBuilder: _item,
            ),
          ),
        ),
      );

      final chain = _physicsChain(tester);
      expect(chain.first, NeverScrollableScrollPhysics);
      expect(chain, contains(ClampingScrollPhysics));
    });

    testWidgets('reads the theme physics', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(ListViewLayout.builder(itemCount: 3, itemBuilder: _item)),
          theme: FakeStratumTheme(physics: const BouncingScrollPhysics()),
        ),
      );

      expect(_physicsChain(tester), contains(BouncingScrollPhysics));
    });

    testWidgets('builds no overscroll indicator under the theme',
        (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(ListViewLayout.builder(itemCount: 50, itemBuilder: _item)),
        ),
      );

      expect(_indicator, findsNothing);
    });

    testWidgets('lets an ancestor hear the overscroll indicator', (
      tester,
    ) async {
      var heard = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: NotificationListener<OverscrollIndicatorNotification>(
            onNotification: (notification) {
              heard++;
              return false;
            },
            child: ListViewLayout.builder(itemCount: 50, itemBuilder: _item),
          ),
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0, 200));
      await tester.pump();

      expect(heard, greaterThan(0));
    });

    testWidgets('puts a vertical gap between items', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            ListViewLayout.builder(gap: 8, itemCount: 3, itemBuilder: _item),
          ),
        ),
      );

      final first = tester.getBottomLeft(find.byKey(const ValueKey(0)));
      final second = tester.getTopLeft(find.byKey(const ValueKey(1)));
      expect(second.dy - first.dy, 8);
    });

    testWidgets('puts a horizontal gap between items', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            ListViewLayout.builder(
              scrollDirection: Axis.horizontal,
              gap: 8,
              itemCount: 3,
              itemBuilder: _item,
            ),
          ),
        ),
      );

      final first = tester.getTopRight(find.byKey(const ValueKey(0)));
      final second = tester.getTopLeft(find.byKey(const ValueKey(1)));
      expect(second.dx - first.dx, 8);
    });

    test('asserts that gap has an itemCount', () {
      expect(
        () => ListViewLayout.builder(
          gap: 8,
          itemCount: null,
          itemBuilder: _item,
        ),
        throwsAssertionError,
      );
    });

    test('asserts that gap takes no itemExtent', () {
      expect(
        () => ListViewLayout.builder(
          gap: 8,
          itemExtent: 40,
          itemCount: 3,
          itemBuilder: _item,
        ),
        throwsAssertionError,
      );
    });

    test('asserts that gap takes no prototypeItem', () {
      expect(
        () => ListViewLayout.builder(
          gap: 8,
          prototypeItem: const SizedBox(height: 40),
          itemCount: 3,
          itemBuilder: _item,
        ),
        throwsAssertionError,
      );
    });

    test('asserts that gap takes no semanticChildCount', () {
      expect(
        () => ListViewLayout.builder(
          gap: 8,
          semanticChildCount: 3,
          itemCount: 3,
          itemBuilder: _item,
        ),
        throwsAssertionError,
      );
    });

    testWidgets('hands findChildIndexCallback to separated as item indices',
        (tester) async {
      int? finder(Key key) => key == const ValueKey('x') ? 1 : null;
      await tester.pumpWidget(
        themedHost(
          _sized(
            ListViewLayout.builder(
              gap: 8,
              itemCount: 3,
              itemBuilder: _item,
              findChildIndexCallback: finder,
            ),
          ),
        ),
      );

      final list = tester.widget<ListView>(find.byType(ListView));
      final delegate = list.childrenDelegate as SliverChildBuilderDelegate;
      expect(delegate.findChildIndexCallback!(const ValueKey('x')), 2);
    });

    testWidgets('forwards scrollCacheExtent', (tester) async {
      const extent = ScrollCacheExtent.pixels(120);
      await tester.pumpWidget(
        themedHost(
          _sized(
            ListViewLayout.builder(
              scrollCacheExtent: extent,
              itemCount: 3,
              itemBuilder: _item,
            ),
          ),
        ),
      );

      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.scrollCacheExtent, extent);
    });

    testWidgets(
      'keeps the scrollbar of a nested list',
      (tester) async {
        await tester.pumpWidget(
          themedHost(
            _macOSTheme(
              _sized(
                ListViewLayout.builder(
                  showScrollbar: false,
                  itemCount: 1,
                  itemBuilder: (context, index) => SizedBox(
                    height: 200,
                    child: ListViewLayout.builder(
                      itemCount: 50,
                      itemBuilder: _item,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Scrollbar), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  });
}
