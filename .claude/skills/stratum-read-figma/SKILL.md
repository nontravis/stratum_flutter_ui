---
name: stratum-read-figma
description: 'Use when the user wants to read a component set from the Stratum Figma design-system file and turn it into a Flutter widget contract: property-to-field mapping, enums, states, slots, nested components, visual tokens, and docs. Triggers on "read figma component", "อ่าน figma", "สร้าง contract จาก figma", "figma to contract", or a figma.com/design URL with a `node-id` plus read, map, or contract.'
---

# Stratum Read Figma

Every Figma component property becomes one configurable field of a Dart constructor. This skill reads one component
set, maps it with the rules in `references/`, and writes a contract that `stratum-create-flutter-widget` implements,
so the owner reviews the mapping before any Dart exists.

It works on any Figma design file the user names. Never hardcode a file key or URL: when the user gives no URL, ask
for one, and take the contract's `fileKey` from this run's URL. Run commands from the repo root. Scratch files go to
`/tmp/stratum-read-figma/`.

## Inputs

- A figma.com/design URL whose `node-id` points at a component set or a standalone component with properties.
- No `node-id`: list the component sets on the page the user names, skipping `Doc` and `Examples` frames, and ask which
  one to read. Pages whose name starts with `☀`, and example-screen pages, hold no widgets: say so and ask before
  reading one.

## Workflow

1. **Load.** **REQUIRED SUB-SKILL:** load `figma:figma-use` before any `use_figma` call and list it in `skillNames`.
2. **Gate.** Run `stratum-figma-lint` with scope 3 (`node-id`). Read its summary line
   `lint: <n> blocking, <n> convention, <n> advisory, <n> info`. When the blocking count is above zero, stop, show
   the blocking findings, and ask the user to fix them in Figma or to confirm continuing anyway.
3. **Extract.** Build the code with `node .claude/skills/stratum-read-figma/scripts/assemble.js --node <node-id>`
   (URL form `123-456` accepted) and pass its stdout unchanged to `use_figma`. The code reads only and returns
   `{ component }`; save that result unchanged as `/tmp/stratum-read-figma/<snake_name>.json`.
   - `omitted` in the result: parts dropped to stay under the result limit; the draft asks for them.
   - `node not found` or `not a component set`: tell the user. A rate-limit error: stop; never retry in a loop.
4. **Resolve.** Run `node .claude/skills/stratum-read-figma/scripts/map_contract.js --data <json> --file-key <key>
   --out /tmp/stratum-read-figma/<snake_name>.md`. It prints `asks:` and `contract:` lines and reads the repo:
   - Nested instances: the frontmatter `figma.componentKey` of every contract in `docs/specs/stratum_ui/components/`
     gives the Dart class. No match is `unresolved`; ask the user whether to read that component first. Never recurse
     on your own: after a yes, finish that component's run, then rerun this step.
   - Enum reuse: an enum in `lib/` or in a contract's `## Enums` with exactly the same value set is reused. When the
     same value set appears for the first time in a second component, ask the user for the shared enum name (for
     example `StratumFieldStyle`) and use it in both contracts.
5. **Map.** The draft applies `references/`; anything no rule covers (an unknown `state` value, a symbol-only value, a
   size outside every vocabulary) is an `- ASK:` line under `## Open questions`. Put every ask to the user in one
   message. Never guess. Apply each answer in the draft. Then replace the `<!-- MODEL -->` block with the class dartdoc
   and fill the enum Doc cells, per `references/contract_template.md`.
6. **Write** the draft to the `contract:` path,
   `docs/specs/stratum_ui/components/<section>/<snake_name>/<snake_name>.md` (`control/button/button.md`). When the
   file exists, show the diff and ask before overwriting.
7. **Hand off.** Tell the user to run `stratum-create-flutter-widget` on the contract.

## References

| File                                                                 | Covers                                                   |
|----------------------------------------------------------------------|----------------------------------------------------------|
| [property_mapping.md](references/property_mapping.md)                | Figma property to Dart field, enum names, base class     |
| [state_mapping.md](references/state_mapping.md)                      | the `state` split                                        |
| [size_mapping.md](references/size_mapping.md)                        | `WidgetSize`, `FontSize`, pixel sizes                    |
| [token_mapping.md](references/token_mapping.md)                      | variables, text styles, hard-coded values                |
| [contract_template.md](references/contract_template.md)              | contract sections and formats, worked example            |

`scripts/map_lib.js` holds the deterministic rules; the description prose and every ask stay with you.

## Maintenance

- Tests: `node --test .claude/skills/stratum-read-figma/scripts/test/`. The golden `scripts/test/expected/button.md`
  must keep the approved constructor.
- Fixture capture: run step 3 on Button, Alert, and TextInput and save each result as
  `scripts/test/fixtures/<name>.json` with `"synthetic": false`. Rerun the tests; when only the golden's data
  sections differ, update the golden from the reviewed draft, keeping its description block.
- A rule change: edit the reference and `map_lib.js` together, with one test in `scripts/test/map.test.js`.

## Common mistakes

| Mistake                                                   | Fix                                                      |
|-----------------------------------------------------------|----------------------------------------------------------|
| Retyping the assembled code or the saved result           | Rebuild with `assemble.js`; save the result as returned  |
| Writing a contract that still holds `- ASK:` or `MODEL`   | Resolve every ask and write the dartdoc first            |
| Hand-editing a mapped row because a rule looks wrong      | Ask the user; change the reference and `map_lib.js`      |
