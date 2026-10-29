import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/kit/story_set.dart';
import 'package:stratum_ui_widgetbook/shell/window_size_addon.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../support/catalog_theme.dart';

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

  test('fo11/us03/fr02: a misplaced Example gets one message, not a false '
      'missing-Example one', () {
    final page = _page([
      StoryNames.playground,
      StoryNames.variants,
      StoryNames.example('a'),
      StoryNames.responsive,
      StoryNames.accessibility,
    ]);

    expect(storySetProblems(page), [
      contains('"Example: a" must come after Accessibility'),
    ]);
  });

  test('fo11/us03/fr02: storySetProblems reports a story out of order', () {
    final page = _page([StoryNames.variants, StoryNames.playground, ..._tail]);

    expect(storySetProblems(page), isNotEmpty);
  });

  test('fo11/us03/fr02: storySetProblems reports a missing story', () {
    final page = _page([StoryNames.playground, ..._tail]);

    expect(storySetProblems(page), [contains('missing story "Variants"')]);
  });

  test('fo11/us03/fr02: a story after Accessibility must be an Example', () {
    final page = _page([
      StoryNames.playground,
      StoryNames.variants,
      ..._tail,
      'Extras',
    ]);

    expect(storySetProblems(page), [contains('"Extras" after Accessibility')]);
  });

  test('fo11/us03/fr02: a story between the fixed ones is reported', () {
    final page = _page([
      StoryNames.playground,
      'Extras',
      StoryNames.variants,
      ..._tail,
    ]);

    expect(storySetProblems(page), [contains('"Extras" must come after')]);
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
              (context) => SizedBox(
                key: Key('probe-${WindowSizeScope.of(context).name}'),
                width: 10,
              ),
            ),
          ),
        ),
      );

      // The corners apply the frame's transform: a probe 10 wide in a window
      // `w` wide shows 10 * 320 / w wide.
      for (final size in WindowSize.values) {
        final probe = find.byKey(Key('probe-${size.name}'));
        final width =
            tester.getTopRight(probe).dx - tester.getTopLeft(probe).dx;
        expect(
          width,
          closeTo(10 * 320 / catalogWindowSizes[size]!.width, 0.01),
          reason: size.name,
        );
        final frame = find
            .ancestor(of: probe, matching: find.byType(ContainerLayout))
            .first;
        expect(
          tester.getSize(frame).height,
          closeTo(
            320 *
                catalogWindowSizes[size]!.height /
                catalogWindowSizes[size]!.width,
            0.01,
          ),
          reason: '${size.name} frame height',
        );
      }

      final tops = [
        for (final size in WindowSize.values)
          tester.getTopLeft(find.text(size.name)).dy,
      ];
      expect(tops, [...tops]..sort(), reason: 'frames follow WindowSize order');
    },
  );

  testWidgets('fo11/us03/fr02: each responsive frame resolves the Material '
      'theme at its own window size', (tester) async {
    final themes = await loadDefaultThemeSet();
    final sizes = <WindowSize, double?>{};
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: MaterialApp(
          home: StratumThemeApplication(
            themes: themes,
            themeMode: ThemeMode.light,
            child: responsiveFrames((context) {
              sizes[WindowSizeScope.of(context)] = Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.fontSize;
              return const SizedBox(width: 10, height: 10);
            }),
          ),
        ),
      ),
    );

    for (final size in WindowSize.values) {
      expect(
        sizes[size],
        themes.light
            .toThemeData(
              locale: const Locale('en'),
              windowSize: size,
              textScaler: TextScaler.noScaling,
            )
            .textTheme
            .bodyMedium
            ?.fontSize,
        reason: size.name,
      );
    }
    expect(sizes[WindowSize.watch], isNot(sizes[WindowSize.bigDesktop]));
  });

  testWidgets('fo11/us03/fr02: every responsive frame has an Overlay of its '
      'own', (tester) async {
    final overlays = <OverlayState>[];
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: responsiveFrames((context) {
            overlays.add(Overlay.of(context));
            return const SizedBox(width: 10, height: 10);
          }),
        ),
      ),
    );

    expect(overlays, hasLength(WindowSize.values.length));
    expect(overlays.toSet(), hasLength(WindowSize.values.length));
  });

  testWidgets('fo11/us03/fr02: every accessibility frame has an Overlay of '
      'its own, under that frame\'s text scale and direction', (tester) async {
    final reads = <({OverlayState overlay, double scale, TextDirection dir})>[];
    Widget probe(BuildContext context) {
      reads.add((
        overlay: Overlay.of(context),
        scale: MediaQuery.textScalerOf(context).scale(10),
        dir: Directionality.of(context),
      ));
      return const SizedBox(width: 10, height: 10);
    }

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(800, 6000)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: accessibilityFrames(build: probe, disabled: probe),
        ),
      ),
    );

    expect(reads, hasLength(3));
    expect(reads.map((read) => read.overlay).toSet(), hasLength(3));
    expect(reads[0].scale, 20);
    expect(reads[1].dir, TextDirection.rtl);
  });

  testWidgets('fo11/us03/fr02: fixedBox gives a child that fills its parent a '
      'bounded size inside a scrolling frame list', (tester) async {
    BoxConstraints? seen;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ColumnLayout(
          scroll: const Scroll(),
          children: [
            fixedBox(
              width: 320,
              height: 240,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  seen = constraints;
                  return const SizedBox.expand();
                },
              ),
            ),
          ],
        ),
      ),
    );

    expect(seen, BoxConstraints.tight(const Size(320, 240)));
  });

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

  test('fo11/us03/fr02: accessibilityFrames rejects an unknown state key', () {
    expect(
      () => accessibilityFrames(
        build: (_) => const SizedBox.shrink(),
        states: {'Busy': (_) => const SizedBox.shrink()},
      ),
      throwsArgumentError,
    );
  });
}
