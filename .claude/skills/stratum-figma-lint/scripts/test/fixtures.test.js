const test = require('node:test');
const assert = require('node:assert/strict');
const { loadFixture, fixtureRecords, lintRecords, find } = require('./helpers.js');

const RECORD_KEYS = ['id', 'name', 'type', 'page', 'description', 'descriptionMarkdown', 'properties', 'variantCount', 'unboundPaints'];
const FIXTURES = ['button', 'alert', 'text_input', 'rule_table'];

test('fixtures are shaped like readComponent output and say whether they are synthetic', () => {
  FIXTURES.forEach((name) => {
    const fixture = loadFixture(name);
    assert.equal(typeof fixture.synthetic, 'boolean', name + ' needs a synthetic flag');
    fixture.components.forEach((rec) => {
      RECORD_KEYS.forEach((key) => assert.ok(key in rec, name + '/' + rec.name + ' lacks ' + key));
      Object.values(rec.properties).forEach((def) => {
        assert.ok(['BOOLEAN', 'TEXT', 'INSTANCE_SWAP', 'VARIANT', 'SLOT'].includes(def.type));
        assert.equal(Array.isArray(def.variantOptions), def.type === 'VARIANT');
      });
    });
  });
});

test('known findings from the 2026-09-30 audit', () => {
  const findings = lintRecords(fixtureRecords(...FIXTURES));
  assert.equal(find(findings, 'L01', 'SocialButton', { value: 'HOVERD' }).length, 1);
  assert.equal(find(findings, 'L01', 'Alert', { value: 'STRING' }).length, 1);
  assert.equal(find(findings, 'L02', 'TextInput').length, 1);
  assert.equal(find(findings, 'L03', 'ChartBar', { property: '%' }).length, 1);
});

test('Button, the reference component, has no blocking finding', () => {
  const findings = lintRecords(fixtureRecords('button'));
  assert.deepEqual(findings.filter((f) => f.severity === 'blocking'), []);
});

// Scope 3 (the stratum-read-figma gate) lints one component set: knownWords stands in for the batch.
function lintAlone(fixture, name) {
  return lintRecords(fixtureRecords(fixture).filter((rec) => rec.name === name));
}

test('single-node scope catches cross-batch typos through knownWords', () => {
  assert.equal(find(lintAlone('rule_table', 'LeftToggle'), 'L01', 'LeftToggle', { value: 'MXIED', suggestion: 'MIXED' }).length, 1);
  assert.equal(find(lintAlone('rule_table', 'MenuItem'), 'L01', 'MenuItem', { property: '💬 descrtiption', suggestion: 'description' }).length, 1);
  assert.equal(find(lintAlone('alert', 'Alert'), 'L01', 'Alert', { value: 'STRING', suggestion: 'STRONG' }).length, 1);
  assert.equal(find(lintAlone('text_input', 'TextInput'), 'L02', 'TextInput').length, 1);
});
