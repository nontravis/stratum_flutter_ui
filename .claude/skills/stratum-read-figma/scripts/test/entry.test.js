// entry_read.js: pure helpers under node, and the assembled use_figma code against a mock `figma`.
const test = require('node:test');
const assert = require('node:assert/strict');
const E = require('../entry_read.js');
const { runRead, boundPaint, alias, solid } = require('./mock_figma.js');

test('description: descriptionMarkdown first, else description, entities unescaped, empty flagged', () => {
  assert.deepEqual(E.pickDescription({ descriptionMarkdown: '# Purpose\nA', description: 'ignored' }),
    { text: '# Purpose\nA', source: 'descriptionMarkdown', empty: false });
  assert.deepEqual(E.pickDescription({ descriptionMarkdown: '', description: 'Use &quot;Save&quot; &amp; Don&#39;t &#x2014; x' }),
    { text: 'Use "Save" & Don\'t — x', source: 'description', empty: false });
  assert.deepEqual(E.pickDescription({ descriptionMarkdown: ' ', description: '' }), { text: '', source: 'none', empty: true });
  assert.equal(E.unescapeHtml('&unknown; &#0; &lt;b&gt;'), '&unknown; &#0; <b>');
});

test('variant values come from variantProperties, else from the variant name', () => {
  assert.deepEqual(E.variantValues({ name: 'x', variantProperties: { '📐 size': 'SMALL' } }), { '📐 size': 'SMALL' });
  assert.deepEqual(E.variantValues({ name: '🕶️ style=GHOST, 📐 size=SMALL', variantProperties: null }), { '🕶️ style': 'GHOST', '📐 size': 'SMALL' });
  const throwing = { name: '📐 size=HUGE' };
  Object.defineProperty(throwing, 'variantProperties', { get() { throw new Error('set has errors'); } });
  assert.deepEqual(E.variantValues(throwing), { '📐 size': 'HUGE' });
});

test('the variant matrix lists existing combinations as option indexes and the full product', () => {
  const props = [{ rawName: '🕶️ style', type: 'VARIANT', variantOptions: ['A', 'B'] }, { rawName: 'label#1:0', type: 'TEXT' },
    { rawName: '📐 size', type: 'VARIANT', variantOptions: ['SMALL', 'LARGE'] }];
  const variants = [{ name: '🕶️ style=A, 📐 size=SMALL' }, { name: '🕶️ style=B, 📐 size=LARGE' }, { name: '🕶️ style=Z, 📐 size=SMALL' }];
  assert.deepEqual(E.variantMatrix(props, variants), { axes: ['🕶️ style', '📐 size'], count: 3, product: 4, combinations: [[0, 0], [1, 1], [-1, 0]] });
});

test('the section is the label of the nearest separator page above', () => {
  const pages = [{ id: 'a', name: '─── Control' }, { id: 'b', name: '❖ Buttons' }, { id: 'c', name: '-- Form' }, { id: 'd', name: '❖ Text input' }];
  assert.deepEqual(E.sectionOf(pages, 'b'), { page: '─── Control', label: 'Control' });
  assert.deepEqual(E.sectionOf(pages, 'd'), { page: '-- Form', label: 'Form' });
  assert.equal(E.sectionOf([{ id: 'x', name: '❖ Alone' }], 'x'), null);
  assert.equal(E.separatorLabel('.utilities'), null);
  assert.equal(E.separatorLabel('─── Control ──────────────'), 'Control', 'trailing decoration is not part of the label');
});

test('tokens: style before variable before hard-coded; columns keep each distinct value once', () => {
  const mixed = Symbol('mixed');
  assert.equal(E.paintToken([solid('#FF0000')], 'S:1', mixed), 'style:S:1');
  assert.equal(E.paintToken([boundPaint('V:1')], '', mixed), 'var:V:1');
  assert.equal(E.paintToken([solid('#FF0000', { visible: false }), solid('#00FF00')], '', mixed), 'hex:#00FF00');
  assert.equal(E.paintToken([], '', mixed), null);
  assert.equal(E.paintToken(mixed, '', mixed), 'mixed');
  assert.equal(E.numberToken({ cornerRadius: 8, boundVariables: { topLeftRadius: alias('V:2') } }, 'topLeftRadius', 'cornerRadius', mixed), 'var:V:2');
  assert.equal(E.numberToken({ cornerRadius: 8 }, 'topLeftRadius', 'cornerRadius', mixed), 'px:8');
  assert.equal(E.textToken({ textStyleId: '', fontName: { family: 'Inter', style: 'Bold' }, fontSize: 14 }, mixed), 'font:Inter Bold 14');
  const cols = E.tokenColumns([{ background: 'var:a', text: 'style:t' }, { background: 'var:a', text: null }]);
  assert.deepEqual(cols.values, ['var:a', 'style:t']);
  assert.equal(cols.rows[1][cols.columns.indexOf('text')], -1);
  assert.deepEqual(E.renameTokens(['var:V:1', 'style:S:1', 'var:V:9', 'hex:#FFFFFF'], { var: { 'V:1': 'button/primary' }, style: { 'S:1': 'body/14-regular' } }),
    ['var:button/primary', 'style:body/14-regular', 'var:V:9', 'hex:#FFFFFF']);
});

