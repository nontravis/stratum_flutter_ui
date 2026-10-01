# Skill spec: `stratum-figma-lint`

| Field    | Value                                                                  |
|----------|------------------------------------------------------------------------|
| name     | `stratum-figma-lint`                                                   |
| scope    | project (`projects/stratum_ui/.claude/skills/stratum-figma-lint/`)     |
| budget   | 800 words (`wc -w SKILL.md`; `references/` and `scripts/` not counted) |
| status   | approved design, 2026-09-30                                            |
| sibling  | `stratum-read-figma` depends on this skill (scripts and lint gate)     |

## Trigger description

> Use when the user wants to lint, audit, or check the Stratum Figma design-system file for property naming, emoji template, value casing, typos, name collisions, and convention drift before components are read into Flutter contracts. Triggers on "lint figma", "ตรวจ figma", "check figma naming", "audit figma properties", a figma.com/design URL together with lint, audit, or ตรวจ, and on the lint gate that `stratum-read-figma` runs for one component set.

## Purpose

Stratum-style design systems live in Figma files. Their component property names and values feed code generation: every Figma property becomes a Dart constructor field. A typo, a name collision, or an inconsistent value in Figma becomes a bug or an inconsistent API in Dart. This skill reports those problems so the owner fixes them in Figma first. It never edits Figma.

The skill works on any Figma design file the user names. It never hardcodes a file key or URL: not in SKILL.md, references, or scripts. When the user gives no URL, ask for one. Test fixtures may keep data captured from the reference file below.

## Facts measured on 2026-09-30 (reference file, used for design and fixtures only)

- Reference file: `Design System 4 by Nonthawit` (file key `wjRe9eL7863nMRfFats8jZ`). Other files may differ in page layout and vocabulary.
- 79 pages, about 300 component sets, plus 1,254 icon component sets on the `❖ Icons & Logos` page. Component pages sit under separator pages named `─── Control`, `─── Disclosure`, `─── Display`, `─── Feedback`, `─── Form`, `─── Navigation`, `─── Overlay`.
- `get_metadata` without `nodeId` listed only 3 of 79 pages. List pages with `use_figma` (`figma.root.children`) instead.
- `use_figma` truncates its returned value at about 20 KB and accepts at most 50,000 characters of `code`.
- The owner's Figma plans are `starter` and `pro` (Full seat). The Figma MCP rate limit on Pro is 200 read calls per day and 10 per minute. Code Connect needs an Organization or Enterprise plan, so it is unavailable.
- `figma:figma-use` must be loaded before every `use_figma` call. Load a page with `await page.loadAsync()`; never loop `figma.setCurrentPageAsync`.
- `componentPropertyDefinitions` throws on a variant `COMPONENT`; read it from the `COMPONENT_SET` or from a standalone `COMPONENT`.
- `description` and `descriptionMarkdown` can appear empty because of a known Figma bug; re-publishing fixes it.

## Inputs

One of three scopes:

1. A file URL: lint every page.
2. A file URL plus a page filter (page names or ids): lint those pages.
3. A file URL plus `node-id` of one component set: lint that set only. `stratum-read-figma` uses this scope as its gate.

## Workflow

1. Load `figma:figma-use`.
2. Scope 1 or 2: run one `use_figma` call that returns `figma.root.children` as `{ id, name }`, then apply the page skip rules.
3. Split the pages into batches of at most 10 pages. Send the batch calls in parallel in one message; the MCP rate limit is handled by behavior (step 5), never by a number written into the skill. Each call runs the concatenated script (see "Script assembly") and returns compact findings only.
4. If a result is truncated, split that batch in half and rerun it.
5. If the rate limit is hit, stop and tell the user how many pages were linted. Do not retry in a loop.
6. Merge the findings and report them in chat (see "Report"). Do not write a report file.

## Skip rules

- Frames named exactly `Doc` or `Examples`, with their whole subtree.
- Pages whose name starts with `.` (for example `.utilities`, `.thumbnail`).
- Separator pages whose name starts with `─` or `-`.
- Documentation pages whose name starts with `☀` (foundations, helpers, native mocks, embeds, cursors, utilities) and pages whose name contains `Example` (example screens). They hold no Flutter widgets. A user who names such a page explicitly (scope 2) still gets it linted.
- Components and component sets whose name starts with `_` (private).
- Variant `COMPONENT` nodes are read through their parent set, never on their own.

