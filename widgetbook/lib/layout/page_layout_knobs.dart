import 'package:stratum_ui/stratum_ui.dart';

import '../kit/preset.dart';
import '../kit/slot_preset.dart';

/// One field per `PageLayout` constructor param, the `argsType` of its
/// stories (fo11/us04/fr01); each slot param is a [SlotPreset].
class PageLayoutKnobs {
  const PageLayoutKnobs({
    this.header = SlotPreset.slot,
    this.left = SlotPreset.slot,
    this.top = SlotPreset.slot,
    this.tab = SlotPreset.slot,
    this.body = SlotPreset.slot,
    this.bottom = SlotPreset.slot,
    this.right = SlotPreset.slot,
    this.footer = SlotPreset.slot,
    this.snack = SlotPreset.slot,
    required this.safeArea,
    this.resizeToAvoidKeyboard = true,
    this.loading = false,
    required this.loadingBuilder,
    required this.controller,
    required this.leftSide,
    required this.rightSide,
    this.drawerCut = WindowSize.tablet,
    this.rightAsOverlay = false,
    this.minCenterWidth = 320,
    required this.leftDividerBuilder,
    required this.rightDividerBuilder,
    this.edgeSwipe = true,
    this.onDrawerChanged = true,
    required this.customStyle,
    required this.systemStyle,
    required this.setting,
  });

  final SlotPreset header;
  final SlotPreset left;
  final SlotPreset top;
  final SlotPreset tab;
  final SlotPreset body;
  final SlotPreset bottom;
  final SlotPreset right;
  final SlotPreset footer;
  final SlotPreset snack;
  final Preset<PageSafeArea> safeArea;
  final bool resizeToAvoidKeyboard;
  final bool loading;
  final Preset<WidgetBuilder> loadingBuilder;
  final Preset<PageLayoutController> controller;
  final Preset<PageSide> leftSide;
  final Preset<PageSide> rightSide;
  final WindowSize drawerCut;
  final bool rightAsOverlay;
  final double minCenterWidth;
  final Preset<SplitDividerBuilder> leftDividerBuilder;
  final Preset<SplitDividerBuilder> rightDividerBuilder;
  final bool edgeSwipe;

  /// Whether the page reports each drawer change.
  final bool onDrawerChanged;
  final Preset<PageLayoutStyle> customStyle;
  final Preset<SystemStyle> systemStyle;
  final Preset<WidgetSettingKey> setting;
}
