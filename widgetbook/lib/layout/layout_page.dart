import 'dart:async';

import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/callback_report.dart';
import '../kit/preset.dart';
import '../kit/sample_text.dart';
import '../kit/style_presets.dart';

/// The `Do` every layout page adds for its recipes: the drawer of
/// `Recipe: page with drawer` hides below the tablet window size.
const recipeWindowDo =
    'Pick the tablet window size or wider in the toolbar to see the drawer '
    'slot of "Recipe: page with drawer".';

/// [recipe] on a bounded width, since the Card recipe stretches its children
/// and needs a width to stretch to.
Widget recipeFrame(Widget recipe) => Align(
  alignment: AlignmentDirectional.topStart,
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 720),
    child: recipe,
  ),
);

/// The nine places a [Preset] of an alignment offers, by their direction
/// aware names.
const _alignments = <String, AlignmentGeometry>{
  'topStart': AlignmentDirectional.topStart,
  'topCenter': AlignmentDirectional.topCenter,
  'topEnd': AlignmentDirectional.topEnd,
  'centerStart': AlignmentDirectional.centerStart,
  'center': AlignmentDirectional.center,
  'centerEnd': AlignmentDirectional.centerEnd,
  'bottomStart': AlignmentDirectional.bottomStart,
  'bottomCenter': AlignmentDirectional.bottomCenter,
  'bottomEnd': AlignmentDirectional.bottomEnd,
};

/// An alignment knob: [initial] first (named `None` when null, else
/// `Default`), then the nine places.
List<Preset<AlignmentGeometry>> alignmentPresets({
  AlignmentGeometry? initial,
}) => [
  Preset(initial == null ? 'None' : 'Default', (_) => initial),
  for (final MapEntry(:key, :value) in _alignments.entries)
    Preset(key, (_) => value),
];

/// The `transform` knob of a box layout.
final List<Preset<Matrix4>> transformPresets = [
  const Preset.none(),
  Preset('Scale 90%', (_) => Matrix4.diagonal3Values(0.9, 0.9, 1)),
  Preset('Skew', (_) => Matrix4.skewX(0.2)),
  Preset('Move 16 right', (_) => Matrix4.translationValues(16, 0, 0)),
];

/// The `semantics` knob of a box layout.
final List<Preset<SemanticsProperties>> semanticsPresets = [
  const Preset.none(),
  Preset(
    'Labelled',
    (context) => SemanticsProperties(label: SampleTexts.label.of(context)),
  ),
];

/// The `interaction` knob of a box layout: a tap reports `onTap called`.
final List<Preset<Interaction>> interactionPresets = [
  const Preset.none(),
  Preset(
    'Tappable',
    (context) => Interaction(onTap: reportCallback(context, 'onTap')),
  ),
  Preset(
    'Disabled',
    (context) =>
        Interaction(onTap: reportCallback(context, 'onTap'), disabled: true),
  ),
];

/// The `scroll` knob of a box layout.
final List<Preset<Scroll>> scrollPresets = [
  const Preset.none(),
  const Preset('Vertical', _verticalScroll),
  const Preset('Horizontal', _horizontalScroll),
];

Scroll? _verticalScroll(BuildContext context) => const Scroll();
Scroll? _horizontalScroll(BuildContext context) =>
    const Scroll(direction: Axis.horizontal);

/// The `focusGroup` knob of a flex or wrap layout.
final List<Preset<FocusGroup>> focusGroupPresets = [
  const Preset.none(),
  const Preset('Group', _focusGroup),
  const Preset('Looping group', _loopingFocusGroup),
];

FocusGroup? _focusGroup(BuildContext context) => const FocusGroup();
FocusGroup? _loopingFocusGroup(BuildContext context) =>
    const FocusGroup(loop: true);

/// The `onEndAnimate` knob's callback: reports `onEndAnimate called` when
/// [enabled], else null.
VoidCallback? endAnimateCallback(
  BuildContext context, {
  required bool enabled,
}) => enabled ? reportCallback(context, 'onEndAnimate') : null;

/// The `style` knob of a box layout.
PresetArg<WidgetStyle> styleKnob() => presetKnob('style', widgetStylePresets);

/// The `transform` knob of a box layout.
PresetArg<Matrix4> transformKnob() => presetKnob('transform', transformPresets);

/// The `transformAlignment` knob of a box layout.
PresetArg<AlignmentGeometry> transformAlignmentKnob() {
  final values = alignmentPresets();
  return presetKnob('transformAlignment', values);
}

/// The `semantics` knob of a box layout.
PresetArg<SemanticsProperties> semanticsKnob() =>
    presetKnob('semantics', semanticsPresets);

/// The `interaction` knob of a box layout.
PresetArg<Interaction> interactionKnob() =>
    presetKnob('interaction', interactionPresets);

/// The `scroll` knob of a box layout.
PresetArg<Scroll> scrollKnob() => presetKnob('scroll', scrollPresets);

