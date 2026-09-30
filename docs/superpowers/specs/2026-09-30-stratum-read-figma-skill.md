# Skill spec: `stratum-read-figma`

| Field      | Value                                                                  |
|------------|------------------------------------------------------------------------|
| name       | `stratum-read-figma`                                                   |
| scope      | project (`projects/stratum_ui/.claude/skills/stratum-read-figma/`)     |
| budget     | 800 words (`wc -w SKILL.md`; `references/` and `scripts/` not counted) |
| status     | approved design, 2026-09-30                                            |
| depends on | `stratum-figma-lint` (shared scripts and the lint gate); build it first |
| hands off  | `stratum-create-flutter-widget` (reads the contract, writes Dart)       |

## Trigger description

> Use when the user wants to read a component set from the Stratum Figma design-system file and turn it into a Flutter widget contract: property-to-field mapping, enums, states, slots, nested components, visual tokens, and docs. Triggers on "read figma component", "อ่าน figma", "สร้าง contract จาก figma", "figma to contract", or a figma.com/design URL with a `node-id` plus read, map, or contract.

## Purpose

Every Figma component property becomes one configurable field in a Dart constructor. This skill reads one component set, applies the agreed mapping rules, and writes a contract file. `stratum-create-flutter-widget` implements the widget from that contract. Splitting the work this way lets the owner review the mapping before any Dart is written and see a diff when Figma changes.

The Figma facts measured on 2026-09-30 (page count, the 20 KB result limit, the 50,000-character code limit, rate limits, the empty-description bug) are listed in `2026-09-30-stratum-figma-lint-skill.md` and apply here unchanged.

## Inputs

- A figma.com/design URL of any file with `node-id` pointing at a component set (or a standalone component with properties). The skill never hardcodes a file key or URL; when the user gives none, ask for one. The file key in each contract's frontmatter comes from the URL of that run.
- Without `node-id`: list the component sets on the page the user names (skipping `Doc` and `Examples` frames) and ask which one to read. Pages whose name starts with `☀` and example-screen pages hold no widgets; when the user points at one, say so and ask before reading.

## Workflow

1. **Load** `figma:figma-use`.
2. **Gate.** Run `stratum-figma-lint` with scope `node-id`. Parse its summary line `lint: <n> blocking, ...`. When `n` is above zero, stop, show the blocking findings, and ask the user to fix them in Figma or to confirm continuing anyway.
3. **Extract.** Concatenate `../../stratum-figma-lint/scripts/conventions.js` + `../../stratum-figma-lint/scripts/extract_lib.js` + `scripts/entry_read.js`, replace `__NODE_ID__`, and run it through `use_figma`. It returns the full JSON for one component set (see "Extracted data").
4. **Resolve.**
   - Nested instances: grep the frontmatter `figma.componentKey` of every contract in `docs/specs/stratum_ui/components/`. A match gives the Dart class. No match marks the instance `unresolved`; ask the user whether to read that component first. Never recurse on your own.
   - Enum reuse: search `lib/` and the `## Enums` section of existing contracts for an enum with exactly the same value set. Reuse it when found. When the same value set appears for the first time in a second component, ask the user for the shared enum name (for example `StratumFieldStyle`).
5. **Map** the JSON to a contract with the rules in `references/`. For any value no rule covers (an unknown `state` value, a symbol-only value, a size outside every vocabulary), ask the user. Never guess.
6. **Write** `docs/specs/stratum_ui/components/<snake_name>.md`. When the file exists, show the diff and ask before overwriting.
7. **Hand off.** Tell the user to run `stratum-create-flutter-widget` on the contract.

## Extracted data (`scripts/entry_read.js`)

For the component set and every variant:

- `componentPropertyDefinitions`: name, type, `defaultValue`, `variantOptions`, `preferredValues`.
- The variant matrix: every existing combination of variant values.
- `descriptionMarkdown` and `documentationLinks` of the set and of each variant, with a flag when the set description is empty. Measured on 2026-09-30: `descriptionMarkdown` came back empty on Button, Alert, and TextInput while `description` held the Markdown source with HTML entities (`&quot;`, `&#39;`). Use `descriptionMarkdown` when it is non-empty, else `description`, and unescape HTML entities before parsing the headings.
- Nested instances: main component key and name, and the properties the designer exposed to the parent.
- Instance-swap slots: width, height, and `layoutSizingHorizontal` / `layoutSizingVertical` (`FIXED`, `HUG`, `FILL`) per variant, so slot size can follow `size`.
- Bound variables for fills, strokes, radius, spacing, and text styles per variant, as variable or style names.
- The Figma section the page sits under: the nearest separator page above it (in the reference file `─── Control`, `─── Disclosure`, `─── Display`, `─── Feedback`, `─── Form`, `─── Navigation`, `─── Overlay`). When the section name matches a folder under `lib/src/components/`, that folder holds the widget; when the file has no separator pages or the name matches no folder, ask the user for the folder.

