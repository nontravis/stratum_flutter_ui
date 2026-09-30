// The returned result is compact: rows by severity as arrays in `columns` order, no per-row page list or rule text.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { CONVENTIONS, fixtureRecords, lintRecords, record, variant } = require('./helpers.js');
const { groupFindings, packLintResult, countBySeverity } = require('../lint_lib.js');

const ENTRY = fs.readFileSync(path.join(__dirname, '..', 'entry_lint.js'), 'utf8');
const LINT_RESULT_LIMIT = Number(ENTRY.match(/const LINT_RESULT_LIMIT = (\d+);/)[1]);

const bytes = (value) => Buffer.byteLength(JSON.stringify(value));
const allRows = (packed) => CONVENTIONS.severityOrder.flatMap((s) => packed.rows[s]);

test('the fixture batch (rule_table, Button, Alert, TextInput) packs without truncation', () => {
  const records = fixtureRecords('rule_table', 'button', 'alert', 'text_input');
  const pages = [...new Set(records.map((r) => r.page))];
  const findings = lintRecords(records);
  const packed = packLintResult(findings, pages, CONVENTIONS, [], LINT_RESULT_LIMIT);
  assert.equal(packed.truncated, undefined);
  assert.ok(bytes(packed) <= LINT_RESULT_LIMIT, bytes(packed) + ' bytes');
  assert.equal(allRows(packed).length, groupFindings(findings, CONVENTIONS, 10).length);
});

test('rows are arrays in columns order, grouped by severity, with pages given once and no rule text', () => {
  const findings = lintRecords([
    record('SocialButton', { '🚦 state': variant(['NORMAL', 'HOVERD']) }, { page: '❖ Buttons' }),
    record('Note', { '✏️ Text:#1:0': ['TEXT', ''] }, { page: '☀ Handoff' }),
  ]);
  const packed = packLintResult(findings, ['❖ Buttons', '☀ Handoff'], CONVENTIONS, [], LINT_RESULT_LIMIT);
  assert.deepEqual(packed.columns, ['rule', 'property', 'value', 'suggestion', 'components', 'note']);
  assert.deepEqual(Object.keys(packed.rows), CONVENTIONS.severityOrder);
  assert.deepEqual(packed.rows.blocking, [['L01', '🚦 state', 'HOVERD', 'HOVERED', ['SocialButton']]]);
  const l06 = packed.rows.convention.find((row) => row[0] === 'L06');
  assert.deepEqual(l06, ['L06', '✏️ Text:', '', '💬 text', ['Note'], 'trailing colon, not camelCase']);
  assert.deepEqual(packed.componentPages, { SocialButton: [0], Note: [1] });
  assert.equal(packed.messages, undefined, 'rule messages come from the reference Rules table');
  assert.ok(!JSON.stringify(packed).includes(CONVENTIONS.rules[0].message), 'no rule message in the result');
  assert.ok(!JSON.stringify(packed.rows).includes('❖ Buttons'), 'no page name inside rows');
});

test('every rule has a message in conventions', () => {
  CONVENTIONS.rules.forEach((row) => assert.ok(typeof row.message === 'string' && row.message.length > 0, row.id));
});

test('a component list capped for space ends with a +<n> entry', () => {
  const findings = lintRecords(['A', 'B', 'C', 'D'].map((name) => record(name, { '🏋️ Weight': variant(['Fill', 'REGULAR']) })));
  const row = groupFindings(findings, CONVENTIONS, 2).find((r) => r.rule === 'L07');
  assert.deepEqual([row.value, row.components, row.more], ['Fill', ['A', 'B'], 2]);
  const records = Array.from({ length: 40 }, (_, i) => record('Component' + i, { '🏋️ Weight': variant(['Fill', 'REGULAR']) }));
  const packed = packLintResult(lintRecords(records), ['❖ Test'], CONVENTIONS, [], 700);
  const cells = packed.rows.convention.find((r) => r[0] === 'L07');
  assert.equal(cells[4][cells[4].length - 1], '+' + (40 - (cells[4].length - 1)));
});

test('packLintResult stays under the limit, drops lowest-severity rows first, and flags truncation', () => {
  const records = Array.from({ length: 400 }, (_, i) => record('Comp' + i, { ['🏋️ Weight' + i]: variant(['Fill' + i, 'Light']) }));
  const findings = lintRecords(records);
  const packed = packLintResult(findings, ['❖ Icons'], CONVENTIONS, [], 4000);
  assert.equal(packed.truncated, true);
  assert.ok(packed.omittedRows > 0);
  assert.ok(bytes(packed) <= 4000, bytes(packed) + ' bytes');
  assert.equal(packed.counts.convention, countBySeverity(findings, CONVENTIONS).convention);
  Object.keys(packed.componentPages).forEach((name) =>
    assert.ok(allRows(packed).some((row) => row[4].includes(name)), name + ' is in no kept row'));
});
