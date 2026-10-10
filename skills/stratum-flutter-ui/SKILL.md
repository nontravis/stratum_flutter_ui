---
name: stratum-flutter-ui
description: Use when building a Flutter app on Stratum UI: layout primitives, keyboard behavior, or Stratum themes. Triggers on ColumnLayout, RowLayout, FlexLayout, ContainerLayout, StackLayout, IndexedStackLayout, WrapLayout, ListViewLayout, GridViewLayout, CustomScrollViewLayout, PageViewLayout, ReorderableListViewLayout, ReorderableItemsController, NestedScrollViewLayout, Space/SpaceDirectional, StratumFocusBorder, FocusSpread, StratumThemeController, StratumThemeApplication.controlled, StratumThemePreloader, StratumRemoteTheme, StratumThemeController.install, typography.fonts in theme.yaml, StratumWebView, StratumWebViewController, its message bridge, animation.transition in theme.yaml, PageTransition, StratumTransitionPage, NoPageTransition, ScreenTransitionType, StratumCaret, StratumCaretDirection, StratumCaretStyle, resolveColor, ColorEnum, Thai labels, supportedLocales, Show, disabled, dimsWhenDisabled, opacity.disabled theme token, StratumWebZoom.
---

# Stratum Flutter UI

Every screen and component in an app that depends on `stratum_ui` builds on this layout family. Each primitive styles
its own box (`style: WidgetStyle`), takes one interaction (`interaction: Interaction`) for taps, hover, and
shortcuts, and scrolls through one `scroll: Scroll` model — never a raw `Container`, `Column`, `Row`, or
`ListView`. Import the barrel: `package:stratum_ui/src/src.dart`.

Names: screen-building blocks carry no `Stratum` prefix (`Interaction`, `Scroll`, `TapTargetSize`, `FocusGroup`,
`ReorderableItemsController`, `Show`, `ShowTransition`, `ShowSlideDirection`), while design-drawn components and theme
or app-setup types keep it (`StratumSlot`, `StratumHighContrastMode`). The old names `StratumInteraction`,
`StratumScroll`, `StratumTapTargetSize`, `StratumFocusGroup`, `StratumReorderableItemsController`, `StratumShow`,
`StratumShowTransition`, `StratumShowSlideDirection`, `Slot`, and `HighContrastMode` still compile for one minor version
as deprecated aliases; write the new names.

## Box layouts

Each entry: usage, key parameters, keyboard behavior.

- **`ContainerLayout`** — a styled box around one `child`.
  Key parameters: `style`, `child`, `fit` (a `BoxFit` that scales `child` into the padded area through a
  `FittedBox`; asserts `fit == null || scroll == null`, because a scrolling box has no extent to fit into).
  Keyboard: none of its own; a tap surface comes from `interaction`.
- **`FlexLayout`** — the base of `ColumnLayout` and `RowLayout`: a `Flex` whose `direction` may change between
  builds without remounting children, with `mainAxisAlignment`, `crossAxisAlignment`, `gap` (maps to `Flex.spacing`),
  and `crossAxisIntrinsic` (sizes the cross axis to the largest child, unless `style` sets that cross size; a
  `direction` change keeps the children's `State` with it set too, and only toggling it remounts them).
  Keyboard: `focusGroup` turns its children into one roving Tab stop (K3): arrows by screen direction, Home, End.
- **`ColumnLayout`**, **`RowLayout`** — `FlexLayout` with `direction` fixed to vertical or horizontal; same
  parameters, defaults, and order as before `FlexLayout` existed, so no caller changes.
  Keyboard: same `focusGroup` roving group as `FlexLayout`.
- **`StackLayout`** — a `Stack` for overlapping and `Positioned` children, with `alignment`, `fit`, and
  `clipBehavior` acting on the stack (`style.alignment`/`style.clipBehavior` act on the box instead).
  Keyboard: none; every child keeps its own focus.
- **`IndexedStackLayout`** — shows one child at `index` (null shows none) and mutes hidden children's tickers through
  `TickerMode`, so paused animations resume on return. Key parameters: `index`, `alignment`, `sizing`, `clipBehavior`.
  Keyboard: when `index` changes while focus sits in the outgoing child, focus moves after the frame to the first
  Tab-order node of the incoming child, else to the stack's own (non-Tab-stop) node.
- **`WrapLayout`** — a `Wrap` that lays children in runs across `direction`, with `gap`, `runGap`, and `focusGroup`.
  `maxRuns` (at least 1) and `maxChildren` (at least 0) cut it, the limit that hides more winning, and
  `overflowBuilder(context, hiddenCount)` builds a "+N" child during layout with the exact hidden count, after the last
  shown child in the last allowed run; more children hide until it fits. Hidden children stay mounted with their `State`
  and take no paint, hits, focus, or semantics, their tickers stopped; their text stays out of a `SelectionArea`'s
  select-all and copy, and a route push flies no `Hero` inside them. With `overflowBuilder` set, switching both limits
  to null keeps the children's `State`; without it the switch remounts them. A limit or `overflowBuilder` with `scroll`
  fails an assertion.
  Keep a child's size the same shown or hidden: one that does not fit shown but fits hidden stays hidden, counted in
  "+N", until the children change in number, order, key, or type, or the limits, `gap`, `runGap`, or the constraints
  change; a rebuild that builds the same children anew keeps it hidden (debug builds report it once).
  While measuring, the wrap calls `overflowBuilder` once per hidden count it tries, then shows the widget built for the
  last; that widget must not carry a `GlobalKey` or a `FocusNode` the app owns (debug builds report it), while a key or
  node a `State` inside the "+N" child creates for itself is safe.
  Inside an app's own scrollable along `direction` (a horizontal wrap in a horizontal `SingleChildScrollView`), the
  main axis is unbounded, so runs never break and `maxRuns` never cuts; use `maxChildren` there.
  Expand or collapse by changing the limits: the size moves over the theme's default level (`fast`, 125 ms in the
  package default) on the `standard` curve, clipped, and changes at once under reduced motion.
  Keyboard: `focusGroup` roving group (K3), same as `FlexLayout`; Tab and the group's arrows skip hidden children,
  and End lands on the last item in reading order, the "+N" child in a horizontal, downward wrap. When a collapse hides
  the focused child, or a collapse or rebuild replaces the focused "+N" child with a new one, focus moves after the
  frame to the "+N" child, else to the last shown child, else to the wrap's own node, which is not a Tab stop; when an
  expand that shows hidden children drops the focused "+N" child, focus moves to the first child it shows, else to the
  wrap's own node.