The script reads only; it never mutates the file. It keeps its own helpers pure and reuses `normalizeName` and the walkers from `extract_lib.js`.

## Mapping rules (`references/`)

### `property_mapping.md`

| Figma                                          | Dart                                                                                                  |
|------------------------------------------------|-------------------------------------------------------------------------------------------------------|
| `style`                                        | `style: Stratum<Component>Style` (or a shared enum)                                                   |
| `type`, `status`, any other variant            | `Stratum<Component><Prop>` enum (or a shared enum)                                                    |
| `size`                                         | `size: WidgetSize` (base field), see `size_mapping.md`                                                |
| `state`                                        | split, see `state_mapping.md`                                                                         |
| `color`                                        | `color: ColorEnum?` (base field); feedback values go to `feedbackState`                               |
| `theme`, dark mode                             | `themeMode` (base field): `DARK` → `ThemeMode.dark`, `LIGHT` → `light`, `AUTO` → `system`              |
| `platform` with `MOBILE`, `TABLET`, `DESKTOP`   | `windowSize` (base field); null resolves from the nearest `WindowSizeScope` through `resolveWindowSize()` |
| `platform`, `os`, `browser` naming an OS or browser | no field; the widget checks the platform at runtime                                              |
| `False/True` variant                           | `bool`                                                                                                |
| counts (🔢) and numbered booleans (`1. Checkbox`, `showTag1..5`) | `List<Widget>` children; the count is not a field                                   |
| `Example` variants                             | skipped (demo data)                                                                                   |
| `show<X>` paired with a TEXT or INSTANCE_SWAP `<x>` | one nullable field (`String? errorText`, `Widget? leftIcon`); null hides it                       |
| unpaired `show<X>`                             | `bool show<X>`                                                                                        |
| TEXT                                           | `String`; required when it has no `show*` pair                                                        |
| INSTANCE_SWAP icon or illustration             | `Widget?` wrapped in a `SizedBox` whose size comes from the slot table per `WidgetSize`               |
| INSTANCE_SWAP slot or content                  | `Widget?` sized by `HUG` (no wrapper) or `FILL` (`Expanded` or `SizedBox.expand`) as in Figma         |
| nested instance                                | typed slot `Stratum<Nested>? <name>`; each property the designer exposed becomes a flattened field `<name><Prop>` |
| callbacks                                      | `onPressed` when `state` has `HOVERED` or `PRESSED`; `onChanged` for inputs; `on<Name>Pressed` for a nested button |
| override of the look                           | `customStyle: WidgetStyle?` (base field), merged over the component defaults by `resolveStyle()`      |

Enum naming: `Stratum<Component><Prop>` (for example `StratumButtonStyle`) so names never clash with Material types such as `ButtonStyle`. Shared enums get a user-chosen name the first time their value set repeats.

Base class: `StratumStatefulWidget` when `state` has an interaction value (`HOVERED`, `PRESSED`, `FOCUSED`, `DRAGGED`), else `StratumStatelessWidget`.

### `state_mapping.md`

`state` holds only interaction values; everything the caller controls becomes its own field (decision A).

| Figma `state` value                         | Dart                                                      |
|---------------------------------------------|-----------------------------------------------------------|
| `NORMAL`                                    | `state: FullWidgetState.normal`                            |
| `HOVERED`                                   | `state: FullWidgetState.hovered`                           |
| `PRESSED`                                   | `state: FullWidgetState.pressed`                           |
| `FOCUSED`                                   | `state: FullWidgetState.focused`                           |
| `DRAGGED`                                   | `state: FullWidgetState.dragged`                           |
| `SELECTED`                                  | `selected: true`                                           |
| `DISABLED`                                  | `disabled: true`                                           |
| `LOADING`                                   | `loading: true` (indeterminate spinner)                    |
| `PROGRESS`                                  | `loading: true` plus `progress: double?` (0.0 to 1.0 bar)  |
| `🔵 INFO`, `🔴 NEGATIVE`, `🟡 WARNING`, `🟢 POSITIVE` | `feedbackState: FeedbackState.info` / `negative` / `warning` / `positive` |

The constructor `state` forces a visual state for previews and golden tests. When it is `normal`, the widget derives hovered, pressed, and focused at runtime from its gesture and focus handling.

### `size_mapping.md`

