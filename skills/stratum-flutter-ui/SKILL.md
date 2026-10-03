---
name: stratum-flutter-ui
description: Use when building a Flutter app on the Stratum UI design system package and deciding which layout primitive to reach for, what its key parameters are, or how it behaves by keyboard. Triggers on questions about ColumnLayout, RowLayout, FlexLayout, ContainerLayout, StackLayout, IndexedStackLayout, WrapLayout, ListViewLayout, GridViewLayout, CustomScrollViewLayout, PageViewLayout, ReorderableListViewLayout, NestedScrollViewLayout, or Space/SpaceDirectional.
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
  and `crossAxisIntrinsic` (sizes to the largest child through `IntrinsicWidth`/`IntrinsicHeight`, unless `style`
  sets that cross size; toggling it does remount the children, because the intrinsic wrapper changes type).
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
  Keyboard: K4 line-mode scrolling, 100 ms per key with `Curves.easeInOutSine`, or a jump when `MediaQuery` or the
  platform asks for reduced motion.
- **`PageViewLayout`** (children or `.builder`) — one page per viewport, with `scrollDirection`, `controller`,
  `pageSnapping`, `onPageChanged`; `style.padding` insets the viewport rather than scrolling. No previous/next
  buttons; a component that needs them builds its own on top.
  Keyboard: an arrow along the axis, Page Up/Page Down, Home, and End move one whole page; a change slides 300 ms
  with `Curves.easeInOutSine`, or jumps when `MediaQuery` or the platform asks for reduced motion; focus moves to the
  new page's first Tab-order node.
- **`ReorderableListViewLayout`** (`.builder` only) — a reorderable list on widgets `ReorderableList`, with a
  caller-placed drag handle or `longPressDrag`, `onReorderItem`, and `dragStyle` for the lifted item; each item keeps
  its `State` and focus across a move through a global key that never uses the index.
  Keyboard: Alt+arrow along the axis moves the focused item one slot, Alt+Home/Alt+End move it to either end; a move
  past either end is still handled, so it never reaches the browser (Chrome's Alt+Left/Alt+Right Back/Forward).
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
