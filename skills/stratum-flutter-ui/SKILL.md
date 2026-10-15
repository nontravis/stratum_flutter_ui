---
name: stratum-flutter-ui
description: Use when building or changing a Flutter app on Stratum UI (screen, layout, taps, hover, keyboard and focus, theme, app start, or any Stratum* widget). Layout triggers are *Layout primitives (ColumnLayout, ContainerLayout.builder), showModalLayout, reorderable lists, and Space spacing. Interaction triggers are Interaction, HoverBuilder, FocusBuilder, and focus rings (StratumFocusBorder). Theme triggers are StratumThemeController install and switching, StratumThemeApplication, remote and preloaded themes, StratumSplashScreen, theme.yaml tokens (border, shadow, blur), and context.* reads (context.themeData). Widget triggers are StratumWebView, StratumWebZoom, page transitions (StratumTransitionPage), StratumCaret, named colors (ColorEnum), Thai labels and supportedLocales, Show and disabled dimming, StratumPlaceholderPage, and update prompts (StratumUpdateGate, UpdateChecker).
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

Values: every Stratum value model compares by value, field by field, and derives a variant with `copyWith`: the
theme data and its parts (`StratumThemeData`, `StratumThemeSet`, `StratumAnimation`, `StratumTextStyle`,
`StratumRemoteTheme`, and the rest), `WidgetStyle`, `Interaction`, `InteractionState`, `Scroll`, `FocusGroup`, the
page, split, modal, and toast values, and the web view values. `StratumByWindowSize` alone has no `copyWith`; its
`==` compares the value of each window size. Callbacks, focus nodes, states controllers, and scroll controllers
inside a value compare by identity, and a remote theme's `bytes` and a recipe's shadows compare by content. No value
carries `map` or `when`: read a sealed one, such as `StratumToastPlacement` or `StratumWebViewSource`, with a Dart
`switch`.

## Install

- Stratum's notices wrap `toastification`, which pins `equatable ^2.0.5`, while Stratum's own `flutter_falconx`
  needs `equatable ^3.0.0`. pub reads overrides only in the app, so add these two lines to the app's `pubspec.yaml`
  when you add stratum_ui, and run `flutter pub get`:

  ```yaml
  dependency_overrides:
    equatable: ^3.0.0
  ```

  Remove them once stratum_ui's own `pubspec.yaml` no longer carries the override.

- Before adding the override, check what else in the app graph reads `equatable`: run `flutter pub deps --style=list` and
  look for other `equatable` dependents. The override silences every package's `equatable` constraint, and `equatable`
  3.0.0 is breaking (removed `EquatableMixin`, changed `toString`, dropped the `runtimeType` comparison of props), so a
  dependency still on `^2.x` runs on 3.0.0 untested. Run the app's tests after adding it.

## Box layouts

Each entry: usage, key parameters, keyboard behavior.