## Conventions (encoded in `scripts/conventions.js`)

`conventions.js` is the single source of truth and holds data only. `lint_lib.js` and the tests read it. Each table is an array of row objects, one object per table row, so the owner edits one object to change one row.

`references/figma_conventions.md` shows the data as Markdown tables for people to read. The tables are generated, never hand-edited:

- `node scripts/gen_conventions_md.js` rewrites only the block between `<!-- generated:start -->` and `<!-- generated:end -->`; hand-written rationale stays outside the markers.
- A test regenerates the block in memory and fails when the file on disk differs, so a stale table cannot pass.
- Generated tables: emoji by role; canonical property names with the legacy names they replace (`helperText` ← `helper`, `showHelperText` ← `showHelper`, `groupErrorText` ← `groupError`, `label` ← `labelText`, `stepNumber` ← `step`, `showLine` ← `line`); value vocabularies (`state`, `size`, `color`, feedback) with the legacy values they replace (`HOVERED` ← `HOVER`, `🔴 NEGATIVE` ← `ERROR`); `ACTIVE` suggestions; `knownWords`; skip rules.

### Property name format

- `<emoji><one space><camelCaseName>`, exactly one emoji, no trailing `:` or space, no double space.
- The emoji follows the role template below. The role comes from the property type plus its name, so a new `show*` property needs no dictionary update.

| Role                                                                  | Property type                   | Emoji |
|-----------------------------------------------------------------------|---------------------------------|-------|
| any name starting with `show`                                         | BOOLEAN                         | 👁️    |
| a graphic toggle: `icon`, `logo`, or a name ending in `Icon` or `Logo` (logo follows icon) | BOOLEAN | 👁️, renamed `show<Name>` (`💼 logo` → `👁️ showLogo`, `🔍 Icon` → `👁️ showIcon`) |
| `loading`                                                             | BOOLEAN                         | ⏳     |
| `checked`, `selected`                                                 | BOOLEAN or VARIANT              | ✅     |
| `expanded`                                                            | VARIANT                         | ↕️    |
| `filled` (the input holds a value)                                    | VARIANT                         | ✍️    |
| any other flag (`removable`, `stacked`, `outgoing`, `portrait`, ...) | BOOLEAN or VARIANT `False/True` | 🔘    |
| text                                                                  | TEXT                            | 💬    |
| slot: the default swapped component is a Slot (its name contains `Slot` or starts with `❖`), or the property names a layout region (`top`, `body`, `bottom`, `left`, `right`, `tab`, `content`, `snackbar`, `slot`) whatever its default | INSTANCE_SWAP | ❖     |
| any other swap: icon, illustration, logo, badge, ...                  | INSTANCE_SWAP                   | ✏️    |
| `style`                                                               | VARIANT                         | 🕶️    |
| `type`                                                                | VARIANT                         | 🔖    |
| `size`                                                                | VARIANT                         | 📐    |
| `state`, `status`                                                     | VARIANT                         | 🚦    |
| `color`                                                               | VARIANT                         | 🌈    |
| `accent`                                                              | VARIANT                         | 💡    |
| `position`, `align`                                                   | VARIANT                         | 📍    |
| `direction`, `arrow`                                                  | VARIANT                         | ➡️    |
| `layout`                                                              | VARIANT                         | ⬒     |
| `platform`, `os`, `browser`                                           | VARIANT                         | 🖥️    |
| counts (`items`, `tabs`, `steps`, `section`, `page`, ...)            | VARIANT                         | 🔢    |
| `theme`, dark mode                                                    | VARIANT                         | 🌗    |
| `graphic`, `image`, `emotion`                                         | VARIANT                         | 🏞️    |
| any other variant                                                     | VARIANT                         | 🔖    |

### Property name vocabulary

