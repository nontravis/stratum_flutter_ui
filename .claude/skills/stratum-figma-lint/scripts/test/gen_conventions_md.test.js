// The generated tables in references/figma_conventions.md must match conventions.js.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const { CONVENTIONS } = require('../conventions.js');
const { renderTables, replaceBlock, DOC_PATH } = require('../gen_conventions_md.js');

test('references/figma_conventions.md holds the current generated tables', () => {
  const onDisk = fs.readFileSync(DOC_PATH, 'utf8');
  assert.equal(replaceBlock(onDisk, renderTables(CONVENTIONS)), onDisk, 'stale tables: run node scripts/gen_conventions_md.js');
});

test('generation rewrites only the marked block and escapes pipes in cells', () => {
  const doc = 'intro\n<!-- generated:start -->\nold\n<!-- generated:end -->\noutro\n';
  const conv = Object.assign({}, CONVENTIONS, { activeSuggestions: [{ components: ['Tabs'], suggestion: 'A|B' }] });
  const out = replaceBlock(doc, renderTables(conv));
  assert.ok(out.startsWith('intro\n<!-- generated:start -->\n') && out.endsWith('<!-- generated:end -->\noutro\n'));
  assert.ok(!out.includes('\nold\n'));
  assert.ok(out.includes('| Tabs | `A\\|B` |'));
  assert.throws(() => replaceBlock('no markers', 'x'), /markers not found/);
});
