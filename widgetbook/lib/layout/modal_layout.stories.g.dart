// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'modal_layout.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ModalLayout, StoryArgs<ModalLayout>>;
typedef _Scenario = ModalLayoutScenario;
typedef _Defaults = ModalLayoutDefaults;
typedef _Story = ModalLayoutStory;
typedef _Args = ModalLayoutKnobsArgs;
final ModalLayoutComponent = Component<ModalLayout, StoryArgs<ModalLayout>>(
  name: componentMeta.name ?? 'ModalLayout',
  path: componentMeta.path ?? 'layout',
  docsBuilder: componentMeta.docsBuilder,
  docComment: r'''The slot widget of a sheet or a modal (US-20 FR-01): an optional [top],
an optional [tab], and a required [body], in that order, on a surface
drawn from theme tokens.

A bottom sheet shows a drag handle above the slots, and [showClose]
shows a close button at the surface's top end corner. Place it inline
in a page, where it draws no scrim and no route, or show it through
`showModalLayout`, whose route state it reads where its own fields are
null. Inline with no [onClose], nothing closes: no close button shows
and the handle is decoration that screen readers and Tab skip (US-20
FR-01 E06). With a bounded height the [body] takes the height left under the
other slots and, unless [scrollBody] is false, scrolls inside it.

Each part's style layers the theme defaults, then the app-wide
[ModalLayoutStyle] the application registers for [ModalLayout], then
[borderRadius], then [customStyle] (FO-08 US-06 FR-01).

Tab visits [top], [tab], and [body], then the handle and the close
button, whatever their place on screen (NFR-U02).

The surface declares the solid color it paints wherever it covers a
system bar's point (US-20 FR-06 E08).''',
  stories: [
    $Playground..$generatedName = 'Playground',
    $RecipeFormRow..$generatedName = 'RecipeFormRow',
    $RecipeCard..$generatedName = 'RecipeCard',
    $RecipeListItem..$generatedName = 'RecipeListItem',
    $RecipeToolbar..$generatedName = 'RecipeToolbar',
    $RecipePageWithDrawer..$generatedName = 'RecipePageWithDrawer',
    $Responsive..$generatedName = 'Responsive',
    $Accessibility..$generatedName = 'Accessibility',
    $ExampleConfirmation..$generatedName = 'ExampleConfirmation',
  ],
);
typedef ModalLayoutScenario = Scenario<ModalLayout, ModalLayoutKnobsArgs>;
typedef ModalLayoutDefaults = Defaults<ModalLayout, ModalLayoutKnobsArgs>;

