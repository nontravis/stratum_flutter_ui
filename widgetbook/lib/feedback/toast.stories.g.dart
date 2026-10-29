// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'toast.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<StratumToastHost, StoryArgs<StratumToastHost>>;
typedef _Scenario = StratumToastHostScenario;
typedef _Defaults = StratumToastHostDefaults;
typedef _Story = StratumToastHostStory;
typedef _Args = ToastKnobsArgs;
final StratumToastHostComponent =
    Component<StratumToastHost, StoryArgs<StratumToastHost>>(
      name: componentMeta.name ?? 'StratumToastHost',
      path: componentMeta.path ?? 'feedback',
      docsBuilder: componentMeta.docsBuilder,
      docComment: r'''Places one notice host above the app's navigator, in
`MaterialApp.builder`, and shows every notice of every
`context.showToast` call under it (US-01 FR-01).

One solid notice shows at a time, each further one queued in call
order; float notices stack up to 3 per corner, a fourth closing that
corner's oldest (US-01 FR-03). A solid notice spans the full screen
width, its fill under the status bar or home indicator and its content
padded by that inset (US-01 FR-02).

Mount ONE root host per process: `toastification` keeps one wrapper
`GlobalKey` and one manager per alignment for the whole process, so a
second root host, in another view or window, draws its notices into
the first one's navigator; a debug build throws on it. A host nested
under another reuses the outer one's wrapper. An app that already
wraps its root in a `ToastificationWrapper` keeps it, and the host adds
none.''',
      stories: [
        $Playground..$generatedName = 'Playground',
        $Variants..$generatedName = 'Variants',
        $Responsive..$generatedName = 'Responsive',
        $Accessibility..$generatedName = 'Accessibility',
        $ExampleErrorWithAction..$generatedName = 'ExampleErrorWithAction',
      ],
    );
typedef StratumToastHostScenario = Scenario<StratumToastHost, ToastKnobsArgs>;
typedef StratumToastHostDefaults = Defaults<StratumToastHost, ToastKnobsArgs>;

class StratumToastHostStory extends Story<StratumToastHost, ToastKnobsArgs> {
  StratumToastHostStory({
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

class ToastKnobsArgs extends StoryArgs<StratumToastHost> {
  ToastKnobsArgs({
    Arg<SlotPreset>? child,
    required Arg<Preset<Widget Function(BuildContext, StratumToastNotice)>>
    builder,
    required Arg<Preset<String>> closeButtonLabel,
    required Arg<Preset<Map<FeedbackState, String>>> kindLabels,
    required Arg<Preset<List<SingleActivator>>> focusShortcuts,
    required Arg<Preset<String>> focusShortcutHint,
    required Arg<RequiredPreset<String>> message,
    required Arg<Preset<StratumToastAction>> action,
    Arg<FeedbackState>? kind,
    required Arg<Preset<StratumToastPlacement>> placement,
    required Arg<Preset<WidgetStyle>> customStyle,
  }) : this.childArg = $initArg(
         'child',
         child,
         EnumArg<SlotPreset>(SlotPreset.slot, values: SlotPreset.values),
       )!,
       this.builderArg = $initArg('builder', builder, null)!,
       this.closeButtonLabelArg = $initArg(
         'closeButtonLabel',
         closeButtonLabel,
         null,
       )!,
       this.kindLabelsArg = $initArg('kindLabels', kindLabels, null)!,
       this.focusShortcutsArg = $initArg(
         'focusShortcuts',
         focusShortcuts,
         null,
       )!,
       this.focusShortcutHintArg = $initArg(
         'focusShortcutHint',
         focusShortcutHint,
         null,
       )!,
       this.messageArg = $initArg('message', message, null)!,
       this.actionArg = $initArg('action', action, null)!,
       this.kindArg = $initArg(
         'kind',
         kind,
         EnumArg<FeedbackState>(
           FeedbackState.info,
           values: FeedbackState.values,
         ),
       )!,
       this.placementArg = $initArg('placement', placement, null)!,
       this.customStyleArg = $initArg('customStyle', customStyle, null)!;

  ToastKnobsArgs.fixed({
    SlotPreset child = SlotPreset.slot,
    required Preset<Widget Function(BuildContext, StratumToastNotice)> builder,
    required Preset<String> closeButtonLabel,
    required Preset<Map<FeedbackState, String>> kindLabels,
    required Preset<List<SingleActivator>> focusShortcuts,
    required Preset<String> focusShortcutHint,
    required RequiredPreset<String> message,
    required Preset<StratumToastAction> action,
    FeedbackState kind = FeedbackState.info,
    required Preset<StratumToastPlacement> placement,
    required Preset<WidgetStyle> customStyle,
  }) : this.childArg = $initArg('child', Arg.fixed(child), null)!,
       this.builderArg = $initArg('builder', Arg.fixed(builder), null)!,
       this.closeButtonLabelArg = $initArg(
         'closeButtonLabel',
         Arg.fixed(closeButtonLabel),
         null,
       )!,
       this.kindLabelsArg = $initArg(
         'kindLabels',
         Arg.fixed(kindLabels),
         null,
       )!,
       this.focusShortcutsArg = $initArg(
         'focusShortcuts',
         Arg.fixed(focusShortcuts),
         null,
       )!,
       this.focusShortcutHintArg = $initArg(
         'focusShortcutHint',
         Arg.fixed(focusShortcutHint),
         null,
       )!,
       this.messageArg = $initArg('message', Arg.fixed(message), null)!,
       this.actionArg = $initArg('action', Arg.fixed(action), null)!,
       this.kindArg = $initArg('kind', Arg.fixed(kind), null)!,
       this.placementArg = $initArg('placement', Arg.fixed(placement), null)!,
       this.customStyleArg = $initArg(
         'customStyle',
         Arg.fixed(customStyle),
         null,
       )!;

  final Arg<SlotPreset> childArg;

  final Arg<Preset<Widget Function(BuildContext, StratumToastNotice)>>
  builderArg;

  final Arg<Preset<String>> closeButtonLabelArg;

  final Arg<Preset<Map<FeedbackState, String>>> kindLabelsArg;

  final Arg<Preset<List<SingleActivator>>> focusShortcutsArg;

  final Arg<Preset<String>> focusShortcutHintArg;

  final Arg<RequiredPreset<String>> messageArg;

  final Arg<Preset<StratumToastAction>> actionArg;

  final Arg<FeedbackState> kindArg;

  final Arg<Preset<StratumToastPlacement>> placementArg;

  final Arg<Preset<WidgetStyle>> customStyleArg;

  SlotPreset get child => childArg.value;

  Preset<Widget Function(BuildContext, StratumToastNotice)> get builder =>
      builderArg.value;

  Preset<String> get closeButtonLabel => closeButtonLabelArg.value;

  Preset<Map<FeedbackState, String>> get kindLabels => kindLabelsArg.value;

  Preset<List<SingleActivator>> get focusShortcuts => focusShortcutsArg.value;

  Preset<String> get focusShortcutHint => focusShortcutHintArg.value;

  RequiredPreset<String> get message => messageArg.value;

  Preset<StratumToastAction> get action => actionArg.value;

  FeedbackState get kind => kindArg.value;

  Preset<StratumToastPlacement> get placement => placementArg.value;

  Preset<WidgetStyle> get customStyle => customStyleArg.value;

  @override
  List<Arg?> get list => [
    childArg,
    builderArg,
    closeButtonLabelArg,
    kindLabelsArg,
    focusShortcutsArg,
    focusShortcutHintArg,
    messageArg,
    actionArg,
    kindArg,
    placementArg,
    customStyleArg,
  ];
}