- Message text uses the `*Text` family with a matching `show*Text` toggle: `helperText` / `showHelperText`, `errorText` / `showErrorText`, `warningText`, `successText`, `groupHelperText`, `groupErrorText`. `label` stays `label`.
- Visual variants (`GHOST`, `OUTLINE`, `FILLED`, `SHADED`, `SUBTLE`, ...) live in a property named `style`, never `type`.
- A property that means `status` (step progress, chat delivery, upload) is named `status`; `state` is reserved for widget interaction state.
- Numbered list toggles (one BOOLEAN per list item) are named `👁️ show<Item><N>`: `👁️ showCheckbox1`, `👁️ showMenuItem1`, `👁️ showTag1`, `👁️ showBadge1`, `👁️ showFile1`, `👁️ showAccordion1`. Legacy forms such as `1. Checkbox`, `Menu item 1`, `🏷️ Badge 1`, `File 1`, and `Accordion 1 (first)` are reported by L20, once per component, and never by L01, L03, L05, or L06. `stratum-read-figma` maps the series to `List<Widget>`, not to single fields.

### Value rules

- Values are `UPPER_SNAKE`. Emoji inside a value is allowed only for feedback dots and direction arrows (`← LEFT`).
- A value never starts with a digit, because a Dart enum value cannot. L07 never suggests one: when the `UPPER_SNAKE` form starts with a digit, the suggestion is empty and the note asks for a word (TextSkeleton `length: 1/5`, for example `ONE_FIFTH`). Counts (🔢) and numeric sizes keep their digits.
- A graphic-role variant (🏞️: `graphic`, `image`, `emotion`) names pictures, so its values skip L09 and L15 (Illustration `🏞️ image: SUCCESS` is an illustration, not feedback).
- A boolean variant uses `False|True`, never `FALSE|TRUE` or `Off|On`.
- Feedback values are `🔵 INFO`, `🔴 NEGATIVE`, `🟡 WARNING`, `🟢 POSITIVE`; `⚫️ NORMAL` means no feedback. These match `FeedbackState`.
- `state` values come from this vocabulary: `NORMAL`, `HOVERED`, `PRESSED`, `FOCUSED`, `DRAGGED`, `SELECTED`, `DISABLED`, `LOADING`, `PROGRESS`, plus the feedback values. `LOADING` and `PROGRESS` stay in `state` (owner ruling 2026-10-01): `stratum-read-figma` maps them to `loading: true` and `loading: true` plus `progress: double?`, so lint no longer advises a `⏳ loading` property.
- Legacy values are old conventions, not typos: `HOVER` → `HOVERED`, `PRESS` → `PRESSED`, `FOCUS` → `FOCUSED`, `DRAG` → `DRAGGED`, `ERROR` → `🔴 NEGATIVE`, and the like. A legacy value is reported by L10 (🟠) with its suggestion and never by L01. Misspellings such as `HOVERD`, `HOVERDED`, and `DRAGED` are not legacy values; they stay L01 (🔴).
- `ACTIVE` is ambiguous and gets a context-specific suggestion:

| Where                                                                                                                            | Suggestion                                     |
|----------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------|
| text inputs (TextInput, Combobox, Dropdown, DateInput, TimeInput, NumberInput, TextArea, TextEditor, Stepper, InlineEditableText, ChatMessageInput) | `FOCUSED`                                      |
| TextDropdown, IconDropdown                                                                                                       | `↕️ expanded: True`                            |
| SideNavigationMenu, PageDot, ChartBar                                                                                            | `SELECTED`                                     |
| BottomNavigationMenu (already has `✅ selected`)                                                                                 | `PRESSED`                                      |
| RatingElement, RatingEmoji (`ACTIVE/INACTIVE`)                                                                                   | `✅ selected: False/True`; keep `NORMAL/HOVERED` (`filled` already means "the input holds a value") |