class ModalLayoutStory extends Story<ModalLayout, ModalLayoutKnobsArgs> {
  ModalLayoutStory({
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

class ModalLayoutKnobsArgs extends StoryArgs<ModalLayout> {
  ModalLayoutKnobsArgs({
    Arg<SlotPreset>? top,
    Arg<SlotPreset>? tab,
    Arg<SlotPreset>? body,
    Arg<ModalLayoutType?>? type,
    Arg<ModalLayoutSize>? size,
    Arg<bool>? showClose,
    Arg<bool>? onClose,
    required Arg<Preset<BorderRadiusGeometry>> borderRadius,
    Arg<bool?>? safeArea,
    Arg<bool?>? fullHeight,
    Arg<bool>? scrollBody,
    required Arg<Preset<ModalLayoutStyle>> customStyle,
  }) : this.topArg = $initArg(
         'top',
         top,
         EnumArg<SlotPreset>(SlotPreset.slot, values: SlotPreset.values),
       )!,
       this.tabArg = $initArg(
         'tab',
         tab,
         EnumArg<SlotPreset>(SlotPreset.slot, values: SlotPreset.values),
       )!,
       this.bodyArg = $initArg(
         'body',
         body,
         EnumArg<SlotPreset>(SlotPreset.slot, values: SlotPreset.values),
       )!,
       this.typeArg = $initArg(
         'type',
         type,
         NullableEnumArg<ModalLayoutType>(null, values: ModalLayoutType.values),
       )!,
       this.sizeArg = $initArg(
         'size',
         size,
         EnumArg<ModalLayoutSize>(
           ModalLayoutSize.medium,
           values: ModalLayoutSize.values,
         ),
       )!,
       this.showCloseArg = $initArg('showClose', showClose, BoolArg(true))!,
       this.onCloseArg = $initArg('onClose', onClose, BoolArg(true))!,
       this.borderRadiusArg = $initArg('borderRadius', borderRadius, null)!,
       this.safeAreaArg = $initArg(
         'safeArea',
         safeArea,
         NullableBoolArg(null),
       )!,
       this.fullHeightArg = $initArg(
         'fullHeight',
         fullHeight,
         NullableBoolArg(null),
       )!,
       this.scrollBodyArg = $initArg('scrollBody', scrollBody, BoolArg(true))!,
       this.customStyleArg = $initArg('customStyle', customStyle, null)!;

  ModalLayoutKnobsArgs.fixed({
    SlotPreset top = SlotPreset.slot,
    SlotPreset tab = SlotPreset.slot,
    SlotPreset body = SlotPreset.slot,
    ModalLayoutType? type = null,
    ModalLayoutSize size = ModalLayoutSize.medium,
    bool showClose = true,
    bool onClose = true,
    required Preset<BorderRadiusGeometry> borderRadius,
    bool? safeArea = null,
    bool? fullHeight = null,
    bool scrollBody = true,
    required Preset<ModalLayoutStyle> customStyle,
  }) : this.topArg = $initArg('top', Arg.fixed(top), null)!,
       this.tabArg = $initArg('tab', Arg.fixed(tab), null)!,
       this.bodyArg = $initArg('body', Arg.fixed(body), null)!,
       this.typeArg = $initArg(
         'type',
         type == null ? null : Arg.fixed(type),
         null,
       ),
       this.sizeArg = $initArg('size', Arg.fixed(size), null)!,
       this.showCloseArg = $initArg('showClose', Arg.fixed(showClose), null)!,
       this.onCloseArg = $initArg('onClose', Arg.fixed(onClose), null)!,
       this.borderRadiusArg = $initArg(
         'borderRadius',
         Arg.fixed(borderRadius),
         null,
       )!,
       this.safeAreaArg = $initArg(
         'safeArea',
         safeArea == null ? null : Arg.fixed(safeArea),
         null,
       ),
       this.fullHeightArg = $initArg(
         'fullHeight',
         fullHeight == null ? null : Arg.fixed(fullHeight),
         null,
       ),
       this.scrollBodyArg = $initArg(
         'scrollBody',
         Arg.fixed(scrollBody),
         null,
       )!,
       this.customStyleArg = $initArg(
         'customStyle',
         Arg.fixed(customStyle),
         null,
       )!;

  final Arg<SlotPreset> topArg;

  final Arg<SlotPreset> tabArg;

  final Arg<SlotPreset> bodyArg;

  final Arg<ModalLayoutType?>? typeArg;

  final Arg<ModalLayoutSize> sizeArg;

  final Arg<bool> showCloseArg;

  final Arg<bool> onCloseArg;

  final Arg<Preset<BorderRadiusGeometry>> borderRadiusArg;

  final Arg<bool?>? safeAreaArg;

  final Arg<bool?>? fullHeightArg;

  final Arg<bool> scrollBodyArg;

  final Arg<Preset<ModalLayoutStyle>> customStyleArg;

  SlotPreset get top => topArg.value;

  SlotPreset get tab => tabArg.value;

  SlotPreset get body => bodyArg.value;

  ModalLayoutType? get type => typeArg?.value;

  ModalLayoutSize get size => sizeArg.value;

  bool get showClose => showCloseArg.value;

  bool get onClose => onCloseArg.value;

  Preset<BorderRadiusGeometry> get borderRadius => borderRadiusArg.value;

  bool? get safeArea => safeAreaArg?.value;

  bool? get fullHeight => fullHeightArg?.value;

  bool get scrollBody => scrollBodyArg.value;

  Preset<ModalLayoutStyle> get customStyle => customStyleArg.value;

  @override
  List<Arg?> get list => [
    topArg,
    tabArg,
    bodyArg,
    typeArg,
    sizeArg,
    showCloseArg,
    onCloseArg,
    borderRadiusArg,
    safeAreaArg,
    fullHeightArg,
    scrollBodyArg,
    customStyleArg,
  ];
}
