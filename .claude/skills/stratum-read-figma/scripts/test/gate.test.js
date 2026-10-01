// Workflow step 2: the lint gate. The reference file has no blocking finding since the 2026-10-01 cleanup, so a
// synthetic fixture (Alert before the cleanup, `💡 accent` = STRING) proves the stop.
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');
const { loadFixture, lintRecord } = require('./helpers.js');
const { parseLintSummary, gateStops } = require('../map_lib.js');

const LINT = path.join(__dirname, '..', '..', '..', 'stratum-figma-lint', 'scripts');
const { CONVENTIONS } = require(path.join(LINT, 'conventions.js'));
const { describeComponent } = require(path.join(LINT, 'extract_lib.js'));
const { lintComponents, packLintResult } = require(path.join(LINT, 'lint_lib.js'));

// The summary line stratum-figma-lint ends its scope-3 report with.
function gateSummary(fixture) {
  const component = loadFixture(fixture).component;
  const findings = lintComponents([describeComponent(lintRecord(component))], CONVENTIONS);
  return { summary: packLintResult(findings, [component.page], CONVENTIONS, [], 18000).summary, findings };
}

test('one blocking finding stops the gate', () => {
  const { summary, findings } = gateSummary('gate_stop');
  assert.equal(parseLintSummary(summary).blocking, 1);
  assert.deepEqual(findings.filter((f) => f.severity === 'blocking').map((f) => [f.rule, f.value, f.suggestion]), [['L01', 'STRING', 'STRONG']]);
  assert.equal(gateStops(summary), true);
});

test('Button, Alert, and TextInput after the cleanup pass the gate', () => {
  ['button', 'alert', 'text_input'].forEach((name) => assert.equal(gateStops(gateSummary(name).summary), false, name));
});

test('the summary parser reads the line inside a report and refuses text without one', () => {
  assert.deepEqual(parseLintSummary('| table |\n\nlint: 2 blocking, 5 convention, 1 advisory, 0 info\n'),
    { blocking: 2, convention: 5, advisory: 1, info: 0 });
  assert.equal(parseLintSummary('no findings'), null);
  assert.throws(() => gateStops('no findings'), /no lint summary line/);
});
