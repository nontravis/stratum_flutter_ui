# Property mapping

Every Figma component property becomes one configurable field of the Dart constructor. `scripts/map_lib.js` applies
this table; a value it cannot map becomes an `- ASK:` line in the draft, and the model asks the user. Never guess.

## Table

| Figma                                          | Dart                                                                                                  |
|------------------------------------------------|-------------------------------------------------------------------------------------------------------|
| `style`                                        | `style: Stratum<Component>Style` (or a shared enum)                                                   |
| `type`, `status`, any other variant            | `Stratum<Component><Prop>` enum (or a shared enum)                                                    |
| `size`                                         | `size: WidgetSize?` (base field; null resolves to the theme default), see `size_mapping.md`           |
| `state`                                        | split, see `state_mapping.md`                                                                         |
| `color`                                        | `color: ColorEnum?` (base field); feedback values go to `feedbackState`                               |
| `theme`, dark mode                             | `themeMode` (base field): `DARK` → `ThemeMode.dark`, `LIGHT` → `light`, `AUTO` → `system`              |
| `platform` with `MOBILE`, `TABLET`, `DESKTOP`   | `windowSize` (base field); null resolves from the nearest `WindowSizeScope` through `resolveWindowSize()` |
| `platform`, `os`, `browser` naming an OS or browser | no field; the widget checks the platform at runtime                                              |
| `False/True` variant                           | `bool`                                                                                                |
| item counts (🔢) and numbered booleans (`1. Checkbox`, `showTag1..5`) | `List<Widget>` children; the count is not a field                              |
| `Example` variants                             | skipped (demo data)                                                                                   |
| `show<X>` paired with a TEXT or INSTANCE_SWAP `<x>` | one nullable field (`String? errorText`, `Widget? leftIcon`); null hides it                       |
| unpaired `show<X>`                             | `bool show<X>`                                                                                        |
| TEXT                                           | `String`; required when it has no `show*` pair                                                        |
| INSTANCE_SWAP icon or illustration             | `Widget?` wrapped in a `SizedBox` whose size comes from the slot table per `WidgetSize`               |
| INSTANCE_SWAP slot or content                  | `Widget?` sized by `HUG` (no wrapper) or `FILL` (`Expanded` or `SizedBox.expand`) as in Figma         |
| nested instance with its own contract or Dart class | typed slot `Stratum<Nested>? <name>`; the caller configures it, so its exposed properties are not flattened; a `show<Name>` toggle merges into the slot (null hides it) |
| nested helper instance (from a `☀` page, such as FocusBorder, Caret, SelectBackground, Slot) | no field; the widget draws it |
| nested instances whose names differ only by a size word (`LargeTextInputLeftItem`, `MediumTextInputLeftItem`, `SmallTextInputLeftItem`) | one slot; its name drops the size word and the parent component name (`leftItem`), and the widget picks the size from its own `size` |
| callbacks                                      | `onChanged` for components in the Form section (never `onPressed`); otherwise `onPressed` when `state` has `HOVERED` or `PRESSED`; `on<Name>Pressed` for a nested button |
| override of the look                           | `customStyle: WidgetStyle?` (base field), merged over the component defaults by `resolveStyle()`      |

Enum naming: `Stratum<Component><Prop>` (for example `StratumButtonStyle`) so names never clash with Material types such
as `ButtonStyle`. Shared enums get a user-chosen name the first time their value set repeats.

Base class: `StratumStatefulWidget` when `state` has an interaction value (`HOVERED`, `PRESSED`, `FOCUSED`, `DRAGGED`),
else `StratumStatelessWidget`.

## Decisions of 2026-10-01

- `LOADING` in any variant maps to `loading: true`, and a feedback value (`🔵 INFO`, `🔴 NEGATIVE`, `🟡 WARNING`,
  `🟢 POSITIVE`) in any variant maps to `FeedbackState`, not only inside `state`. When a variant mixes these with other
  values (Spinner `type`, ModalContent `type`), ask whether the widget keeps them in a component enum as well.