- Values allowed outside the Dart enums (owner ruling 2026-10-01, group 2 category 3): `state` gains `EMPTY` (a real `FullWidgetState` member) and accepts a `_LEFT` or `_RIGHT` part suffix on its values for split controls (SplitButton `HOVERED_LEFT`); design-only `size` values `FILL_WIDTH` and `EXTRA_TINY`; design-only `color` values `BLACK`, `GHOST`, `CUSTOM` (the caller sets the color), and `LOADING` (it may sit in any variant). A property named `status` (ChatStatus, UploadedFile, Steps) is not checked against the `state` vocabulary.
- `size` values come from `WidgetSize`: `TINY`, `EXTRA_SMALL`, `SMALL`, `MEDIUM`, `LARGE`, `EXTRA_LARGE`, `HUGE`. Font-size numbers (`10`, `12`, `14`, `16`, `18`, `20`, `24`, `36`, `48`, `56`) and pixel numbers with `Free` are allowed and reported as info. Anything else is flagged.
- `color` values come from `ColorEnum` in `UPPER_SNAKE` (`BRAND`, `RED`, `PINK`, `ROSE`, `VIOLET`, `PURPLE`, `INDIGO`, `BLUE`, `CYAN`, `TEAL`, `EMERALD`, `GREEN`, `MOSS`, `LIME`, `YELLOW`, `AMBER`, `ORANGE`, `BROWN`, `BLUE_GRAY`, `GRAY`), plus the feedback values and `NONE`. `VIOLET` and `PURPLE` are distinct colors in `ColorEnum`.

### Rules

| ID  | Rule                                                                                                                                                | Severity |
|-----|-----------------------------------------------------------------------------------------------------------------------------------------------------|----------|
| L01 | Typo: a name or value within Levenshtein distance 2 of a vocabulary or `knownWords` entry, or of a value used more often in the same batch (for example `HOVERD` next to `HOVERED`) | 🔴       |
| L02 | Two properties of one component normalize to the same name (for example `showSuccessText` as BOOLEAN and as TEXT)                                   | 🔴       |
| L03 | A name normalizes to an empty string (for example `%`, `⌥`)                                                                                         | 🔴       |
| L04 | A normalized name is a Dart reserved word or built-in identifier (for example `dynamic`)                                                             | 🔴       |
| L05 | Emoji missing or not matching the role template                                                                                                     | 🟠       |
| L06 | Name format: trailing `:` or space, double space, not camelCase                                                                                     | 🟠       |
| L07 | Value not `UPPER_SNAKE`, or emoji in a non-feedback, non-direction value                                                                           | 🟠       |
| L08 | Boolean variant not `False/True`                                                                                                                    | 🟠       |
| L09 | Feedback value not in the feedback vocabulary (`ERROR`, `NEGATIVE` without dot, `🟢 SUCCESS`)                                                        | 🟠       |
| L10 | `state`, `size`, or `color` value outside its vocabulary                                                                                             | 🟠       |
| L11 | Visual variant named `type` instead of `style`                                                                                                     | 🟠       |
| L12 | Fill or stroke color not bound to a variable (hard-coded hex)                                                                                       | 🟠       |
| L13 | `ACTIVE` value (with the context suggestion above)                                                                                                  | 🟡       |
| L14 | Variant with a single value                                                                                                                         | 🟡       |
| L15 | Mixed axis: an interaction value (`DISABLED`, `HOVER*`, `PRESSED`) inside a property not named `state` or `status` (`LOADING` and feedback values are allowed anywhere since 2026-10-01), or a slot value (`CONTENT`, `Slot`) inside a `position` or `type` variant, unless the set has a `❖` slot property of the same name (`CONTENT` with `❖ content`, `SLOT` with `❖ slot`) | 🟡       |
| L16 | Same concept under a different name across components (`helper` versus `helperText`, `step` versus `stepNumber`)                                     | 🟡       |
| L17 | Retired 2026-10-01: `LOADING` and `PROGRESS` inside `state` are allowed (see "Value rules"); the ID stays reserved                                  | —        |
| L18 | Variant matrix incomplete (existing variants fewer than the product of the option counts)                                                            | ℹ️       |
| L19 | Component set without `descriptionMarkdown` (mention the re-publish workaround)                                                                     | ℹ️       |
| L20 | Numbered list toggles not named `👁️ show<Item><N>` (one finding per component, listing the properties)                                             | 🟠       |

Each problem is reported once, by its highest-severity rule: a value caught by L01 is not reported again by L10, and `ACTIVE` is reported only by L13.

L01 never fires on:

- a legacy value (L10 owns it);
- a value or name whose parts are all known words (`LEFT_RIGHT` = `LEFT` + `RIGHT`; `showLeftItems` = `show` + `Left` + `Items`);
- a value that differs from a known word only by a numeric suffix (`LOADING_1`, `LOADING_2`), which is an animation frame, not a typo;
- a numbered list toggle (L20 owns it).

