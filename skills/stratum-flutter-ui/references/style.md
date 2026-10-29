# Widget Styling

## Values

Values: every Stratum value model compares by value, field by field, and derives a variant with `copyWith`:
`StratumThemeData`, `StratumThemeSet`, `StratumAppPalette`, `StratumMotionLevels`, `StratumAnimation`,
`StratumRemoteTheme`, `StratumFontData`, `StratumThemeTransitions`, `StratumTextStyle`, `WidgetStyle`, `Interaction`,
`InteractionState`, `Scroll`, `ImplicitScrolling`, `FocusGroup`, `StratumFocusTokens`, `StratumFocusBorderStyle`,
`StratumInkWellStyle`, `ScrollFocusStyle`, `StratumCaretStyle`, the page, split, modal, and toast values, and the web
view values. A
`StratumFocusBorderStyle` compares by value for its `.all` and `.fromMap` properties, by identity for a
`resolveWith` one. A theme data's `*Tokens` groups compare by identity and carry no `copyWith` (`StratumColorTokens`
and the rest), except `StratumFocusTokens`, which compares by value like the list above, so two parses of one theme
compare unequal only outside `focus`. `StratumByWindowSize` has no `copyWith`; its `==` compares the value of each
window size. A sealed family's `copyWith` lives on each case, not on the base type: `StratumWebViewSource` itself has
none, only `StratumWebViewUrlSource` and `StratumWebViewHtmlSource` do. Callbacks, focus nodes, states controllers,
and scroll controllers inside a value compare by identity, and a remote theme's `bytes` and a recipe's shadows
compare by content. `StratumThemeData.copyWith` takes each field's own non-nullable type: pass a field only to
change it. `StratumTextStyle.copyWith(fontSize:` or `colorRole:)` keeps `customSize`/`customColor`, which win when
the recipe resolves; use the fluent getters (`size`, `color*`) instead to change one. No value carries `map` or
`when`: read a sealed one, such as `StratumToastPlacement` or `StratumWebViewSource`, with a Dart `switch`.

## Page transitions

- **The theme's transition per window size** — every `MaterialPageRoute` and `MaterialPage` (go_router's default
  page) below `StratumThemeApplication` takes the type the theme names for the window size, with no transition code:
  the application's Material theme installs a Stratum page transitions builder for every platform. Name the types in
  `theme.yaml` under `animation.transition`, one for each of `watch`, `mobile`, `tablet`, `desktop`, `bigDesktop`; the
  package default names `platform` for all five, Flutter's own page motion, so the iOS slide keeps its swipe-back.
  For `platform` and `cupertino`, the builder delegates to Flutter's whole builder, the outgoing page's motion
  included; during a back-swipe the page tracks the finger, with no curve. A layer may change any of the five and
  add no key; a name outside the nineteen types throws `StratumThemeFormatException` with `expected_transition` at
  its path. A package build without the key reads it as `unknown_key`. A `Theme` of your own below the application
  replaces the builder for its subtree.
- **The nineteen types** — `ScreenTransitionType`: `fade`; the slides `rightToLeft`, `leftToRight`, `topToBottom`,
  `bottomToTop`; `scale`, `rotate`, `size`; `rightToLeftWithFade`, `leftToRightWithFade`; the joined
  `rightToLeftJoined`, `leftToRightJoined`; `platform`, Flutter's default motion for the platform; `cupertino`, the
  Cupertino slide with swipe-back on every platform; `none`; `fadeThrough`; and `sharedAxisHorizontal`,
  `sharedAxisVertical`, `sharedAxisScaled`, from package `animations`.
- **One page's own type** — `PageTransition(type:, child:)` for `Navigator.push`, and
  `StratumTransitionPage(key: state.pageKey, type:, child:)` for go_router's `pageBuilder` or a Navigator 2.0 page
  list; either shows its own type, never the theme's. `PageTransition` also takes `curve`, `duration`,
  `reverseDuration`, `alignment` (the point `scale`, `rotate`, and `size` grow from; the center by default),
  `childCurrent` (the current page, required by the joined types), and `inheritTheme` with `ctx`. In the theme and in
  `StratumTransitionPage`, which have neither, `scale`, `rotate`, and `size` grow from the center and a joined type
  slides the page below out in its own route.
  `NoPageTransition(builder:)` shows its page with no animation and zero push and pop durations, whatever the theme
  names. The page below moves only under an opaque route, or under a route that hands its own delegated
  transition, such as `showCupertinoSheet`: `PageTransition` is translucent by default, so pass `opaque: true`
  for the page below to slide, fade, or parallax; a translucent page leaves it as it was.
- **Timing** — `none` always shows at once, zero push and pop durations in every route, whatever the theme names,
  unless a `PageTransition` caller passes its own; every other type but `platform` and `cupertino` runs over the theme's
  `slow` level (300 ms push, 192 ms pop in the package default) on its `standard` curve, unless the caller passes its
  own; `platform` and `cupertino` keep the Flutter motion's durations and, when they show it, its curve.
- **Reduced motion** — when `MediaQuery` or the platform asks for reduced motion, every slide, scale, rotation, and
  size change drops: a type with a fade, `fadeThrough`, the shared-axis types, and `platform` on Android, Windows,
  and Linux included, still fades over its full duration on the caller's curve, else the theme's `standard` curve, and
  any other type shows the page at once.
- **Flutter floor** — `stratum_ui` needs Flutter 3.47 or later, which packages `google_fonts` 9.0.0, `badges`
  ^4.0.1, and `webview_flutter_wkwebview` ^3.27.0 need.
