import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

const _delegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
);

Widget _item(BuildContext context, int index) {
  return SizedBox(key: ValueKey(index));
}

Widget _sized(Widget child) {
  return SizedBox(width: 200, height: 300, child: child);
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

void main() {
  group('GridViewLayout', () {
    testWidgets('builds its items', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            GridViewLayout.builder(
              gridDelegate: _delegate,
              itemCount: 4,
              itemBuilder: _item,
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey(3)), findsOneWidget);
      expect(find.byType(AnimatedStyledBox), findsNothing);
    });

    testWidgets('moves style padding into the grid', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            GridViewLayout.builder(
              style: const WidgetStyle(padding: EdgeInsets.all(16)),
              gridDelegate: _delegate,
              itemCount: 4,
              itemBuilder: _item,
            ),
          ),
        ),
      );

      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(grid.padding, const EdgeInsets.all(16));
      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.style?.padding, isNull);
    });

    testWidgets('applies the physics parameter on top of the theme',
        (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            GridViewLayout.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: _delegate,
              itemCount: 4,
              itemBuilder: _item,
            ),
          ),
        ),
      );

      final chain = _physicsChain(tester);
      expect(chain.first, NeverScrollableScrollPhysics);
      expect(chain, contains(ClampingScrollPhysics));
    });

    testWidgets('builds no overscroll indicator under the theme',
        (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            GridViewLayout.builder(
              gridDelegate: _delegate,
              itemCount: 40,
              itemBuilder: _item,
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is StretchingOverscrollIndicator ||
              widget is GlowingOverscrollIndicator,
        ),
        findsNothing,
      );
    });
  });
}
