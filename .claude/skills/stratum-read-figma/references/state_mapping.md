# State mapping

`state` holds only interaction values; everything the caller controls becomes its own field (decision A).

| Figma `state` value                         | Dart                                                      |
|---------------------------------------------|-----------------------------------------------------------|
| `NORMAL`                                    | `state: FullWidgetState.normal`                            |
| `HOVERED`                                   | `state: FullWidgetState.hovered`                           |
| `PRESSED`                                   | `state: FullWidgetState.pressed`                           |
| `FOCUSED`                                   | `state: FullWidgetState.focused`                           |
| `DRAGGED`                                   | `state: FullWidgetState.dragged`                           |
| `SELECTED`                                  | `selected: true` (own `bool selected = false`, like `✅ selected`) |
| `DISABLED`                                  | `disabled: true`                                           |
| `LOADING`                                   | `loading: true` (indeterminate spinner)                    |
| `PROGRESS`                                  | `loading: true` plus `progress: double?` (0.0 to 1.0 bar)  |
| `🔵 INFO`, `🔴 NEGATIVE`, `🟡 WARNING`, `🟢 POSITIVE` | `feedbackState: FeedbackState.info` / `negative` / `warning` / `positive` |

The constructor `state` forces a visual state for previews and golden tests. When it is `normal`, the widget derives
hovered, pressed, and focused at runtime from its gesture and focus handling.

## Values the table does not cover: ask the user

- A value with a `_LEFT` or `_RIGHT` suffix (SplitButton `HOVERED_LEFT`) is the state of that half of a split control
  (2026-10-01). The table has no field for it, so ask which fields carry it; the component still counts as stateful.
- Any other value (`EMPTY`, `TYPING`): ask. Never fold it into the nearest row.

`LOADING` and the feedback values map the same way in any variant, not only `state` (2026-10-01; see
`property_mapping.md`).
