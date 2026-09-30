// False L01 findings from the first real-file run (10 Control pages): legacy values, compounds of known words,
// numeric-suffix frames, and knownWords spellings.
const test = require('node:test');
const assert = require('node:assert/strict');
const { CONVENTIONS, lintRecords, record, variant, find } = require('./helpers.js');
const { lintComponents } = require('../lint_lib.js');
const { describeComponent } = require('../extract_lib.js');

const words = (groups) => groups.join('|').split('|');

test('a legacy value is L10 with its suggestion, never L01, even beside a more frequent canonical value', () => {
  const findings = lintRecords(['ModalCloseButton', 'InfoButton', 'IconButton'].map((name, i) =>
    record(name, { '🚦 state': variant(i === 0 ? ['NORMAL', 'HOVER'] : ['NORMAL', 'HOVERED']) })));
  assert.deepEqual(find(findings, 'L01', 'ModalCloseButton'), []);
  assert.deepEqual(find(findings, 'L10', 'ModalCloseButton').map((f) => [f.value, f.suggestion]), [['HOVER', 'HOVERED']]);
});

test('misspellings are not legacy values and stay L01', () => {
  const legacy = Object.values(CONVENTIONS.vocabularies).flatMap((v) => v.values.flatMap((row) => row.legacy || []));
  assert.deepEqual(['HOVERD', 'HOVERDED', 'DRAGED'].filter((t) => legacy.includes(t)), []);
  const findings = lintRecords([record('Chip', { '🚦 state': variant(['NORMAL', 'HOVERD', 'HOVERDED', 'DRAGED']) })]);
  assert.deepEqual(find(findings, 'L01', 'Chip').map((f) => [f.value, f.suggestion]),
    [['HOVERD', 'HOVERED'], ['HOVERDED', 'HOVERED'], ['DRAGED', 'DRAGGED']]);
});

test('a numeric suffix on a known word is an animation frame, not a typo', () => {
  const findings = lintRecords([record('EmojiButton', { '🚦 state': variant(['NORMAL', 'LOADING_1', 'LOADING_2']) })]);
  assert.deepEqual(find(findings, 'L01', 'EmojiButton'), []);
});

test('a value or name whose parts are all known words is not a typo', () => {
  const findings = lintRecords([
    record('HorizontalSlider', { '📍 position': variant(['LEFT_RIGHT', 'CENTER']) }),
    record('Toolbar', { '📍 align': variant(['BUTTON_RIGHT', 'CENTER']) }),
    record('Label', { '👁️ showBold#1:0': ['BOOLEAN', false] }),
  ]);
  assert.deepEqual(findings.filter((f) => f.rule === 'L01'), []);
  const withoutEntry = Object.assign({}, CONVENTIONS, { knownWords: Object.assign({}, CONVENTIONS.knownWords, {
    values: CONVENTIONS.knownWords.values.map((g) => g.split('|').filter((w) => w !== 'LEFT_RIGHT').join('|')),
  }) });
  const alone = lintComponents([record('HorizontalSlider', { '📍 position': variant(['LEFT_RIGHT', 'CENTER']) })]
    .map(describeComponent), withoutEntry);
  assert.deepEqual(alone.filter((f) => f.rule === 'L01'), [], 'LEFT + RIGHT without the knownWords entry');
});

test('a compound with one misspelled part is still a typo', () => {
  const findings = lintRecords([record('Slider', { '📍 position': variant(['TEXT_LEFT', 'TEXT_RIGTH']) })]);
  assert.deepEqual(find(findings, 'L01', 'Slider').map((f) => [f.value, f.suggestion]), [['TEXT_RIGTH', 'TEXT_RIGHT']]);
});

test('knownWords spells macOS and holds LEFT_RIGHT', () => {
  assert.ok(words(CONVENTIONS.knownWords.names).includes('macOS'));
  assert.ok(!words(CONVENTIONS.knownWords.names).includes('macOs'));
  assert.ok(words(CONVENTIONS.knownWords.values).includes('LEFT_RIGHT'));
  const findings = lintRecords([record('NativeMenuItem', { '🖥️ macOS#1:0': ['BOOLEAN', false] })]);
  assert.deepEqual(find(findings, 'L01', 'NativeMenuItem'), []);
});
