// The 2026-10-01 owner rulings (group 2), non-ASCII spaces, and the false positives of the post-rename lint.
const test = require('node:test');
const assert = require('node:assert/strict');
const { CONVENTIONS, lintRecords, record, variant, find } = require('./helpers.js');

const words = (groups) => groups.join('|').split('|');
const ruleRows = (findings, rule) => findings.filter((f) => f.rule === rule).map((f) => [f.component, f.value]);

test('L06 reports a non-ASCII space in a name or value and suggests the plain-space form', () => {
  const spaces = [' ', ' ', ' ', ' ', ' ', ' ', '　'];
  const texts = {};
  spaces.forEach((space, i) => { texts['💬' + space + 'text' + i + '#1:' + i] = ['TEXT', '']; });
  const findings = lintRecords([
    record('ChatStatus', { '🚦 status': variant(['NORMAL', 'DONE']) }),
    record('Modal', { '🎛️ showPrimaryButton#1:0': ['BOOLEAN', true] }),
    record('Alert', { '🌈 color': variant(['🔴 NEGATIVE', '🔵 INFO']) }),
    record('Spaces', texts),
  ]);
  const l06 = (component) => find(findings, 'L06', component).map((f) => [f.property, f.value, f.message, f.suggestion]);
  assert.deepEqual(l06('ChatStatus'), [['🚦 status', '', 'non-ASCII space', '🚦 status']]);
  assert.deepEqual(l06('Modal'), [['🎛️ showPrimaryButton', '', 'non-ASCII space', '👁️ showPrimaryButton']]);
  assert.deepEqual(findings.filter((f) => f.component === 'Alert').map((f) => [f.rule, f.value, f.message, f.suggestion]),
    [['L06', '🔴 NEGATIVE', 'non-ASCII space', '🔴 NEGATIVE']], 'the plain form is a feedback value: no L09 or L07 on it');
  assert.equal(find(findings, 'L06', 'Spaces').length, spaces.length);
});

test('name roles: colored is a known word; attachments, rating, avatars, frame are counts; darkMode is a theme', () => {
  const findings = lintRecords([
    record('SlideHandle', { '🔘 colored#1:0': ['BOOLEAN', false] }),
    record('MediaAttachment', { '🔢 attachments': variant(['1', '2', '3']) }),
    record('Rating', { '🔢 rating': variant(['1', '2', '3', '4', '5']) }),
    record('AvatarGroup', { '🔢 avatars': variant(['2', '3', '4']) }),
    record('SpinnerIndeterminate', { '🔢 frame': variant(['1', '2', '3']) }),
    record('SystemTooltip', { '🌗 darkMode': variant(['False', 'True']) }),
    record('LargeShortcut', { '🔘 darkMode': variant(['False', 'True']) }),
  ]);
  assert.deepEqual(findings.filter((f) => f.rule === 'L01' || f.rule === 'L05').map((f) => [f.rule, f.component, f.suggestion]),
    [['L05', 'LargeShortcut', '🌗 darkMode']]);
});

test('L17 is retired; L15 reports interaction values outside state and slot values without a same-name slot', () => {
  const l17 = CONVENTIONS.rules.find((row) => row.id === 'L17');
  assert.equal(l17.severity, '—');
  const slot = ['INSTANCE_SWAP', '1:1', null, 'Slot'];
  const findings = lintRecords([
    record('Button', { '🚦 state': variant(['NORMAL', 'LOADING', 'PROGRESS']) }),
    record('Toggle', { '✅ checked': variant(['False', 'True', 'LOADING']) }),
    record('ModalContent', { '🔖 type': variant(['NORMAL', '🔴 NEGATIVE', '🟢 POSITIVE', 'CONTENT']), '❖ content#1:0': slot }),
    record('StateActions', { '📍 position': variant(['TOP', 'SLOT']), '❖ slot#1:1': slot }),
    record('Card', { '📍 position': variant(['TOP', 'CONTENT']) }),
    record('CalendarItem', { '📐 size': variant(['SMALL', 'DISABLED', 'HOVER', 'PRESSED']) }),
  ]);
  assert.deepEqual(findings.filter((f) => f.rule === 'L17'), []);
  assert.deepEqual(ruleRows(findings, 'L15'),
    [['Card', 'CONTENT'], ['CalendarItem', 'DISABLED'], ['CalendarItem', 'HOVER'], ['CalendarItem', 'PRESSED']]);
});