- `CUSTOM` color means the caller passes the color; `BLACK` and `GHOST` are design-only and are resolved when the
  widget is built. The draft still asks, quoting that meaning.
- `🔢` item counts (`items`, `tabs`, `steps`, `section`, `page`, `avatars`, `attachments`) map to `List<Widget>`.
  Value-like `🔢` (`rating`, `percent`) map to `int` when every option is a whole number, else `double`. `🔢 frame`
  (animation frames) is not a field.
- `✅ selected` and the `SELECTED` state map to the component's own `bool selected = false` (`this.selected`, never
  `super.selected`): the base props have no `selected`. `✍️ filled` and `↕️ expanded` are not fields: the widget
  derives them from its value and its open state.
- Size-specific nested instances merge into one slot (TextInput: `leftItem`, `rightItem`).
- A slot value pairs with its slot: Figma uses `SLOT` with `❖ slot`, so the enum keeps `slot` and the slot becomes
  `Widget? slot`; the widget asserts in debug when `slot` is set while the variant is not `SLOT`.

## How map_lib.js reads the table

These points fill gaps the table leaves; each follows the approved Button example or an ask.

- **Pairing.** `show<X>` pairs with the TEXT, INSTANCE_SWAP, or SLOT property `<x>`. When no such property exists, it
  pairs with the nested instance whose visibility it binds, on the instance itself or on a wrapper frame between the
  variant and the instance: Button's `showBadge` plus its nested Badge gives `badge`, as the worked example requires.
  A helper never takes a toggle. A toggle that binds nothing while a nested instance of the same name has no toggle
  is asked.
- **Nested instances.** An instance that an INSTANCE_SWAP property swaps belongs to that property. A helper (its main
  component sits on a page whose name starts with `☀`) maps to no field. Any other instance a `show*` toggle hides, or
  one the designer exposed, becomes a typed slot only. A nested instance that no property toggles or exposes (a
  spinner drawn inside a loading variant) maps to no field.
- **Size groups.** The size words are `Huge`, `Large`, `Medium`, `Small`, `Tiny`, and their `Extra` forms, each at a
  word start of the component name. Instances whose names differ only by that word, with at least two different size
  words, form one slot at the first member's place; a lone `LargeBadge` keeps its name. The slot takes the members'
  class when all resolve to one, else `Widget?` with one ask for the group.
- **Old captures.** A capture without the nested `helper` field (`entry_read.js` before 2026-10-01) cannot tell a
  helper apart: the draft asks for a rerun of step 3.
- **Unresolved nested.** No contract with that `figma.componentKey`: the slot is `Widget?` and the draft asks whether to
  read that component first. Never read it on your own.
- **Flags.** A BOOLEAN or `False/True` variant named `loading` or `disabled` sets the base field; one named `selected`
  sets the own `selected`. Others become `bool <name>` with the Figma default.
- **Defaults.** An own field takes the Figma default (`style = StratumButtonStyle.filledBrand`). A base field keeps the
  base default (`super.size`, although Figma defaults Button to `HUGE`).
- **Inputs.** A component under the `Form` section is an input: it gets `onChanged` and never `onPressed`, and the
  draft asks for its value type (provisional `ValueChanged<String>?`).
- **Constructor order** (from the worked example): required text, `style` then other enums, `size` and `color`,
  content slots (property slots, then nested slots), flags and numbers, `themeMode` and `windowSize`,
  then `state`, `selected`, `feedbackState`, `disabled`, `loading`, `progress`, then callbacks, then `customStyle`.
- **Asks.** A value no rule covers (an unknown `state` value, a symbol-only value, a value starting with a digit, a Dart
  reserved word, a size outside every vocabulary), a field name two properties both claim, or an enum default that
  left the enum.
