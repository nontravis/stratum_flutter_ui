# Contract template

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

The section separator page gives the folder of `path` only when its name matches a folder under `lib/src/components/`.
When the file has no separator pages or the name matches no folder, `path` is `null` in the draft: ask the user for
the folder.

The contract file lives at `docs/specs/stratum_ui/components/<section>/<snake_name>/<snake_name>.md`, where
`<section>` is the folder of `path` (`control/button/button.md`). `map_contract.js` prints it as `contract:`.

## Sections, in this order

1. `# <Name>` followed by the description. `descriptionMarkdown` headings map to dartdoc: `# Purpose` becomes the class
   summary; `# Use when` and `# Don't use when` become dartdoc sections; `# Related` names resolve to
   `[Stratum<Name>]` links through the contracts; `# Content guidelines` is kept for the widget skill to decide. A
   description without those headings becomes the class doc as is. Each variant description becomes the doc comment
   of its enum value; `documentationLinks` become `/// See also: <uri>`.
2. `## Properties`: `Figma | Dart field | Type | Default`.
3. `## Enums`: each new or reused enum with its values.
4. `## States`: the `state_mapping` rows this component uses.
5. `## Slots`: slot size per `WidgetSize` and its sizing mode.
6. `## Visual tokens`: `style × state` rows with background, foreground, border, and radius tokens.
7. `## Nested`: Figma component, Dart class, exposed properties.
8. `## Variant combinations`: only when the matrix is incomplete; lists the combinations that exist.
9. `## Open questions`: anything the user deferred.

## Section formats

`map_contract.js` writes every section but the description. It also reads `## Enums` of existing contracts back for
enum reuse, so keep that section's shape.

- **Description.** The draft holds a `<!-- MODEL: ... -->` note (source field, links, variant descriptions) and the
  source text in a `~~~markdown` fence. Replace both with a fenced `dart` block of `///` lines: the `# Purpose` text,
  then `## Use when`, `## Don't use when`, and `## Related` as dartdoc headings, then `/// See also: <uri>` lines. A
  `# Related` name with a contract becomes `[Stratum<Name>]`; a name without one stays as written. After the block,
  list `# Content guidelines` under "Content guidelines, kept for `stratum-create-flutter-widget` to place:". The golden
  `scripts/test/expected/button.md` shows the result.
- **Properties.** One row per field in constructor order; `(base)` marks a base-class field. Figma cells name each
  source property (`` `✏️ leftIcon` + `👁️ showLeftIcon` ``, `` `🚦 state` (DISABLED) ``, nested `` `Badge` ``).
  Skipped properties close the table with `—` as the field. A `dart` block with the constructor follows the table.
- **Enums.** One `` ### `StratumButtonStyle` (new) `` heading per enum (`reused from <file>` when reused), then a
  `Figma value | Dart value | Doc` table; the Doc cell takes the variant description of that value.
- **States.** `Figma value | Dart`, one row per value used, from any variant.
- **Slots.** `Slot | Size | Width | Height | Sizing (H × V) | Wrapper`, one row per slot and size.
- **Visual tokens.** One row per combination of the non-`size` axes (`style × state` on Button): background,
  foreground, border, radius, padding (top right bottom left), gap, text. A token that changes only with `size` reads
  `by size` there and fills a second table, one row per size; a row whose variants all lack that layer reads `—`.
- **Nested.** `Figma component | Layer | Dart class | Field | Exposed properties`; `unresolved` until a contract exists.
  The Field cell reads `none (helper)` for a `☀` helper and `none (internal)` for an instance no property toggles or
  exposes. Exposed properties are listed for the reader; they never become fields.
- **Open questions.** The draft lists each ask as `- ASK: ...`. Apply every answer in the draft and delete its line; a
  question the user defers stays as a plain bullet. Write `None.` when nothing is left.

## Worked example

Approved 2026-09-30: the Button constructor the contract must produce.

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
  super.customStyle,
});
```
