// assemble.js: the bundle for one node id, and the size guard (characters, not bytes).
const test = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('child_process');
const path = require('path');
const { assemble, parseArgs, checkSize, MAX_CODE_CHARS } = require('../assemble.js');

const SCRIPT = path.join(__dirname, '..', 'assemble.js');

test('the bundle for one node id fills the id, strips comments and the export line, and stays under the limit', () => {
  const code = assemble(parseArgs(['--node', '55483-24307']));
  assert.ok(code.startsWith('const CONVENTIONS = {"skip":['), 'CONVENTIONS ships the skip rows only');
  assert.ok(!/^\s*\/\//m.test(code), 'no comment lines');
  assert.ok(!code.includes('__NODE_ID__'));
  assert.ok(!code.includes('module.exports'));
  assert.ok(code.trimEnd().endsWith('return readEntry(figma, "55483:24307", CONVENTIONS);'));
  assert.ok(code.includes('function normalizeName'), 'reuses the lint extract_lib.js');
  assert.ok(code.length <= MAX_CODE_CHARS * 0.95, code.length + ' characters');
});

test('the guard refuses code over MAX_CODE_CHARS and counts characters, not bytes', () => {
  assert.equal(MAX_CODE_CHARS, 50000);
  assert.equal(checkSize('a'.repeat(50000)).length, 50000);
  assert.throws(() => checkSize('a'.repeat(50001)), /code is 50001 characters, limit 50000/);
  const thai = 'ก'.repeat(30000);
  assert.ok(Buffer.byteLength(thai) > 50000);
  assert.equal(checkSize(thai), thai, '90,000 bytes but 30,000 characters passes');
});

test('the CLI prints the bundle, and exits 1 without --node', () => {
  const ok = spawnSync(process.execPath, [SCRIPT, '--node', '1:2'], { encoding: 'utf8' });
  assert.equal(ok.status, 0);
  assert.ok(ok.stdout.includes('readEntry(figma, "1:2", CONVENTIONS)'));
  const bad = spawnSync(process.execPath, [SCRIPT], { encoding: 'utf8' });
  assert.equal(bad.status, 1);
  assert.match(bad.stderr, /assemble: pass --node <id>/);
});
