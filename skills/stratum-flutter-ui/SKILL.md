---
name: stratum-flutter-ui
description: Use when building a Flutter app on the Stratum UI design system package and deciding which layout primitive to reach for, what its key parameters are, or how it behaves by keyboard, or when starting, switching, or writing a Stratum theme. Triggers on questions about ColumnLayout, RowLayout, FlexLayout, ContainerLayout, StackLayout, IndexedStackLayout, WrapLayout, ListViewLayout, GridViewLayout, CustomScrollViewLayout, PageViewLayout, ReorderableListViewLayout, StratumReorderableItemsController, NestedScrollViewLayout, Space/SpaceDirectional, StratumFocusBorder, FocusSpread, StratumThemeController, StratumThemeApplication.controlled, StratumThemePreloader, StratumRemoteTheme, StratumThemeController.install, typography.fonts files in theme.yaml, or StratumWebView, StratumWebViewController, and the page message bridge, or page transitions: animation.transition in theme.yaml, PageTransition, StratumTransitionPage, NoPageTransition, and ScreenTransitionType.
---

# Stratum Flutter UI

Every screen and component in an app that depends on `stratum_ui` builds on this layout family. Each primitive styles
its own box (`style: WidgetStyle`), takes one interaction (`interaction: StratumInteraction`) for taps, hover, and
shortcuts, and scrolls through one `scroll: StratumScroll` model — never a raw `Container`, `Column`, `Row`, or
`ListView`. Import the barrel: `package:stratum_ui/src/src.dart`.

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
  Keyboard: `focusGroup` roving group (K3), same as `FlexLayout`.

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
  them. Like the keys, the buttons jump when motion is reduced or the theme's `slow` level has no duration, else
  `previousPage` or `nextPage` over that level's duration and curve.

  ```dart
  void turn(BuildContext context, {required bool forward}) {
    final slow = StratumTheme.of(context).animation.slow;
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion ||
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
            interaction: StratumInteraction(
              onTap: () => turn(context, forward: false),
            ),
            child: const Icon(Icons.chevron_left),
          ),
          ContainerLayout(
            semantics: const SemanticsProperties(button: true, label: 'Next slide'),
            interaction: StratumInteraction(
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
        interaction: StratumInteraction(onTap: () => moveTask(index, index - 1)),
        child: const Icon(Icons.arrow_upward),
      ),
      ContainerLayout(
        semantics: const SemanticsProperties(button: true, label: 'Move down'),
        interaction: StratumInteraction(onTap: () => moveTask(index, index + 1)),
        child: const Icon(Icons.arrow_downward),
      ),
    ],
  ),
  ```

  Insert and remove: pass a `StratumReorderableItemsController` as `itemsController` (the scroll `controller` stays
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
  final itemsController = StratumReorderableItemsController();

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
- **`FocusSpread`** — deprecated in 1.1.0, and removed after one minor version: it builds `StratumFocusBorder`, so
  it already draws the new look. Its `color` now colors only the ring, as `customColor`, and no longer fills the
  box; a box that needs a fill takes it from its own style. Replace `FocusSpread(focus: f, color: c, inside: i,
  borderRadius: r, child: x)` with `StratumFocusBorder(state: f ? FullWidgetState.focused : FullWidgetState.normal,
  customColor: c, insideEdge: i ?? false, borderRadius: r, child: x)`; its `spread` has no counterpart and never
  took effect.

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
  the stratum_ui package or its default theme; a `pubspec.yaml` that is not a regular file, cannot be read, or is not
  yaml), an `--out` that is not a folder, or a zip that fails to write. Names starting with `.` and `__MACOSX/` stay out
  of a pack. An install refuses an entry name holding a control character and a folder entry that holds bytes.
  stratum_ui allows only the google_fonts version its CLI family list came from, so the CLI and your app accept the same
  `Google/<Name>` families. When `pub get` reports a google_fonts conflict, let your own google_fonts constraint allow
  the version stratum_ui's `pubspec.yaml` names.

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
  names. The page below moves only under an opaque route: `PageTransition` is translucent by default, so pass
  `opaque: true` for the page below to slide, fade, or parallax; a translucent page leaves it as it was.
- **Timing** — `none` always shows at once, zero push and pop durations in every route, whatever the theme names,
  unless a `PageTransition` caller passes its own; every other type but `platform` and `cupertino` runs over the theme's
  `slow` level (300 ms push, 192 ms pop in the package default) on its `standard` curve, unless the caller passes its
  own; `platform` and `cupertino` keep the Flutter motion's durations and, when they show it, its curve.
- **Reduced motion** — when `MediaQuery` or the platform asks for reduced motion, every slide, scale, rotation, and
  size change drops: a type with a fade, `fadeThrough`, the shared-axis types, and `platform` on Android, Windows,
  and Linux included, still fades over its full duration on the caller's curve, else the theme's `standard` curve, and
  any other type shows the page at once.
- **Flutter floor** — `stratum_ui` needs Flutter 3.44 or later, which package `animations` 3.0.0 needs.

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