/// The `focusGroup` knob of a flex or wrap layout.
PresetArg<FocusGroup> focusGroupKnob() =>
    presetKnob('focusGroup', focusGroupPresets);

/// The `alignment` knob of a stack or an indexed stack: the layout's own
/// default first.
PresetArg<AlignmentGeometry> stackAlignmentKnob() {
  final values = alignmentPresets(initial: AlignmentDirectional.topStart);
  return presetKnob('alignment', values);
}

/// A count knob from [min] to [max] named [name], the number of slot
/// placeholders a layout page arranges (`children`, or `panes` of a split).
IntArg slotCountKnob(
  String name, {
  required int initial,
  int min = 1,
  int max = 8,
}) => IntArg(
  initial,
  name: name,
  style: SliderIntArgStyle(min: min, max: max, divisions: max - min),
);

/// [baseline], or the alphabetic baseline when [alignment] aligns children
/// by baseline and none is set, since a flex asserts a baseline then.
TextBaseline? baselineFor(
  CrossAxisAlignment alignment,
  TextBaseline? baseline,
) =>
    baseline ??
    (alignment == CrossAxisAlignment.baseline ? TextBaseline.alphabetic : null);

/// The `physics` knob of a scroll layout: the default null, then two named
/// choices.
final List<Preset<ScrollPhysics>> scrollPhysicsPresets = [
  const Preset.none(),
  const Preset('Bouncing', _bouncingPhysics),
  const Preset('Never scroll', _neverPhysics),
];

ScrollPhysics? _bouncingPhysics(BuildContext context) =>
    const BouncingScrollPhysics();
ScrollPhysics? _neverPhysics(BuildContext context) =>
    const NeverScrollableScrollPhysics();

/// The `itemBuilder` knob of a scroll layout: the default slot builder that
/// names each item by its index, then one that counts from zero
/// (fo11/us06/fr01).
final List<Preset<Widget? Function(BuildContext, int)>> slotItemBuilders = [
  Preset(
    'Slot builder',
    (_) =>
        (context, index) => StratumSlot(name: 'item ${index + 1}'),
  ),
  Preset(
    'Slot builder from 0',
    (_) =>
        (context, index) => StratumSlot(name: 'item $index'),
  ),
];

/// The `findChildIndexCallback` knob of a scroll layout: null, then one that
/// reads a key-to-index map the data keeps in sync.
final List<Preset<ChildIndexGetter>> findChildIndexPresets = [
  const Preset.none(),
  const Preset('By key', _findChildByKey),
];

ChildIndexGetter? _findChildByKey(BuildContext context) =>
    (key) => null; // a real app reads its own key-to-index map here

/// The `scrollCacheExtent` knob of a scroll layout.
final List<Preset<ScrollCacheExtent>> scrollCacheExtentPresets = [
  const Preset.none(),
  const Preset('200 px', _cache200),
  const Preset('2 viewports', _cacheTwoViewports),
];

ScrollCacheExtent? _cache200(BuildContext context) =>
    const ScrollCacheExtent.pixels(200);
ScrollCacheExtent? _cacheTwoViewports(BuildContext context) =>
    const ScrollCacheExtent.viewport(2);

/// The `semanticsLabel` knob of a scroll layout.
final List<Preset<String>> scrollSemanticsLabelPresets = [
  const Preset.none(),
  Preset('Title', (context) => SampleTexts.title.of(context)),
  Preset('Message', (context) => SampleTexts.message.of(context)),
];

/// The `scrollFocusStyle` knob of a scroll layout.
final List<Preset<ScrollFocusStyle>> scrollFocusStylePresets = [
  const Preset.none(),
  Preset(
    'Gray ring',
    (context) => ScrollFocusStyle(
      focus: StratumFocusBorderStyle(
        width: WidgetStatePropertyAll(context.theme.focus.outsideWidth),
        color: WidgetStatePropertyAll(context.theme.color.border.color.gray),
      ),
    ),
  ),
];

/// The scroll-view knob pairs that Flutter and the layouts assert on, each
/// resolved once for every page (fo11/us04/fr01; us06/fr01).
///
/// A Playground never builds an asserting pair: `primary` drops beside an
/// explicit controller, the item-extent knobs keep one by priority
/// (`itemExtent`, then `itemExtentBuilder`, then `prototypeItem`),
/// `semanticChildCount` clamps to `itemCount`, `gap` drops beside any
/// item-extent knob or `semanticChildCount`, and a padded style drops beside
/// slivers.
abstract final class ScrollKnobGuards {
  /// [primary] while no explicit [controller] is picked, else null: the
  /// `ScrollView` constructor asserts on both.
  static bool? primary({required bool? primary, required Object? controller}) =>
      controller != null ? null : primary;

  /// [prototypeItem] while neither [itemExtent] nor [itemExtentBuilder] is
  /// set, else null: the item builders take only one of the three, and the
  /// prototype holds the lowest priority.
  static T? prototypeItem<T>({
    required T? prototypeItem,
    required double? itemExtent,
    required Object? itemExtentBuilder,
  }) => itemExtent == null && itemExtentBuilder == null ? prototypeItem : null;