test('a result over the limit drops tokens, then slots, then variant docs, and lists them', () => {
  const big = 'x'.repeat(300);
  const result = { component: { name: 'Big', tokens: { values: [big] }, slots: { a: big }, variantDocs: [] } };
  assert.deepEqual(E.fitResult(JSON.parse(JSON.stringify(result)), 400).omitted, ['tokens']);
  assert.deepEqual(E.fitResult(JSON.parse(JSON.stringify(result)), 10).omitted, ['tokens', 'slots', 'variantDocs']);
  assert.equal(E.fitResult(JSON.parse(JSON.stringify(result)), 10000).omitted, undefined);
});

// A two-variant set: an icon slot toggled by showIcon, a nested Badge that showBadge hides through a wrapper frame, a
// FocusBorder helper from a ☀ page, a Doc frame, a hard-coded border.
function smallFile() {
  const variant = (id, size, px) => ({
    id, type: 'COMPONENT', name: '📐 size=' + size, variantProperties: { '📐 size': size },
    description: size === 'SMALL' ? 'Compact&#39;s use.' : '', descriptionMarkdown: '', documentationLinks: [],
    fills: [boundPaint('V:bg')], strokes: [solid('#112233')], cornerRadius: 4, layoutMode: 'HORIZONTAL',
    paddingTop: 4, paddingRight: 8, paddingBottom: 4, paddingLeft: 8, itemSpacing: 2,
    boundVariables: { paddingLeft: alias('V:pad'), paddingRight: alias('V:pad') },
    children: [
      { id: id + 'i', type: 'INSTANCE', name: 'icon', main: '9:1', width: px, height: px, layoutSizingHorizontal: 'FIXED',
        layoutSizingVertical: 'FIXED', componentPropertyReferences: { visible: '👁️ showIcon#1:0', mainComponent: '✏️ icon#1:1' } },
      { id: id + 't', type: 'TEXT', name: 'label', fills: [boundPaint('V:fg')], textStyleId: 'S:body' },
      { id: id + 'w', type: 'FRAME', name: 'badgeWrap', componentPropertyReferences: { visible: '👁️ showBadge#1:2' },
        children: [{ id: id + 'b', type: 'INSTANCE', name: 'badge', main: '8:2' }] },
      { id: id + 'f', type: 'INSTANCE', name: 'FocusBorder', main: '7:1', isExposedInstance: true,
        componentProperties: { '🚦 state': { type: 'VARIANT', value: 'NORMAL' } } },
      { id: id + 'd', type: 'FRAME', name: 'Doc', children: [{ id: id + 'x', type: 'INSTANCE', name: 'note', main: '9:1' }] },
    ],
  });
  const set = {
    id: '5:1', type: 'COMPONENT_SET', name: 'Chip', key: 'chip-key', description: 'Chip &quot;tag&quot;.', descriptionMarkdown: '',
    documentationLinks: [{ uri: 'https://example.com/chip' }],
    componentPropertyDefinitions: {
      '👁️ showIcon#1:0': { type: 'BOOLEAN', defaultValue: true },
      '✏️ icon#1:1': { type: 'INSTANCE_SWAP', defaultValue: '9:1', preferredValues: [{ type: 'COMPONENT', key: 'star-key' }] },
      '👁️ showBadge#1:2': { type: 'BOOLEAN', defaultValue: false },
      '📐 size': { type: 'VARIANT', defaultValue: 'SMALL', variantOptions: ['SMALL', 'LARGE'] },
    },
    children: [variant('5:2', 'SMALL', 16), variant('5:3', 'LARGE', 20)],
  };
  return {
    pages: [{ id: '0:1', name: '─── Display ─────', children: [] }, { id: '0:2', name: '❖ Chips', children: [set] },
      { id: '0:4', name: '❖ Badges', children: [
        { id: '8:1', type: 'COMPONENT_SET', name: 'Badge', key: 'badge-key', children: [{ id: '8:2', type: 'COMPONENT', name: 'size=SMALL' }] }] },
      { id: '0:3', name: '☀ Utilities', children: [{ id: '9:1', type: 'COMPONENT', name: 'Star', key: 'star-key' },
        { id: '7:0', type: 'COMPONENT_SET', name: 'FocusBorder', key: 'focus-key', children: [{ id: '7:1', type: 'COMPONENT', name: 'state=NORMAL' }] }] }],
    variables: { 'V:bg': 'chip/background', 'V:fg': 'text/default/primary', 'V:pad': 'space/xs' },
    styles: { 'S:body': 'body/12-semi-bold' },
  };
}

