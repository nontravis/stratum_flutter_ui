# Layout

Sections: Box layouts; `ContainerLayout`; `FlexLayout`; `ColumnLayout`; `StackLayout`; `IndexedStackLayout`;
`WrapLayout`; Scroll views; `ListViewLayout`; `PageViewLayout`; `ReorderableListViewLayout`; `NestedScrollViewLayout`;
Spacing; `Space`; `SpaceDirectional`; Focus ring; `StratumFocusBorder`; `StratumInkWell`;
Ids and screen-reader actions on a tap surface; Show and hide; `Show`; Modal layout; `showModalLayout`; `ModalLayout`;
List body; Type and size; Corners; Close and handle; Insets; Style; Split layout; `SplitLayout`; Resize; Divider look;
Keep widths; Page layout; `PageLayout`; Rebuild scope; Keyboard; Loading; Drawers; Side panes; Controller;
Hover and focus observers; `HoverBuilder`; `FocusBuilder`; Both

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
`ScrollFocus` is the scrolling area's focus host: `componentPartDefaults: (theme) => {ScrollFocus:
ScrollFocusStyle(focus: StratumFocusBorderStyle(...))}` restyles every scrolling area's ring, and each scroll
view's `scrollFocusStyle` one area's; the window check counts a second ring's width.
Every scroll view but `NestedScrollViewLayout`, and `Scroll`, take `scrollFocusStyle: ScrollFocusStyle(focus: ...)`
beside `style`, which draws the box.

- **`ListViewLayout`**, **`GridViewLayout`**, **`CustomScrollViewLayout`** — lazy list, grid, and sliver view inside
  a `WidgetStyle` box; `style.padding` becomes the scroll padding, so it scrolls with the content.
  Keyboard: K4 line-mode scrolling, each key over the theme's `fast` level (125 ms in the package default) on its
  `standard` curve, or a jump when `MediaQuery` or the platform asks for reduced motion.
- **`PageViewLayout`** (children or `.builder`) — one page per viewport, with `scrollDirection`, `controller`,
  `pageSnapping`, `onPageChanged`; `style.padding` insets the viewport rather than scrolling. Null `implicitScrolling`
  builds no neighbor page ahead; `implicitScrolling: ImplicitScrolling()` turns it on with a cache extent of one
  viewport, or pass `ImplicitScrolling(scrollCacheExtent: ...)`; the extent must be above zero. It replaces Flutter's
  `allowImplicitScrolling` and `scrollCacheExtent`, which the layout no longer takes.
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
- **`ReorderableListViewLayout`** (`.builder` only) — a reorderable list on stratum's own private
  `SliverReorderableList` subtype, with a caller-placed drag handle or `longPressDrag`, `onReorderItem`, and `dragStyle`
  for the lifted item; it keys each item by its own key, with no global key, so the item keeps its `State` and focus
  across a move. An item finds the list through `SliverReorderableList.maybeOf(context)`, not `ReorderableList.maybeOf`,
  and a test through `find.byWidgetPredicate((widget) => widget is SliverReorderableList)`, not `find.byType`.
  A dragged item stays hidden in its slot, with its screen-reader node, while a still image of it follows the pointer: a
  spinner or caret in it stops until the drop, and a text field in it needs no app `Material`. A long press in a focused
  text field stays the field's; a handle still drags.
  A drag held near a viewport edge scrolls the list toward that edge; `autoScrollerVelocityScalar` scales its speed. A
  dragged item longer than the list scrolls it only once one of its edges shows, toward the side still sticking out; in
  an app `DragBoundary` it stays inside, or only the pointer does on an axis it outgrows.
  The neighbors a drag passes and a dropped item move on the theme's `normal` level and `standard` curve, at once under
  reduced motion; the lifted look keeps its timing.
  Keyboard: Alt+arrow along the axis moves the focused item one slot, Alt+Home/Alt+End move it to either end; a move
  past either end is still handled, so it never reaches the browser (Chrome's Alt+Left/Alt+Right Back/Forward).
  A screen reader hears each move by key, screen-reader action, or drop, and each reorder key past an end, in English or
  Thai; a held key speaks once, where the item ends, when it is let go. `moveAnnouncement`, `atStartAnnouncement`, and
  `atEndAnnouncement` replace the texts, and an empty one stays silent. A screen-reader move treats its item as focused
  while focus stays put, moving no focus.
  A tappable row: a root tap surface that holds the whole item, `ContainerLayout(interaction: Interaction(onTap: ...))`
  or a `StratumInkWell`, with only `Padding`, `KeyedSubtree`, or a `Dismissible` at rest between the item and it, adds
  no node of its own: a screen reader reads the row's label, button role, enabled or dimmed state, tap, and move actions
  at one stop, and a disabled row reads as a dimmed button with no tap that keeps its moves. A control inside the row,
  such as a delete button beside the label, keeps its own node and never takes the row's tap. A row splits whenever a
  configuration between the item and the root surface, or on the surface itself, cannot merge into the item's node, such
  as overlapping actions or conflicting flags, for example an app's own `Focus` with semantics around the row; the
  surface's own `onSecondaryTap` action, and an `identifier` or custom actions in its `semantics:`, join the row's stop;
  a `Semantics(identifier: ...)` wrapped around the row splits it, since an identifier makes a node of its own. A row in a `Dismissible` that snaps back after a partial swipe stays split until it
  rebuilds, a Flutter limit. A child added or removed between the item and the root reads otherwise for one frame. A
  disabled component on the Stratum base that holds the whole item joins the same way, with or without a tap surface
  below.
  An item that holds focus, on its own node or one inside it, stays alive with its State and focus when a scroll, the
  user's or the app's, takes it out of view, and the list scrolls nothing for it; Tab, Shift+Tab, or an arrow key from
  it brings it back into view first, then moves focus; an app's own `nextFocus()`, `previousFocus()`, or
  `focusInDirection()` on it brings it back the same way, and when the app holds the scroll so it cannot come back,
  focus goes to the first item that shows (the last, going backward), and with none showing it leaves the list that way;
  a focus that moves elsewhere lets it go. The newest input wins: a drag, or an EndUser or app scroll (even in the app's
  `moveItem` turn), ends the list's scroll toward a moved, dropped, or growing item; the list never scrolls against it.
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
  `onReorderStart`, and `onReorderEnd`; from those, call after the frame. Such a call before every built item moves the
  items on screen one row.
  An added item grows and fades in over the theme's `normal` level; a removed one shrinks and fades out in its current
  look unless `removeItem`'s `builder` gives another; `itemTransitionBuilder(context, animation, child)` replaces size
  and fade both ways and wraps every item, one at rest at value 1, as `AnimatedList` does: return one widget shape for
  every value, or the item's State ends. Without `builder`, a removed item's leaving copy ends at once if its key
  returns; a `builder` keeps it fading in its own look. The leaving item keeps its State and rebuilds: an item reading
  data through `context` (`watch` or `select` by id or index, a provider family) needs a `builder` capturing that data.
  Under reduced motion, or with `itemExtent`, `itemExtentBuilder`, or `prototypeItem`, the size jumps and the fade
  plays.
  A leaving item has no screen-reader node from its first frame; test it on the live semantics tree:
  `find.bySemanticsLabel` reads a stale debug cache for excluded subtrees.
  Focus on a removed item, or on one dropped from the data with no call (a remove, a replace, or, with no
  `findChildIndexCallback`, a reorder), moves to the next item, else the previous, else the nearest item with a
  focusable node, else a focusable list's Tab stop, and the list shows it, unless the app moves focus in the same turn
  or after the frame. A focused item removed and inserted back with its key in the same turn keeps focus instead and
  shows on screen. A lift ends the item's grow-in; a lift or reorder of a leaving item's neighbor ends the leaving item.
  During a drag, an `insertItem`, `removeItem`, `moveItem`, key or screen-reader move, item-count change, or same-count
  data change that moves or replaces the dragged item ends it first, and a pointer cancel or a second pointer's takeover
  ends it, each with `onReorderEnd` at its start index and no `onReorderItem`; key and screen-reader moves then report
  their own. A reorder key, screen-reader move, or drag during a drop's settle completes the drop first, `onReorderItem`
  included. Every drag ends with exactly one `onReorderEnd`; a drop's `onReorderEnd` reports its gap's insert index.

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

## Focus ring

- **`StratumFocusBorder`** — the Figma `FocusBorder` ring around one `child`. `StratumInkWell`, and so every
  `interaction`, every focusable scroll view, and every `SplitLayout` divider already draw it; wrap a widget yourself
  only when it takes focus or hover without them. Parameters: `state` (`FullWidgetState.focused`, `.hovered`, or
  `.normal`, resolved from focus and hover alone: a field in error that holds focus still passes `focused`, and any
  other value shows no ring), `borderRadius` (the child's own radius), `insideEdge` (an outside ring on the child's
  inner edge, for a box whose ring around it would leave the window), and `customStyle`, a
  `StratumFocusBorderStyle`. Every look value comes from that focus style, field by field over four levels, low to
  high: the theme's `focus` group; `componentPartDefaults: (theme) => {StratumFocusBorder:
  StratumFocusBorderStyle(...)}` for every ring; the host type's style (`StratumInkWellStyle`, `ScrollFocusStyle`,
  `SplitLayoutStyle`) and its `focus` field; and one instance. The style's fields: `color`, `width`, `gap`,
  `radius`, `placement` (`StratumFocusBorderPlacement.outside`, the default, for every interaction the user does
  not type into; `.inside` for form fields), `motion` (an `AnimationStyle`), `secondRing` (`(color: c, width:
  null)`, a two-tone ring touching the first on the side away from the child's edge, outward for an outside ring and
  inward for an inside or `insideEdge` one, at the first ring's width unless set), and `glow` (a
  `List<BoxShadow>`). Every field but `placement` takes `WidgetStateProperty.all(v)` or
  `WidgetStateProperty.fromMap({WidgetState.hovered: a, WidgetState.focused: b})`; a `.fromMap` value must be
  `WidgetStateProperty<T?>` (a nullable `T`) or carry a `WidgetState.any` entry, since an inside ring resolves
  `hovered` and an outside ring resolves `focused` even in the normal look, and a non-nullable map with no `any`
  entry throws Flutter's own `ArgumentError` for a state it was never given. A width of 0 or a fully
  transparent color fails a debug assert, and no field draws a dashed ring. The every-ring style lives only in
  `componentPartDefaults`: a `componentDefaults` entry under `StratumFocusBorder` fails a debug assert. Default look: outside, 3 px in
  `border.subtle.blue` after a 2 px gap, only when focused; inside, `border.default.normal` on the inner edge, 3 px
  when hovered and 2 px when focused. It fades over the style's motion, shows at once under reduced motion, second
  ring and glow included, and never changes the child's layout size. Its default colors stay below 3:1 in the light
  and dark themes (WCAG 1.4.11), and both high-contrast themes give the outside ring 3:1 or more; set a focus style
  color, from the theme's `focus` group up to one ring, where an app needs that ratio in light or dark.
- **`StratumInkWell`** — the tap surface every `interaction` builds on. Its own hover and press overlay fades over
  the theme's `fast` level and snaps straight to its target color under reduced motion, same as the ring above it.
  `tapTargetSize` (default `TapTargetSize.platform`) grows its layout and hit area to the platform minimum
  when `child` is smaller; pass `TapTargetSize.shrinkWrap` to keep `child`'s own size in a dense UI.
  `Interaction.tapTargetSize` carries the same choice to every `BoxLayout` (`ContainerLayout`, `ColumnLayout`,
  `RowLayout`, `StackLayout`, `WrapLayout`) with a tap surface, so a dense `BoxLayout` opts out the same way.
  `onHover` reports a pointer over the surface while it is enabled: turning disabled under a still pointer, by its own
  `disabled` or a disabled component around it, calls `onHover(false)` once, and turning enabled again under it calls
  `onHover(true)` once. `customStyle: StratumInkWellStyle(focus: StratumFocusBorderStyle(...))` restyles this
  surface's focus ring, over `componentPartDefaults: (theme) => {StratumInkWell: StratumInkWellStyle(focus: ...)}`
  for every tap surface, which sits over the every-ring `StratumFocusBorder` style; `Interaction.customStyle`
  carries it to every `BoxLayout` with a tap surface.
- **Ids and screen-reader actions on a tap surface** — pass them in the surface's own
  `semantics: SemanticsProperties(identifier: ..., customSemanticsActions: ...)`, or a `BoxLayout`'s `semantics:`,
  which reaches it unchanged. The surface puts them on its one node beside its role, label, tap, and `onSecondaryTap`
  action, and a caller action with the secondary action's label replaces it. Never add a `Semantics` of your own for
  them: one with custom actions inside `child` splits the label and tap away from the button role, since a node takes
  custom actions from one source only, and one with an `identifier` around the surface leaves the id on a node of its
  own with no tap.

  ```dart
  // One stop: "Row, Button", with the actions Pin and Show menu.
  StratumInkWell(
    onTap: openRow,
    onSecondaryTap: showRowMenu,
    semantics: SemanticsProperties(
      identifier: 'row.1',
      customSemanticsActions: {const CustomSemanticsAction(label: 'Pin'): pinRow},
    ),
    child: const Text('Row'),
  )
  ```

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
  move stays within both panes' `min` and `max`. Each divider is a Tab stop with the focus ring; `customStyle:
  SplitLayoutStyle(focus: StratumFocusBorderStyle(...))` restyles that ring for one split, over
  `componentPartDefaults: (theme) => {SplitLayout: SplitLayoutStyle(focus: ...)}` for every split. Each divider reads
  as a slider valued by the start pane's percent; `dividerLabel:` replaces the built-in "Resize panes" label.
- **Divider look** — nothing paints by default and the divider takes no space, so the panes stay flush; its hit area
  is the platform's minimum target size centered on the seam, with a resize cursor on hover; a tap, a scroll, or a
  drag across the axis that starts there still reaches the pane content under it. Paint one with
  `dividerBuilder: (context, state) => ...`, where `state.hovered`, `state.dragging`, and `state.focused` pick the
  look; the widget fills the hit area, so center a thin line in it and read its color from a theme token.
- **Keep widths** — pass `setting: WidgetSettingKey.global()` (every instance) or `setting:
  WidgetSettingKey.id('mail')` (instances sharing that id) to have Stratum remember and restore the split's
  fractions itself under the `StratumWidgetSettings` above (see Widget settings); with no `setting:`, Stratum
  persists nothing. Pass a `SplitLayoutController(fractions: saved)` to restore kept
  fractions yourself instead (one per pane in `panes`, a null pane included; a null entry is a pane with no choice
  yet, which opens at its own `size` or `flex`), listen to it to save `controller.fractions`, and set
  `controller.fractions = [...]` from code. It notifies once per settled move (a drag's end, one key step, a slider
  action, or a code set), never per drag frame and never when a narrow window only squeezes the panes. A saved entry
  that is NaN, infinite, or negative reads as null, so a corrupt value opens the pane at its own size. With no
  controller the split makes and disposes its own; it never disposes one you pass. With both, a stored value wins
  over the controller's, which becomes the default only where the store holds none.

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
  closed); `openLeft()` on a side shown inline does nothing. The EndUser also opens one by a swipe from its edge of the
  `PageLayout`'s own box (never from the iOS start edge of a page that can go back, and never with `edgeSwipe: false`)
  and closes it by the scrim, Esc, back, or a drag. `leftSide: PageSide(type: PageDrawerType.back, pageScale: 0.9,
  maxWidth: 320)` picks the type (`front`, `back`, `slide`, `permanent`, or `page`; default `slide` on iOS, `front`
  elsewhere), the width bounds (80% of the `PageLayout`'s own box, up to 360 by default, never wider than that box), an
  optional page scale, and `semanticsLabel:`. A `page` drawer opens as a new page that sits outside the `PageLayout`, so
  close it with `Navigator.pop`, never `PageLayout.of`. A drawer open when the window grows past the cut closes
  (`onDrawerChanged` hears null after that frame) and the side shows inline.
- **Side panes** — at the cut and up, `left` and `right` sit beside the center column as `SplitLayout` panes the EndUser
  resizes by drag, arrow keys, Home, and End, within the side's `minWidth` and `maxWidth`; on either divider End widens
  the side pane to its maximum, Home narrows it to its minimum, and the slider reads its share, while the arrows move by
  screen direction. Nothing paints between a pane and the center column; paint a line with `leftDividerBuilder:` or
  `rightDividerBuilder:`, the same `(context, state)` shape as `SplitLayout.dividerBuilder`. A pane opens at the
  controller's chosen width, else at Figma's (`left` 280 and `right` 380 at `bigDesktop`; 260 and 320 below). The center
  column keeps at least `minCenterWidth` (default 320): a divider stops there, and a narrow window narrows the panes
  first. `rightAsOverlay: true` instead opens `right` at the cut and up as a front drawer over a scrim, 450 wide at
  `bigDesktop` and 400 below (never wider than the `PageLayout`'s own box), with a close button; open it with
  `openRight()`.
- **Controller** — `PageLayout.of(context)` returns the page's `PageLayoutController`, which opens and closes its
  drawers; pass your own `PageLayoutController(leftWidth:, rightWidth:)` to restore kept side pane widths, listen to
  it to save `leftWidth` and `rightWidth`, and set them from code. It notifies once per settled resize (a drag's end,
  a key step, or a code set), never per drag frame and never when a narrow window only squeezes a pane. A saved
  width that is NaN, infinite, or negative reads as null, so a corrupt value opens Figma's width. The page disposes
  only the one it makes.
- **Keep widths** — pass `setting: WidgetSettingKey.global()` (every instance) or `setting:
  WidgetSettingKey.id('mail')` (instances sharing that id) to have Stratum remember and restore `leftWidth` and
  `rightWidth` itself under the `StratumWidgetSettings` above (see Widget settings), judged each on its own; with
  no `setting:`, Stratum persists nothing. With a passed controller too, a stored width wins, and the controller's
  width becomes the default only where the store holds none.

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
