import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/callback_report.dart';
import '../kit/preset.dart';
import '../kit/sample_text.dart';
import 'layout_slots.dart';

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
  const Preset('None', _noTransform),
  Preset('Scale 90%', (_) => Matrix4.diagonal3Values(0.9, 0.9, 1)),
  Preset('Skew', (_) => Matrix4.skewX(0.2)),
  Preset('Move 16 right', (_) => Matrix4.translationValues(16, 0, 0)),
];

Matrix4? _noTransform(BuildContext context) => null;

/// The `semantics` knob of a box layout.
final List<Preset<SemanticsProperties>> semanticsPresets = [
  const Preset('None', _noSemantics),
  Preset(
    'Labelled',
    (context) => SemanticsProperties(
      label: SampleTexts.label.resolve(Localizations.localeOf(context)),
    ),
  ),
];

SemanticsProperties? _noSemantics(BuildContext context) => null;

/// The `interaction` knob of a box layout: a tap reports `onTap called`.
final List<Preset<Interaction>> interactionPresets = [
  const Preset('None', _noInteraction),
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

Interaction? _noInteraction(BuildContext context) => null;

/// The `scroll` knob of a box layout.
final List<Preset<Scroll>> scrollPresets = [
  const Preset('None', _noScroll),
  const Preset('Vertical', _verticalScroll),
  const Preset('Horizontal', _horizontalScroll),
];

Scroll? _noScroll(BuildContext context) => null;
Scroll? _verticalScroll(BuildContext context) => const Scroll();
Scroll? _horizontalScroll(BuildContext context) =>
    const Scroll(direction: Axis.horizontal);

/// The `focusGroup` knob of a flex or wrap layout.
final List<Preset<FocusGroup>> focusGroupPresets = [
  const Preset('None', _noFocusGroup),
  const Preset('Group', _focusGroup),
  const Preset('Looping group', _loopingFocusGroup),
];

FocusGroup? _noFocusGroup(BuildContext context) => null;
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
PresetArg<WidgetStyle> styleKnob() => PresetArg(
  widgetStylePresets.first,
  name: 'style',
  values: widgetStylePresets,
);

/// The `transform` knob of a box layout.
PresetArg<Matrix4> transformKnob() => PresetArg(
  transformPresets.first,
  name: 'transform',
  values: transformPresets,
);

/// The `transformAlignment` knob of a box layout.
PresetArg<AlignmentGeometry> transformAlignmentKnob() {
  final values = alignmentPresets();
  return PresetArg(values.first, name: 'transformAlignment', values: values);
}

/// The `semantics` knob of a box layout.
PresetArg<SemanticsProperties> semanticsKnob() => PresetArg(
  semanticsPresets.first,
  name: 'semantics',
  values: semanticsPresets,
);

/// The `interaction` knob of a box layout.
PresetArg<Interaction> interactionKnob() => PresetArg(
  interactionPresets.first,
  name: 'interaction',
  values: interactionPresets,
);

/// The `scroll` knob of a box layout.
PresetArg<Scroll> scrollKnob() =>
    PresetArg(scrollPresets.first, name: 'scroll', values: scrollPresets);

/// The `focusGroup` knob of a flex or wrap layout.
PresetArg<FocusGroup> focusGroupKnob() => PresetArg(
  focusGroupPresets.first,
  name: 'focusGroup',
  values: focusGroupPresets,
);

/// The `alignment` knob of a stack or an indexed stack: the layout's own
/// default first.
PresetArg<AlignmentGeometry> stackAlignmentKnob() {
  final values = alignmentPresets(initial: AlignmentDirectional.topStart);
  return PresetArg(values.first, name: 'alignment', values: values);
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

/// The style preset of [widgetStylePresets] named [name], such as `Card`.
Preset<WidgetStyle> stylePreset(String name) =>
    widgetStylePresets.firstWhere((preset) => preset.name == name);

/// [baseline], or the alphabetic baseline when [alignment] aligns children
/// by baseline and none is set, since a flex asserts a baseline then.
TextBaseline? baselineFor(
  CrossAxisAlignment alignment,
  TextBaseline? baseline,
) =>
    baseline ??
    (alignment == CrossAxisAlignment.baseline ? TextBaseline.alphabetic : null);

/// A knob that picks one of [values], the first by default, named [name].
PresetArg<T> presetKnob<T>(String name, List<Preset<T>> values) =>
    PresetArg(values.first, name: name, values: values);

/// The `physics` knob of a scroll layout: the default null, then two named
/// choices.
final List<Preset<ScrollPhysics>> scrollPhysicsPresets = [
  const Preset('None', _noPhysics),
  const Preset('Bouncing', _bouncingPhysics),
  const Preset('Never scroll', _neverPhysics),
];

ScrollPhysics? _noPhysics(BuildContext context) => null;
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
  const Preset('None', _noFindChild),
  const Preset('By key', _findChildByKey),
];

ChildIndexGetter? _noFindChild(BuildContext context) => null;
ChildIndexGetter? _findChildByKey(BuildContext context) =>
    (key) => null; // a real app reads its own key-to-index map here

/// The `scrollCacheExtent` knob of a scroll layout.
final List<Preset<ScrollCacheExtent>> scrollCacheExtentPresets = [
  const Preset('None', _noCacheExtent),
  const Preset('200 px', _cache200),
  const Preset('2 viewports', _cacheTwoViewports),
];

ScrollCacheExtent? _noCacheExtent(BuildContext context) => null;
ScrollCacheExtent? _cache200(BuildContext context) =>
    const ScrollCacheExtent.pixels(200);
ScrollCacheExtent? _cacheTwoViewports(BuildContext context) =>
    const ScrollCacheExtent.viewport(2);

/// The `semanticsLabel` knob of a scroll layout.
final List<Preset<String>> scrollSemanticsLabelPresets = [
  const Preset('None', _noSemanticsLabel),
  Preset(
    'Title',
    (context) => SampleTexts.title.resolve(Localizations.localeOf(context)),
  ),
  Preset(
    'Message',
    (context) => SampleTexts.message.resolve(Localizations.localeOf(context)),
  ),
];

String? _noSemanticsLabel(BuildContext context) => null;

/// The `scrollFocusStyle` knob of a scroll layout.
final List<Preset<ScrollFocusStyle>> scrollFocusStylePresets = [
  const Preset('None', _noFocusStyle),
  Preset(
    'Gray 4 ring',
    (context) => ScrollFocusStyle(
      focus: StratumFocusBorderStyle(
        width: const WidgetStatePropertyAll(4),
        color: WidgetStatePropertyAll(context.theme.color.border.color.gray),
      ),
    ),
  ),
];

ScrollFocusStyle? _noFocusStyle(BuildContext context) => null;
