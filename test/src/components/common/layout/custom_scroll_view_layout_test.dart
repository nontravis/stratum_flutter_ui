import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

const _children = [
  SizedBox(key: ValueKey(0), height: 40),
  SizedBox(key: ValueKey(1), height: 40),
  SizedBox(key: ValueKey(2), height: 40),
];

Widget _sized(Widget child) {
  return SizedBox(width: 200, height: 300, child: child);
}

/// [MaterialScrollBehavior] reads the platform from [Theme], and the
/// fallback theme keeps the platform of the first test, so desktop cases
/// set it here.
Widget _macOSTheme(Widget child) {
  return Theme(data: ThemeData(platform: TargetPlatform.macOS), child: child);
}

void main() {
  group('CustomScrollViewLayout', () {
    testWidgets('builds children in one SliverList and counts them',
        (tester) async {
      await tester.pumpWidget(
        themedHost(_sized(const CustomScrollViewLayout(children: _children))),
      );

      expect(find.byType(SliverList), findsOneWidget);
      expect(find.byKey(const ValueKey(2)), findsOneWidget);
      final view = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      expect(view.semanticChildCount, 3);
      expect(find.byType(AnimatedStyledBox), findsNothing);
    });

    testWidgets('turns style padding into a SliverPadding', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            const CustomScrollViewLayout(
              style: WidgetStyle(padding: EdgeInsets.all(16)),
              children: _children,
            ),
          ),
        ),
      );

      final padding = tester.widget<SliverPadding>(find.byType(SliverPadding));
      expect(padding.padding, const EdgeInsets.all(16));
      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.style?.padding, isNull);
    });

    testWidgets('passes slivers through', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            const CustomScrollViewLayout(
              slivers: [SliverToBoxAdapter(child: SizedBox(height: 40))],
            ),
          ),
        ),
      );

      expect(find.byType(SliverToBoxAdapter), findsOneWidget);
      final view = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      expect(view.semanticChildCount, isNull);
    });

    testWidgets('asserts that slivers take no style padding', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            const CustomScrollViewLayout(
              style: WidgetStyle(padding: EdgeInsets.all(16)),
              slivers: [SliverToBoxAdapter(child: SizedBox(height: 40))],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });

    test('asserts exactly one of slivers and children', () {
      expect(() => CustomScrollViewLayout(), throwsAssertionError);
      expect(
        () => CustomScrollViewLayout(
          slivers: const [],
          children: const [],
        ),
        throwsAssertionError,
      );
    });

    testWidgets(
      'hides the scrollbar when showScrollbar is false',
      (tester) async {
        await tester.pumpWidget(
          themedHost(
            _macOSTheme(
              _sized(
                const CustomScrollViewLayout(
                  showScrollbar: false,
                  children: _children,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Scrollbar), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'keeps the desktop scrollbar by default',
      (tester) async {
        await tester.pumpWidget(
          themedHost(
            _macOSTheme(
              _sized(const CustomScrollViewLayout(children: _children)),
            ),
          ),
        );

        expect(find.byType(Scrollbar), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  });
}