At equal distance, a canonical name wins over a `knownWords` entry, then the name used more often in the batch wins (`💬 lebel` → `label`, not `level`).

L16 compares properties of the same type only: the canonical `line` → `showLine` pair is a BOOLEAN rename, so a TEXT `💬 line` (MultiLineCodeSnippet line numbers) is not reported.

Name normalization (shared with `stratum-read-figma`): strip the `#<id>` suffix Figma adds to BOOLEAN, TEXT, and INSTANCE_SWAP names, strip emoji and symbols, trim, collapse spaces, then convert to camelCase.

### Known words

The "used more often" check in L01 sees only one batch, and the single-node gate of `stratum-read-figma` sees one component set. A typo whose correct spelling lives in another batch (for example `MXIED`, `descrtiption`, `STRING`) would slip through. `conventions.js` therefore holds a curated `knownWords` list: the correctly spelled property names (normalized camelCase) and values used in the file. L01 compares every name and value against it in every scope.

- The first seed comes from a real-file `vocab` run (see "Script assembly"), curated by main and the owner so that no typo enters the list. A token within distance 2 of a more frequent token is excluded unless a vocabulary already names it (`HOVERED` stays; `HOVERD` goes).
- When the Figma file gains new words, refresh the list with the same `vocab` run. `references/figma_conventions.md` documents the refresh steps; SKILL.md only points to them.

The list holds `INPUT` (SimplePagination `type`), which the 2026-09-30 dry run flagged as a typo of `PUT`.

Known limit: L01 cannot catch misspelled proper nouns that have no nearby vocabulary entry (for example country or bank names on icon variants). The report says so once.

## Report

- One table per severity, in the order 🔴, 🟠, 🟡, ℹ️, with columns `rule | page | component | property | value | message | suggestion` (the message comes from the rule id plus any per-finding note).
- Group repeated findings (the same wrong value in many components) into one row that lists the components.
- End with one summary line in this exact shape, which `stratum-read-figma` parses: `lint: <n> blocking, <n> convention, <n> advisory, <n> info`.

## Script assembly

```
scripts/
├── conventions.js     data only: emoji template, vocabularies, skip rules, ACTIVE suggestions
├── extract_lib.js     pure: walk a page or node, apply skip rules, normalize names, collect definitions
├── lint_lib.js        pure: rules L01-L19 over extracted data, returns findings
├── entry_lint.js      Figma calls only: load pages or one node, call the libs, return findings
└── test/
    ├── fixtures/      JSON captured from the real file with entry_lint.js in raw mode
    └── *.test.js      node --test
```

- The agent concatenates `conventions.js` + `extract_lib.js` + `lint_lib.js` + `entry_lint.js`, replaces the placeholders `__PAGE_IDS__`, `__NODE_ID__`, and `__MODE__`, and passes the result to `use_figma`. The concatenated code stays under 50,000 characters.
- `__MODE__` is `findings` (default), `raw`, or `vocab`. `raw` returns the extracted data for one node and exists only to capture test fixtures. `vocab` returns, per batch, each normalized property name and each value with its use count, compact enough to stay under the result limit; main merges the batches to seed or refresh `knownWords`.
- Library files use no `import`, no top-level `await`, and no `figma` global. Each ends with `if (typeof module !== 'undefined') module.exports = { ... };` so `node --test` can `require` it while the Figma sandbox skips the export.
- A finding has the shape `{ rule, severity, page, component, property, value, message, suggestion }` inside the sandbox. The returned result is compact so a batch of up to 10 pages fits without truncation: rows carry no text derivable from the rule id (the rule message lives in `conventions.js` and the reference), and page names travel once in a component → page map instead of once per row.
- Functions stay small and named by concern (`readPropertyDefinitions`, `readVariantMatrix`, `normalizeName`, `checkEmojiTemplate`, ...). Adding a rule means adding one function and one entry to the rule list.

## References

- `references/figma_conventions.md`: generated tables (see "Conventions") plus hand-written rationale for each rule, with one before/after example per rule, and the `knownWords` refresh steps.

## Tests

