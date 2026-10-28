import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/kit/story_set.dart';
import 'package:stratum_ui_widgetbook/shell/window_size_addon.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

/// Story args of [_Story].
class _StoryArgs extends StoryArgs<SizedBox> {
  const _StoryArgs();

  @override
  List<Arg?> get list => const [];
}

/// A stub story that only carries a name.
class _Story extends Story<SizedBox, _StoryArgs> {
  _Story({required super.name})
    : super(
        args: const _StoryArgs(),
        builder: (_, _) => const SizedBox.shrink(),
      );
}

Component _page(List<String> names, {String path = 'Display'}) => Component(
  name: 'Stub',
  path: path,
  stories: [for (final name in names) _Story(name: name)],
);

const _tail = [StoryNames.responsive, StoryNames.accessibility, 'Example: a'];

/// The label texts [accessibilityFrames] shows, in order.
Future<List<String>> _labels(WidgetTester tester, Widget frames) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: Size(800, 6000)),
      child: Directionality(textDirection: TextDirection.ltr, child: frames),
    ),
  );
  return [
    for (final text in tester.widgetList<Text>(find.byType(Text)))
      text.data ?? '',
  ];
}

void main() {
  test('fo11/us03/fr02: storySetProblems accepts the INV-4 order', () {
    final page = _page([
      StoryNames.playground,
      StoryNames.variants,
      ..._tail,
      StoryNames.example('b'),
    ]);

    expect(storySetProblems(page), isEmpty);
  });

  test('fo11/us03/fr02: storySetProblems reports a story out of order', () {
    final page = _page([StoryNames.variants, StoryNames.playground, ..._tail]);

    expect(storySetProblems(page), isNotEmpty);
  });

  test('fo11/us03/fr02: storySetProblems reports a missing story', () {
    final page = _page([StoryNames.playground, ..._tail]);

    expect(storySetProblems(page), isNotEmpty);
  });

  test('fo11/us03/fr02/e03: a page with no Example story fails', () {
    final page = _page([
      StoryNames.playground,
      StoryNames.variants,
      StoryNames.responsive,
      StoryNames.accessibility,
    ]);

    expect(storySetProblems(page), hasLength(1));
  });

  test('fo11/us03/fr02/e03: one Example story per use', () {
    final page = _page([
      StoryNames.playground,
      StoryNames.variants,
      StoryNames.responsive,
      StoryNames.accessibility,
      StoryNames.example('a'),
      StoryNames.example('b'),
    ]);

    expect(storySetProblems(page), isEmpty);
  });

  test('fo11/us03/fr02/e04: a Layout page carries Recipes in the Variants '
      'place', () {
    final recipes = _page([
      StoryNames.playground,
      ...StoryNames.recipes,
      ..._tail,
    ], path: 'Layout');
    final variants = _page([
      StoryNames.playground,
      StoryNames.variants,
      ..._tail,
    ], path: 'Layout');

    expect(storySetProblems(recipes), isEmpty);
    expect(storySetProblems(variants), isNotEmpty);
  });

  test('fo11/us03/fr02/e04: a page outside Layout fails with Recipes', () {
    final page = _page([
      StoryNames.playground,
      ...StoryNames.recipes,
      ..._tail,
    ]);

    expect(storySetProblems(page), isNotEmpty);
  });

  testWidgets('fo11/us03/fr02: responsiveFrames shows each window size', (
    tester,
  ) async {
    final reads = <WindowSize, Size>{};
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: responsiveFrames((context) {
            reads[WindowSizeScope.of(context)] = MediaQuery.sizeOf(context);
            return const SizedBox(width: 10, height: 10);
          }),
        ),
      ),
    );

    expect(reads, catalogWindowSizes);
    for (final size in WindowSize.values) {
      expect(find.text(size.name), findsOneWidget);
    }
  });

  testWidgets(
    'fo11/us03/fr02: responsiveFrames scales each frame to 320 wide',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(800, 600)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: responsiveFrames(
              (context) => const SizedBox(key: Key('probe'), width: 10),
            ),
          ),
        ),
      );

      // The watch frame is 240 wide, so it scales by 320 / 240; the corners
      // apply the frame's transform.
      final probe = find.byKey(const Key('probe')).first;
      final width = tester.getTopRight(probe).dx - tester.getTopLeft(probe).dx;
      expect(width, closeTo(10 * 320 / 240, 0.01));
    },
  );

  testWidgets(
    'fo11/us03/fr02/e01: a widget with no loading, error, or empty state '
    'shows three frames',
    (tester) async {
      final labels = await _labels(
        tester,
        accessibilityFrames(
          build: (_) => const SizedBox.shrink(),
          disabled: (_) => const SizedBox.shrink(),
        ),
      );

      expect(labels, ['200% text', 'Right to left', 'Disabled']);
    },
  );

  testWidgets(
    'fo11/us03/fr02/e02: a widget with no disabled prop shows no Disabled '
    'frame',
    (tester) async {
      final labels = await _labels(
        tester,
        accessibilityFrames(build: (_) => const SizedBox.shrink()),
      );

      expect(labels, ['200% text', 'Right to left']);
    },
  );

  testWidgets('fo11/us03/fr02: accessibilityFrames adds one frame per state', (
    tester,
  ) async {
    final labels = await _labels(
      tester,
      accessibilityFrames(
        build: (_) => const SizedBox.shrink(),
        states: {
          'Loading': (_) => const SizedBox.shrink(),
          'Empty': (_) => const SizedBox.shrink(),
        },
      ),
    );

    expect(labels, ['200% text', 'Right to left', 'Loading', 'Empty']);
  });

  testWidgets('fo11/us03/fr02: accessibilityFrames sets scale and direction', (
    tester,
  ) async {
    final reads = <String, (TextScaler, TextDirection)>{};
    WidgetBuilder probe(String key) => (context) {
      reads[key] = (
        MediaQuery.textScalerOf(context),
        Directionality.of(context),
      );
      return const SizedBox.shrink();
    };
    var calls = 0;
    await _labels(
      tester,
      accessibilityFrames(
        build: (context) {
          // Frames build in order: 200% text, then Right to left.
          probe(calls++ == 0 ? 'scaled' : 'rtl')(context);
          return const SizedBox.shrink();
        },
        disabled: probe('disabled'),
      ),
    );

    expect(reads['scaled']!.$1, const TextScaler.linear(2));
    expect(reads['scaled']!.$2, TextDirection.ltr);
    expect(reads['rtl']!.$1, TextScaler.noScaling);
    expect(reads['rtl']!.$2, TextDirection.rtl);
    expect(reads['disabled']!.$1, TextScaler.noScaling);
    expect(reads['disabled']!.$2, TextDirection.ltr);
  });
}
