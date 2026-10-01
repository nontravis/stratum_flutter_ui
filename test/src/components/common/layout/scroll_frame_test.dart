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
  for (ScrollPhysics? physics = state.position.physics;
      physics != null;
      physics = physics.parent) {
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
  return Theme(data: ThemeData(platform: TargetPlatform.macOS), child: child);
}

Widget _bouncingOutside(Widget child) {
  return ScrollConfiguration(behavior: const _BouncingBehavior(), child: child);
}

void main() {
  group('ScrollFrame', () {
    testWidgets('lets theme physics win over an outer ScrollConfiguration',
        (tester) async {
      await tester.pumpWidget(themedHost(_bouncingOutside(_framed())));

      final chain = _physicsChain(tester);
      expect(chain, contains(ClampingScrollPhysics));
      expect(chain, isNot(contains(BouncingScrollPhysics)));
    });

    testWidgets('uses the outer ScrollConfiguration without a theme',
        (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: _bouncingOutside(_framed())),
        ),
      );

      expect(_physicsChain(tester), contains(BouncingScrollPhysics));
    });

    testWidgets(
      'removes the scrollbar when showScrollbar is false',
      (tester) async {
        await tester.pumpWidget(
          themedHost(_macOSTheme(_framed(showScrollbar: false))),
        );

        expect(find.byType(Scrollbar), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'keeps the desktop scrollbar when showScrollbar is null',
      (tester) async {
        await tester.pumpWidget(themedHost(_macOSTheme(_framed())));

        expect(find.byType(Scrollbar), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
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
}
