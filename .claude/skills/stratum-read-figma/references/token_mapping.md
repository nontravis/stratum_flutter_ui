# Token mapping

- Bound color variables map to theme color tokens by variable name; bound spacing and radius variables map to the
  `space` and `radius` keys of the theme YAML (`assets/themes/default/theme.yaml`).
- Text styles are named `<type>[-<scale>]/<size>-<weight>` (for example `body/14-semi-bold`,
  `body-large/16-semi-bold`): `<type>` maps to the `FontType` value of the same name (`body` → `FontType.body`),
  `<size>` to `FontSize.s<size>`, `<weight>` to the `FontWeight` (`semi-bold` → `w600`); the `-<scale>` suffix repeats
  the size and is ignored.
- A hard-coded value (not bound) is copied into the contract with a `hard-coded` marker; `stratum-figma-lint` rule L12
  already reports it.

## How map_lib.js writes each token

| Token in the extracted data      | Contract cell                                                                 |
|----------------------------------|-------------------------------------------------------------------------------|
| color variable `button/primary/normal` | `` `button.primary.normal` `` (the variable name, `/` read as `.`)      |
| paint style name                 | the style name                                                                |
| radius variable `radius/md`      | `` `radius.md` `` when `md` is a `radius` key in the theme YAML, else ask     |
| spacing variable `space/md` (padding, gap) | `` `space.md` `` when `md` is a `space` key, else ask               |
| text style `body-large/16-semi-bold` | `` `FontType.body`, `FontSize.s16`, `FontWeight.w600` ``; no match: ask   |
| hex color, pixel number, raw font | the value plus `(hard-coded)`                                                |

Weights: `thin` `w100`, `extra-light` `w200`, `light` `w300`, `regular` `w400`, `medium` `w500`, `semi-bold` `w600`,
`bold` `w700`, `extra-bold` `w800`, `black` `w900`. The `FontType` values come from
`lib/src/themes/constant/font_type.dart`; the type is the longest leading run of `-` parts that names one
(`number-mono` → `numberMono`).

## Where tokens come from

Per variant, `entry_read.js` reads the background, border, radius, padding, and gap of the variant frame, and the
foreground and text style of its first visible text layer outside nested instances. A token that changes only with
`size` reads `by size` in the `style × state` table and gets its own `Size` table (see `contract_template.md`). A
variant without that layer (no text while `LOADING`) does not break the size rule; its row reads `—`.
