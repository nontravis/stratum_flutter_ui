// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'slot.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<StratumSlot, StoryArgs<StratumSlot>>;
typedef _Scenario = StratumSlotScenario;
typedef _Defaults = StratumSlotDefaults;
typedef _Story = StratumSlotStory;
typedef _Args = SlotKnobsArgs;
final StratumSlotComponent = Component<StratumSlot, StoryArgs<StratumSlot>>(
  name: componentMeta.name ?? 'StratumSlot',
  path: componentMeta.path ?? 'utility',
  docsBuilder: componentMeta.docsBuilder,
  docComment: null,
  stories: [
    $Playground..$generatedName = 'Playground',
    $Variants..$generatedName = 'Variants',
    $Responsive..$generatedName = 'Responsive',
    $Accessibility..$generatedName = 'Accessibility',
    $ExampleAvatarPlaceholder..$generatedName = 'ExampleAvatarPlaceholder',
  ],
);
typedef StratumSlotScenario = Scenario<StratumSlot, SlotKnobsArgs>;
typedef StratumSlotDefaults = Defaults<StratumSlot, SlotKnobsArgs>;

class StratumSlotStory extends Story<StratumSlot, SlotKnobsArgs> {
  StratumSlotStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    required super.args,
    required super.builder,
    super.scenarios,
    super.excludeFromTests,
  });
}

class SlotKnobsArgs extends StoryArgs<StratumSlot> {
  SlotKnobsArgs({
    Arg<double?>? height,
    Arg<double?>? width,
    required Arg<Preset<EdgeInsets>> padding,
    Arg<String>? name,
  }) : this.heightArg = $initArg('height', height, NullableDoubleArg(null))!,
       this.widthArg = $initArg('width', width, NullableDoubleArg(null))!,
       this.paddingArg = $initArg('padding', padding, null)!,
       this.nameArg = $initArg('name', name, StringArg('Slot'))!;

  SlotKnobsArgs.fixed({
    double? height = null,
    double? width = null,
    required Preset<EdgeInsets> padding,
    String name = 'Slot',
  }) : this.heightArg = $initArg(
         'height',
         height == null ? null : Arg.fixed(height),
         null,
       ),
       this.widthArg = $initArg(
         'width',
         width == null ? null : Arg.fixed(width),
         null,
       ),
       this.paddingArg = $initArg('padding', Arg.fixed(padding), null)!,
       this.nameArg = $initArg('name', Arg.fixed(name), null)!;

  final Arg<double?>? heightArg;

  final Arg<double?>? widthArg;

  final Arg<Preset<EdgeInsets>> paddingArg;

  final Arg<String> nameArg;

  double? get height => heightArg?.value;

  double? get width => widthArg?.value;

  Preset<EdgeInsets> get padding => paddingArg.value;

  String get name => nameArg.value;

  @override
  List<Arg?> get list => [heightArg, widthArg, paddingArg, nameArg];
}