1. **Unit tests** (`node --test`, no npm packages). Fixtures captured from Button (every property type), Alert (nested instances, `STRING` typo, `warningIcon` default equal to `errorIcon`), and TextInput (`showSuccessText` collision). The tests assert the known findings: L01 for `HOVERD` and `STRING`, L02 for `showSuccessText`, L03 for `%`.
2. **Drift test.** Parse the enum values of `ColorEnum`, `WidgetSize`, `FeedbackState`, `FontSize`, and `WindowSize` from `lib/src/themes/constant/*.dart`, and of `FullWidgetState` from the `flutter_falmodel` package located through `.dart_tool/package_config.json`. Fail when a vocabulary in `conventions.js` does not match.
3. **Behavioral test** after build: lint the real file and confirm the report contains the findings from the 2026-09-30 audit (for example `HOVERD` in SocialButton, `MXIED` in LeftToggle, `descrtiption` in MenuItem, the `showSuccessText` collision in TextInput).

## Behavioral test (recorded 2026-09-30)

- Scenario: lint 27 real component pages in three batches (Control 10, Feedback 7, Form 10), then a round-6 check on ⬒ Layouts, ❖ Menu, and ❖ Navigation (Side).
- RED (before the round-4 fixes): Control returned 31 blocking, of which about 19 were false (legacy `HOVER`, `LOADING_1/2`, numbered toggles, `macOS`, `LEFT_RIGHT`), and the result was truncated (132 rows omitted).
- GREEN (after round 4): Control 12, Feedback 7, Form 8 blocking, every one a real typo or name collision (`HOVERD`, `MXIED`, `descrtiption`, `STRING`, `NORMALL`, `showLebel`, `showTItle`, `TODOAY`, `DRAGED`, `🟡 WARNGIN`, the `showSuccessText` and `size` collisions); no truncation. Round-6 check: slot names resolved in the sandbox with no error; PageLayout slots no longer flagged; MenuItem `↻ right` suggests the slot emoji.
- Verdict: pass, with the region-name slot rule and the ❖ emoji change queued for round 7.

## Out of scope

- Writing to Figma (renames, fixes, descriptions).
- Generating contracts or Dart code (`stratum-read-figma`, `stratum-create-flutter-widget`).
- Code Connect.
- Writing a report file.

## Decisions log

