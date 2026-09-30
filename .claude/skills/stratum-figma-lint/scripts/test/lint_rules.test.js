const test = require('node:test');
const assert = require('node:assert/strict');
const { CONVENTIONS, fixtureRecords, lintRecords, record, variant, find } = require('./helpers.js');
const { countBySeverity, summaryLine } = require('../lint_lib.js');

// The audit rule table plus the three component fixtures, linted as one batch.
const all = lintRecords(fixtureRecords('button', 'alert', 'text_input', 'rule_table'));

function expectOne(rule, component, match) {
  const hits = find(all, rule, component, match);
  assert.equal(hits.length, 1, rule + ' ' + component + ' ' + JSON.stringify(match) + ' -> ' + JSON.stringify(find(all, rule, component)));
  return hits[0];
}

test('L01 typo: values near a vocabulary entry', () => {
  expectOne('L01', 'SocialButton', { value: 'HOVERD', suggestion: 'HOVERED' });
  expectOne('L01', 'RatingEmoji', { value: 'HOVERDED', suggestion: 'HOVERED' });
  expectOne('L01', 'SegmentedBar', { value: 'NORMALL', suggestion: 'NORMAL' });
  expectOne('L01', 'NumberInput', { value: '🟡 WARNGIN', suggestion: '🟡 WARNING' });
  expectOne('L01', 'BreadcrumbSectionLink', { value: 'MEDIUm', suggestion: 'MEDIUM' });
});

test('L01 typo: values and names near a more frequent neighbour', () => {
  expectOne('L01', 'LeftToggle', { value: 'MXIED', suggestion: 'MIXED' });
  expectOne('L01', 'Alert', { value: 'STRING', suggestion: 'STRONG' });
  expectOne('L01', 'SegmentedBar', { property: '👁️ showLebel', suggestion: 'showLabel' });
  expectOne('L01', 'MenuItem', { property: '💬 descrtiption', suggestion: 'description' });
  const dymanic = expectOne('L01', 'NumberCell', { property: '📈 dymanic', suggestion: 'dynamic' });
  assert.match(dymanic.message, /Dart reserved word, L04/);
  assert.deepEqual(find(all, 'L01', 'MenuItem', { value: 'SWITCH' }), [], 'WindowSize WATCH is a reference only for the platform role');
});

test('L01 typo: a word outside knownWords near a more frequent word in the batch', () => {
  const findings = lintRecords([
    record('A', { '🔖 finish': variant(['COBALT', 'MATTE']) }),
    record('B', { '🔖 finish': variant(['COBALT', 'MATTE']) }),
    record('C', { '🔖 finish': variant(['COBALD', 'MATTE']) }),
  ]);
  assert.deepEqual(find(findings, 'L01', 'C').map((f) => [f.value, f.suggestion]), [['COBALD', 'COBALT']]);
});

test('L01 typo: plural, digit-only, short, and co-occurring neighbours are not typos', () => {
  const findings = lintRecords([
    record('A', { '🔖 kind': variant(['LOWER', 'LOWEST']), '🔖 mode': variant(['ITEM_1', 'ITEM_2']), '🔖 part': variant(['CART']) }),
    record('B', { '🔖 kind': variant(['LOWER', 'LOWEST']), '🔖 mode': variant(['ITEM_1', 'ITEM_10']), '🔖 part': variant(['CARD']) }),
    record('C', { '🔖 kind': variant(['LOWER', 'UPPER']), '🔖 mode': variant(['ITEM_1', 'ITEMS']), '🔖 part': variant(['CARD']) }),
  ]);
  assert.deepEqual(findings.filter((f) => f.rule === 'L01'), []);
});

test('L02 collision: two properties normalize to one name', () => {
  expectOne('L02', 'TextInput', { suggestion: 'rename the TEXT to `successText`' });
  expectOne('L02', 'UploadedFile', { property: '💬 size (TEXT) + 📐 size (VARIANT)' });
});