## Scroll views

All six share one keyboard model (K4) through the internal `ScrollViewBox`: a `focusable` view (true by default on
web, macOS, Windows, and Linux) is one Tab stop whose arrows (50 px), Page Up/Page Down (0.8 viewport), Home, and End
scroll it, guarded so a text field inside keeps its own keys.

- **`ListViewLayout`**, **`GridViewLayout`**, **`CustomScrollViewLayout`** — lazy list, grid, and sliver view inside
  a `WidgetStyle` box; `style.padding` becomes the scroll padding, so it scrolls with the content.
  Keyboard: K4 line-mode scrolling, each key over the theme's `fast` level (125 ms in the package default) on its
  `standard` curve, or a jump when `MediaQuery` or the platform asks for reduced motion.
- **`PageViewLayout`** (children or `.builder`) — one page per viewport, with `scrollDirection`, `controller`,
  `pageSnapping`, `onPageChanged`; `style.padding` insets the viewport rather than scrolling.
  Keyboard: an arrow along the axis, Page Up/Page Down, Home, and End move one whole page; a change slides over the
  theme's `slow` level (300 ms in the package default) on its `standard` curve, or jumps when `MediaQuery` or the
  platform asks for reduced motion or the level has no duration; focus moves to the new page's first Tab-order node.
  Buttons: the layout draws no previous or next buttons, and on desktop a mouse without a trackpad cannot swipe, so
  the app adds previous and next buttons around the view (WCAG 2.5.1) until a component in the package provides
  them. Like the keys, the buttons jump when `context.reducesMotion` is true or the theme's `slow` level has no
  duration, else `previousPage` or `nextPage` over that level's duration and curve.

  ```dart
  void turn(BuildContext context, {required bool forward}) {
    final slow = StratumTheme.of(context).animation.slow;
    final reduced =
        context.reducesMotion ||
        slow.duration == null ||
        slow.duration == Duration.zero;
    if (reduced) {
      final page = (pages.page ?? 0).round() + (forward ? 1 : -1);
      pages.jumpToPage(page.clamp(0, slides.length - 1));
    } else if (forward) {
      pages.nextPage(duration: slow.duration!, curve: slow.curve ?? Curves.easeInOutSine);
    } else {
      pages.previousPage(
        duration: slow.duration!,
        curve: slow.curve ?? Curves.easeInOutSine,
      );
    }
  }

  ColumnLayout(
    children: [
      Expanded(child: PageViewLayout(controller: pages, children: slides)),
      RowLayout(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ContainerLayout(
            semantics: const SemanticsProperties(button: true, label: 'Previous slide'),
            interaction: Interaction(
              onTap: () => turn(context, forward: false),
            ),
            child: const Icon(Icons.chevron_left),
          ),
          ContainerLayout(
            semantics: const SemanticsProperties(button: true, label: 'Next slide'),
            interaction: Interaction(
              onTap: () => turn(context, forward: true),
            ),
            child: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    ],
  )
  ```