- **`ContainerLayout`** — a styled box around one `child`, or around the content `builder: (context, state)` builds
  from its tap surface's `InteractionState`.
  Key parameters: `style`, `child` or `builder` (never both: a debug assertion names the fix), `fit` (a `BoxFit` that
  scales the content into the padded area through a `FittedBox`; asserts `fit == null || scroll == null`, because a
  scrolling box has no extent to fit into).
  `state.hovered` is true while a pointer is over the surface, with or without `onTap`, or while the app sets
  `WidgetState.hovered` through `statesController` (a preview); `state.pressed` while it is held; both stay false
  while `state.disabled`, which is the interaction's own `disabled` or a disabled component around it.
  `state.focused` is true exactly while the focus ring shows: Tab focus under the default focus type, so a mouse click
  does not set it, and any focus under `FocusType.focused`. With no `interaction`, or one with no callback and no
  shortcut, every value is false and no tap surface is added. `builder` runs only when a value changes. Pair every
  state color with text, an icon, or a shape.
  Keyboard: none of its own; a tap surface comes from `interaction`.

  ```dart
  ContainerLayout(
    interaction: Interaction(onTap: openProduct),
    builder: (context, state) => Text(
      product.title,
      style: TextStyle(
        decoration: state.hovered ? TextDecoration.underline : null,
      ),
    ),
  )
  ```
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
scroll it, guarded so a text field inside keeps its own keys. Any of them, focusable or not, brings a focused node it
keeps alive off screen, such as a text field scrolled far away, back into view before a focus move from it: Tab,
Shift+Tab, an arrow, or the app's own `nextFocus()`, `previousFocus()`, or `focusInDirection()`. The one limit: the
app's own call on a node whose nearest traversal group is a `FocusTraversalGroup` the app adds with a policy of its own
is the app's to reveal; a key from that node is still brought back first. Tab among the items of any of them follows
reading order on every platform: an app's `FocusTraversalOrder` on the items does not reorder them, even under its own
`OrderedTraversalPolicy` around the view; only a `FocusTraversalGroup` inside an item keeps its own order.
Pass `semanticsLabel` to a focusable view: its Tab stop has no other accessible name for a screen reader to read
(WCAG 4.1.2).

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
  `SliverReorderableList.maybeOf(context)`, not `ReorderableList.maybeOf`. The list builds a private
  `SliverReorderableList` subtype, which `find.byType(SliverReorderableList)` misses: a test finds it with
  `find.byWidgetPredicate((widget) => widget is SliverReorderableList)`.
  A drag held near a viewport edge scrolls the list toward that edge; `autoScrollerVelocityScalar` scales its speed.
  Under reduced motion the neighbors a drag passes and a dropped item take their slots at once; the lifted look
  still fades.
  Keyboard: Alt+arrow along the axis moves the focused item one slot, Alt+Home/Alt+End move it to either end; a move
  past either end is still handled, so it never reaches the browser (Chrome's Alt+Left/Alt+Right Back/Forward).
  A screen reader hears each move by key, screen-reader action, or drop, and each reorder key past an end, in English
  or Thai; a held key speaks once, where the item ends, when it is let go. `moveAnnouncement`, `atStartAnnouncement`,
  and `atEndAnnouncement` replace the texts, and an empty one stays silent.
  An item that holds focus, on its own node or one inside it, stays alive with its State and focus when a scroll, the
  user's or the app's, takes it out of view, and the list scrolls nothing for it; Tab, Shift+Tab, or an arrow key from
  it brings it back into view first, then moves focus; an app's own `nextFocus()`, `previousFocus()`, or
  `focusInDirection()` on it brings it back the same way, and when the app holds the scroll so it cannot come back,
  focus goes to the first item that shows (the last, going backward), and with none showing it leaves the list that
  way; a focus that moves elsewhere lets it go.
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

  Insert and remove: pass a `ReorderableItemsController` as `itemsController` (not the scroll `controller`) and call
  `insertItem(index)` or `removeItem(index)` in the turn of the data change, outside a build and `onReorderItem`,
  `onReorderStart`, and `onReorderEnd`; from those, call after the frame.
  An added item grows and fades in over the theme's `normal` level; a removed one shrinks and fades out in its current
  look unless `removeItem`'s `builder` gives another; `itemTransitionBuilder(context, animation, child)` replaces size
  and fade both ways. Without `builder`, a removed item's leaving copy ends at once if its key returns; a `builder`
  keeps it fading in its own look. The leaving item keeps its State and rebuilds: an item reading data through `context`
  (`watch` or `select` by id or index, a provider family) needs a `builder` capturing that data. Under reduced motion,
  or with `itemExtent`, `itemExtentBuilder`, or `prototypeItem`, the size jumps and the fade plays.
  Until flutter/flutter#193710 ships, an item with its own semantics boundary (nested scroll view, tappable
  `StratumInkWell`, `Semantics(container: true)`) asserts at `object.dart:6723` in debug with semantics on (every
  `testWidgets`) when an `itemTransitionBuilder` fades it through opacity 0 or a focused far `moveItem` lands where the
  frame does not lay it out (uneven heights, app-held scroll). Check a removed item's semantics after its exit, or walk
  the live semantics tree: `find.bySemanticsLabel` reads a stale debug cache for excluded subtrees.
  Focus on a removed item, or on one dropped from the data with no call (a remove, a replace, or, with no
  `findChildIndexCallback`, a reorder), moves to the next item, else the previous, else the nearest item with a
  focusable node, else a focusable list's Tab stop, and the list shows it, unless the app moves focus in the same turn
  or after the frame. A focused item removed and inserted back with its key in the same turn keeps focus instead and
  shows on screen. Reordering a leaving item's neighbor ends the leaving item. During a drag, an `insertItem`,
  `removeItem`, `moveItem`, key or screen-reader move, item-count change, or same-count data change that moves or
  replaces the dragged item ends it first, and a pointer cancel or a second pointer's takeover ends it, each with
  `onReorderEnd` at its start index and no `onReorderItem`; key and screen-reader moves then report their own. Every
  drag ends with exactly one `onReorderEnd`; a drop reports the index Flutter's reorderable list gives it.

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

  Move: call `moveItem(from, to)` in the turn of the data move, where `to` is the item's final index, as `onReorderItem`
  reports it. The old slot closes while the item grows and fades into its new one over the theme's `normal` level (at
  once under reduced motion or a fixed extent, where the item only fades in); the item keeps its State and focus, and a
  focused item keeps its State and shows on screen at every distance, unless the app moves focus in the same turn: that
  focus stays, and the item keeps its State only when its new slot is built. At the next frame's start, the list scrolls
  toward a moved item: `position.pixels` read right after `moveItem`, or inside `onReorderItem` of a key or
  screen-reader move, has not moved yet. `onReorderItem` does not fire. Prefer it to `removeItem` plus `insertItem`,
  which keeps an unfocused item's State only when its new slot is built; a focused item removed and inserted back in the
  same turn keeps its State too. The buttons above can call it.
  An app reordering its data without `moveItem`, as a live sync does, passes `findChildIndexCallback`, which reads the
  app's O(1) key-to-index map, kept in sync: a focused moved item then keeps its State and focus at every distance and
  shows on screen, and an item the app keeps alive follows the reorder. A focused item already out of view follows its
  new place off screen with its State and focus; the list scrolls nothing for it until the next focus move or reorder
  key brings it back.

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

## Screen corner radius

- `context.deviceWindow.radius` is the screen's corner radii as a `BorderRadius?`: Android API 31+, iOS 26+, and
  macOS 27+ under a `StratumThemeApplication`; null everywhere else. Always pass a fallback:
  `context.deviceWindow.radius ?? BorderRadius.zero`. A reader rebuilds only when the radius changes. The app writes
  no setup code for it.

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
  under reduced motion, and never changes the child's layout size. Its colors stay below 3:1 by design in the light
  and dark themes (WCAG 1.4.11), and both high-contrast themes give the outside ring 3:1 or more; pass `customColor`
  where an app needs that ratio in light or dark.