test('L03 empty name: symbols only', () => {
  expectOne('L03', 'ChartBar', { property: '%' });
  assert.equal(find(all, 'L03', 'ShortcutGroup').length, 4);
  assert.deepEqual(find(all, 'L02', 'ShortcutGroup'), [], 'empty names never collide');
  assert.deepEqual(all.filter((f) => ['L05', 'L06'].includes(f.rule) && f.property === '%'), [], 'L03 owns the empty name');
});

test('L04 reserved: Dart reserved word or built-in identifier', () => {
  expectOne('L04', 'TextCell', { property: '📈 dynamic' });
});

test('L05 emoji template: wrong or missing emoji by role', () => {
  expectOne('L05', 'ChartBar', { property: '🎨 color', suggestion: '🌈 color' });
  expectOne('L05', 'TextInput', { property: '💨 showClearButton', suggestion: '👁️ showClearButton' });
  expectOne('L05', 'Spinner', { property: '🌈 color', suggestion: '🔘 color' });
  expectOne('L05', 'NativeMenuItem', { property: '☑️ Selected', suggestion: '✅ selected' });
  expectOne('L05', 'Note', { property: '✏️ Text:', suggestion: '💬 text' });
  const missing = lintRecords([record('Plain', { size: variant(['SMALL', 'LARGE']) })]);
  assert.equal(find(missing, 'L05', 'Plain', { suggestion: '📐 size' }).length, 1);
  assert.deepEqual(find(all, 'L05', 'Button'), [], 'Button follows the template');
});

test('L05 emoji template: an INSTANCE_SWAP is a slot by its swapped component or by a region name', () => {
  const swap = (defaultName) => ['INSTANCE_SWAP', '1:1', null, defaultName];
  const findings = lintRecords([record('PageLayout', {
    '❖ top': swap('Slot'),
    '✏️ header': swap('❖ Header'),
    '✏️ icon': swap('Star'),
    '✏️ body': swap(),
    '✏️ leftIcon': swap(),
  })]);
  assert.deepEqual(find(findings, 'L05', 'PageLayout').map((f) => [f.property, f.suggestion]), [
    ['✏️ header', '❖ header'], ['✏️ body', '❖ body'],
  ]);
});

test('L05 emoji template: a region-name swap is a slot even when its default is a real component', () => {
  const swap = (defaultName) => ['INSTANCE_SWAP', '1:1', null, defaultName];
  const findings = lintRecords([
    record('CardLayout', { '◇ top': swap('TopNavigation'), '❖ content': swap('Card') }),
    record('Sidebar', { '◇ top': swap('SideNavigationMenu'), '◇ body': swap('SideNavigationMenu'), '✏️ bottom': swap('SideNavigationMenu') }),
  ]);
  assert.deepEqual(find(findings, 'L05', 'CardLayout').map((f) => [f.property, f.suggestion]), [['◇ top', '❖ top']]);
  assert.deepEqual(find(findings, 'L05', 'Sidebar').map((f) => [f.property, f.suggestion]), [
    ['◇ top', '❖ top'], ['◇ body', '❖ body'], ['✏️ bottom', '❖ bottom'],
  ]);
});

test('L05 emoji template: legacy slot emoji ◇, ↻, and ↺ get the ❖ suggestion', () => {
  const swap = ['INSTANCE_SWAP', '1:1', null, 'Slot'];
  const findings = lintRecords([record('MenuItem', { '◇ left': swap, '↻ right': swap, '↺ slot': swap })]);
  assert.deepEqual(find(findings, 'L05', 'MenuItem').map((f) => [f.property, f.suggestion]), [
    ['◇ left', '❖ left'], ['↻ right', '❖ right'], ['↺ slot', '❖ slot'],
  ]);
});

test('L06 name format: space, colon, camelCase', () => {
  expectOne('L06', 'RatingEmoji', { property: '🚦state', message: 'no space after emoji' });
  expectOne('L06', 'Accordion', { message: 'leading space' });
  expectOne('L06', 'Note', { property: '✏️ Text:', message: 'trailing colon, not camelCase' });
  expectOne('L06', 'NativeMenuItem', { property: '✏️ Label text:' });
  expectOne('L06', 'Alert', { property: '✏️ InfoIcon', suggestion: '✏️ infoIcon' });
});

