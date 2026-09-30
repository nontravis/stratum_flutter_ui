// False and missed findings from the 2026-09-30 cleanup dry run of every ❖ and ⬒ Layouts page.
const test = require('node:test');
const assert = require('node:assert/strict');
const { CONVENTIONS, lintRecords, record, variant, find } = require('./helpers.js');

const cells = (findings, rule, component, keys) => find(findings, rule, component).map((f) => keys.map((k) => f[k]));

test('L05: a BOOLEAN icon or logo toggle is renamed `👁️ show<Name>`; an INSTANCE_SWAP logo stays ✏️', () => {
  const findings = lintRecords([
    record('SideNavigationMenu', { '💼 logo#1:0': ['BOOLEAN', true] }),
    record('InlineAlert', { '🔍 Icon#1:0': ['BOOLEAN', true] }),
    record('Card', { '👁️ leftIcon#1:0': ['BOOLEAN', true], '🔘 iconFilled#1:1': ['BOOLEAN', false] }),
    record('Tab', { '👁️ showBrandLogo#1:0': ['BOOLEAN', true] }),
    record('TopNavigationMenu', { '💼 logo#1:0': ['INSTANCE_SWAP', '1:1', null, 'Logo'] }),
  ]);
  assert.deepEqual(findings.filter((f) => f.rule === 'L05').map((f) => [f.component, f.property, f.suggestion]), [
    ['SideNavigationMenu', '💼 logo', '👁️ showLogo'],
    ['InlineAlert', '🔍 Icon', '👁️ showIcon'],
    ['Card', '👁️ leftIcon', '👁️ showLeftIcon'],
    ['TopNavigationMenu', '💼 logo', '✏️ logo'],
  ]);
});

test('knownWords holds INPUT: SimplePagination `type: INPUT` is no typo of PUT', () => {
  assert.ok(CONVENTIONS.knownWords.values.join('|').split('|').includes('INPUT'));
  const findings = lintRecords([record('SimplePagination', { '🔖 type': variant(['DOTS', 'INPUT', 'NUMBERS']) })]);
  assert.deepEqual(find(findings, 'L01', 'SimplePagination'), []);
});

test('L01 breaks a distance tie toward a canonical name, then toward the name used more often in the batch', () => {
  const alone = lintRecords([record('BufferingBar', { '💬 lebel#1:0': ['TEXT', ''] })]);
  assert.deepEqual(cells(alone, 'L01', 'BufferingBar', ['suggestion']), [['label']], 'canonical label over knownWords level');
  const batch = lintRecords([
    record('A', { '👁️ showButton#1:0': ['BOOLEAN', true] }),
    record('B', { '👁️ showButton#1:0': ['BOOLEAN', true] }),
    record('C', { '👁️ showButtom#1:0': ['BOOLEAN', true] }),
  ]);
  assert.deepEqual(cells(batch, 'L01', 'C', ['suggestion']), [['showButton']], 'showButton (2 uses) over showBottom (0)');
});

test('L16 pairs a legacy name with its canonical name only for the same property type', () => {
  const findings = lintRecords([
    record('MultiLineCodeSnippet', { '💬 line#1:0': ['TEXT', '1'] }),
    record('Divider', { '🔘 line#1:0': ['BOOLEAN', true] }),
  ]);
  assert.deepEqual(find(findings, 'L16', 'MultiLineCodeSnippet'), [], 'TEXT line is line numbers, not the showLine toggle');
  assert.deepEqual(cells(findings, 'L16', 'Divider', ['suggestion']), [['showLine']]);
});

test('graphic-role variant values name pictures, so they skip L09 and L15', () => {
  const findings = lintRecords([
    record('Illustration', { '🏞️ image': variant(['SUCCESS', 'ERROR', 'LOADING', 'EMPTY']) }),
    record('Spinner', { '🔖 kind': variant(['SUCCESS', 'LOADING']) }),
  ]);
  assert.deepEqual(findings.filter((f) => f.component === 'Illustration' && ['L09', 'L15'].includes(f.rule)), []);
  assert.deepEqual(cells(findings, 'L09', 'Spinner', ['value']), [['SUCCESS']], 'other variants still get L09');
  assert.deepEqual(cells(findings, 'L15', 'Spinner', ['value']), [['SUCCESS'], ['LOADING']], 'other variants still get L15');
});

test('L07 never suggests a value that starts with a digit; counts keep their digits', () => {
  const findings = lintRecords([
    record('TextSkeleton', { '🔖 length': variant(['1/5', '1/2', 'FULL']) }),
    record('Tabs', { '🔢 tabs': variant(['2 tabs', '3 tabs']) }),
  ]);
  const skeleton = find(findings, 'L07', 'TextSkeleton');
  assert.deepEqual(skeleton.map((f) => [f.value, f.suggestion]), [['1/5', ''], ['1/2', '']]);
  skeleton.forEach((f) => assert.match(f.message, /digit.*word/, f.value));
  assert.deepEqual(cells(findings, 'L07', 'Tabs', ['value', 'suggestion']), [['2 tabs', '2_TABS'], ['3 tabs', '3_TABS']]);
});