- **`StratumInkWell`** — the tap surface every `interaction` builds on. Its own hover and press overlay fades over
  the theme's `fast` level and snaps straight to its target color under reduced motion, same as the ring above it.
  `tapTargetSize` (default `TapTargetSize.platform`) grows its layout and hit area to the platform minimum
  when `child` is smaller; pass `TapTargetSize.shrinkWrap` to keep `child`'s own size in a dense UI.
  `Interaction.tapTargetSize` carries the same choice to every `BoxLayout` (`ContainerLayout`, `ColumnLayout`,
  `RowLayout`, `StackLayout`, `WrapLayout`) with a tap surface, so a dense `BoxLayout` opts out the same way.
  `onHover` reports a pointer over the surface while it is enabled: turning disabled under a still pointer, by its own
  `disabled` or a disabled component around it, calls `onHover(false)` once, and turning enabled again under it calls
  `onHover(true)` once.
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
- A component's size hook is `resolveDefaultSize(context)`: the widget's `size` when set, else
  `resolveTheme(context).defaultWidgetSize`, so a subclass that overrides `resolveTheme` sets its own default size.
  `resolveSize` is its deprecated old name, kept one minor version.

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
- **Custom text size** — `StratumTextStyle.body.size(15)` sets a custom size of 15 logical pixels, with the metrics
  of the nearest named size. The size must be a finite number above 0: a debug build asserts it, and a release build
  skips the assert and reads any other size as unset, so the text takes `s16` for its size and its metrics.
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
  `StratumThemePreloader` or `StratumSplashScreen`, under `tester.runAsync`.
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
  highContrast:, componentDefaults:, componentPartDefaults:, child:)` publishes the controller's active theme and
  rebuilds dependents once per switch; below it, `StratumThemeController.of(context)` and `maybeOf(context)` find the
  controller, so a theme picker calls `StratumThemeController.of(context).switchTo('brand')`.
  `StratumThemeApplication(themes:)` stays for a fixed theme set.
- **`StratumThemePreloader`** — the widget form of `preload`: `StratumThemePreloader(initialThemeId:,
  onThemeChanged:, googleFontsTimeout:, loading:, error:, builder: (context, controller) => ...)` shows `loading`
  until the start theme is active, then `builder`, or `error` with what preload threw; it reads its asset bundle from
  `DefaultAssetBundle` and disposes its controller when it leaves the tree. Pick it or `await preload(...)` before
  `runApp`, not both.
- **`StratumSplashScreen`** — the splash an app shows while it starts: place it above `MaterialApp` as the root of
  `runApp`, instead of `StratumThemePreloader` or an awaited `preload`. It keeps the platform's launch screen, or on
  the web the page's own loader, until the start theme is active, then runs `postload` with the controller and hands
  the one required `builder` one `StratumSplashState` at a time; the package draws no splash look, so the builder
  draws every state, the failure and its retry button included, and returns the app itself, never a route, at
  `StratumSplashDone`:

  ```dart
  runApp(
    StratumSplashScreen<AppData>(
      initialThemeId: savedThemeId,
      onThemeChanged: saveThemeId,
      themeMode: ThemeMode.system, // the modes the app gives its theme application
      postload: (context, controller) => loadAppData(), // bound its own time limits
      minimumDuration: firstLaunch ? const Duration(seconds: 2) : Duration.zero,
      builder: (context, state) => switch (state) {
        StratumSplashLoadingTheme() || StratumSplashLoadingApp() => const BrandSplash(),
        StratumSplashFailed(:final error, :final retry) =>
          BrandFailure(error: error, onRetry: retry),
        StratumSplashDone(:final controller, :final data) => MaterialApp(
          builder: (context, child) => StratumThemeApplication.controlled(
            controller: controller,
            themeMode: ThemeMode.system,
            child: child!,
          ),
          home: HomePage(data: data),
        ),
      },
    ),
  );
  ```

  `postload`'s context sits above the splash's own theme scope: read the active theme through `controller`, never
  `StratumTheme.of(context)`. If your own `AssetBundle` cannot read the package's embedded default theme either, the
  failed frame has no theme above it at all, and the read failure reaches `FlutterError.reportError` on its own; fix
  the bundle, since the package has nothing left to fall back to.

  Every frame before done has no `Overlay` and no `Localizations` above it — no `Tooltip`, no `TextField` — until
  the app's own `MaterialApp`. The splash wraps those frames in its own `Shortcuts`/`Actions` of
  `WidgetsApp.defaultShortcuts`/`defaultActions`, so Tab still reaches a focusable retry button and Enter or Space
  still activates it.

  `StratumSplashFailed.phase` says which step failed, `StratumSplashPhase.theme` (its `error` is the theme file's
  `StratumThemeFormatException`) or `StratumSplashPhase.postload` (what `postload` threw); `retry` runs that step
  again and the builder gets its loading state, while `minimumDuration` keeps counting from the first frame.
  `StratumSplashFailed.stackTrace` is `error`'s stack trace, `StackTrace.empty` when none was caught with it, for
  your own crash reporting. After a theme failure the builder's frames read the package default theme alone. Screen
  readers hear the built-in "Loading" label (Thai on a Thai device), or your `loadingLabel`, on every loading frame
  your builder draws. The app takes over in place by `exitTransition`, default `ScreenTransitionType.fadeThrough`,
  on the theme's `slow` level and `standard` curve unless you pass `exitDuration` and `exitCurve`; every type but
  `platform` and `cupertino` works, and reduced motion keeps only the fade a type has, as page routes do. Above
  `MaterialApp` the platform locale picks the text
  direction. On the web, remove your page's loader when `window` dispatches `stratum-splash-shown`:
  `window.addEventListener('stratum-splash-shown', () => document.getElementById('loader')?.remove());`. Keep
  first-launch timing in your own storage: the package stores nothing.
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
- **Supported zip tools** — make a theme zip with `pack` or with 7-Zip, the two zip tools measured against the install;
  a zip Windows Explorer makes is not measured, so run `check` on it before you upload it.
- **Disabled opacity and scrim** — `opacity.disabled` in `theme.yaml`, a number from 0 to 1, is the opacity every
  disabled component paints at, and `opacity.scrim` is a modal layout's background scrim opacity; the package
  default sets 0.5 for both, and an app theme may leave the group out. Read them as
  `StratumThemeApplication.of(context).opacity.disabled` and `.opacity.scrim`. A value outside 0 to 1 throws
  `StratumThemeFormatException` with `expected_opacity` at its path, and a third key under `opacity` is
  `unknown_key`. The package default reads `$schema: stratum-theme/v1.4.0`; this package reads every `v1.0` to
  `v1.4` theme, while a package build that reads only up to `v1.2` refuses a `v1.3` theme as
  `unsupported_schema`, so a theme that must load on every build writes `v1.0.0` and leaves `opacity` out; one that
  must load on every build from `v1.1` on writes `v1.1.0` and keeps `disabled` but leaves `scrim` out.
- **Border, shadow, and blur tokens** — `border`, `shadow`, and `blur` in `theme.yaml` (format
  `stratum-theme/v1.2.0`) set every border width, drop shadow, and background blur, and the package default carries
  the Figma values. Read them in `build`: `StratumTheme.of(context).border.md` (a `double`; `sm` 0.5, `md` 1, `lg`
  1.5, and `md` is the usual width), `.shadow.level1` to `.level6` (each a `List<BoxShadow>` for
  `WidgetStyle.dropShadow`, colored from the active color set, so dark and high-contrast themes get their own), and
  `.blur.level1` to `.level6` (each an `ImageBlurFilter` for `WidgetStyle.backgroundBlur`, sigma half the Figma
  radius): `WidgetStyle(border: Border.all(width: theme.border.md, color: theme.color.border.defaults.normal),
  dropShadow: theme.shadow.level2, backgroundBlur: theme.blur.level3)`. A theme sets `border: {md: 2}`,
  `blur: {"3": 24}`, or a `shadow."2"` list of layers such as
  `{x: 0, y: 4, blur: 8, spread: 0, color: "{color.shadow.secondary}"}`, where `blur` is the Figma blur radius and
  `color` is a quoted hex, a `{palette...}` or `{transparent...}` alias, or `"{color.<group>.<name>}"`, a token of
  each color set; a list of at most 8 layers replaces the default's whole, and `[]` is no shadow. Every length a
  theme sets, in `space`, `radius`, `layouts` (the `N` of a `"N%"` too), `border`, `blur`, a layer's `x`, `y`, `blur`,
  and `spread`, and `typography` (`adjustSize`, each `scaleByWindowSize` entry, `spaceHeight`, and `letterSpacing`,
  the `N` of a `"N%"` too, negatives included), is a finite number from -10000 to 10000, and from 0 for `border`,
  `blur`, and a layer's `blur`. A bad value throws `StratumThemeFormatException` with `expected_dimension`,
  `expected_shadow`, or `expected_color` at its path, and a key the default lacks, such as `shadow.7`, is
  `unknown_key`. A `typography` that draws some text at a font size or a line box of 0 px or less is
  `expected_dimension` too: at text scale 1 the package tries every size `s10` to `s56`, with no window size and at
  each one, in every font a tag gives the type, and blames the `adjustSize`, the `scaleByWindowSize` entry, or the
  `spaceHeight` that does it, once per path, in the app and in the `stratum_theme` CLI alike. A package build
  that reads only up to `v1.1` refuses a
  `v1.2` theme as `unsupported_schema`, so a theme that must load there writes `v1.1.0` and leaves the three groups
  out. `AppBorder`, `AppShadow`, `AppFilter`, `StratumThemeData.filter`, and `screenBorderRadius` no longer exist;
  read the screen's corner radius from `context.deviceWindow.radius` (see Screen corner radius).
- **System bar look** — `system` in `theme.yaml` (format `stratum-theme/v1.4.0`) sets how the status bar and the
  navigation bar look, in `light` and `dark` and the optional partial overlays `highContrastLight` and
  `highContrastDark`, as `color` does: `statusBarIcons` and `navigationBarIcons` (`auto`, `light`, or `dark`; `auto`
  picks the icon color of higher contrast against what the page paints under the bar), `statusBarColor`,
  `navigationBarColor`, `navigationBarDividerColor`, and `appSwitcherColor` (a quoted hex or a color alias such as
  `"{color.light.background.default.normal}"`), and `statusBarContrast` and `navigationBarContrast` (`true` or
  `false`, Android's own contrast scrim). The package default sets `auto` icons, transparent bars, `false` and
  `true`, and the page background. The bar mode, the rotation lock, and the app switcher label are set in Dart only
  (see System bars): a `system` set holding `barMode`, `orientations`, or `appSwitcherLabel` throws
  `StratumThemeFormatException` with `unknown_key`, a bad icons value `expected_bar_icons`, and a bad flag
  `expected_boolean`. A package build that reads only up to `v1.3` refuses a `v1.4` theme as `unsupported_schema`.
- Read the theme data, its default widget size, and the window size where a widget sits:
  `context.themeData()` (or `context.themeData(ThemeMode.dark)`), `context.defaultWidgetSize()`, and
  `context.windowSize`. Each throws a `FlutterError`: `themeData` and `defaultWidgetSize` name the missing
  `StratumThemeApplication`; the window-size error says how to wrap the app.
- **App-wide component defaults** — `StratumThemeApplication(componentDefaults: (theme) => {MyWidget:
  WidgetStyle(...)}, ...)` restyles every instance of a component type from one place; read it in a component's
  `build` through `StratumWidgetProps.resolveStyle`, never directly. A component drawn in several parts, such as a
  page layout, a modal layout, or a notice, instead takes `componentPartDefaults: (theme) => {ModalLayout:
  ModalLayoutStyle(...)}`, one parts style per component type; read it through
  `StratumComponentDefaults.partsOf<ModalLayoutStyle>(context, ModalLayout)`, null when none is registered, and a
  thrown `FlutterError` naming both types when the registered value is not a `ModalLayoutStyle`. Both builders run
  again whenever the active theme changes, and `StratumThemeApplication.wrap` copies both to a nested application.
  Under `StratumApplication`, pass both to it instead (see App assembly).

## App assembly

- Wrap the app once:

  ```dart
  StratumApplication(
    initialThemeId: savedId,
    onThemeChanged: save,
    themeMode: savedMode,
    webZoom: (child) => StratumWebZoom(child: child),
    appBuilder: (context, stratum) => MaterialApp.router(
      theme: stratum.theme,
      darkTheme: stratum.darkTheme,
      themeMode: stratum.themeMode,
      builder: stratum.builder,
      routerConfig: router,
    ),
  )
  ```

  `stratum.builder` inserts the theme application, the update gate, the notice host (`notices: false` leaves it
  out), and web zoom, outer to inner; your router, locales, and providers stay yours. With a builder of your own,
  chain it: `builder: (context, child) => stratum.builder(context, MyWrapper(child: child!))`. `CupertinoApp` and
  `WidgetsApp` take the same `builder`. Add the `## Install` override lines first.
