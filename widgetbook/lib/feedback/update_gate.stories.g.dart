// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'update_gate.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<StratumUpdateGate, StoryArgs<StratumUpdateGate>>;
typedef _Scenario = StratumUpdateGateScenario;
typedef _Defaults = StratumUpdateGateDefaults;
typedef _Story = StratumUpdateGateStory;
typedef _Args = UpdateGateKnobsArgs;
final StratumUpdateGateComponent =
    Component<StratumUpdateGate, StoryArgs<StratumUpdateGate>>(
      name: componentMeta.name ?? 'StratumUpdateGate',
      path: componentMeta.path ?? 'feedback',
      docsBuilder: componentMeta.docsBuilder,
      docComment: r'''Puts the app's own update and maintenance screens in place of the app,
or the app's own update dialog over it, by the answers of the app's
[UpdateChecker] (CO-05-09).

Place it in `MaterialApp.builder`, below `StratumThemeApplication`,
around the navigator, so it covers every route. It draws nothing:
[builder] returns the app's screen or dialog for each
[UpdateGateState]. It shows [child] while the first answer is pending,
when the app is up to date, and after a failed check.''',
      stories: [
        $Playground..$generatedName = 'Playground',
        $Variants..$generatedName = 'Variants',
        $Responsive..$generatedName = 'Responsive',
        $Accessibility..$generatedName = 'Accessibility',
        $ExampleAvailableDialog..$generatedName = 'ExampleAvailableDialog',
      ],
    );
typedef StratumUpdateGateScenario =
    Scenario<StratumUpdateGate, UpdateGateKnobsArgs>;
typedef StratumUpdateGateDefaults =
    Defaults<StratumUpdateGate, UpdateGateKnobsArgs>;

class StratumUpdateGateStory
    extends Story<StratumUpdateGate, UpdateGateKnobsArgs> {
  StratumUpdateGateStory({
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

class UpdateGateKnobsArgs extends StoryArgs<StratumUpdateGate> {
  UpdateGateKnobsArgs({
    required Arg<Preset<UpdateChecker>> checker,
    required Arg<Preset<Widget Function(BuildContext, UpdateGateState)>>
    builder,
    Arg<SlotPreset>? child,
  }) : this.checkerArg = $initArg('checker', checker, null)!,
       this.builderArg = $initArg('builder', builder, null)!,
       this.childArg = $initArg(
         'child',
         child,
         EnumArg<SlotPreset>(SlotPreset.slot, values: SlotPreset.values),
       )!;

  UpdateGateKnobsArgs.fixed({
    required Preset<UpdateChecker> checker,
    required Preset<Widget Function(BuildContext, UpdateGateState)> builder,
    SlotPreset child = SlotPreset.slot,
  }) : this.checkerArg = $initArg('checker', Arg.fixed(checker), null)!,
       this.builderArg = $initArg('builder', Arg.fixed(builder), null)!,
       this.childArg = $initArg('child', Arg.fixed(child), null)!;

  final Arg<Preset<UpdateChecker>> checkerArg;

  final Arg<Preset<Widget Function(BuildContext, UpdateGateState)>> builderArg;

  final Arg<SlotPreset> childArg;

  Preset<UpdateChecker> get checker => checkerArg.value;

  Preset<Widget Function(BuildContext, UpdateGateState)> get builder =>
      builderArg.value;

  SlotPreset get child => childArg.value;

  @override
  List<Arg?> get list => [checkerArg, builderArg, childArg];
}
