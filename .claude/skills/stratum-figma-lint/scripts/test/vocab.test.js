const test = require('node:test');
const assert = require('node:assert/strict');
const { fixtureRecords, record, variant } = require('./helpers.js');
const { describeComponent } = require('../extract_lib.js');
const { collectVocabulary, packVocabulary } = require('../vocab_lib.js');

test('collectVocabulary counts components per normalized name and per value', () => {
  const vocab = collectVocabulary(fixtureRecords('button', 'alert').map(describeComponent));
  assert.equal(vocab.names.size, 2);
  assert.equal(vocab.names.showLeftIcon, 1);
  assert.equal(vocab.values.MEDIUM, 2);
  assert.equal(vocab.values.STRING, 1);
});

test('packVocabulary returns everything when it fits', () => {
  const packed = packVocabulary({ names: { label: 3 }, values: { HOVERED: 2 } }, ['❖ Buttons'], 18000);
  assert.deepEqual(packed, { mode: 'vocab', pages: ['❖ Buttons'], names: { label: 3 }, values: { HOVERED: 2 } });
});

test('packVocabulary drops count-1 tokens first, then raises the minimum count', () => {
  const records = Array.from({ length: 300 }, (_, i) => record('C' + i, { ['🔖 property' + i]: variant(['VALUE_' + i, 'SHARED_' + (i % 3)]) }));
  const vocab = collectVocabulary(records.map(describeComponent));
  const singles = packVocabulary(vocab, ['p'], 1000);
  assert.deepEqual([singles.droppedSingles, singles.truncated, singles.values], [true, undefined, { SHARED_0: 100, SHARED_1: 100, SHARED_2: 100 }]);
  assert.equal(singles.droppedTokens, 600);
  const tight = packVocabulary(vocab, ['p'], 60);
  assert.deepEqual([tight.truncated, tight.values, tight.names], [true, {}, {}]);
});
