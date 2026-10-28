import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../shell/catalog_section.dart';
import '../shell/window_size_addon.dart';

/// The story names every component page uses, in display order
/// (fo11/us03/fr02; s03 INV-4).
abstract final class StoryNames {
  static const playground = 'Playground';
  static const variants = 'Variants';
  static const responsive = 'Responsive';
  static const accessibility = 'Accessibility';

  /// The stories a `Layout` page shows in place of [variants].
  static const recipes = [
    'Recipe: form row',
    'Recipe: card',
    'Recipe: list item',
    'Recipe: toolbar',
    'Recipe: page with drawer',
  ];

  static const _examplePrefix = 'Example: ';

  /// The name of the story that shows [use].
  static String example(String use) => '$_examplePrefix$use';
}

/// The width every responsive frame scales to.
const double _responsiveFrameWidth = 320;

/// The state frames [accessibilityFrames] accepts, besides the three it
/// always shows (s03 INV-5).
const _stateFrameLabels = {'Loading', 'Error', 'Empty'};

/// One message per breach of the story-set order, empty when [component]
/// reads Playground, Variants (the five recipes on a `Layout` page),
/// Responsive, Accessibility, then one or more `Example: ` stories
/// (s03 INV-4).
List<String> storySetProblems(Component component) {
  final names = [for (final story in component.stories) story.name];
  final fixed = [
    StoryNames.playground,
    ..._isLayoutPage(component) ? StoryNames.recipes : [StoryNames.variants],
    StoryNames.responsive,
    StoryNames.accessibility,
  ];
  final problems = <String>[];
  for (var i = 0; i < fixed.length; i++) {
    final found = i < names.length ? '"${names[i]}"' : 'nothing';
    if (i >= names.length || names[i] != fixed[i]) {
      problems.add(
        '${component.fullPath}: story ${i + 1} must be '
        '"${fixed[i]}", found $found',
      );
    }
  }
  final examples = names.skip(fixed.length).toList();
  if (examples.isEmpty) {
    problems.add('${component.fullPath}: needs at least one "Example: " story');
  }
  for (final name in examples) {
    if (!name.startsWith(StoryNames.example(''))) {
      problems.add(
        '${component.fullPath}: "$name" after Accessibility must '
        'start with "Example: "',
      );
    }
  }
  return problems;
}

bool _isLayoutPage(Component component) =>
    component.path.split('/').first == CatalogSection.layout.label;

/// Five frames, one per [WindowSize], each [build] under that window size,
/// shown at [catalogWindowSizes] logical size and scaled to 320 wide.
Widget responsiveFrames(WidgetBuilder build) => ColumnLayout(
  scroll: const Scroll(),
  crossAxisAlignment: CrossAxisAlignment.start,
  gap: 16,
  children: [
    for (final size in WindowSize.values)
      _Frame(
        label: size.name,
        child: _ScaledWindow(size: catalogWindowSizes[size]!, builder: build),
      ),
  ],
);

/// The accessibility frames of a component page: `200% text`,
/// `Right to left`, `Disabled` when [disabled] is set, then one frame per
/// [states] key (`Loading`, `Error`, or `Empty`) (s03 INV-5).
///
/// Pass [disabled] only when the widget takes the shared `disabled` prop
/// (RL10).
Widget accessibilityFrames({
  required WidgetBuilder build,
  WidgetBuilder? disabled,
  Map<String, WidgetBuilder> states = const {},
}) {
  assert(
    states.keys.every(_stateFrameLabels.contains),
    'states keys must come from $_stateFrameLabels',
  );
  return ColumnLayout(
    scroll: const Scroll(),
    crossAxisAlignment: CrossAxisAlignment.start,
    gap: 16,
    children: [
      _Frame(
        label: '200% text',
        child: _Scaled(builder: build),
      ),
      _Frame(
        label: 'Right to left',
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(builder: build),
        ),
      ),
      if (disabled != null)
        _Frame(
          label: 'Disabled',
          child: Builder(builder: disabled),
        ),
      for (final MapEntry(:key, :value) in states.entries)
        _Frame(
          label: key,
          child: Builder(builder: value),
        ),
    ],
  );
}

/// A label above the content it names.
class _Frame extends StatelessWidget {
  const _Frame({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => ColumnLayout(
    crossAxisAlignment: CrossAxisAlignment.start,
    gap: 4,
    children: [Text(label), child],
  );
}

/// [build] under a text scale of 2.
class _Scaled extends StatelessWidget {
  const _Scaled({required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(2)),
    child: Builder(builder: builder),
  );
}

/// [build] in a window of [size] logical pixels, scaled to 320 wide.
class _ScaledWindow extends StatelessWidget {
  const _ScaledWindow({required this.size, required this.builder});

  final Size size;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => ContainerLayout(
    fit: BoxFit.contain,
    style: WidgetStyle(
      width: _responsiveFrameWidth,
      height: _responsiveFrameWidth * size.height / size.width,
      clipBehavior: Clip.hardEdge,
    ),
    child: SizedBox.fromSize(
      size: size,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(size: size),
        child: WindowSizeScope(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: Builder(builder: builder),
          ),
        ),
      ),
    ),
  );
}