- `appBuilder` runs again on a theme switch, a `StratumApplication` rebuild, and a change of window size class, text
  scale, or platform locale: build the router and providers outside it.
- `themeMode:`, `highContrast:`, and `componentDefaults:` go on `StratumApplication`, which forwards them to the theme
  application; pass `stratum.themeMode` to the app widget. Never set the mode on `MaterialApp(themeMode:)` alone: the
  theme application inside its builder keeps the wrapper's `themeMode` (default `ThemeMode.system`) on every route.
- `controller:` hands in a `StratumThemeController` you hold, which the wrapper never disposes. With one, the preload
  inputs (`initialThemeId`, `onThemeChanged`, `googleFontsTimeout`, `remoteThemes`, `onRemoteThemeError`, `error`,
  `loadingBuilder`) are ignored; with none, the wrapper reads the first five once, at its first build.
- `loadingBuilder:` replaces the theme's background color shown until the start theme is active. `error:` is the
  frame for a start theme that fails to load, and the failure reaches only it, so log it there; with none, the failure
  goes to `FlutterError.reportError` and the background stays. Both build above the app widget, with no
  `Directionality` or theme: give a `Text` its `textDirection`.
- `onRemoteThemeError:` gets each kept zip that fails to install, so you delete it and download it again; with none,
  the failure goes to `FlutterError.reportError` instead.