test('L07 value case: UPPER_SNAKE and emoji only for feedback and direction', () => {
  expectOne('L07', 'Note', { value: '↑', suggestion: '↑ UP' });
  const findings = lintRecords([record('Icon', { '🏋️ Weight': variant(['Fill', 'Light', 'Regular', '← LEFT', '⭐ STAR']) })]);
  assert.deepEqual(find(findings, 'L07', 'Icon').map((f) => [f.value, f.suggestion]), [
    ['Fill', 'FILL'], ['Light', 'LIGHT'], ['Regular', 'REGULAR'], ['⭐ STAR', 'STAR'],
  ]);
});

test('L08 boolean variant: False/True only', () => {
  expectOne('L08', 'Checkbox', { value: 'FALSE', suggestion: 'False' });
  expectOne('L08', 'Checkbox', { value: 'TRUE', suggestion: 'True' });
  expectOne('L08', 'NativeMenuItem', { value: 'Off', suggestion: 'False' });
  assert.deepEqual(find(all, 'L07', 'NativeMenuItem'), [], 'L08 owns Off/On');
});

test('L09 feedback vocabulary: aliases and missing dots', () => {
  expectOne('L09', 'Checkbox', { value: 'ERROR', suggestion: '🔴 NEGATIVE' });
  expectOne('L09', 'Spinner', { value: '🟢 SUCCESS', suggestion: '🟢 POSITIVE' });
  assert.deepEqual(find(all, 'L10', 'Checkbox'), [], 'L09 owns ERROR over L10');
  const bare = lintRecords([record('Field', { '🚦 state': variant(['NORMAL', 'NEGATIVE', 'WARNING']) })]);
  assert.deepEqual(bare.filter((f) => f.value === 'NEGATIVE' || f.value === 'WARNING').map((f) => f.rule), ['L09', 'L09']);
});

test('L10 vocabulary: state, size, color; numeric sizes are info', () => {
  expectOne('L10', 'Spinner', { value: 'EXTRA_TINY' });
  expectOne('L10', 'Badge', { value: 'BLACK' });
  expectOne('L10', 'Badge', { value: 'GHOST' });
  assert.deepEqual(find(all, 'L10', 'Badge', { value: 'PURPLE' }), [], 'PURPLE is a ColorEnum value');
  assert.deepEqual(find(all, 'L10', 'SocialButton'), [], 'L01 owns HOVERD');
  const legacy = lintRecords([record('Chip', { '🚦 state': variant(['NORMAL', 'DRAG']) })]);
  assert.deepEqual(find(legacy, 'L10', 'Chip').map((f) => [f.value, f.suggestion]), [['DRAG', 'DRAGGED']], 'legacy table suggests');
  const mixed = lintRecords([record('Tag', { '🚦 state': variant(['NORMAL', 'Hover', 'press', 'Focus']) })]);
  assert.deepEqual(mixed.filter((f) => f.component === 'Tag').map((f) => [f.rule, f.value, f.suggestion]), [
    ['L10', 'Hover', 'HOVERED'], ['L10', 'press', 'PRESSED'], ['L10', 'Focus', 'FOCUSED'],
  ], 'legacy lookup ignores case');
  const sizes = lintRecords([record('Avatar', { '📐 size': variant(['16', '24', 'Free', 'extraSmall']) })]);
  assert.deepEqual(find(sizes, 'L10', 'Avatar').map((f) => [f.value, f.severity, f.suggestion]), [
    ['extraSmall', 'convention', 'EXTRA_SMALL'], ['16|24|Free', 'info', ''],
  ]);
});

test('every legacy value in a state or feedback row is reported with its canonical value', () => {
  const rows = CONVENTIONS.vocabularies.state.values.concat(CONVENTIONS.vocabularies.feedback.values);
  const pairs = rows.flatMap((row) => (row.legacy || []).map((legacy) => [legacy, row.value]));
  const findings = lintRecords([record('Legacy', { '🚦 state': variant(['NORMAL'].concat(pairs.map((p) => p[0]))) })]);
  pairs.forEach(([legacy, canonical]) => {
    const hits = findings.filter((f) => f.value === legacy && ['L01', 'L09', 'L10'].includes(f.rule));
    assert.deepEqual(hits.map((f) => f.suggestion), [canonical], legacy);
  });
});