test('the assembled read returns the extracted data and writes nothing', async () => {
  const spec = smallFile();
  const { result, writes } = await runRead(spec, '5-3');
  assert.deepEqual(writes, [], 'entry_read must be read-only');
  assert.deepEqual(spec.loaded, ['0:2'], 'loads only the page of the set');
  const c = result.component;
  assert.deepEqual([c.id, c.key, c.name, c.page], ['5:1', 'chip-key', 'Chip', '❖ Chips'], 'a variant id reads its set');
  assert.deepEqual(c.section, { page: '─── Display ─────', label: 'Display' });
  assert.deepEqual(c.description, { text: 'Chip "tag".', source: 'description', empty: false });
  assert.deepEqual(c.documentationLinks, ['https://example.com/chip']);
  assert.deepEqual(c.variantDocs, [{ variant: 0, text: "Compact's use.", links: [] }]);
  const icon = c.properties.find((p) => p.name === 'icon');
  assert.deepEqual([icon.defaultName, icon.preferredValues], ['Star', [{ type: 'COMPONENT', key: 'star-key' }]]);
  assert.deepEqual(c.variants, { axes: ['📐 size'], count: 2, product: 2, combinations: [[0], [1]] });
  assert.deepEqual(c.slots['✏️ icon#1:1'], { visibleProperty: '👁️ showIcon#1:0', byVariant: [0, 1],
    table: [{ width: 16, height: 16, sizingH: 'FIXED', sizingV: 'FIXED' }, { width: 20, height: 20, sizingH: 'FIXED', sizingV: 'FIXED' }] });
  assert.deepEqual(c.nested, [
    { layer: 'badge', name: 'Badge', key: 'badge-key', page: '❖ Badges', helper: false, visibleProperty: '👁️ showBadge#1:2',
      exposed: false, exposedProperties: [], variants: 2 },
    { layer: 'FocusBorder', name: 'FocusBorder', key: 'focus-key', page: '☀ Utilities', helper: true, visibleProperty: null,
      exposed: true, exposedProperties: [{ name: '🚦 state', type: 'VARIANT' }], variants: 2 },
  ], 'the wrapper toggle and the ☀ page are recorded; the Doc frame instance and the icon slot are not nested components');
  const row = c.tokens.rows[0].map((idx) => (idx < 0 ? null : c.tokens.values[idx]));
  assert.deepEqual(Object.fromEntries(c.tokens.columns.map((col, i) => [col, row[i]])), {
    background: 'var:chip/background', foreground: 'var:text/default/primary', border: 'hex:#112233', radius: 'px:4',
    paddingTop: 'px:4', paddingRight: 'var:space/xs', paddingBottom: 'px:4', paddingLeft: 'var:space/xs', gap: 'px:2',
    text: 'style:body/12-semi-bold' });
  assert.equal(result.omitted, undefined);
});

test('a toggle bound on the instance itself wins over one bound on a wrapper frame', async () => {
  const spec = smallFile();
  spec.pages[1].children[0].children.forEach((v) => {
    v.children[2].children[0].componentPropertyReferences = { visible: '👁️ showIcon#1:0' };
  });
  const { result } = await runRead(spec, '5:1');
  assert.equal(result.component.nested[0].visibleProperty, '👁️ showIcon#1:0');
});

test('the read rejects a node that is no component and an unknown id', async () => {
  const spec = smallFile();
  await assert.rejects(runRead(spec, '0:1'), /not a component set: 0:1 is PAGE/);
  await assert.rejects(runRead(spec, '404:1'), /node not found/);
});