- `updateGate:` wraps the inner layers in your own update gate; see Update gate.
- `noticeHost:` replaces the plain notice host `notices: true` builds; see Notices. Mount one `StratumApplication`
  with `notices: true` per process: the notice host is process-wide, so every other view's wrapper passes
  `notices: false`.
- `systemStyle:` forwards the app-wide system bar style to the theme application; see System bars.
- `componentPartDefaults:` forwards the app-wide parts style per component type to the theme application; see
  Themes, App-wide component defaults.

## System bars

- **The theme's look** — `StratumTheme.of(context).systemStyle` is the theme's `SystemStyle` for the active mode: the
  look of the status bar and the navigation bar from the theme file's `system` set (see System bar look), with no bar
  mode, rotation lock, or app switcher label. `AppSystemUI` and `systemOverlayStyle` no longer exist, and the Material
  theme sets no app bar overlay style.
- **App-wide** — `StratumThemeApplication(systemStyle: SystemStyle(...))`, on both constructors, sets the app-wide
  layer over the theme's look: any look field, plus `barMode` (`SystemBarMode.edgeToEdge`, `immersive`,
  `immersiveSticky`, `leanBack`, `topOnly`, or `bottomOnly`), `orientations` (such as
  `[DeviceOrientation.portraitUp]`), and `appSwitcherLabel`, passed in the user's language. A null field takes the
  layer below. The application leaves the platform's own bar mode and rotation lock untouched until some layer sets
  `barMode` or `orientations`; once one has, an unset field falls back to `edgeToEdge` and no lock. An app that locks
  rotation in `AndroidManifest.xml` or hides the status bar in `Info.plist` keeps that native setting on its own, but
  once any page sets `orientations` or `barMode`, declare the app-wide lock or mode here instead, since Flutter
  cannot read the native value back. The application applies the merged style after each frame and is the
  one writer of the system chrome: never call `SystemChrome.setSystemUIOverlayStyle`, `setEnabledSystemUIMode`, or
  `setPreferredOrientations` yourself, and never set `AppBar.systemOverlayStyle` to force the icons; set
  `statusBarIcons` instead. The application paints `statusBarColor`, and on Android `navigationBarColor` with its
  `navigationBarDividerColor` line, under the bars itself, above every page, and sends the platform transparent bar
  colors, so a bar color shows on every Android version and on iOS; leave a bar color transparent for an edge-to-edge
  page. `auto` icons pick light or dark against what paints under each bar, the bar color the topmost, else the
  theme's page background; with no label set, the app widget's `title` shows, except a web router app with no
  `title:` of its own, which builds no `Title` widget to read — pass `title:` or an app-wide `appSwitcherLabel`.
  On the web only the label and
  `appSwitcherColor`, the browser theme color, apply; the bar mode and the rotation lock apply on Android and iOS
  only, and a platform that ignores a setting shows no error.
- **Per page** — wrap any screen, or a part of it, in `SystemStyleScope(style: SystemStyle(...), child: ...)`, with
  or without a page layout and on any router: its look fields apply at a bar its child covers, and its `barMode`,
  `orientations`, and `appSwitcherLabel` apply while its child paints. A dialog or sheet over the page keeps them, a
  pushed page with no scope returns to the app-wide style, and pop restores the page's own, with no
  `NavigatorObserver` and no restore code; only the shown tab of an `IndexedStack` counts. An inner scope wins field
  by field over an outer one. Pass the label in the user's language (FO-09).
- **Fill under a bar** — wrap every surface that paints under the status bar or the navigation bar, such as a
  header, a full-screen video, or a translucent scrim, in `SystemBarFill(color: <the color it paints>, child: ...)`,
  so `auto` icons pick the color of higher contrast against it. A translucent color blends over the fills beneath it.
  Neither `SystemStyleScope` nor `SystemBarFill` paints, adds a semantics node, takes focus, or handles a gesture; a
  bar color a scope sets, the application paints under the bar.

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

## Modal layout

- **`showModalLayout`** — `final value = await showModalLayout<T>(context, builder: (c) => ModalLayout(top: ...,
  body: ...))` shows a bottom sheet on a phone and a centered modal on a tablet and up; pass `type:` to fix one. It
  completes with the value `Navigator.pop(c, value)` closes it with, or null when the user dismisses it by Esc, a tap
  outside, back, a drag down, the handle, or the close button. The route dims and blurs the page with the theme's
  scrim (`opacity.scrim`, `blur.level1`); `showBackground: false` drops the scrim, while the page still refuses taps
  and a tap on it closes the modal. `semanticsLabel:` replaces the built-in "Dialog" or "Sheet" screen-reader label.
  Focus moves in, Tab stays inside, and focus returns to the opener on close. It enters over the theme's `normal`
  level and fades with no slide under reduced motion. It opens on the root navigator, so it also covers a tab bar
  outside a nested navigator; `useRootNavigator: false` keeps it in the nearest one. After every drag a sheet
  settles on its nearest resting height, hidden, half, or full, over the `fast` level (at once under reduced
  motion); settling hidden closes it with null, unless a `PopScope` keeps it open, which brings it back to full
  height. A sheet rises with the keyboard and takes the screen radius and the status-bar inset once dragged to the
  top; a modal moves clear of the keyboard. A body list with `scrollBody: false` hands a drag past its top to the
  sheet. Every vertical list in a sheet with no `controller` of its own shares the sheet's scroll controller, on
  desktop too, so give each extra list its own `controller`; two lists sharing it break the desktop scrollbar drag.
  Any widget works in it, a `ListTile` included.
- **`ModalLayout`** — the slot widget of every sheet and modal: `ModalLayout(top: title, tab: tabs, body: content)`
  shows an optional `top`, an optional `tab`, and the required `body`, in that order; a null slot shows nothing. The
  `body` scrolls inside the surface when the surface has a bounded height; in an unbounded parent, such as a
  scrolling page, it sizes to its content.
- **List body** — a body that scrolls itself, such as `ListView.builder`, takes `scrollBody: false`: it then gets the
  height left unwrapped, with no second scroll view around it.
