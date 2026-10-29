// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'web_zoom.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<StratumWebZoom, StoryArgs<StratumWebZoom>>;
typedef _Scenario = StratumWebZoomScenario;
typedef _Defaults = StratumWebZoomDefaults;
typedef _Story = StratumWebZoomStory;
typedef _Args = WebZoomKnobsArgs;
final StratumWebZoomComponent =
    Component<StratumWebZoom, StoryArgs<StratumWebZoom>>(
      name: componentMeta.name ?? 'StratumWebZoom',
      path: componentMeta.path ?? 'utility',
      docsBuilder: componentMeta.docsBuilder,
      docComment:
          r'''Lets the EndUser pinch to zoom a web app between [minScale] and
[maxScale], pan it, and see it clipped to this widget's bounds; on
Android, iOS, macOS, Windows, and Linux it builds [child] alone
(CO-01-04 US-01).

- In debug builds on every platform the constructor asserts that
  [minScale] is above 0 and [maxScale] is at least [minScale].
- New limits that leave the zoom outside them ease it to the nearest
  limit about the viewport's center, at once under reduced motion; the
  center stays fixed only as far as the app's bounds allow, as a pinch
  does (R16).
- It extends no component base, as [StratumSlot] does.''',
      stories: [
        $Playground..$generatedName = 'Playground',
        $Variants..$generatedName = 'Variants',
        $Responsive..$generatedName = 'Responsive',
        $Accessibility..$generatedName = 'Accessibility',
        $ExampleZoomableMap..$generatedName = 'ExampleZoomableMap',
      ],
    );
typedef StratumWebZoomScenario = Scenario<StratumWebZoom, WebZoomKnobsArgs>;
typedef StratumWebZoomDefaults = Defaults<StratumWebZoom, WebZoomKnobsArgs>;

class StratumWebZoomStory extends Story<StratumWebZoom, WebZoomKnobsArgs> {
  StratumWebZoomStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    WebZoomKnobsArgs? args,
    required super.builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(args: args ?? WebZoomKnobsArgs());
}

class WebZoomKnobsArgs extends StoryArgs<StratumWebZoom> {
  WebZoomKnobsArgs({
    Arg<double>? minScale,
    Arg<double>? maxScale,
    Arg<SlotPreset>? child,
  }) : this.minScaleArg = $initArg('minScale', minScale, DoubleArg(1.0))!,
       this.maxScaleArg = $initArg('maxScale', maxScale, DoubleArg(2.5))!,
       this.childArg = $initArg(
         'child',
         child,
         EnumArg<SlotPreset>(SlotPreset.slot, values: SlotPreset.values),
       )!;

  WebZoomKnobsArgs.fixed({
    double minScale = 1.0,
    double maxScale = 2.5,
    SlotPreset child = SlotPreset.slot,
  }) : this.minScaleArg = $initArg('minScale', Arg.fixed(minScale), null)!,
       this.maxScaleArg = $initArg('maxScale', Arg.fixed(maxScale), null)!,
       this.childArg = $initArg('child', Arg.fixed(child), null)!;

  final Arg<double> minScaleArg;

  final Arg<double> maxScaleArg;

  final Arg<SlotPreset> childArg;

  double get minScale => minScaleArg.value;

  double get maxScale => maxScaleArg.value;

  SlotPreset get child => childArg.value;

  @override
  List<Arg?> get list => [minScaleArg, maxScaleArg, childArg];
}