test('vocabularies accept EMPTY, split-part states, and the design-only size and color values', () => {
  const findings = lintRecords([
    record('CardLayout', { '🚦 state': variant(['NORMAL', 'EMPTY']) }),
    record('SplitButton', { '🚦 state': variant(['NORMAL', 'HOVERED_LEFT', 'HOVERED_RIGHT', 'PRESSED_LEFT', 'PRESSED_RIGHT', 'HOVERED_TOP']) }),
    record('ModalLayout', { '📐 size': variant(['MEDIUM', 'FILL_WIDTH', 'SMALL_LEFT']) }),
    record('Spinner', { '📐 size': variant(['TINY', 'EXTRA_TINY']) }),
    record('Badge', { '🌈 color': variant(['BRAND', 'BLACK', 'GHOST']) }),
    record('StateIcon', { '🌈 color': variant(['BRAND', 'CUSTOM']) }),
  ]);
  assert.deepEqual(ruleRows(findings, 'L10'), [['SplitButton', 'HOVERED_TOP'], ['ModalLayout', 'SMALL_LEFT']],
    'the part suffix is for state values only');
});

test('a property named status is never checked against the state vocabulary', () => {
  const findings = lintRecords([
    record('ChatStatus', { '🚦 status': variant(['SENDING', 'SENT', 'FAILED', 'DISABLE']) }),
    record('UploadedFile', { '🚦 status': variant(['UPLOADING', 'DONE']) }),
  ]);
  const state = CONVENTIONS.vocabularies.state.values.map((row) => row.value);
  assert.deepEqual(findings.filter((f) => f.rule === 'L10' || f.rule === 'L15' || (f.rule === 'L01' && state.includes(f.suggestion))), []);
});

test('every value the 2026-10-01 renames introduced is a known word and raises no L01', () => {
  const renamed = ['SENDING', 'SENT', 'FAILED', 'UPLOADING', 'CUSTOM', 'ONE_FIFTH', 'TWO_FIFTHS', 'HALF', 'THREE_FIFTHS',
    'FOUR_FIFTHS', 'INCOMPLETE'];
  assert.deepEqual(renamed.filter((value) => !words(CONVENTIONS.knownWords.values).includes(value)), []);
  const findings = lintRecords(renamed.map((value, i) => record('Renamed' + i, { '🔖 kind': variant(['NORMAL', value]) })));
  assert.deepEqual(ruleRows(findings, 'L01'), []);
});

test('LOADING is allowed in a color variant (owner ruling 2b/2c: LOADING may sit in any variant)', () => {
  const findings = lintRecords([record('BarCell', { '🌈 color': variant(['GREEN', 'RED', 'YELLOW', 'LOADING']) })]);
  assert.deepEqual(ruleRows(findings, 'L10'), []);
  assert.deepEqual(ruleRows(findings, 'L15'), []);
});

test('show toggles may be False/True variants, and -- is an accepted placeholder value (owner 2026-10-01)', () => {
  const findings = lintRecords([
    record('PersonCell', { '👁️ showName': variant(['False', 'True']) }),
    record('PieChart', { '🔖 example': variant(['--', '1']) }),
    record('BarCell', { '🌈 color': variant(['GREEN', '--']) }),
  ]);
  assert.deepEqual(findings.filter((f) => ['L05', 'L07', 'L10'].includes(f.rule)).map((f) => [f.rule, f.component, f.value]), []);
});
