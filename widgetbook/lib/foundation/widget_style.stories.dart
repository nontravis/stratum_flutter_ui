import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/preset.dart';
import '../shell/catalog_section.dart';
import 'widget_style_knobs.dart';

part 'widget_style.stories.g.dart';

/// Key of the sample box the Playground draws.
const widgetStyleSampleKey = ValueKey('widget-style.sample');

const meta = Meta(ContainerLayout.new, argsType: WidgetStyleKnobs.new);

final componentMeta = ComponentMeta(
  name: 'WidgetStyle',
  path: CatalogSection.foundation.label,
);

/// A fresh set of knobs: one per `WidgetStyle` field, in field order.
WidgetStyleKnobsArgs _knobs() => WidgetStyleKnobsArgs(
  opacity: DoubleArg(
    1,
    name: 'opacity',
    style: const SliderDoubleArgStyle(min: 0, max: 1, divisions: 20),
  ),
  alignment: presetKnob('alignment', _alignments),
  backgroundGradient: presetKnob('backgroundGradient', _gradients),
  backgroundImage: presetKnob('backgroundImage', _images),
  foregroundGradient: presetKnob('foregroundGradient', _gradients),
  foregroundImage: presetKnob('foregroundImage', _images),
  innerShadow: presetKnob('innerShadow', _shadows),
  dropShadow: presetKnob('dropShadow', _shadows),
);

/// `None`, then the nine `Alignment` constants (`Alignment` is a class, so
/// `EnumArg` cannot take it).
final _alignments = <Preset<AlignmentGeometry>>[
  const Preset.none(),
  const Preset('topLeft', _topLeft),
  const Preset('topCenter', _topCenter),
  const Preset('topRight', _topRight),
  const Preset('centerLeft', _centerLeft),
  const Preset('center', _center),
  const Preset('centerRight', _centerRight),
  const Preset('bottomLeft', _bottomLeft),
  const Preset('bottomCenter', _bottomCenter),
  const Preset('bottomRight', _bottomRight),
];

AlignmentGeometry _topLeft(BuildContext context) => Alignment.topLeft;
AlignmentGeometry _topCenter(BuildContext context) => Alignment.topCenter;
AlignmentGeometry _topRight(BuildContext context) => Alignment.topRight;
AlignmentGeometry _centerLeft(BuildContext context) => Alignment.centerLeft;
AlignmentGeometry _center(BuildContext context) => Alignment.center;
AlignmentGeometry _centerRight(BuildContext context) => Alignment.centerRight;
AlignmentGeometry _bottomLeft(BuildContext context) => Alignment.bottomLeft;
AlignmentGeometry _bottomCenter(BuildContext context) => Alignment.bottomCenter;
AlignmentGeometry _bottomRight(BuildContext context) => Alignment.bottomRight;

/// `None`, then a two-stop gradient of two theme brand colors.
final _gradients = <Preset<Gradient>>[
  const Preset.none(),
  Preset(
    'brand.normal to brand.active',
    (context) => LinearGradient(
      colors: [
        context.theme.color.brand.normal,
        context.theme.color.brand.active,
      ],
    ),
  ),
];

/// `None`, then the sample image the catalog bundles.
final _images = <Preset<DecorationImage>>[
  const Preset.none(),
  Preset(
    'sample_image.png',
    (_) => const DecorationImage(
      image: AssetImage('assets/sample_image.png'),
      fit: BoxFit.cover,
    ),
  ),
];

/// `None`, then the theme's shadow tokens `shadow.1` to `shadow.6`.
final _shadows = <Preset<List<BoxShadow>>>[
  const Preset.none(),
  Preset('shadow.1', (context) => context.theme.shadow.level1),
  Preset('shadow.2', (context) => context.theme.shadow.level2),
  Preset('shadow.3', (context) => context.theme.shadow.level3),
  Preset('shadow.4', (context) => context.theme.shadow.level4),
  Preset('shadow.5', (context) => context.theme.shadow.level5),
  Preset('shadow.6', (context) => context.theme.shadow.level6),
];

/// The one story of the page, the one place with a knob per style field (s03
/// INV-10). A Foundation page is no component page, so it carries no story
/// set.
final $Playground = _Story(
  args: _knobs(),
  // The default setup rebuilds the sample on every knob change; keeping the
  // box lets its `animationStyle` play each change.
  setup: (context, child, args) => child,
  builder: (context, args) => ContainerLayout(
    key: widgetStyleSampleKey,
    style: WidgetStyleKnobs(
      opacity: args.opacity,
      padding: args.padding,
      margin: args.margin,
      width: args.width,
      height: args.height,
      minWidth: args.minWidth,
      maxWidth: args.maxWidth,
      minHeight: args.minHeight,
      maxHeight: args.maxHeight,
      alignment: args.alignment,
      border: args.border,
      borderRadius: args.borderRadius,
      backgroundColor: args.backgroundColor,
      backgroundGradient: args.backgroundGradient,
      backgroundImage: args.backgroundImage,
      backgroundBlur: args.backgroundBlur,
      foregroundColor: args.foregroundColor,
      foregroundGradient: args.foregroundGradient,
      foregroundImage: args.foregroundImage,
      foregroundBlur: args.foregroundBlur,
      clipBehavior: args.clipBehavior,
      innerShadow: args.innerShadow,
      dropShadow: args.dropShadow,
      animationStyle: args.animationStyle,
    ).toStyle(context),
    child: const StratumSlot(name: 'content'),
  ),
);