- **`ReorderableListViewLayout`** (`.builder` only) — a reorderable list on widgets `SliverReorderableList`, with a
  caller-placed drag handle or `longPressDrag`, `onReorderItem`, and `dragStyle` for the lifted item; each item keeps
  its `State` and focus across a move through a global key that never uses the index. An item finds the list through
  `SliverReorderableList.maybeOf(context)`, not `ReorderableList.maybeOf`.
  A drag held near a viewport edge scrolls the list toward that edge; `autoScrollerVelocityScalar` scales its speed.
  Keyboard: Alt+arrow along the axis moves the focused item one slot, Alt+Home/Alt+End move it to either end; a move
  past either end is still handled, so it never reaches the browser (Chrome's Alt+Left/Alt+Right Back/Forward).
  Without dragging: dragging is the list's only pointer path, so the app adds one that needs no drag (WCAG 2.5.7),
  such as Move up and Move down buttons or context-menu entries on each item, until a component in the package
  provides it. They call the handler the app passes to `onReorderItem`, with the indexes the keys pass, and that
  handler ignores a target past either end.

  ```dart
  itemBuilder: (context, index) => RowLayout(
    key: ValueKey(tasks[index].id),
    children: [
      Expanded(child: Text(tasks[index].title)),
      ContainerLayout(
        semantics: const SemanticsProperties(button: true, label: 'Move up'),
        interaction: Interaction(onTap: () => moveTask(index, index - 1)),
        child: const Icon(Icons.arrow_upward),
      ),
      ContainerLayout(
        semantics: const SemanticsProperties(button: true, label: 'Move down'),
        interaction: Interaction(onTap: () => moveTask(index, index + 1)),
        child: const Icon(Icons.arrow_downward),
      ),
    ],
  ),
  ```

  Insert and remove: pass a `ReorderableItemsController` as `itemsController` (the scroll `controller` stays
  separate) and call `insertItem(index)` or `removeItem(index)` in the same turn as the data change, outside a build
  and `onReorderItem`, `onReorderStart`, and `onReorderEnd`; from those, call after the frame.
  An added item grows and fades in over the theme's `normal` level, and a removed one shrinks and fades out in the
  look it had, unless `removeItem`'s `builder` gives it another; `itemTransitionBuilder(context, animation, child)`
  replaces the size and fade both ways. Without `builder`, a removed item's leaving copy ends at once if its key comes
  back; a `builder` keeps it fading on its own look. The leaving item keeps its State and rebuilds, so an item reading
  its data through `context` (a `watch` or `select` by id or index, a provider family) needs a `builder` capturing that
  data. Under reduced motion, or with `itemExtent`, `itemExtentBuilder`, or `prototypeItem`, the size jumps and the fade
  plays. Focus on a removed item moves to the next item, else the previous, else the list's Tab stop when the list is
  focusable, unless the app moves focus in the same turn; a focused item the app removes and inserts back with its key
  in the same turn keeps focus instead, and the list scrolls to it and shows it. A reorder of a leaving item's neighbor
  ends that leaving item. An `insertItem`, `removeItem`, `moveItem`, key or screen-reader move, or item-count change
  during a drag ends it first with `onReorderEnd` at its start index and no `onReorderItem`; key and screen-reader moves
  then report their own.

  ```dart
  final itemsController = ReorderableItemsController();

  void addTask(int index, Task task) {
    setState(() => tasks.insert(index, task));
    itemsController.insertItem(index);
  }

  void deleteTask(int index) {
    setState(() => tasks.removeAt(index));
    itemsController.removeItem(index);
  }
  ```

  Move: call `moveItem(from, to)` in the same turn as moving the item in the data, where `to` is the index the item
  ends at, as `onReorderItem` reports it. The old slot closes while the item grows and fades into its new one over the
  theme's `normal` level (under reduced motion or a fixed extent the slot closes at once and the item only fades in);
  the item keeps its State and focus, and a focused item shows on screen even when its new slot is far off screen,
  unless the app moves focus in the same turn: that focus stays, and the item keeps its State only when the list has
  built its new slot. `onReorderItem` does not fire. Prefer it to `removeItem` plus `insertItem`, which keeps the
  item's State only when the list has built its new slot. The Move up and Move down buttons above can call it.

  ```dart
  void moveTask(int from, int to) {
    if (to < 0 || to >= tasks.length) return;
    setState(() => tasks.insert(to, tasks.removeAt(from)));
    itemsController.moveItem(from, to);
  }
  ```
- **`NestedScrollViewLayout`** — a collapsing header (`headerSliverBuilder`) above a `body` scroll view; it is never
  a Tab stop itself, only the body's scroll view is, and a desktop scrollbar needs `showScrollbar: false` when the
  body is a `TabBarView`.
  Keyboard: the body's K4 keys act on one joined range, header extent then list extent — a key that would collapse
  past the header's end spills the remainder into the list, and Home/End expand or fully collapse the header.

## Spacing

- **`Space`** — static getters/constructors for fixed spacers and insets (`Space.box16`, `Space.empty`, and the
  rest), returning `SizedBox`, `Gap`, or `EdgeInsets` in steps from 1 to 72 px.
- **`SpaceDirectional`** — the same steps as `EdgeInsetsDirectional`, so start and end mirror under
  `TextDirection.rtl`.

## Focus ring

- **`StratumFocusBorder`** — the Figma `FocusBorder` ring around one `child`. `StratumInkWell`, and so every
  `interaction`, and every focusable scroll view already draw it; wrap a widget yourself only when it takes focus or
  hover without them. Key parameters: `style` (`StratumFocusBorderStyle.outside`, the default, for every interaction
  the user does not type into; `.inside` for form fields), `state` (`FullWidgetState.focused`, `.hovered`, or
  `.normal`, resolved from focus and hover alone: a field in error that holds focus still passes `focused`, and any
  other value shows no ring), `borderRadius` (the child's own radius), `insideEdge` (an outside ring on the child's
  inner edge, for a box whose ring around it would leave the window), and per-ring `customColor`, `width`, and `gap`.
  Look: outside, 3 px in `border.subtle.blue` after a 2 px gap, only when focused; inside, `border.default.normal`
  on the inner edge, 3 px when hovered and 2 px when focused. It fades over the theme's `fast` level, shows at once
  under reduced motion, and never changes the child's layout size. Its colors stay below the 3:1 contrast of WCAG
  1.4.11 by design; pass `customColor` where an app needs that ratio.
- **`StratumInkWell`** — the tap surface every `interaction` builds on. Its own hover and press overlay fades over
  the theme's `fast` level and snaps straight to its target color under reduced motion, same as the ring above it.
  `tapTargetSize` (default `TapTargetSize.platform`) grows its layout and hit area to the platform minimum
  when `child` is smaller; pass `TapTargetSize.shrinkWrap` to keep `child`'s own size in a dense UI.
  `Interaction.tapTargetSize` carries the same choice to every `BoxLayout` (`ContainerLayout`, `ColumnLayout`,
  `RowLayout`, `StackLayout`, `WrapLayout`) with a tap surface, so a dense `BoxLayout` opts out the same way.
- **`FocusSpread`** — deprecated in 1.1.0, and removed after one minor version: it builds `StratumFocusBorder`, so
  it already draws the new look. Its `color` now colors only the ring, as `customColor`, and no longer fills the
  box; a box that needs a fill takes it from its own style. Replace `FocusSpread(focus: f, color: c, inside: i,
  borderRadius: r, child: x)` with `StratumFocusBorder(state: f ? FullWidgetState.focused : FullWidgetState.normal,
  customColor: c, insideEdge: i ?? false, borderRadius: r, child: x)`; its `spread` has no counterpart and never
  took effect.

## Disabled components

- **`disabled: true`** — on any component built on `StratumStatelessWidget` or `StratumStatefulWidget`, the
  base paints it at the theme's `opacity.disabled` (0.5 by default), shows the forbidden cursor, lets no tap,
  long press, drag, or hover run its action — a tap reaches a gesture detector wrapped around it, as with a
  Flutter button whose `onPressed` is null — and keeps it and every node inside it out of focus and Tab order,
  losing focus if focused. A screen reader marks it disabled on its own node. Turning `disabled` off keeps the
  component's state. A `StratumInkWell` press already down when it turns disabled is cancelled and runs no action; a
  scroll already holding the finger goes on, and a `GestureDetector` you write inside it finishes its gesture
  underway.
- **Your own disabled look** — a component overrides `@protected bool get dimsWhenDisabled => false` to draw its
  own; the cursor, input, focus, and screen-reader rules still hold. A widget extending neither base gets none of
  this.
- **A decorative component** — a component that gives a screen reader nothing to read, such as a caret, overrides
  `@protected bool get contributesSemantics => false`; while disabled it then gets no screen-reader node, and the
  dimming, cursor, input, and focus rules still hold.
- **One box widget at its root** — a component on either base builds exactly one box widget at its root, never
  `Expanded`, `Flexible`, or `Positioned`; the base asserts no `ParentDataWidget` root in debug builds, so move the
  parent-data widget to the call site instead. A sliver root is not caught by this assertion; it fails Flutter's own
  box-child assertion instead.

## Caret and named colors

- **`StratumCaret`** — the Figma `Caret` glyph that marks a disclosure, select, or dropdown as open or closed; for
  navigation between pages or sections, use a dedicated arrow or chevron icon instead. Key parameters: `direction`
  (`StratumCaretDirection.down`, the default, `.up`, `.start`, `.end`: `start` and `end` follow the text direction,
  so `end` points right in a left-to-right app and left in a right-to-left app), `style`
  (`StratumCaretStyle.regular`, the default, a 1.5 px round chevron; `.light`, 1.0 px; `.fill`, a solid triangle),
  `size` (a `WidgetSize`: `tiny` 10 px to `huge` 32 px, `medium` 16 px; null takes the theme's `defaultWidgetSize`)
  or `customSize` (any side in logical pixels, must be finite and >= 0), and `color` (a `ColorEnum`: the theme's
  `icon.color.<name>` token, else `icon.default.primary`) or `customColor` (any color, as given). The line width
  stays the same at every size, and the glyph sits centered in its square box and never stretches. Change
  `direction` to turn it: it turns the short way over the theme's `fast` level, a half turn back the way the last
  half turn came, and shows the new direction at once under reduced motion or when the text direction flips. It
  adds nothing to the semantics tree: announce expanded or collapsed on the component that holds it. `customStyle`
  styles the box, never the glyph, and `state`, `feedbackState`, and `loading` leave its look as it is.
- **Named colors** — a component of your own on `StratumStatelessWidget` or `StratumStatefulWidget` maps its `color`
  prop with `resolveColor(context, (colors) => colors.icon.color, fallback)`: the token of that name in the group
  you pick (`background.color`, `border.color`, `icon.color`, or `text.color`), else `fallback` when `color` is null
  or the group has no token of that name. Read a group by name yourself with
  `StratumTheme.of(context).color.icon.color[ColorEnum.blue]`, which gives null for a name the group lacks; a token
  the package's default theme gains joins the lookup in the next package release; an app's own theme can only
  restyle the names the package already has.

## Built-in labels

- **Thai labels** — Stratum's own labels hold English and Thai, and read English for any other language. The menu
  action a screen reader offers on a tap surface with `onSecondaryTap` takes the app's material localizations'
  tooltip first when present, so with the global material delegates a Japanese app hears the Japanese material
  tooltip, not Stratum's English fallback; otherwise it reads Stratum's built-in label, Thai for a Thai locale. List
  `Locale('th')` in the app's `supportedLocales` to show them in Thai. Stratum's built-in labels need no delegate of
  their own: an app that lists `Locale('th')` in `supportedLocales` still adds Flutter's
  `GlobalMaterialLocalizations.delegates`, as any Thai Flutter app does, for its own material widgets; Stratum reads
  the resulting locale without registering a delegate of its own. Above `MaterialApp` the platform locale picks the
  language. A component's label prop, such as `StratumInkWell.secondaryTapSemanticsLabel`, replaces its built-in
  label.

## Themes

- **Theme font files** — a theme ships its own fonts by listing them under `typography.fonts.<key>.files` in its
  `theme.yaml`: paths relative to that file's folder, ending in `ttf` or `otf` (`files: [fonts/Brand-Regular.ttf]`).
  Declare the font folder in pubspec (`- assets/themes/brand/fonts/`), since Flutter does not include asset
  subfolders. A font with `files` takes no `package` and no `Google/` family. Each theme's fonts register under
  `<theme id>/<family>`, so two themes may ship files under the same family name; a theme that inherits the font
  from a layer it merges over shares that layer's registration.
- **Default theme fonts** — the package default theme names Google fonts only (`Google/Inter`, `Google/Geist`,
  `Google/Geist Mono`, `Google/Roboto Mono`, `Google/Kanit`) and bundles no font file. The app owns
  `GoogleFonts.config`: bundle the font files under its own assets to skip the download, which also keeps the app's
  widget tests off the network, since the google_fonts library looks in the assets first.
- **Google font weights** — a Google font draws only in the weights its theme loads it in: each type's `weight` for
  the font that type names, and every type's weight for each tag's `body` font and theme-wide `mono`. A recipe weight
  outside that set, such as `.medium` on the package default's Inter (loaded in 400 and 600), draws the nearest loaded
  weight, the heavier on a tie, and prints one debug warning per family and weight. A Google font in the fallback list
  snaps the style's drawn weight — the primary's snapped weight, or the recipe's weight when the primary is an app or
  theme font — into its own set: the drawn weight when its set holds it, otherwise the nearest weight in it (the
  heavier on a tie), which can be lighter than the primary. The package asks google_fonts for
  no other weight, with run-time fetching on or off, so bundling exactly those weights keeps every normal-style Google
  font off the network; an italic face loads on first use, at the snapped weight. A font the theme ships as `files`
  or the app registers keeps the weight it is asked for.
- **Material text theme** — `StratumThemeApplication` inserts a Material `ThemeData` whose text theme resolves Stratum
  recipes for the active theme, locale, and window size: display and headline slots read `header`; title, body, and
  label slots read `body`. No slot sets a weight, so each draws its type's yaml weight: title and label slots draw the
  body weight (400 in the package default), not Material's medium.
- **Theme models** — the parsed theme types (`StratumThemeConfig`, `StratumColorSets`, `StratumTypography`,
  `StratumTypeStyle`, `StratumAnimationConfig`, and the models inside them) are immutable values with `copyWith`;
  their maps refuse changes, so derive a variant with `config.copyWith(name: ...)` instead of editing a map. A
  `StratumCurve` gives its Flutter `Curve` as `.curve` through `package:stratum_ui/stratum_ui.dart`.
  `StratumAnimationConfig.transitions` holds the `animation.transition` names, and
  `StratumTheme.of(context).animation.transition[windowSize]` gives the theme's `ScreenTransitionType` for a window
  size.
- **Before `preload`** — call `WidgetsFlutterBinding.ensureInitialized()` first: `preload` reads the asset manifest
  through `rootBundle`, which needs the binding. In a `testWidgets` test, the background parse runs on a real
  isolate, which the test's fake-async zone never finishes; run `preload`, or pump a tree rooted in
  `StratumThemePreloader`, under `tester.runAsync`.
- **`StratumThemeController`** — the registered themes and the active one. Build it before the first themed frame
  with `await StratumThemeController.preload(initialThemeId: savedId, onThemeChanged: save)`; `googleFontsTimeout`
  (default 3 s, also the limit of every switch) and `bundle` are optional. It registers every
  `assets/themes/<id>/theme.yaml` the app declares in pubspec as `<id>` (`themeIds`: `default` first, then
  alphabetical), and an app `default` folder layers over the package default. An `initialThemeId` that names no
  theme starts on `default` and calls `onThemeChanged('default')`, so the app overwrites its saved id; a theme file
  with problems throws `StratumThemeFormatException`.
  A theme file, bundled or in a zip, holds no YAML anchor, alias, or tag (`&a`, `*a`, `!x`), no mapping key that is a
  collection or an explicit `?` key (`[a]: x`, `{a: 1}: x`, `? a`), nests at most 64 collections, holds at most 256
  keys in one mapping and 2,048 in all, stays within 1 MiB, and holds a byte-order mark (U+FEFF) only as its own
  first character, never later even on its own line; past that it fails as `yaml_syntax` at the offending character,
  so write each value out, refer to a token with a quoted `"{group.path}"` alias, split a larger mapping, write each
  key as a plain or quoted value, and move or remove a stray byte-order mark.
  `switchTo(id)` completes after the new theme is active, keeps the current theme on screen while it loads and when
  it fails, throws `StratumThemeNotFoundException` for an unknown id, and lets the latest of overlapping switches
  win. For the active id it does nothing, unless a newer install of that id is registered and not yet on screen:
  then it shows that install, with no `onThemeChanged`. The package stores nothing: save the id `onThemeChanged`
  reports.
- **`StratumThemeApplication.controlled`** — `StratumThemeApplication.controlled(controller:, themeMode:,
  highContrast:, componentDefaults:, child:)` publishes the controller's active theme and rebuilds dependents once
  per switch; below it, `StratumThemeController.of(context)` and `maybeOf(context)` find the controller, so a theme
  picker calls `StratumThemeController.of(context).switchTo('brand')`. `StratumThemeApplication(themes:)` stays for a
  fixed theme set.
- **`StratumThemePreloader`** — the widget form of `preload`: `StratumThemePreloader(initialThemeId:,
  onThemeChanged:, googleFontsTimeout:, loading:, error:, builder: (context, controller) => ...)` shows `loading`
  until the start theme is active, then `builder`, or `error` with what preload threw; it reads its asset bundle from
  `DefaultAssetBundle` and disposes its controller when it leaves the tree. Pick it or `await preload(...)` before
  `runApp`, not both.
- **Remote theme zips** — hand a downloaded `<id>.zip` with the checksum your own API serves (never a file beside the
  zip): `StratumRemoteTheme(id:, bytes:, checksum: 'sha256:<64 hex>')`, caps `maxBytes` 20 MB and `maxEntries` 200 by
  default. Pass kept zips to `preload(remoteThemes: [...], onRemoteThemeError: (id, error) => ...)` or the same two
  parameters of `StratumThemePreloader`; a zip that fails is skipped and reported, so delete it and download it again.
  At run time `await controller.install(theme)`, then `switchTo(theme.id)`; installing the active id repaints in one
  step with no `onThemeChanged`. The latest install of an id that reaches registration wins, a bundled id too, for the
  run only; of overlapping `install` calls for one id, the later-started call that installs wins, and an earlier call
  that finishes after it completes normally while installing nothing, so await the call you started last; a later call
  that fails leaves an earlier one free to install. `default` is always refused. Ask your server for the zip of
  `StratumSchemaVersion.current`. `theme.yaml` sits at the zip root or in its one top folder; every `files:` font and
  asset slot it names must be in the zip; `Google/<Name>` fonts load as for a bundled theme. A failure throws
  `StratumRemoteThemeException` with a `code` (`StratumRemoteThemeErrorCode`), `themeFormat` carrying the FO-01 report
  in `formatException`. Its `path` field is entry text straight from the zip: escape it before your app logs or shows
  it, since a hostile zip crafts it. `StratumThemeFormatException` and each `StratumThemeFormatError` print their
  yaml paths and messages escaped, but an error's `path` field is the raw yaml path: escape it the same way.
- **Pack and check a theme zip** — from your app project, `dart run stratum_ui:stratum_theme pack <folder>` writes
  `<id>.zip` (the id is the folder name, or `--id`; `--out <folder>` to write elsewhere) and prints `sha256:<hex>`, the
  checksum your API serves; the same folder always packs to the same bytes, and a pack into the folder itself leaves its
  own last `<id>.zip` out. `dart run stratum_ui:stratum_theme check <file.zip>` runs your app's own install checks on a
  zip, over the package default and your `assets/themes/default/theme.yaml` when your `pubspec.yaml` lists it under
  `flutter: assets:`, as the file or as `assets/themes/default/` (`assets/themes/` does not cover it), the way your app
  reads it; a file you hold but do not list is not read and prints a `warning:`. `--app-default <path>` names another
  file; pass `--max-bytes` and `--max-entries` when your app raises a cap. A run that passes prints only the checksum on
  stdout; stderr names the defaults read, each problem with the code your app would report, and `warning:` lines that
  never fail it: files the theme does not name; entries the install never reads, such as anything under `__MACOSX/`, a
  `.DS_Store`, or a loose file beside the theme folder; and names that differ only in letter case, one line per two
  neighbors in name order. Exit 0 pass; 1 check failed, or a `pack` that stops before the check with one problem and no
  defaults line (`invalid_id`, a symbolic link or other special entry as `unsafe_entry_path`, or a file name or size a
  zip cannot hold as `unsafe_entry_path` or `archive_too_large`); 64 usage; 66 an input that cannot be read (the folder;
  a zip or `--app-default` that is not a regular file or cannot be read; your default theme; a file under the folder;
  the stratum_ui package or its default theme; a `pubspec.yaml` that is not a regular file, is longer than 1 MiB, cannot
  be read, or is not yaml, such as one holding an anchor, alias, or tag or nesting deeper than 64), an `--out` that is
  not a folder, or a zip that fails to write. Names starting with `.` and `__MACOSX/` stay out of a pack. An install
  refuses an entry name holding any character outside printable ASCII, U+0020 to U+007E (a control character, an
  accented letter, or a Thai letter alike), or a name Windows would not create unchanged (a part ending in a dot or a
  space, a part of dots only, any of `:`, `<`, `>`, `"`, `|`, `?`, `*`, a device name such as `CON`, `aux.txt`, or
  `CONIN$` in any letter case with trailing spaces before the dot trimmed, or a part holding `~` before a digit, an
  8.3 short-name marker such as `THEME~1.YAM`), and a folder entry that holds bytes; `pack` refuses such a file or
  folder name under the folder before it writes anything, so rename it. stratum_ui allows only the google_fonts
  version its CLI family list came from, so the CLI and your app accept the same `Google/<Name>` families. When
  `pub get` reports a google_fonts conflict, let your own google_fonts constraint allow the version stratum_ui's
  `pubspec.yaml` names.
- **Disabled opacity** — `opacity.disabled` in `theme.yaml`, a number from 0 to 1, is the opacity every disabled
  component paints at; the package default sets 0.5, and an app theme may leave the group out. Read it as
  `StratumThemeApplication.of(context).opacity.disabled`. A value outside 0 to 1 throws
  `StratumThemeFormatException` with `expected_opacity` at its path, and a second key under `opacity` is
  `unknown_key`. The package default reads `$schema: stratum-theme/v1.1.0`; this package reads every `v1.0` and
  `v1.1` theme, while a package build that reads only `v1.0` refuses a `v1.1` theme as `unsupported_schema`, so a
  theme that must load on both writes `v1.0.0` and leaves `opacity` out.

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
  `reverseDuration`, `alignment` (required by `scale`, `rotate`, `size`), `childCurrent` (the current page, required
  by the joined types), and `inheritTheme` with `ctx`. In the theme and in `StratumTransitionPage`, which have neither,
  `scale`, `rotate`, and `size` grow from the center and a joined type slides the page below out in its own route.
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

## Show and hide

- **`Show`** — `Show(visible: v, child: c)` shows `c` while `v` is true and hides it while false, by
  `transition`: `ShowTransition.sizeAndFade` (the default), `.fade`, `.size`, or `.slide`, over the theme's
  default motion level (125 ms to show and 80 ms to hide in the package default) on its `standard` curve; `duration`,
  `reverseDuration`, and `curve` each replace one of them. A slide moves the content by its own size from
  `slideDirection`: `ShowSlideDirection.end` (the default), `.start`, `.top`, or `.bottom`, with start and end
  mirrored under right-to-left text, and fades as it moves. Hidden content takes no space in a row or a column and is
  unmounted after its hide motion, so it builds fresh when shown again; `maintainState: true` keeps it mounted
  instead, with its state, its tickers stopped, and no size. From the frame it turns hidden, leaving or hidden content
  takes no tap, focus, or screen-reader attention; focus inside it moves to the show, which Tab never stops on. Under
  reduced motion nothing moves or resizes: `fade`, `sizeAndFade`, and `slide` keep their fade, and `size` shows and
  hides at once.

## Web zoom

- **`StratumWebZoom`** — wrap a web app, or the part of it to zoom, in `StratumWebZoom(child: app)`. On the web the
  EndUser pinches, on a touch screen or a trackpad, to zoom between `minScale` (default 1.0, so the app never shrinks
  below its own layout) and `maxScale` (default 2.5), pans the zoomed app, and sees it clipped to the zoom's bounds;
  the mouse wheel never zooms and keeps scrolling the list under the pointer. On Android, iOS, macOS, Windows, and
  Linux it builds the child alone. A `maxScale` below `minScale`, or a `minScale` of 0 or less, fails an assertion in
  debug builds on every platform. It does not zoom the page inside a `StratumWebView`.

## Web view

- **`StratumWebView`** — shows a URL page or the app's own HTML (`StratumWebViewSource.url`, `.html`) on Android,
  iOS, macOS, Windows, Linux, and the web, driven by an optional `StratumWebViewController`.
  Bridge: list the page origins you trust in `allowedOrigins` (empty closes the bridge, HTML included). A page calls
  `StratumBridge.postMessage(data)`; `onMessage` gets the text and the origin of the page that sent it, `null` for
  your HTML; answer the sender with `controller.reply(message, data)`: it reaches only the page or HTML document
  that sent the message, and throws `StateError` once the view shows another origin or that document is gone
  (`ArgumentError` for a message the controller did not deliver). Three limits on that guarantee: on Windows and
  Linux the reply is credited to the page of the last `onPageStarted`, not necessarily the sender; on the web, after
  an in-frame link to another origin the check still passes on stale history and the browser drops the reply
  silently with no throw; and on the web, a reply to your own HTML after a link away inside it resolves the same
  way, without delivering the data. `controller.postMessage(data, targetOrigin: origin)` names a recipient origin
  the same way; `postMessage(data)` sends to whatever page is shown. Your HTML
  connects its bridge when its bootstrap script runs: a `postMessage` before that throws `StateError` on every
  platform, so wait for the page's first message instead of sending right after `loadHtml`. On iOS and macOS a
  `reload()` of your HTML shows an empty page and the bridge stays closed until the next `loadHtml`.
  Native code: the package ships Android (Kotlin, AndroidX WebKit) and iOS and macOS (Swift) code that names the
  sender of each page message, so only the top-level page's messages pass, even one sent before `onPageStarted`; an
  app needs no setup of its own. On Android a system WebView without `WEB_MESSAGE_LISTENER` or
  `JS_INJECTION_IN_FRAME_AND_WORLD` keeps the bridge off, and every `postMessage` throws `StateError`. On Android a
  send to your HTML reaches only the document that connected the bridge; once that document leaves, the next one
  gets nothing and the send throws `StateError`. On Windows and Linux every frame of an allowed page can send,
  credited to the page of the last `onPageStarted`.
  Web: `onMessage`'s origin names the page that sent the message, even a URL page the view has moved away from, and
  `currentUrl()` reports the requested URL until the frame finishes loading it. On the web, load only content the app
  trusts on the app's own origin: such a page runs with the app's privileges.
