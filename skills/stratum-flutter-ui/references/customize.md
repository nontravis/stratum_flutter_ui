# Customize

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

## Named colors

- **Named colors** — a component of your own on `StratumStatelessWidget` or `StratumStatefulWidget` maps its `color`
  prop with `resolveColor(context, (colors) => colors.icon.color, fallback)`: the token of that name in the group
  you pick (`background.color`, `border.color`, `icon.color`, or `text.color`), else `fallback` when `color` is null
  or the group has no token of that name. Read a group by name yourself with
  `StratumTheme.of(context).color.icon.color[ColorEnum.blue]`, which gives null for a name the group lacks; a token
  the package's default theme gains joins the lookup in the next package release; an app's own theme can only
  restyle the names the package already has. To list every color of the theme and mode shown, read
  `StratumTheme.of(context).color.byName`, an unmodifiable map from each token path (`brand.normal`,
  `background.color.blue`) to its color.
- A component's size hook is `resolveDefaultSize(context)`: the widget's `size` when set, else
  `resolveTheme(context).defaultWidgetSize`, so a subclass that overrides `resolveTheme` sets its own default size.