  /// [count] clamped to [itemCount], so the semantic count never exceeds the
  /// items the builder builds.
  static int? semanticChildCount({
    required int? count,
    required int itemCount,
  }) {
    if (count == null) return null;
    return count < itemCount ? count : itemCount;
  }

  /// [gap] while no [itemExtent], [prototypeItem], or [semanticChildCount]
  /// is set, else null: `ListViewLayout` asserts on each beside a gap.
  static double? gap({
    required double? gap,
    required double? itemExtent,
    required Object? prototypeItem,
    required int? semanticChildCount,
  }) =>
      itemExtent == null && prototypeItem == null && semanticChildCount == null
      ? gap
      : null;

  /// [style] while it carries no padding or no [slivers] are set, else null:
  /// `CustomScrollViewLayout` asserts on `style.padding` beside slivers.
  static WidgetStyle? style({
    required WidgetStyle? style,
    required List<Widget>? slivers,
  }) => slivers != null && style?.padding != null ? null : style;
}

/// Holds what a layout Playground builds once per story: the controllers its
/// presets hand out, and, with [withSettings], the settings controller of the
/// `StratumWidgetSettings` above the page. Disposes all of them with the
/// story.
///
/// Sits in the Playground's `setup`, outside Widgetbook's `KeyedSubtree`, so
/// a knob change rebuilds the page below and keeps every held controller (a
/// split keeps the position the EndUser dragged it to); a preset that built
/// a new controller on each build would leave the old one undisposed.
class LayoutStoryScope extends StatefulWidget {
  const LayoutStoryScope({
    super.key,
    this.withSettings = false,
    required this.child,
  });

  /// Whether to place a `StratumWidgetSettings` with an in-memory store above
  /// [child], for a preset that binds a setting key.
  final bool withSettings;

  final Widget child;

  /// The [T] the nearest scope above [context] holds, made by [create] on the
  /// first ask. A scope holds one controller of each type, since a page
  /// offers one kind.
  static T held<T extends ChangeNotifier>(
    BuildContext context,
    T Function() create,
  ) => _of(context)._hold(create);

  /// Whether [value] differs from the last one asked for [key] in the
  /// nearest scope above [context], and remembers it: a page refits a held
  /// controller only when the knob it fits to changed.
  static bool changed(BuildContext context, Object key, Object? value) =>
      _of(context)._changed(key, value);

  static _LayoutStoryScopeState _of(BuildContext context) {
    final state = context.findAncestorStateOfType<_LayoutStoryScopeState>();
    if (state == null) {
      throw StateError('The story controllers need the Playground setup');
    }
    return state;
  }

  @override
  State<LayoutStoryScope> createState() => _LayoutStoryScopeState();
}

class _LayoutStoryScopeState extends State<LayoutStoryScope> {
  final _held = <Type, ChangeNotifier>{};
  final _seen = <Object, Object?>{};
  StratumWidgetSettingsController? _settings;
  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.withSettings) {
      _settings = StratumWidgetSettingsController(
        store: StratumMemorySettingStore(),
      );
      unawaited(_loadSettings());
    }
  }

  /// Reads the in-memory store once; a page that binds a setting asserts the
  /// controller is loaded, so the story builds only after this ends.
  Future<void> _loadSettings() async {
    await _settings!.load();
    if (mounted) setState(() => _settingsLoaded = true);
  }

  T _hold<T extends ChangeNotifier>(T Function() create) =>
      (_held[T] ??= create()) as T;

  bool _changed(Object key, Object? value) {
    if (_seen.containsKey(key) && _seen[key] == value) return false;
    _seen[key] = value;
    return true;
  }

  @override
  void dispose() {
    for (final controller in _held.values) {
      controller.dispose();
    }
    _settings?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (settings == null) return widget.child;
    return _settingsLoaded
        ? StratumWidgetSettings(controller: settings, child: widget.child)
        : const SizedBox.shrink();
  }
}

/// The `controller` knob of the scroll layouts that take a
/// `ScrollController`: the default null, then one held by the story that
/// starts the view at the second item.
final List<Preset<ScrollController>> scrollControllerPresets = [
  const Preset.none(),
  Preset(
    'Start at item 2',
    (context) => LayoutStoryScope.held(
      context,
      () => ScrollController(initialScrollOffset: 80),
    ),
  ),
];

/// The setting keys a layout page offers; a keyed one needs the
/// `StratumWidgetSettings` a [LayoutStoryScope] with `withSettings` places
/// above the page.
final List<Preset<WidgetSettingKey>> widgetSettingPresets = [
  const Preset.none(),
  Preset('Global', (_) => const WidgetSettingKey.global()),
  Preset('Catalog id', (_) => const WidgetSettingKey.id('catalog')),
];
