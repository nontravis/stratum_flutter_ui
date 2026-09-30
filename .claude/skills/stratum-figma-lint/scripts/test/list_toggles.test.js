// L20: numbered list toggles (one BOOLEAN per list item) are named `👁️ show<Item><N>`.
const test = require('node:test');
const assert = require('node:assert/strict');
const { CONVENTIONS, lintRecords, record, find } = require('./helpers.js');

const SILENCED = ['L01', 'L03', 'L05', 'L06'];

function toggles(labels) {
  const props = {};
  labels.forEach((label, i) => { props[label + '#9:' + i] = ['BOOLEAN', true]; });
  return props;
}

function range(from, to, make) {
  return Array.from({ length: to - from + 1 }, (_, i) => make(from + i));
}

test('one L20 per component for a numbered series, silencing L01, L03, L05, L06 on its properties', () => {
  const labels = range(1, 8, (n) => n + '. Toggle');
  const findings = lintRecords([record('ToggleGroup', toggles(labels))]);
  const l20 = find(findings, 'L20', 'ToggleGroup');
  assert.equal(l20.length, 1);
  assert.equal(l20[0].property, labels.join(', '));
  assert.equal(l20[0].suggestion, '👁️ showToggle1..8');
  assert.equal(l20[0].severity, 'convention');
  assert.deepEqual(findings.filter((f) => SILENCED.includes(f.rule)), []);
});

test('legacy series from the real file: checkbox, menu item, badge, file, accordion', () => {
  const findings = lintRecords([
    record('CheckboxGroup', toggles(range(1, 8, (n) => n + '. Checkbox'))),
    record('Menu', toggles(range(1, 16, (n) => 'Menu item ' + n))),
    record('BadgeGroup', toggles(['🏷️ Badge 1', '🏷️ Badge 2'])),
    record('FileList', toggles(['File 1', 'File 2', 'File 3'])),
    record('AccordionGroup', toggles(['Accordion 1 (first)', 'Accordion 2', 'Accordion 3 (last)'])),
  ]);
  const suggestions = findings.filter((f) => f.rule === 'L20').map((f) => [f.component, f.suggestion]);
  assert.deepEqual(suggestions, [
    ['CheckboxGroup', '👁️ showCheckbox1..8'], ['Menu', '👁️ showMenuItem1..16'], ['BadgeGroup', '👁️ showBadge1..2'],
    ['FileList', '👁️ showFile1..3'], ['AccordionGroup', '👁️ showAccordion1..3'],
  ]);
  assert.deepEqual(findings.filter((f) => SILENCED.includes(f.rule)), [], 'no 🔘 8Checkbox or 🔘 menuItem1 noise');
});

test('show<Item><N> with a sibling of the same stem is a series; wrong emoji draws L20, not L05', () => {
  const findings = lintRecords([
    record('TagList', toggles(['🔘 showTag1', '🔘 showTag2'])),
    record('Canonical', toggles(['👁️ showTag1', '👁️ showTag2', '👁️ showTag3'])),
  ]);
  assert.deepEqual(find(findings, 'L20', 'TagList').map((f) => [f.property, f.suggestion]),
    [['🔘 showTag1, 🔘 showTag2', '👁️ showTag1..2']]);
  assert.deepEqual(find(findings, 'L20', 'Canonical'), [], 'the canonical form draws nothing');
  assert.deepEqual(findings.filter((f) => SILENCED.includes(f.rule)), []);
});

test('a lone show<Item><N> without a sibling is an ordinary toggle', () => {
  const findings = lintRecords([record('Card', toggles(['🔘 showBody2']))]);
  assert.deepEqual(find(findings, 'L20', 'Card'), []);
  assert.equal(find(findings, 'L05', 'Card').length, 1);
});

test('only BOOLEAN properties form a list-toggle series', () => {
  const findings = lintRecords([record('Typography', { '💬 Body 2#1:0': ['TEXT', ''], '💬 Body 3#1:1': ['TEXT', ''] })]);
  assert.deepEqual(find(findings, 'L20', 'Typography'), []);
});

test('every legacy form example in conventions is detected', () => {
  const lt = CONVENTIONS.listToggles;
  assert.equal(lt.emoji + ' ' + lt.prefix + '<Item><N>', lt.canonical);
  lt.legacy.forEach((row) => {
    const findings = lintRecords([record('Series', toggles(row.examples))]);
    assert.equal(find(findings, 'L20', 'Series').length, 1, row.form);
  });
});

test('list-toggle names are never typo references for other names', () => {
  const findings = lintRecords([
    record('GroupA', toggles(['1. Checkbox', '2. Checkbox'])),
    record('GroupB', toggles(['1. Checkbox', '2. Checkbox'])),
    record('ListItem', toggles(['🔘 checkbox'])),
  ]);
  assert.deepEqual(find(findings, 'L01', 'ListItem'), []);
});
