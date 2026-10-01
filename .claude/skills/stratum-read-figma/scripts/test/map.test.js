// map_lib.js: the golden Button contract, the rules on Alert and TextInput, and every value that must become an ask.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { mapContract, buildContract, enumValueName, snakeName, parseTextStyle } = require('../map_lib.js');
const { BADGE_KEY, loadFixture, testContext, WORKED_EXAMPLE, withoutDescription, dartBlock } = require('./helpers.js');

const GOLDEN = fs.readFileSync(path.join(__dirname, 'expected', 'button.md'), 'utf8');
const SECTIONS = ['## Properties', '## Enums', '## States', '## Slots', '## Visual tokens', '## Nested', '## Open questions'];

const field = (model, name) => model.rows.find((r) => r.field === name);
const fields = (model) => model.rows.map((r) => r.field);

// Minimal entry_read component: props maps a raw name to [type, defaultValue, variantOptions?].
function component(name, props, extra) {
  const properties = Object.keys(props).map((rawName) => {
    const [type, defaultValue, variantOptions] = props[rawName];
    return Object.assign({ rawName, type, defaultValue }, variantOptions ? { variantOptions } : {});
  });
  const axes = properties.filter((p) => p.type === 'VARIANT');
  return Object.assign({
    id: '1:1', key: name + '-key', name, type: 'COMPONENT_SET', page: '❖ Test', section: { page: '─── Control', label: 'Control' },
    description: { text: 'Doc.', source: 'description', empty: false }, documentationLinks: [], properties,
    variants: { axes: axes.map((p) => p.rawName), count: 1, product: 1, combinations: [axes.map(() => 0)] },
    variantDocs: [], nested: [], slots: {}, tokens: { columns: ['background'], values: [], rows: [[-1]] },
  }, extra);
}

test('Button maps to the golden contract, whose constructor is the approved worked example', () => {
  const { markdown, asks } = mapContract(loadFixture('button').component, testContext());
  assert.deepEqual(asks, []);
  assert.equal(withoutDescription(markdown), withoutDescription(GOLDEN));
  assert.equal(dartBlock(GOLDEN), WORKED_EXAMPLE);
  assert.equal(dartBlock(markdown), WORKED_EXAMPLE);
});