test('L11 visual variant named type', () => {
  expectOne('L11', 'CloseButton', { value: 'OUTLINE|GHOST', suggestion: '🕶️ style' });
});

test('L12 hard-coded fill or stroke', () => {
  expectOne('L12', 'Divider', { property: 'fills', value: '#E5E7EB' });
});

test('L13 ACTIVE with a context suggestion, never L01 or L10', () => {
  expectOne('L13', 'TextInput', { suggestion: 'FOCUSED' });
  expectOne('L13', 'ChartBar', { suggestion: 'SELECTED' });
  expectOne('L13', 'RatingEmoji', { suggestion: '✅ selected: False/True; keep NORMAL/HOVERED' });
  assert.deepEqual(all.filter((f) => ['ACTIVE', 'INACTIVE'].includes(f.value) && f.rule !== 'L13'), []);
  const other = lintRecords([record('Tabs', { '🚦 state': variant(['NORMAL', 'ACTIVE']) })]);
  assert.equal(find(other, 'L13', 'Tabs')[0].suggestion, CONVENTIONS.activeDefault);
});

test('L14 single-value variant', () => {
  expectOne('L14', 'FilterButton', { value: 'NORMAL' });
});

test('L15 mixed axis: state-like or slot value in the wrong property', () => {
  expectOne('L15', 'Toggle', { value: 'LOADING' });
  expectOne('L15', 'Spinner', { value: '🔴 ERROR' });
  assert.deepEqual(find(all, 'L15', 'Alert'), [], 'feedback values belong in color');
  const slot = lintRecords([record('Card', { '📍 position': variant(['TOP', 'CONTENT']) })]);
  assert.deepEqual(find(slot, 'L15', 'Card', { value: 'CONTENT' }).map((f) => f.suggestion), ['use a ❖ slot INSTANCE_SWAP']);
});

test('L16 legacy name for a canonical name', () => {
  expectOne('L16', 'Toggle', { property: '💬 helper', suggestion: 'helperText' });
  expectOne('L16', 'TextInput', { property: '👁️ showHelper', suggestion: 'showHelperText' });
  expectOne('L16', 'NativeMenuItem', { suggestion: 'label' });
  expectOne('L16', 'StepItem', { suggestion: 'stepNumber' });
  assert.deepEqual(find(all, 'L16', 'StepIndicator'), [], 'the more frequent name wins');
});

test('L17 loading inside state', () => {
  expectOne('L17', 'Button', { value: 'LOADING' });
  expectOne('L17', 'Button', { value: 'PROGRESS' });
});

test('L18 incomplete variant matrix', () => {
  expectOne('L18', 'MenuItem', { value: '96/135' });
  assert.deepEqual(find(all, 'L18', 'Button'), []);
});

test('L19 component set without description', () => {
  expectOne('L19', 'Popover', {});
  assert.deepEqual(find(all, 'L19', 'Alert'), []);
});

test('L20 numbered list toggles', () => {
  expectOne('L20', 'ToggleGroup', { suggestion: '👁️ showToggle1..3' });
});

test('every rule id in conventions has a severity the summary counts', () => {
  const rules = CONVENTIONS.rules.map((row) => row.id);
  assert.equal(rules.length, 20);
  CONVENTIONS.rules.forEach((row) => assert.ok(CONVENTIONS.severityOrder.includes(row.severity), row.id));
  assert.deepEqual([...new Set(all.map((f) => f.rule))].sort(), rules);
});

test('summary line has the exact shape stratum-read-figma parses', () => {
  const line = summaryLine(countBySeverity(all, CONVENTIONS));
  assert.match(line, /^lint: \d+ blocking, \d+ convention, \d+ advisory, \d+ info$/);
});
