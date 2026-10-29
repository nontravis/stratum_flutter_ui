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
  final path = component.fullPath;
  final problems = <String>[
    for (final name in fixed)
      if (!names.contains(name)) '$path: missing story "$name"',
  ];
  final present = names.where(fixed.contains).toList();
  if (!_sameList(present, fixed.where(names.contains).toList())) {
    problems.add('$path: stories must read ${fixed.join(', ')} in that order');
  }
  final lastFixed = names.lastIndexWhere(fixed.contains);
  var hasExample = false;
  for (var i = 0; i < names.length; i++) {
    if (fixed.contains(names[i])) continue;
    final isExample = names[i].startsWith(StoryNames.example(''));
    if (isExample) hasExample = true;
    if (i < lastFixed) {
      problems.add('$path: "${names[i]}" must come after Accessibility');
    } else if (!isExample) {
      problems.add(
        '$path: "${names[i]}" after Accessibility must start '
        'with "Example: "',
      );
    }
  }
  if (!hasExample) {
    problems.add('$path: needs at least one "Example: " story');
  }
  return problems;
}

bool _sameList(List<String> a, List<String> b) =>
    a.length == b.length &&
    Iterable.generate(a.length).every((i) => a[i] == b[i]);

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

/// The logical size every accessibility frame's stage shows its content at:
/// the catalog's mobile width, so a stage that sizes itself to its content
/// (an `Overlay.wrap` the Toast page builds) never reads the unbounded
/// height the frames column gives it and lays its entries out 0 px wide.
const Size _accessibilityStageSize = Size(390, 480);

/// The accessibility frames of a component page: `200% text`,
/// `Right to left`, `Disabled` when [disabled] is set, then one frame per
/// [states] key (`Loading`, `Error`, or `Empty`) (s03 INV-5).
///
/// Each frame's stage is bounded to [_accessibilityStageSize] and publishes
/// that size as its `MediaQuery.size`, so a frame's overlays size and place
/// their entries as they would in a window of that size.
///
/// Throws an [ArgumentError] for a [states] key outside that set.
///
/// Pass [disabled] only when the widget takes the shared `disabled` prop
/// (RL10).
Widget accessibilityFrames({
  required WidgetBuilder build,
  WidgetBuilder? disabled,
  Map<String, WidgetBuilder> states = const {},
}) {
  for (final key in states.keys) {
    if (!_stateFrameLabels.contains(key)) {
      throw ArgumentError.value(
        key,
        'states',
        'key must be one of $_stateFrameLabels',
      );
    }
  }
  return ColumnLayout(
    scroll: const Scroll(),
    crossAxisAlignment: CrossAxisAlignment.start,
    gap: 16,
    children: [
      _Frame(
        label: '200% text',
        child: _Stage(textScaler: const TextScaler.linear(2), builder: build),
      ),
      _Frame(
        label: 'Right to left',
        child: _Stage(textDirection: TextDirection.rtl, builder: build),
      ),
      if (disabled != null)
        _Frame(
          label: 'Disabled',
          child: _Stage(builder: disabled),
        ),
      for (final MapEntry(:key, :value) in states.entries)
        _Frame(
          label: key,
          child: _Stage(builder: value),
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

/// [builder] on the bounded [_accessibilityStageSize] stage, under the
/// frame's [textScaler] and [textDirection].
class _Stage extends StatelessWidget {
  const _Stage({this.textScaler, this.textDirection, required this.builder});

  final TextScaler? textScaler;
  final TextDirection? textDirection;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => ContainerLayout(
    fit: BoxFit.contain,
    style: WidgetStyle(
      width: _accessibilityStageSize.width,
      height: _accessibilityStageSize.height,
      clipBehavior: Clip.hardEdge,
    ),
    child: SizedBox.fromSize(
      size: _accessibilityStageSize,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: _accessibilityStageSize,
          textScaler: textScaler ?? MediaQuery.textScalerOf(context),
        ),
        child: WindowSizeScope(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: Directionality(
              textDirection: textDirection ?? TextDirection.ltr,
              child: Builder(builder: builder),
            ),
          ),
        ),
      ),
    ),
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