test('the golden keeps the contract_template sections in order, with a dartdoc description', () => {
  const at = SECTIONS.map((s) => GOLDEN.indexOf('\n' + s + '\n'));
  assert.ok(at.every((i, k) => i > 0 && (k === 0 || i > at[k - 1])), JSON.stringify(at));
  assert.ok(!GOLDEN.includes('## Variant combinations'), 'Button has every combination');
  assert.match(GOLDEN, /^---\nname: Button\nfigma:\n {2}fileKey: "[^"]+"\n {2}nodeId: "55483:24307"\n {2}componentKey: "7687e83a1ce129a5ae07141a00699e2d0484a42c"\ndart:\n {2}class: StratumButton\n {2}base: StratumStatefulWidget\n {2}path: lib\/src\/components\/control\/button\/button\.dart\n---\n/);
  assert.match(GOLDEN, /# Button\n\n```dart\n\/\/\/ The primary interactive element/);
  assert.ok(!GOLDEN.includes('<!-- MODEL'), 'the model replaced the description block');
});

test('Alert: feedback color, its own accent enum, icon slots, nested buttons as typed slots only', () => {
  const m = buildContract(loadFixture('alert').component, testContext());
  assert.equal(m.base, 'StratumStatelessWidget');
  assert.deepEqual([field(m, 'feedbackState').base, field(m, 'color')], [true, undefined]);
  assert.deepEqual(m.enums.map((e) => [e.name, e.values.map((v) => v.dart)]), [['StratumAlertAccent', ['light', 'medium', 'strong']]]);
  assert.deepEqual([field(m, 'title').type, field(m, 'description').required, field(m, 'showIcon').type], ['String?', true, 'bool']);
  assert.deepEqual(m.slots.map((s) => [s.field, s.kind]), [['infoIcon', 'icon'], ['errorIcon', 'icon'], ['warningIcon', 'icon'], ['positiveIcon', 'icon']]);
  assert.deepEqual([field(m, 'primaryButton').type, field(m, 'secondaryButton').type, field(m, 'onPrimaryButtonPressed').type],
    ['StratumButton?', 'StratumButton?', 'VoidCallback?']);
  assert.ok(!fields(m).some((name) => /^(primaryButton|secondaryButton|link)[A-Z]/.test(name) && !/Pressed$/.test(name)), 'no flattened fields');
  assert.deepEqual([field(m, 'link').type, field(m, 'closeable').type], ['Widget?', 'Widget?']);
  assert.ok(m.asks.some((a) => a.includes('Nested `LinkText` has no contract')), 'an unresolved nested instance is asked, never read');
  assert.equal(m.path, 'lib/src/components/feedback/alert/alert.dart');
  assert.equal(m.contractPath, 'docs/specs/stratum_ui/components/feedback/alert/alert.md');
});

test('TextInput: state split, show*Text pairs, loading on the base field, filled is no field, onChanged only', () => {
  const m = buildContract(loadFixture('text_input').component, testContext());
  assert.equal(m.base, 'StratumStatefulWidget');
  assert.deepEqual(m.states.map((s) => s.value + '>' + s.field), ['NORMAL>state', 'DISABLED>disabled', 'HOVERED>state',
    'FOCUSED>state', '🔴 NEGATIVE>feedbackState', '🟡 WARNING>feedbackState', '🟢 POSITIVE>feedbackState']);
  ['label', 'helperText', 'errorText', 'warningText', 'successText'].forEach((name) => assert.equal(field(m, name).type, 'String?', name));
  assert.ok(!fields(m).some((name) => /^show(Label|HelperText|ErrorText|WarningText|SuccessText|ClearButton)$/.test(name)), 'paired toggles merge');
  assert.deepEqual([field(m, 'loading').base, field(m, 'showRequired').init, field(m, 'input').required], [true, 'false', true]);
  assert.ok(!fields(m).includes('filled') && m.skipped.some((s) => s.figma === '`✍️ filled`'));
  assert.deepEqual([field(m, 'onChanged').type, field(m, 'onPressed')], ['ValueChanged<String>?', undefined]);
  assert.equal(field(m, 'onClearButtonPressed').type, 'VoidCallback?');
  assert.ok(m.asks.some((a) => a.includes('`onChanged`')));
  assert.equal(m.path, 'lib/src/components/form/text_input/text_input.dart');
});

test('nested: a ☀ helper and an untoggled internal instance map to no field; a component is a typed slot only', () => {
  const nested = (layer, name, key, extra) => Object.assign({ layer, name, key, page: '❖ ' + name, helper: false,
    visibleProperty: null, exposed: false, exposedProperties: [], variants: 1 }, extra);
  const c = component('Card', { '👁️ showBadge#1:0': ['BOOLEAN', false], '👁️ showFocus#1:1': ['BOOLEAN', false] }, { nested: [
    nested('Badge', 'Badge', BADGE_KEY, { visibleProperty: '👁️ showBadge#1:0', exposed: true,
      exposedProperties: [{ name: '💬 label#2:0', type: 'TEXT' }, { name: '🕶️ style', type: 'VARIANT' }] }),
    nested('FocusBorder', 'FocusBorder', 'focus-key', { page: '☀ Utilities', helper: true, visibleProperty: '👁️ showFocus#1:1',
      exposed: true, exposedProperties: [{ name: '🚦 state', type: 'VARIANT' }] }),
    nested('Spinner', 'SpinnerIndeterminate', 'spin-key'),
  ] });
  const { model, markdown, asks } = mapContract(c, testContext());
  assert.deepEqual(fields(model).sort(), ['badge', 'customStyle', 'showFocus'], 'a helper never takes a toggle');
  assert.deepEqual([field(model, 'badge').type, field(model, 'badge').figma], ['StratumBadge?', ['nested `Badge`', '`👁️ showBadge`']]);
  assert.deepEqual(asks, []);
  assert.ok(markdown.includes('| `Badge` | `Badge` | `StratumBadge` | `badge` | `label`, `style` |'));
  assert.ok(markdown.includes('| `FocusBorder` | `FocusBorder` | — | none (helper) | `state` |'));
  assert.ok(markdown.includes('| `SpinnerIndeterminate` | `Spinner` | unresolved | none (internal) | — |'));
});

test('owner rulings of 2026-10-01: value-like and frame counts, selected, filled, expanded', () => {
  const m = buildContract(component('Rating', {
    '🔢 rating': ['VARIANT', '3', ['1', '2', '3', '4', '5']],
    '🔢 percent': ['VARIANT', '0.5', ['0', '0.5', '1']],
    '🔢 frame': ['VARIANT', '1', ['1', '2', '3']],
    '🔢 avatars': ['VARIANT', '2', ['1', '2']],
    '✅ selected': ['VARIANT', 'False', ['False', 'True']],
    '✍️ filled': ['VARIANT', 'False', ['False', 'True']],
    '↕️ expanded': ['VARIANT', 'False', ['False', 'True']],
  }), testContext());
  assert.deepEqual([field(m, 'rating').type, field(m, 'rating').init], ['int', '3']);
  assert.deepEqual([field(m, 'percent').type, field(m, 'percent').init], ['double', '0.5']);
  assert.equal(field(m, 'avatars').type, 'List<Widget>');
  assert.deepEqual(m.skipped.map((s) => s.figma), ['`🔢 frame`', '`✍️ filled`', '`↕️ expanded`']);
  assert.deepEqual(m.asks, []);
});

test('selected is the component\'s own bool field, from `✅ selected` and from the SELECTED state (2026-10-01)', () => {
  [component('Tab', { '✅ selected': ['VARIANT', 'False', ['False', 'True']] }),
    component('Chip', { '🚦 state': ['VARIANT', 'NORMAL', ['NORMAL', 'SELECTED']] })].forEach((c) => {
    const { model, markdown } = mapContract(c, testContext());
    assert.deepEqual([field(model, 'selected').base, field(model, 'selected').type], [false, 'bool'], c.name);
    assert.ok(dartBlock(markdown).includes('  this.selected = false,'), c.name);
    assert.ok(!markdown.includes('super.selected') && !markdown.includes('`selected` (base)'), c.name);
  });
});

test('nested instances whose names differ only by a size word merge into one slot without the size or parent name', () => {
  const m = buildContract(loadFixture('text_input').component, testContext());
  assert.deepEqual(fields(m).filter((name) => /Item$/.test(name)), ['leftItem', 'rightItem']);
  assert.deepEqual(field(m, 'leftItem').figma, ['nested `LargeTextInputLeftItem`', 'nested `MediumTextInputLeftItem`', 'nested `SmallTextInputLeftItem`']);
  assert.deepEqual(m.nested.filter((n) => /Item$/.test(n.component)).map((n) => n.field),
    ['leftItem', 'rightItem', 'leftItem', 'rightItem', 'leftItem', 'rightItem']);
  assert.equal(m.asks.filter((a) => a.includes('TextInputLeftItem')).length, 1, 'one ask per merged slot');
  const nested = (name, key) => ({ layer: name, name, key, page: '❖ ' + name, helper: false, visibleProperty: null,
    exposed: true, exposedProperties: [], variants: 1 });
  const c = component('Chip', {}, { nested: [nested('ExtraSmallChipIcon', 'a'), nested('ExtraLargeChipIcon', 'b'),
    nested('HugeChipIcon', 'c'), nested('LargeBadge', BADGE_KEY)] });
  const chip = buildContract(c, testContext());
  assert.deepEqual(fields(chip).sort(), ['customStyle', 'icon', 'largeBadge'], 'a lone size word stays');
  assert.equal(field(chip, 'icon').type, 'Widget?');
});

test('a Form component gets onChanged only; the contract path follows <section>/<component>/<component>.md', () => {
  const form = buildContract(component('Picker', { '🚦 state': ['VARIANT', 'NORMAL', ['NORMAL', 'HOVERED', 'PRESSED']] },
    { section: { page: '─── Form ───', label: 'Form ───' } }), testContext());
  assert.deepEqual([field(form, 'onPressed'), field(form, 'onChanged').type], [undefined, 'ValueChanged<String>?']);
  assert.equal(form.path, 'lib/src/components/form/picker/picker.dart');
  assert.equal(form.contractPath, 'docs/specs/stratum_ui/components/form/picker/picker.md');
  const control = buildContract(component('Chip', { '🚦 state': ['VARIANT', 'NORMAL', ['NORMAL', 'PRESSED']] }), testContext());
  assert.deepEqual([field(control, 'onPressed').type, field(control, 'onChanged')], ['VoidCallback?', undefined]);
});

test('values no rule covers become asks: unknown state, split-control suffix, symbol-only value, size outside the vocabulary', () => {
  const m = buildContract(component('Split', {
    '🚦 state': ['VARIANT', 'NORMAL', ['NORMAL', 'HOVERED_LEFT', 'EMPTY']],
    '🔖 type': ['VARIANT', 'A', ['A', '★', '1']],
    '📐 size': ['VARIANT', 'SMALL', ['SMALL', 'EXTRA_TINY', 'FILL_WIDTH']],
    '🌈 color': ['VARIANT', 'BRAND', ['BRAND', 'CUSTOM', 'BLACK']],
  }), testContext());
  const asked = (value) => m.asks.some((a) => a.includes('value `' + value + '`'));
  ['HOVERED_LEFT', 'EMPTY', '★', '1', 'EXTRA_TINY', 'FILL_WIDTH', 'CUSTOM', 'BLACK'].forEach((v) => assert.ok(asked(v), v));
  assert.ok(m.asks.some((a) => a.includes('`HOVERED_LEFT`') && a.includes('half of a split control')));
  assert.ok(m.asks.some((a) => a.includes('`EXTRA_TINY`') && a.includes('design-only')));
  assert.equal(m.base, 'StratumStatefulWidget', 'a split-control interaction value still needs state');
  assert.deepEqual(m.enums[0].values.map((v) => v.dart), ['a', null, null]);
  assert.deepEqual([field(m, 'size').base, field(m, 'color').base], [true, true]);
});

test('LOADING and feedback values leave any variant for loading and feedbackState; a mix is asked', () => {
  const m = buildContract(component('Spinner', { '🔖 type': ['VARIANT', 'DEFAULT_SPIN', ['DEFAULT_SPIN', 'LOADING', '🔴 NEGATIVE']] }), testContext());
  assert.deepEqual([field(m, 'loading').base, field(m, 'feedbackState').base], [true, true]);
  assert.deepEqual(m.enums[0].values.map((v) => v.figma), ['DEFAULT_SPIN']);
  assert.ok(m.asks.some((a) => a.includes('mixes LOADING, 🔴 NEGATIVE')));
});

test('enum reuse: an exact value set in lib/ is reused; a second component with another one\'s set asks for a shared name', () => {
  const ctx = testContext({ libEnums: [{ file: 'lib/a.dart', name: 'StratumDensity', values: ['compact', 'comfortable'] }] });
  const reused = buildContract(component('Table', { '🔖 density': ['VARIANT', 'COMPACT', ['COMPACT', 'COMFORTABLE']] }), ctx);
  assert.deepEqual([reused.enums[0].name, field(reused, 'density').init], ['StratumDensity', 'StratumDensity.compact']);
  assert.deepEqual(reused.asks, []);
  const repeat = buildContract(component('IconButton', { '🕶️ style': ['VARIANT', 'GHOST', ['FILLED_BRAND', 'OUTLINE', 'GHOST', 'SHADED', 'FILLED', 'DESTRUCTIVE']] }), testContext());
  assert.equal(repeat.enums[0].name, 'StratumIconButtonStyle');
  assert.ok(repeat.asks.some((a) => a.includes('`StratumButtonStyle`') && a.includes('name the shared enum')));
});

test('platform, theme, counts, numbered toggles, Example, font and pixel sizes', () => {
  const m = buildContract(component('Frame', {
    '🖥️ platform': ['VARIANT', 'MOBILE', ['MOBILE', 'TABLET', 'DESKTOP']],
    '🖥️ os': ['VARIANT', 'IOS', ['IOS', 'ANDROID']],
    '🌗 theme': ['VARIANT', 'LIGHT', ['LIGHT', 'DARK', 'AUTO']],
    '🔢 items': ['VARIANT', '3', ['1', '2', '3']],
    '👁️ showTag1#1:0': ['BOOLEAN', true], '👁️ showTag2#1:1': ['BOOLEAN', true],
    '🔖 example': ['VARIANT', 'EXAMPLE_A', ['EXAMPLE_A', 'EXAMPLE_B']],
    '📐 iconSize': ['VARIANT', 'Free', ['16', '24', 'Free']],
    '📐 textSize': ['VARIANT', '14', ['12', '14']],
  }), testContext());
  assert.deepEqual([field(m, 'windowSize').base, field(m, 'themeMode').base], [true, true]);
  assert.ok(field(m, 'themeMode').figma[0].includes('AUTO → system'));
  assert.deepEqual(m.skipped.map((s) => s.type), ['no field: the widget checks the platform at runtime', 'skipped (demo data)']);
  assert.deepEqual([field(m, 'items').type, field(m, 'tags').type], ['List<Widget>', 'List<Widget>']);
  assert.ok(!fields(m).includes('showTag1'));
  assert.deepEqual([field(m, 'iconSize').type, field(m, 'iconSize').init, field(m, 'textSize').init], ['double?', undefined, 'FontSize.s14']);
  assert.deepEqual(m.asks, []);
});

test('missing folder, empty description, and an incomplete matrix surface in the draft', () => {
  const c = component('Orphan', { '🕶️ style': ['VARIANT', 'A', ['A', 'B']], '📐 size': ['VARIANT', 'SMALL', ['SMALL', 'LARGE']] }, {
    section: null, description: { text: '', source: 'none', empty: true },
  });
  c.variants = { axes: ['🕶️ style', '📐 size'], count: 3, product: 4, combinations: [[0, 0], [0, 1], [1, 0]] };
  c.tokens = { columns: ['background'], values: ['var:a/b'], rows: [[0], [0], [0]] };
  const { markdown, asks, model } = mapContract(c, testContext());
  assert.deepEqual([model.path, model.contractPath], [null, null]);
  assert.ok(asks.some((a) => a.includes('which folder holds the widget')));
  assert.ok(asks.some((a) => a.includes('description is empty')));
  assert.ok(markdown.includes('## Variant combinations\n\n3 of 4 combinations exist:\n\n- 🕶️ style=A, 📐 size=SMALL\n- 🕶️ style=A, 📐 size=LARGE\n- 🕶️ style=B, 📐 size=SMALL\n'));
  assert.ok(markdown.indexOf('## Variant combinations') < markdown.indexOf('## Open questions'));
});

test('omitted parts and unknown token names are asked, never guessed', () => {
  const c = component('Bare', { '📐 size': ['VARIANT', 'SMALL', ['SMALL']] });
  delete c.tokens;
  c.slots = undefined;
  c.properties.push({ rawName: '✏️ icon#1:0', type: 'INSTANCE_SWAP', defaultValue: '9:1' });
  const m = buildContract(c, testContext());
  assert.ok(m.asks.some((a) => a.startsWith('Visual tokens were omitted')));
  assert.ok(m.asks.some((a) => a.startsWith('Slot sizes were omitted')));
  const t = component('Tok', { '📐 size': ['VARIANT', 'SMALL', ['SMALL']] });
  t.tokens = { columns: ['radius', 'text'], values: ['var:corner/huge', 'style:Brand Display'], rows: [[0, 1]] };
  const asks = buildContract(t, testContext()).asks;
  assert.ok(asks.some((a) => a.includes('`corner/huge` matches no `radius` key')));
  assert.ok(asks.some((a) => a.includes('Text style `Brand Display`')));
});

test('naming helpers', () => {
  assert.deepEqual(['FILLED_BRAND', '🔵 INFO', 'BLUE_GRAY', '←', 'DEFAULT', '★', '2X'].map(enumValueName),
    ['filledBrand', 'info', 'blueGray', 'left', null, null, null]);
  assert.deepEqual(['TextInput', 'Button', 'IconButton'].map(snakeName), ['text_input', 'button', 'icon_button']);
  assert.equal(parseTextStyle('body/14-semi-bold'), 'FontType.body, FontSize.s14, FontWeight.w600');
  assert.equal(parseTextStyle('body-large/16-semi-bold'), 'FontType.body, FontSize.s16, FontWeight.w600', 'the scale is ignored');
  assert.equal(parseTextStyle('number-mono/24-regular'), 'FontType.numberMono, FontSize.s24, FontWeight.w400');
  assert.equal(parseTextStyle('body/12-semi-bold', ['body']), 'FontType.body, FontSize.s12, FontWeight.w600');
  ['body/15-bold', 'brand/14-regular', 'body/14-heavy', 'UI Text 14 Semi Bold'].forEach((name) => assert.equal(parseTextStyle(name), null, name));
});