- **Type and size** — `type: ModalLayoutType.bottomSheet`, `.floating`, or `.modal`; null picks a bottom sheet
  below the tablet window size and a centered modal at tablet and up. `size: ModalLayoutSize.medium` (400, the
  default), `.large` (800), `.extraLarge` (1000), or `.fillWidth` (the window less the theme's `lg` space on each
  side); every width clamps to the window less that margin on each side, and below tablet a bottom sheet takes the
  full width and a floating sheet the width less 8 on each side, both ignoring `size`.
- **Corners** — set by the type and the screen's own corners (`context.deviceWindow.radius`): a bottom sheet's top
  corners take the theme's `radius.sheet` token and its bottom corners the screen radius; a floating sheet's corners
  are the screen radius less 8, else 38; a modal's take `radius.card-large`. `borderRadius` wins over that rule, and
  `customStyle`'s surface radius wins over `borderRadius`. `fullHeight: true` gives a bottom sheet the screen radius
  on top.
- **Close and handle** — `showClose` (default true) shows a close button at the top end corner; a bottom sheet also
  shows a drag handle. Both call `onClose`, else dismiss the route of `showModalLayout`. Inline with no `onClose`,
  no close button shows and the handle draws as decoration that screen readers and Tab skip, so pass `onClose` to
  let the EndUser close an inline layout. Tab visits `top`, `tab`, and `body`, then the handle and the close
  button.
- **Insets** — `safeArea` (null: true for a sheet, false for a modal) keeps a sheet's content above the home
  indicator, and below the status bar once `fullHeight`; on a modal it keeps clear of every inset.
- **Style** — `customStyle: ModalLayoutStyle(surface:, top:, tab:, body:, handle:, close:)`, one `WidgetStyle` per
  part, each merged over the theme defaults (the default background with `shadow.level4`, and the close button's
  `blur.level3`), then over the app-wide `componentPartDefaults` entry for `ModalLayout`.
- Placed inline in a page it draws its surface and slots with no scrim and no route.

## Split layout

- **`SplitLayout`** — `SplitLayout(panes: [SplitPane(size: 320, min: 240, max: 480, child: list), SplitPane(flex: 1,
  min: 320, child: detail)])` splits a body into panes along `axis` (default horizontal; under right-to-left text the
  first pane sits on the right). A null pane hides and the others fill the split; `resizable: false` turns every
  divider off. The split needs a bounded width (or height, vertical).
- **Resize** — the EndUser drags a divider, steps it by the arrow keys along the axis (16 px, 64 with Shift), jumps
  by Home and End to the start pane's min and max, or uses a screen reader's increase and decrease actions; every
  move stays within both panes' `min` and `max`. Each divider is a Tab stop with the focus ring and reads as a slider
  valued by the start pane's percent; `dividerLabel:` replaces the built-in "Resize panes" label.
- **Divider look** — nothing paints by default and the divider takes no space, so the panes stay flush; its hit area
  is the platform's minimum target size centered on the seam, with a resize cursor on hover; a tap, a scroll, or a
  drag across the axis that starts there still reaches the pane content under it. Paint one with
  `dividerBuilder: (context, state) => ...`, where `state.hovered`, `state.dragging`, and `state.focused` pick the
  look; the widget fills the hit area, so center a thin line in it and read its color from a theme token.
- **Keep widths** — Stratum stores nothing. Pass a `SplitLayoutController(fractions: saved)` to restore kept
  fractions (one per pane in `panes`, a null pane included; a null entry is a pane with no choice yet, which opens
  at its own `size` or `flex`), listen to it to save `controller.fractions`, and set
  `controller.fractions = [...]` from code. It notifies once per settled move (a drag's end, one key step, a slider
  action, or a code set), never per drag frame and never when a narrow window only squeezes the panes. A saved entry
  that is NaN, infinite, or negative reads as null, so a corrupt value opens the pane at its own size. With no
  controller the split makes and disposes its own; it never disposes one you pass.

## Page layout

- **`PageLayout`** — `PageLayout(header: ..., left: ..., top: ..., tab: ..., body: ..., bottom: ..., right: ...,
  footer: ..., snack: ...)` lays out a page in Figma's slot geometry: `header` on top, `left` full height beside a
  main column of `top` over the center column (`tab`, `body`, `bottom`) and `right`, `footer` at the end, and
  `snack` floating at the bottom center. A null slot takes no space; under right-to-left text `left` sits on the
  right. Each slot hosts any widget, a `ListTile` included, with no `Scaffold`. The page needs bounded constraints.
  `systemStyle: SystemStyle(...)` sets this page's system bar style as an inner scope over the app-wide one.
- **Rebuild scope** — slots take plain widgets, so you pick what rebuilds: put a `BlocBuilder`, `BlocSelector`,
  `Consumer` (Riverpod), or `context.select` (Provider) inside one slot to rebuild only that slot, or around the
  whole `PageLayout` to rebuild every slot.
- **Insets** — every slot that touches a screen edge runs its fill under the status bar, home indicator, or side
  inset while its content pads by it; `body` instead hands its top and bottom insets to its children, so a body
  `ListView` scrolls under the home indicator with its last row clear. `safeArea: PageSafeArea(top: false)` turns a
  side's padding off (`left` and `right` name the start and end sides); the slot on that edge still hands the inset
  to its children, so a `SafeArea` or an `AppBar` inside pads itself. A nested `PageLayout` pads nothing twice.
- **Keyboard** — the page above `footer` ends at the keyboard's top, so `bottom` rides above it and `footer` stays
  docked under it; `resizeToAvoidKeyboard: false` lets the keyboard cover the page.
- **Loading** — `loading: true` fades in a layer that refuses taps and keyboard focus and reads as "Loading"; focus
  returns to where it sat once `loading` turns false. Pass `loadingBuilder:` to draw your own spinner.
- **Style** — `customStyle: PageLayoutStyle(outer:, header:, top:, tab:, left:, body:, right:, bottom:, footer:,
  snack:)`, merged over the theme (edge slots `background.default.surface`, page and body
  `background.default.normal`), then over the app-wide `componentPartDefaults` entry for `PageLayout`.
