// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'placeholder_page.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<StratumPlaceholderPage, StoryArgs<StratumPlaceholderPage>>;
typedef _Scenario = StratumPlaceholderPageScenario;
typedef _Defaults = StratumPlaceholderPageDefaults;
typedef _Story = StratumPlaceholderPageStory;
typedef _Args = PlaceholderPageKnobsArgs;
final StratumPlaceholderPageComponent =
    Component<StratumPlaceholderPage, StoryArgs<StratumPlaceholderPage>>(
      name: componentMeta.name ?? 'StratumPlaceholderPage',
      path: componentMeta.path ?? 'feedback',
      docsBuilder: componentMeta.docsBuilder,
      docComment: r'''A page to place where a screen is not built yet (CO-05-08): a title,
and an icon and a message only when passed, centered in the space its
parent gives it, with no app bar and no back action of its own.

The title defaults to the built-in placeholder page title, in Thai for
a Thai locale and in English otherwise. The text wraps, and the page
scrolls when it is taller than its space. The page fixes [icon]'s slot
at [iconSize] whatever size the icon itself asks for; the theme's
secondary icon color is only a default an icon with its own color
overrides.''',
      stories: [
        $Playground..$generatedName = 'Playground',
        $Variants..$generatedName = 'Variants',
        $Responsive..$generatedName = 'Responsive',
        $Accessibility..$generatedName = 'Accessibility',
        $ExampleNotBuiltScreen..$generatedName = 'ExampleNotBuiltScreen',
      ],
    );
typedef StratumPlaceholderPageScenario =
    Scenario<StratumPlaceholderPage, PlaceholderPageKnobsArgs>;
typedef StratumPlaceholderPageDefaults =
    Defaults<StratumPlaceholderPage, PlaceholderPageKnobsArgs>;

class StratumPlaceholderPageStory
    extends Story<StratumPlaceholderPage, PlaceholderPageKnobsArgs> {
  StratumPlaceholderPageStory({
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

class PlaceholderPageKnobsArgs extends StoryArgs<StratumPlaceholderPage> {
  PlaceholderPageKnobsArgs({
    required Arg<Preset<String>> title,
    required Arg<Preset<String>> message,
    Arg<SlotPreset>? icon,
  }) : this.titleArg = $initArg('title', title, null)!,
       this.messageArg = $initArg('message', message, null)!,
       this.iconArg = $initArg(
         'icon',
         icon,
         EnumArg<SlotPreset>(SlotPreset.icon, values: SlotPreset.values),
       )!;

  PlaceholderPageKnobsArgs.fixed({
    required Preset<String> title,
    required Preset<String> message,
    SlotPreset icon = SlotPreset.icon,
  }) : this.titleArg = $initArg('title', Arg.fixed(title), null)!,
       this.messageArg = $initArg('message', Arg.fixed(message), null)!,
       this.iconArg = $initArg('icon', Arg.fixed(icon), null)!;

  final Arg<Preset<String>> titleArg;

  final Arg<Preset<String>> messageArg;

  final Arg<SlotPreset> iconArg;

  Preset<String> get title => titleArg.value;

  Preset<String> get message => messageArg.value;

  SlotPreset get icon => iconArg.value;

  @override
  List<Arg?> get list => [titleArg, messageArg, iconArg];
}
