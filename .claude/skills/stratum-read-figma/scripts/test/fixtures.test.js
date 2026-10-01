// Fixtures hold entry_read.js output and say whether they are synthetic. button, alert, and text_input are captures
// from the real file; gate_stop is synthetic.
const test = require('node:test');
const assert = require('node:assert/strict');
const { READ_RESULT_LIMIT } = require('../entry_read.js');
const { loadFixture } = require('./helpers.js');

const REAL = ['button', 'alert', 'text_input'];
const NAMES = REAL.concat(['gate_stop']);
const COMPONENT_KEYS = ['id', 'key', 'name', 'type', 'page', 'section', 'description', 'documentationLinks', 'properties',
  'variants', 'variantDocs', 'nested', 'slots', 'tokens'];
// Nested-instance fields entry_read.js records since 2026-10-01 (brief round 2, step 1).
const NESTED_KEYS = ['layer', 'name', 'key', 'page', 'helper', 'visibleProperty', 'exposed', 'exposedProperties', 'variants'];

test('every fixture is entry_read.js output with a synthetic flag and fits the result limit', () => {
  NAMES.forEach((name) => {
    const fixture = loadFixture(name);
    assert.equal(typeof fixture.synthetic, 'boolean', name + ' needs a synthetic flag');
    COMPONENT_KEYS.forEach((key) => assert.ok(key in fixture.component, name + ' lacks ' + key));
    const { synthetic, source, ...result } = fixture;
    assert.ok(Buffer.byteLength(JSON.stringify(result)) <= READ_RESULT_LIMIT, name + ' is over the result limit');
    const c = fixture.component;
    assert.equal(c.variants.combinations.length, c.variants.count, name);
    assert.equal(c.tokens.rows.length, c.variants.count, name);
  });
});

test('button, alert, and text_input are real captures; gate_stop is synthetic', () => {
  REAL.forEach((name) => assert.equal(loadFixture(name).synthetic, false, name));
  assert.equal(loadFixture('gate_stop').synthetic, true, 'gate_stop');
});

test('the real captures carry the nested page, helper, and wrapper-toggle fields', () => {
  REAL.forEach((name) => loadFixture(name).component.nested.forEach((n) => assert.deepEqual(Object.keys(n), NESTED_KEYS, name + ' ' + n.layer)));
  assert.deepEqual(loadFixture('button').component.nested.map((n) => [n.layer, n.page, n.helper, n.visibleProperty]), [
    ['FocusBorder', '☀ Utilities', true, null], ['Badge', '❖ Badges & Tags', false, '👁️ showBadge#55483:19'],
    ['SpinnerIndeterminate', '❖ Loading', false, null]]);
  assert.deepEqual(REAL.map((name) => loadFixture(name).component.section.label), ['Control', 'Feedback', 'Form']);
});

test('property names use plain spaces only, as after the 2026-10-01 cleanup', () => {
  NAMES.forEach((name) => loadFixture(name).component.properties.forEach((p) => {
    assert.ok(!/[\u00a0\u2000-\u200a\u202f\u205f\u3000]/.test(p.rawName), name + ': ' + JSON.stringify(p.rawName));
  }));
});

test('the real captures carry the cleaned property names', () => {
  const names = (n) => loadFixture(n).component.properties.map((p) => p.name);
  assert.deepEqual(names('button'), ['showLeftIcon', 'showBadge', 'showRightIcon', 'label', 'leftIcon', 'rightIcon', 'style', 'size', 'state']);
  assert.ok(names('alert').includes('infoIcon'));
  assert.deepEqual(loadFixture('alert').component.properties.find((p) => p.name === 'accent').variantOptions, ['LIGHT', 'MEDIUM', 'STRONG']);
  assert.ok(names('text_input').includes('successText') && names('text_input').includes('helperText'));
  assert.deepEqual(loadFixture('text_input').component.properties.find((p) => p.name === 'state').variantOptions,
    ['NORMAL', 'DISABLED', 'HOVERED', 'FOCUSED', '🔴 NEGATIVE', '🟡 WARNING', '🟢 POSITIVE']);
});