- **Drawers** — below `drawerCut` (default `WindowSize.tablet`), `left` and `right` are drawers that take no space; at
  the cut and up they sit inline. Open one from a menu button with `PageLayout.of(context).openLeft()` (or
  `openRight()`), close it with `close()`, and listen with `onDrawerChanged:` (the side that opened, then null once it
  closed); `openLeft()` on a side shown inline does nothing. The EndUser also opens one by a swipe from its screen edge
  (never from the iOS start edge of a page that can go back, and never with `edgeSwipe: false`) and closes it by the
  scrim, Esc, back, or a drag. `leftSide: PageSide(type: PageDrawerType.back, pageScale: 0.9, maxWidth: 320)` picks the
  type (`front`, `back`, `slide`, `permanent`, or `page`; default `slide` on iOS, `front` elsewhere), the width bounds
  (80% of the screen, up to 360 by default), an optional page scale, and `semanticsLabel:`. A `page` drawer opens as a
  new page that sits outside the `PageLayout`, so close it with `Navigator.pop`, never `PageLayout.of`. A drawer open
  when the window grows past the cut closes (`onDrawerChanged` hears null after that frame) and the side shows inline.
- **Side panes** — at the cut and up, `left` and `right` sit beside the center column as `SplitLayout` panes the
  EndUser resizes by drag, arrow keys, Home, and End, within the side's `minWidth` and `maxWidth`; on either divider
  End widens the side pane to its maximum, Home narrows it to its minimum, and the slider reads its share, while
  the arrows move by screen direction. Nothing paints
  between a pane and the center column; paint a line with `leftDividerBuilder:` or `rightDividerBuilder:`, the same
  `(context, state)` shape as `SplitLayout.dividerBuilder`. A pane opens at the controller's chosen width, else at
  Figma's (`left` 280 and `right` 380 at `bigDesktop`; 260 and 320 below). The center column keeps at least
  `minCenterWidth` (default 320): a divider stops there, and a narrow window narrows the panes first.
  `rightAsOverlay: true` instead opens `right` at the cut and up as a front drawer over a scrim, 450 wide at
  `bigDesktop` and 400 below (never wider than the screen), with a close button; open it with `openRight()`.
- **Controller** — `PageLayout.of(context)` returns the page's `PageLayoutController`, which opens and closes its
  drawers; pass your own `PageLayoutController(leftWidth:, rightWidth:)` to restore kept side pane widths, listen to
  it to save `leftWidth` and `rightWidth`, and set them from code. It notifies once per settled resize (a drag's end,
  a key step, or a code set), never per drag frame and never when a narrow window only squeezes a pane. A saved
  width that is NaN, infinite, or negative reads as null, so a corrupt value opens Figma's width. The page disposes
  only the one it makes.

## Hover and focus observers

- **`HoverBuilder`** — `HoverBuilder(builder: (context, hovered, child) => ..., child: c, onHover: (hovered) {})`
  builds a look from whether a pointer is over what it builds. It only observes: no Tab stop, focus ring, tap, hover
  overlay, cursor, or size of its own; for those, use `ContainerLayout(interaction:)`. `builder` and `onHover` run only
  when `hovered` changes, also when content scrolls under a still mouse, never on each pointer move; `child` reaches
  `builder` without rebuilding. Touch screens have no hover, so never put content or an action behind hover alone.
- **`FocusBuilder`** — `FocusBuilder(builder: (context, focused, child) => ..., onFocusChange: (focused) {})` builds a
  look from whether focus sits anywhere inside, a tap's focus included, as the web's `:focus-within` does; moving
  focus between fields inside calls nothing. It adds no Tab stop. Its `focused` differs on purpose from
  `InteractionState.focused`, which follows the focus ring.
- **Both** — `semantics: SemanticsProperties(label: ...)` labels the wrapped group in one node a screen reader reads
  before the fields inside; null adds no node. Inside a disabled component both read false and call no listener. Pair
  every hover or focus color with text, an icon, or a shape.

  ```dart
  FocusBuilder(
    semantics: const SemanticsProperties(label: 'ที่อยู่จัดส่ง'),
    builder: (context, focused, child) => ContainerLayout(
      style: focused ? focusedSectionStyle : sectionStyle,
      child: child,
    ),
    child: ColumnLayout(children: [streetField, cityField]),
  )
  ```

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

## Placeholder page

- **`StratumPlaceholderPage`** — put `StratumPlaceholderPage()` in the body of a page whose screen is not built yet.
  It fills the space it gets and shows the built-in title "Coming soon" (Thai "เร็วๆ นี้" for a Thai locale), centered.
  `title` replaces that title, also for screen readers; `message` adds centered text below it; `icon` adds an icon
  above it, sized 48 in the theme's secondary icon color and skipped by screen readers. The title reads as a heading.
  It adds no app bar or back button: the app's own page and navigation carry them. Text wraps, and the page scrolls
  when it is taller than its space.

## Update gate

- Under `StratumApplication`, pass `updateGate: (child) => StratumUpdateGate(..., child: child)` instead of placing
  the gate yourself (see App assembly).
- **`StratumUpdateGate`** — wrap the app's navigator in `MaterialApp.builder`, below `StratumThemeApplication`, so the
  gate covers every route. It asks your `UpdateChecker` and draws nothing itself: `builder` returns your own screen
  for each `UpdateGateState`.

  ```dart
  MaterialApp(
    builder: (context, child) => StratumThemeApplication(
      themes: themes,
      themeMode: ThemeMode.system,
      child: StratumUpdateGate(
        checker: AppUpdateChecker(),
        builder: (context, gate) => switch (gate) {
          UpdateGateRequired() => const ForceUpdateScreen(),
          UpdateGateMaintenance(:final retry, :final checking) =>
            MaintenanceScreen(onRetry: checking ? null : retry),
          UpdateGateAvailable(:final dismiss, :final checking) =>
            UpdateDialog(onLater: dismiss, busy: checking),
        },
        child: child!,
      ),
    ),
  );
  ```

- **`UpdateChecker`** — implement `Future<UpdateStatus> check()`: read your remote settings, package version, and
  store version, and answer `UpdateStatus.upToDate`, `.available`, `.required`, or `.maintenance`. The package calls
  no store, plugin, or backend. A thrown error shows the app, never a lockout; log it in your checker. The gate asks
  when it mounts, on each return to the foreground, and on `retry`, one ask at a time, and sets no time limit: give
  `check` your own timeout.
