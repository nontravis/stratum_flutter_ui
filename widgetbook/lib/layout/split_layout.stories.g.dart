// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'split_layout.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<SplitLayout, StoryArgs<SplitLayout>>;
typedef _Scenario = SplitLayoutScenario;
typedef _Defaults = SplitLayoutDefaults;
typedef _Story = SplitLayoutStory;
typedef _Args = SplitLayoutKnobsArgs;
final SplitLayoutComponent = Component<SplitLayout, StoryArgs<SplitLayout>>(
  name: componentMeta.name ?? 'SplitLayout',
  path: componentMeta.path ?? 'layout',
  docsBuilder: componentMeta.docsBuilder,
  docComment:
      r'''Lays out its [panes] side by side along [axis], with a divider the
EndUser drags between each two neighbors (US-21).

A null pane does not show, and the shown panes fill the split. Under
[TextDirection.rtl] a horizontal split mirrors, so the first pane sits
on the right. The divider takes no layout space, so neighbors stay
flush, and paints nothing unless [dividerBuilder] paints it. Whether or
not one paints, the divider's hit area spans the platform's minimum
target size ([TapTargetSize.minimumFor]) centered on the seam, shows a
resize cursor on hover, and takes a drag along the axis, while a tap, a
scroll, or a drag across the axis that starts there still reaches the
pane under it; the divider is a Tab stop after every Tab stop of the
pane before it, shows the FO-06 focus ring, steps 16 px by the arrow
keys along the axis by screen direction, 64 px with Shift held, and
goes to the start pane's minimum and maximum by Home and End; and it
reads as a slider valued by the start pane's share of the split, with
increase and decrease actions that step it. With [resizable] false no
divider takes a drag or focus or adds a slider node, while
[dividerBuilder] still paints.

The split needs a bounded extent along [axis]. It builds on
`MultiSplitView` of `multi_split_view` for its layout and its pane
limits, and draws its own translucent hit layer over the seams (layout
s03 INV-75).''',
  stories: [
    $Playground..$generatedName = 'Playground',
    $RecipeFormRow..$generatedName = 'RecipeFormRow',
    $RecipeCard..$generatedName = 'RecipeCard',
    $RecipeListItem..$generatedName = 'RecipeListItem',
    $RecipeToolbar..$generatedName = 'RecipeToolbar',
    $RecipePageWithDrawer..$generatedName = 'RecipePageWithDrawer',
    $Responsive..$generatedName = 'Responsive',
    $Accessibility..$generatedName = 'Accessibility',
    $ExampleListBesideDetail..$generatedName = 'ExampleListBesideDetail',
  ],
);
typedef SplitLayoutScenario = Scenario<SplitLayout, SplitLayoutKnobsArgs>;
typedef SplitLayoutDefaults = Defaults<SplitLayout, SplitLayoutKnobsArgs>;

class SplitLayoutStory extends Story<SplitLayout, SplitLayoutKnobsArgs> {
  SplitLayoutStory({
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

class SplitLayoutKnobsArgs extends StoryArgs<SplitLayout> {
  SplitLayoutKnobsArgs({
    Arg<int>? panes,
    Arg<Axis>? axis,
    Arg<bool>? resizable,
    required Arg<Preset<SplitLayoutController>> controller,
    required Arg<Preset<String>> dividerLabel,
    required Arg<Preset<Widget Function(BuildContext, SplitDividerState)>>
    dividerBuilder,
    required Arg<Preset<SplitLayoutStyle>> customStyle,
    required Arg<Preset<WidgetSettingKey>> setting,
  }) : this.panesArg = $initArg('panes', panes, IntArg(2))!,
       this.axisArg = $initArg(
         'axis',
         axis,
         EnumArg<Axis>(Axis.horizontal, values: Axis.values),
       )!,
       this.resizableArg = $initArg('resizable', resizable, BoolArg(true))!,
       this.controllerArg = $initArg('controller', controller, null)!,
       this.dividerLabelArg = $initArg('dividerLabel', dividerLabel, null)!,
       this.dividerBuilderArg = $initArg(
         'dividerBuilder',
         dividerBuilder,
         null,
       )!,
       this.customStyleArg = $initArg('customStyle', customStyle, null)!,
       this.settingArg = $initArg('setting', setting, null)!;

  SplitLayoutKnobsArgs.fixed({
    int panes = 2,
    Axis axis = Axis.horizontal,
    bool resizable = true,
    required Preset<SplitLayoutController> controller,
    required Preset<String> dividerLabel,
    required Preset<Widget Function(BuildContext, SplitDividerState)>
    dividerBuilder,
    required Preset<SplitLayoutStyle> customStyle,
    required Preset<WidgetSettingKey> setting,
  }) : this.panesArg = $initArg('panes', Arg.fixed(panes), null)!,
       this.axisArg = $initArg('axis', Arg.fixed(axis), null)!,
       this.resizableArg = $initArg('resizable', Arg.fixed(resizable), null)!,
       this.controllerArg = $initArg(
         'controller',
         Arg.fixed(controller),
         null,
       )!,
       this.dividerLabelArg = $initArg(
         'dividerLabel',
         Arg.fixed(dividerLabel),
         null,
       )!,
       this.dividerBuilderArg = $initArg(
         'dividerBuilder',
         Arg.fixed(dividerBuilder),
         null,
       )!,
       this.customStyleArg = $initArg(
         'customStyle',
         Arg.fixed(customStyle),
         null,
       )!,
       this.settingArg = $initArg('setting', Arg.fixed(setting), null)!;

  final Arg<int> panesArg;

  final Arg<Axis> axisArg;

  final Arg<bool> resizableArg;

  final Arg<Preset<SplitLayoutController>> controllerArg;

  final Arg<Preset<String>> dividerLabelArg;

  final Arg<Preset<Widget Function(BuildContext, SplitDividerState)>>
  dividerBuilderArg;

  final Arg<Preset<SplitLayoutStyle>> customStyleArg;

  final Arg<Preset<WidgetSettingKey>> settingArg;

  int get panes => panesArg.value;

  Axis get axis => axisArg.value;

  bool get resizable => resizableArg.value;

  Preset<SplitLayoutController> get controller => controllerArg.value;

  Preset<String> get dividerLabel => dividerLabelArg.value;

  Preset<Widget Function(BuildContext, SplitDividerState)> get dividerBuilder =>
      dividerBuilderArg.value;

  Preset<SplitLayoutStyle> get customStyle => customStyleArg.value;

  Preset<WidgetSettingKey> get setting => settingArg.value;

  @override
  List<Arg?> get list => [
    panesArg,
    axisArg,
    resizableArg,
    controllerArg,
    dividerLabelArg,
    dividerBuilderArg,
    customStyleArg,
    settingArg,
  ];
}
