---
name: stratum-figma-lint
description: Use when the user wants to lint, audit, or check the Stratum Figma design-system file for property naming, emoji template, value casing, typos, name collisions, and convention drift before components are read into Flutter contracts. Triggers on "lint figma", "ตรวจ figma", "check figma naming", "audit figma properties", a figma.com/design URL together with lint, audit, or ตรวจ, and on the lint gate that `stratum-read-figma` runs for one component set.
---

# Stratum Figma Lint

Figma property names become Dart constructor fields, so a Figma typo or collision becomes a Dart bug. This skill
reports those problems for the owner to fix in Figma; it never edits Figma or writes a report file.

It works on any Figma design file the user names; when the user gives no file URL, ask for one. Rules L01-L20, their
rationale, and the convention tables: [references/figma_conventions.md](references/figma_conventions.md). The data
lives only in `scripts/conventions.js`. Run commands from the repo root.

## Inputs

| Scope | Input                               | Lints                                    |
|-------|-------------------------------------|------------------------------------------|
| 1     | file URL                            | every page                               |
| 2     | file URL plus page names or ids     | those pages                              |
| 3     | file URL with `node-id` of one set  | that set (the `stratum-read-figma` gate) |

## Workflow

1. **REQUIRED SUB-SKILL:** load `figma:figma-use` before any `use_figma` call and list it in `skillNames`.
2. Scope 1 or 2: list pages with one `use_figma` call,
   `return figma.root.children.map((p) => ({ id: p.id, name: p.name }));`, then drop pages per the skip rules.
   `get_metadata` without `nodeId` can list only a few pages.
3. Batch at most 10 pages per call, keeping one section's pages (between two separator pages) together: L01 also
   compares values with more frequent ones inside a batch.
4. Build each call's `code` with
   `node .claude/skills/stratum-figma-lint/scripts/assemble.js --pages <id,id,...>` (scope 2: add `--named`; scope 3:
   `--node <node-id>`, URL form `123-456` accepted) and pass its stdout unchanged. Send all batch calls in parallel in
   one message.
5. Read each result:
   - `truncated: true` or cut-off JSON on a multi-page batch: split the batch in half, rerun both halves.
   - `truncated: true` on one page: keep the rows, state `omittedRows`.
   - rate-limit error: stop and tell the user how many pages were linted. Never retry in a loop.
6. Merge the batches and report in chat.

## Skip rules

The script applies these; step 2 applies the page rules before batching.

- Pages whose name starts with `.`, `─`, or `-`.
- Scope 1 only: pages whose name starts with `☀` or contains `Example` (documentation, example screens).
- Frames named exactly `Doc` or `Examples`, with their subtree.
- Components and sets whose name starts with `_`.
- Variant components: read through their set, never alone.

## Report

Each result holds `pages`, `counts`, `summary`, `errors` (sets Figma could not read), `componentPages` (component →
indexes into `pages`), and `rows` keyed by severity. A row is an array in `columns` order:
`rule, property, value, suggestion, components`, plus `note` when it adds detail. A last `+<n>` in `components`
counts the components left out.

1. One table per severity, in the order 🔴 blocking, 🟠 convention, 🟡 advisory, ℹ️ info, with columns
   `rule | page | component | property | value | message | suggestion`. Take `page` from `componentPages`, and
   `message` from the Rules table, the first table in the reference, plus `: <note>` when the row has one.
2. Merge rows from different batches that share rule, property, value, and suggestion.
3. List `errors` after the tables, then state once: L01 cannot catch misspelled proper nouns (country or bank names on
   icon variants) with no nearby vocabulary entry.
4. End with the summary line, summing `counts` over all batches, in exactly this shape:

```
lint: <n> blocking, <n> convention, <n> advisory, <n> info
```

Counts are findings, not rows. `stratum-read-figma` parses this line; any blocking finding stops it.

## Maintenance

- Convention change: edit one row in `conventions.js`, regenerate the reference tables with
  `node .claude/skills/stratum-figma-lint/scripts/gen_conventions_md.js`, then run
  `node --test .claude/skills/stratum-figma-lint/scripts/test/`. Tests fail on stale tables and on enum drift.
- New rule: one function in `lint_lib.js`, one `LINT_RULES` entry, its severity and message in
  `CONVENTIONS.rules`, one test, one reference section.
- L01 false positive on a real word, or new words in the file: follow "Refreshing knownWords" in the reference.
- Fixture capture: save a scope-3 `--mode raw` result as `scripts/test/fixtures/<name>.json` with
  `"synthetic": false`, then rerun the tests.

## Common mistakes

| Mistake                                  | Fix                                                 |
|------------------------------------------|-----------------------------------------------------|
| Retyping or editing the assembled code   | Rebuild it with `assemble.js`                       |
| One call per page, or all pages in one   | Batches of up to 10 pages, all sent in one message  |
| Reading an empty description as "none"   | Figma can read it empty; L19 names the re-publish fix |