- `WidgetSize` names map one to one without shifting: `HUGE` → `huge`, `EXTRA_LARGE` → `extraLarge`, `LARGE` → `large`, `MEDIUM` → `medium`, `SMALL` → `small`, `EXTRA_SMALL` → `extraSmall`, `TINY` → `tiny`.
- Font-size numbers (`10` to `56`) map to `FontSize.s<N>`.
- Pixel numbers with `Free` map to `double?`, where `Free` is null.
- Any other value (`EXTRA_TINY`, `FILL_WIDTH`, `FULL`, `COMPACT`): ask the user.

### `token_mapping.md`

- Bound color variables map to theme color tokens by variable name; bound spacing and radius variables map to the `space` and `radius` keys of the theme YAML (`assets/themes/example.yaml`).
- Text styles named like `UI Text 14 Semi Bold` map to `FontType.ui` + `FontSize.s14` + the weight.
- A hard-coded value (not bound) is copied into the contract with a `hard-coded` marker; `stratum-figma-lint` rule L12 already reports it.

### `contract_template.md`

The contract is a Markdown file with YAML frontmatter:

```yaml
---
name: Button
figma:
  fileKey: "<file key from the URL of this run>"
  nodeId: "<set node id>"
  componentKey: "<set component key>"   # nested-instance resolution reads this
dart:
  class: StratumButton
  base: StratumStatefulWidget
  path: lib/src/components/control/button/button.dart   # folder from the Figma section
---
```

Sections, in this order:

1. `# <Name>` followed by the description. `descriptionMarkdown` headings map to dartdoc: `# Purpose` becomes the class summary; `# Use when` and `# Don't use when` become dartdoc sections; `# Related` names resolve to `[Stratum<Name>]` links through the contracts; `# Content guidelines` is kept for the widget skill to decide. A description without those headings becomes the class doc as is. Each variant description becomes the doc comment of its enum value; `documentationLinks` become `/// See also: <uri>`.
2. `## Properties`: `Figma | Dart field | Type | Default`.
3. `## Enums`: each new or reused enum with its values.
4. `## States`: the `state_mapping` rows this component uses.
5. `## Slots`: slot size per `WidgetSize` and its sizing mode.
6. `## Visual tokens`: `style × state` rows with background, foreground, border, and radius tokens.
7. `## Nested`: Figma component, Dart class, exposed properties.
8. `## Variant combinations`: only when the matrix is incomplete; lists the combinations that exist.
9. `## Open questions`: anything the user deferred.

Worked example (approved 2026-09-30) for the Button constructor the contract must produce:

```dart
const StratumButton({
  required this.label,
  this.style = StratumButtonStyle.filledBrand,
  super.size,
  this.leftIcon,
  this.rightIcon,
  this.badge,
  super.state,
  super.disabled,
  super.loading,
  this.progress,
  this.onPressed,
  this.customStyle,
});
```

## Tests

1. **Fixtures.** `scripts/test/fixtures/` holds `entry_read.js` output for Button, Alert, and TextInput captured from the real file.
2. **Golden contract.** `scripts/test/expected/button.md` holds the contract for Button that matches the worked example above. The behavioral test reads Button and compares the result with it.
3. **Behavioral checks** after build: reading Alert stops at the lint gate (the `STRING` typo is blocking) until the user confirms; reading TextInput reports the `showSuccessText` collision through the gate.

## Out of scope

- Linting beyond the single-node gate (`stratum-figma-lint`).
- Writing Dart code (`stratum-create-flutter-widget`).
- Writing to Figma and Code Connect.

## Decisions log

- 2026-09-30: output is a contract file under `docs/specs/stratum_ui/components/`, not Dart code.
- 2026-09-30: contracts double as the registry (frontmatter `figma.componentKey` → `dart.class`) because Code Connect is unavailable on the owner's plans.
- 2026-09-30: nested instances become typed slots plus flattened fields for exposed properties.
- 2026-09-30: `state` holds interaction values only; `disabled`, `loading`, `selected`, and `feedbackState` are separate fields; `PROGRESS` adds `progress: double?`.
- 2026-09-30: `show<X>` plus `<x>` merge into one nullable field; `style` is the Figma enum and `customStyle` the `WidgetStyle` override; enums are named `Stratum<Component><Prop>` and shared when their value sets match.
- 2026-09-30: `MOBILE/TABLET/DESKTOP` map to the base `windowSize`; OS values are not fields.
- 2026-09-30: skip `Doc` and `Examples` frames.
- 2026-09-30: the sibling skill is renamed `stratum-create-flutter-widget`; all four Stratum skills use kebab-case names.
- 2026-09-30: no hardcoded Figma file key or URL; the user names the file on every run, and the Dart folder comes from the section separator only when it matches an existing folder.