- **Full screens** — `UpdateGateRequired` (no way on) and `UpdateGateMaintenance` (call `retry`) replace the
  navigator, so the app's pages start over from the first page once the gate shows the app again; screens swap with
  no animation. While a later ask runs, the gate keeps the shown screen and sets `checking`: show a busy cue and
  disable retry, since a retry during an ask does nothing. Your update button runs your own store or installer code;
  the gate takes no update callback. Each screen opens as a screen of its own: focus moves in, and a screen reader
  announces it. A tooltip or a text field works on it, since it sits in an overlay of the gate's own. No navigator
  exists while a full screen shows: build it without routes or dialogs of its own, and guard any global
  `navigatorKey` use, such as from a push-notification handler, against a null `currentState`.
- **The update dialog** — `UpdateGateAvailable` opens your dialog once per gate lifetime, as a route on your app's
  navigator over the page it shows; a new launch may offer it again, since the package stores nothing. Draw its scrim
  and card yourself: the route paints nothing and runs no transition. While it shows, taps, focus, and screen readers
  stay away from the pages behind it, focus moves into it, and Tab stays inside it. The Android back button closes the
  dialog alone, so the user stays on the page they were on, and Esc calls `dismiss`. Call `dismiss` from your later
  button, and from a scrim tap if you want one. A later ask that answers anything but `available` — up to date,
  required, maintenance, or a failure — closes it first. The gate needs a navigator below it, as `MaterialApp.builder`
  gives.

## Notices

- Under `StratumApplication`, pass `noticeHost:` to customize the host, or keep `notices: true`, instead of placing
  one yourself (see App assembly).
- **`StratumToastHost`** — place it once in `MaterialApp.builder`, below `StratumThemeApplication` and above the app's
  navigator, so every notice shows above every route, modal routes included. It wraps `toastification` itself: call
  `context.showToast(...)`, never `toastification.show`, since a raw call can freeze the wrong per-alignment config.
  An app that already wraps its root in its own `ToastificationWrapper` keeps it; the host adds none. One solid notice
  shows at a time (further ones queue in call order), and float notices stack up to 3 per corner, the newest nearest
  the screen edge; a fourth closes that corner's oldest.

  ```dart
  MaterialApp(
    builder: (context, child) => StratumThemeApplication(
      themes: themes,
      themeMode: ThemeMode.system,
      child: StratumToastHost(child: child!),
    ),
    home: HomePage(),
  );
  ```

- **`context.showToast`** — shows one notice from any context under the host: `message` (required), `kind`
  (`FeedbackState.info`, the default, `.positive`, `.warning`, `.negative`), `action` (a `StratumToastAction` of label
  and callback), and `placement`. A call with no host above throws a `FlutterError` naming `StratumToastHost`.
- **`StratumToastPlacement`** — `const StratumToastPlacement.float(StratumToastCorner.bottomEnd)` for a corner
  (`topStart` … `bottomEnd`, start and end following the text direction), or
  `const StratumToastPlacement.solid(StratumToastEdge.top)` for a full-width bar at an edge. Omitted placement defaults
  by window size: bottom center on mobile and tablet, bottom start on desktop.
- A notice closes after 4 s, or 8 s with `action: StratumToastAction(label: 'Undo', onPressed: undo)`; hover, focus,
  and touch pause it, and a notice with an action never closes by itself while a screen reader runs. A swipe, the
  close button, or Esc while focus is inside it closes a notice; a tap on the action runs its callback, then closes
  it. Each notice announces once on show, the kind's name then the message, taking no focus.
- The plain look draws every value from theme tokens, each kind with its own icon as well as color; a float notice's
  corner next to a rounded screen corner follows the screen's curve. Pass
  `StratumToastHost(builder: (context, notice) => ...)` for your own look instead; placement, timing, and the
  announcement stay the host's. A solid notice's plain-look fill declares itself under the status bar or home
  indicator, as a page layout's fills do, so the bar icons stay readable over it; your own look declares its own
  fill. `customStyle` on the call wins over the theme and the app-wide notice style, field by field.
- **Your `builder` look** — the host gives it the notice's full slot: the theme's notice width, capped by the window,
  in its corner, so draw at that width and never place or size the notice yourself. From the `StratumToastNotice`,
  pad your content by `notice.insets` (a solid notice's status bar or home indicator; zero on a float), close through
  `notice.close()` from your close button and after your action's callback, so the queue, the focus return, and the
  timers stay right, and label the close button with `notice.closeLabel` and the kind's icon with
  `notice.kindLabel`, the same names the announcement speaks. Merge `notice.pageSnack` then `notice.customStyle` over
  your own style to keep the style order.
- **`StratumToastHost(closeButtonLabel:, kindLabels:)`** — replace the built-in close-button label and, per
  `FeedbackState`, the kind's name; each reaches the announcement and the accessible names alike, and a kind missing
  from `kindLabels` keeps its built-in name.
- **`context.dismissAllToasts()`** — closes every notice at once, float and solid, and empties the solid queue, so no
  waiting notice shows later; it does nothing while none shows or waits, runs no exit animation under reduced motion,
  and returns focus from a notice that held it. Call it on logout and on account switch, as
  `ScaffoldMessenger.clearSnackBars()` serves snack bars, so a notice from the ended session never reaches the next
  one.

  ```dart
  Future<void> logOut(BuildContext context) async {
    context.dismissAllToasts();
    await auth.signOut();
  }
  ```
- **`StratumToastHost(focusShortcuts:, focusShortcutHint:)`** — a host shortcut moves focus into the newest notice on
  screen from any page or dialog, to its action, else its close button; it does nothing while no notice shows.
  Platform-ordered by default: Option+T then F8 on macOS and iOS, since F8 is a media key there, and F8 then Alt+T
  elsewhere. Pass your own `focusShortcuts` to replace the keys, `const []` to turn the shortcut off, and
  `focusShortcutHint` to replace the announcement's hint, which otherwise names the first key; the hint speaks on
  desktop and web only.
- A notice's action is never the only way to do that action: offer it in your own page too, as Gmail offers undo on
  its `z` key beside the notice's Undo, since a notice can close, or sit under a pushed route, before the end user
  reaches it.