- 2026-09-30: lint is its own skill, separate from `stratum-read-figma`, and owns the shared scripts (`conventions.js`, `extract_lib.js`). `stratum-read-figma` depends on it.
- 2026-09-30: read-only. Findings are fixed by the owner in Figma.
- 2026-09-30: emoji template by role (type plus name prefix), not a per-name dictionary.
- 2026-09-30: message text uses the `*Text` family; `ACTIVE` gets context-specific renames; `status` shares 🚦 with `state`; `PROGRESS` means a determinate progress bar.
- 2026-09-30 (after first build): skill names use kebab-case (`stratum-figma-lint`, `stratum-read-figma`); L01 adds a curated `knownWords` list seeded by a `vocab` run so typos are caught across batches and in the single-node gate; Rating `ACTIVE/INACTIVE` becomes `✅ selected`, because `filled` already means "the input holds a value".
- 2026-09-30: `conventions.js` stays the single source; `references/figma_conventions.md` tables are generated from it and a test fails on a stale table.
- 2026-09-30: no hardcoded Figma file key or URL anywhere in the skills; the user names the file on every run.
- 2026-09-30: interaction state values end in "ED" to match `FullWidgetState` and Flutter `WidgetState`; legacy values `HOVER` → `HOVERED`, `PRESS` → `PRESSED`, `FOCUS` → `FOCUSED`, `DRAG` → `DRAGGED` (L10 🟠). The misspellings `HOVERD`, `HOVERDED`, `DRAGED` are typos (L01 🔴), not legacy values; an earlier line of this log listed them as legacy by mistake.
- 2026-09-30: an INSTANCE_SWAP is a slot (◇) when its default swapped component is a Slot; the entry script resolves the default component's name (the sandbox may resolve names; the libraries stay pure) and falls back to the property name when the component is not in the file. Cleanup scope is component pages (❖) and layout pages (⬒ Layouts): `☀` pages and example screens are skipped by default, and L12 is reported but excluded from the rename cleanup.
- 2026-09-30: the slot emoji is ❖ (it was ◇ until this line; earlier log lines keep ◇ as history). Existing `◇`, `↻`, and `↺` slot names are renamed to `❖` in the cleanup; `❖ type` becomes `🔖 type` as before.
- 2026-09-30 (after the independent audit): the findings bundle keeps at least 5% headroom under MAX_CODE_CHARS, checked by a test on a 10-page batch of real-shaped ids; legacy-value lookup is case-insensitive (`Hover` → `HOVERED`); scope 3 lints a private `_` set when the user names it; the FullWidgetState drift test fails, not skips, when the package cannot be located.
- 2026-09-30: a layout-region property is a slot even when its default is a real component (CardLayout `◇ top` defaults to `TopNavigation`; Sidebar `◇ top/body/bottom` default to `SideNavigationMenu`); the region-name match applies whether or not the default name resolved.
- 2026-09-30 (after the first real-file run on 10 Control pages): numbered list toggles are named `👁️ show<Item><N>` (L20); L01 skips legacy values, compounds of known words, numeric-suffix frames, and list toggles; the returned result is compacted; knownWords gains `macOS` (was misspelled `macOs` in the seed) and `LEFT_RIGHT`.
- 2026-09-30 (after the cleanup dry run of every ❖ and ⬒ Layouts page): logo follows icon (owner ruling): an INSTANCE_SWAP `logo` takes ✏️ and a BOOLEAN logo toggle becomes `👁️ showLogo`, as `icon` becomes `👁️ showIcon`. Lint fixes from the dry run: `INPUT` joins `knownWords`; L01 breaks distance ties toward canonical names (`lebel` → `label`); L16 compares same-type properties only; graphic-role values skip L09 and L15; L07 never suggests a value that starts with a digit.
- 2026-10-01 (group 2, category 1): `LOADING` and `PROGRESS` stay inside `state`. `FullWidgetStates` in `flutter_falconx` is a set that already holds `loading`, so a one-value variant maps to it without loss; splitting a `⏳ loading` axis in Figma would restructure about 25 sets for combinations nobody draws. L17 is retired; `stratum-read-figma` keeps its `LOADING` and `PROGRESS` mapping.
- 2026-10-01 (group 2, category 2a): a slot value inside `position` or `type` stays when the set has a `❖` slot property of the same name; the value selects the layout that shows that slot. Eight sets follow it (BottomActions, ModalActions, TooltipAction, MenuItem, SideNavigationMenu, ModalContent, MarketingActions with `CONTENT` + `❖ content`; StateActions with `SLOT` + `❖ slot`). L15 reports a slot value only when no matching slot property exists.
- 2026-10-01 (group 2, categories 2b and 2c): feedback values and `LOADING` may sit in any variant (Spinner and ModalContent `type`, Toggle `checked`, FileGeneral `style`/`type`, BarCell `color`); each value is one drawn look, and `stratum-read-figma` maps `LOADING` to `loading: true` and feedback values to `FeedbackState` wherever they appear. L15 keeps reporting interaction values (`HOVER*`, `PRESSED`, `DISABLED`) outside `state`.
- 2026-10-01 (group 2, category 3): renames in Figma: ChatStatus `🚦 state` → `🚦 status` with `SENDING/SENT/FAILED`; UploadedFile `🚦 state` → `🚦 status` with `UPLOADING`; ChartContainer `📐 size` → `⬒ layout`; SpinnerIndeterminate `🚦 state` → `🔢 frame`; StateIcon `🔄 CUSTOM` → `CUSTOM`; PinInput `TYPING` → `FOCUSED` and `FILLED` → a `✍️ filled` axis. Lint accepts the values listed under "Value rules"; `frame` joins the count names (🔢).
- 2026-10-01 (group 2, categories 4 and 5): `ACTIVE` resolved in Figma per the ACTIVE table: RatingElement and RatingEmoji gained a `✅ selected` axis, TextDropdown and IconDropdown a `↕️ expanded` axis, and TagDropdown `ACTIVE` became `FOCUSED`. Single-value variants were dropped (FilterButton and SortButton `🚦 state`, ChartContainer `🚦 state`, BottomNavigation `🖥️ platform` and `🚦 state`, EmptyStateSection `🔖 type`); a property comes back when it has a second value.
