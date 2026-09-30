// knownWords must hold only correct spellings: no typo and no legacy value may slip in.
const test = require('node:test');
const assert = require('node:assert/strict');
const { CONVENTIONS, lintRecords, record, variant, find } = require('./helpers.js');

const words = (groups) => groups.join('|').split('|');
const NAMES = words(CONVENTIONS.knownWords.names);
const VALUES = words(CONVENTIONS.knownWords.values);

// "Excluded on purpose" in the owner-approved 2026-09-30 seed: the file's typos and legacy values.
const EXCLUDED = ['HOVERD', 'HOVERDED', 'MXIED', 'NORMALL', 'WARNGIN', 'TODOAY', 'INCOMPLIETED', 'DRAGED', 'COTROL',
  'MEDIUm', 'STRING', 'SERACHING', 'DECENDING', 'SUBTLED', 'descrtiption', 'showLebel', 'lebel', 'showTItle', 'showicon',
  'showEstimateLIne', 'minMaxPostion', 'dymanic', 'ration', 'showFileAttachement', 'showMoreMediaAttache', 'hightLight',
  'HOVER', 'PRESS', 'FOCUS', 'DRAG', 'TODAY_HOVER', 'INCOMPLETED'];

test('no excluded typo or legacy value is a known word', () => {
  assert.deepEqual(EXCLUDED.filter((t) => NAMES.includes(t) || VALUES.includes(t)), []);
});

test('no legacy state value is a known word', () => {
  const legacy = CONVENTIONS.vocabularies.state.values.flatMap((row) => row.legacy || []);
  assert.deepEqual(legacy.filter((t) => VALUES.includes(t)), []);
});

test('knownWords lists no name that canonicalNames already supplies', () => {
  const canonical = CONVENTIONS.canonicalNames.flatMap((row) => [row.name].concat(row.legacy));
  assert.deepEqual(NAMES.filter((n) => canonical.includes(n)), []);
});

test('knownWords holds unique, well-formed tokens', () => {
  assert.equal(new Set(NAMES).size, NAMES.length);
  assert.equal(new Set(VALUES).size, VALUES.length);
  NAMES.forEach((n) => assert.match(n, /^[a-z][A-Za-z0-9]*$/, n));
  VALUES.forEach((v) => assert.match(v, /^[A-Z0-9]+(_[A-Z0-9]+)*$/, v));
});

test('correctly spelled neighbours do not trip L01', () => {
  const findings = lintRecords([record('Neighbours', {
    '🔘 level#1:0': ['BOOLEAN', false],
    '🔘 line#1:1': ['BOOLEAN', false],
    '👁️ showLink#1:2': ['BOOLEAN', false],
    '💬 label#1:3': ['TEXT', ''],
    '🔖 marker': variant(['DOT', 'DOTS', 'LINE', 'LINK_LIKE', '← LEFT', '→ RIGHT']),
  })]);
  assert.deepEqual(find(findings, 'L01', 'Neighbours'), []);
});

test('a typo after a direction arrow keeps the arrow in the suggestion', () => {
  const findings = lintRecords([record('Pager', { '➡️ direction': variant(['← LEFTT', '→ RIGHT']) })]);
  assert.deepEqual(find(findings, 'L01', 'Pager').map((f) => f.suggestion), ['← LEFT']);
});
