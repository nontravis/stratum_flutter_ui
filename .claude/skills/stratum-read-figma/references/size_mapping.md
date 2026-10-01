# Size mapping

- `WidgetSize` names map one to one without shifting: `HUGE` → `huge`, `EXTRA_LARGE` → `extraLarge`, `LARGE` →
  `large`, `MEDIUM` → `medium`, `SMALL` → `small`, `EXTRA_SMALL` → `extraSmall`, `TINY` → `tiny`.
- Font-size numbers (`10` to `56`) map to `FontSize.s<N>`.
- Pixel numbers with `Free` map to `double?`, where `Free` is null.
- Any other value (`EXTRA_TINY`, `FILL_WIDTH`, `FULL`, `COMPACT`): ask the user.

## Notes for the ask

- The 2026-10-01 decisions give meanings to quote in the question: `FILL_WIDTH` means full available width;
  `EXTRA_TINY` is design-only and is resolved when the widget is built. The user still decides the Dart side.
- A property named `size` whose values are font sizes or pixels cannot reuse the base `size` field, which is a
  `WidgetSize?`. The draft gives it a provisional name (`fontSize`, `customSize`) and asks for the real one.
- Slot sizes follow the `size` axis: the `## Slots` table lists width, height, and sizing per `WidgetSize` value.
