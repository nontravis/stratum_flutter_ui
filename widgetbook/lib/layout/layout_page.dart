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
