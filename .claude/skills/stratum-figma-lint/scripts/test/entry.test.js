// Runs the assembled use_figma code against a mock `figma` global.
const test = require('node:test');
const assert = require('node:assert/strict');
const { assemble, parseArgs, sandboxConventions, BUNDLES, MAX_CODE_CHARS } = require('../assemble.js');
const { CONVENTIONS, fixtureRecords } = require('./helpers.js');
const { describeComponent } = require('../extract_lib.js');
const { lintComponents } = require('../lint_lib.js');

const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;

function node(type, name, extra, children) {
  const n = Object.assign({ id: name, type, name }, extra);
  if (children) {
    n.children = children;
    children.forEach((child) => { child.parent = n; });
  }
  return n;
}

function mockFigma() {
  const loaded = [];
  const lookups = [];
  const variants = ['NORMAL', 'HOVERD'].map((v) => node('COMPONENT', '🚦 state=' + v, { id: '5:' + v }));
  const set = node('COMPONENT_SET', 'SocialButton', {
    id: '5:1', description: 'Social sign-in.', descriptionMarkdown: '',
    componentPropertyDefinitions: { '🚦 state': { type: 'VARIANT', defaultValue: 'NORMAL', variantOptions: ['NORMAL', 'HOVERD'] } },
  }, variants);
  // Swap defaults: a Slot component, a variant of a `❖ Header` set, and an instance of an icon component.
  const slot = node('COMPONENT', 'Slot', { id: '9:1', description: 'Slot.' });
  const slotSet = node('COMPONENT_SET', '❖ Header', { id: '9:4', description: 'Slot.' }, [node('COMPONENT', 'size=SM', { id: '9:5' })]);
  const star = node('COMPONENT', 'Star', { id: '9:3' });
  const starInstance = node('INSTANCE', 'Star', { id: '9:2', getMainComponentAsync: async () => star });
  const swap = (id) => ({ type: 'INSTANCE_SWAP', defaultValue: id });
  const layout = node('COMPONENT_SET', 'PageLayout', {
    id: '6:1', description: 'Layout.', descriptionMarkdown: '',
    componentPropertyDefinitions: {
      '❖ top#1:0': swap('9:1'), '↻ right#1:1': swap('9:1'), '❖ header#1:2': swap('9:5'),
      '❖ icon#1:3': swap('9:2'), '✏️ body#1:4': swap('404:1'),
    },
  }, [node('COMPONENT', 'size=SM', { id: '6:2' })]);
  const page = (id, name, children) => node('PAGE', name, { id, loadAsync: async () => { loaded.push(id); } }, children);
  const pages = [
    page('0:1', '❖ Buttons', [set]), page('0:2', '.utilities', []), page('0:3', '☀ Utilities', [slot, slotSet, star]),
    page('0:4', 'Example Screens', [starInstance]), page('0:5', '⬒ Layouts', [layout]),
  ];
  const byId = {};
  const index = (n) => { byId[n.id] = n; (n.children || []).forEach(index); };
  pages.forEach(index);
  return { loaded, lookups, figma: { getNodeByIdAsync: async (id) => { lookups.push(id); return byId[id] || null; } } };
}

async function run(argv) {
  const mock = mockFigma();
  const result = await new AsyncFunction('figma', assemble(parseArgs(argv)))(mock.figma);
  return { result, loaded: mock.loaded, lookups: mock.lookups };
}

test('every mode bundle strips comment lines', () => {
  Object.keys(BUNDLES).forEach((mode) => {
    assert.ok(!/^\s*\/\//m.test(assemble(parseArgs(['--pages', '0:1', '--mode', mode]))), mode + ' keeps comment lines');
  });
});

// Tripwire: a batch holds up to 10 pages, and each bundle keeps HEADROOM under the tool limit, so a growing rule set
// fails here before use_figma rejects the code. REAL_BATCH is the larger 10-page batch of the reference file
// (2026-10-01 post-rename run); LONG_BATCH gives every page an 11-character id (`55552:29918`).
const REAL_BATCH = '924:17802,955:17323,55552:29918,915:13155,927:27102,55533:32137,1093:30620,915:12623,914:2613,55506:29831';
const LONG_BATCH = Array.from({ length: 10 }, (_, i) => (55510 + i) + ':' + (29900 + i)).join(',');
const HEADROOM = 0.05;

test('the larger real 10-page batch and a long-id batch keep every mode bundle at least 5% under MAX_CODE_CHARS', () => {
  const cap = Math.floor(MAX_CODE_CHARS * (1 - HEADROOM));
  [REAL_BATCH, LONG_BATCH].forEach((batch) => Object.keys(BUNDLES).forEach((mode) => {
    const code = assemble(parseArgs(['--pages', batch, '--mode', mode]));
    assert.ok(code.length <= cap, mode + ': ' + code.length + ' characters, cap ' + cap);
  }));
});

test('the sandbox gets no doc-only data and lints the fixtures exactly as the full conventions do', () => {
  const shipped = sandboxConventions(null);
  const line = assemble(parseArgs(['--node', '1:1'])).split('\n')[0];
  assert.ok(line.startsWith('const CONVENTIONS = ') && line.endsWith(';'));
  assert.deepEqual(new Function('return ' + line.slice('const CONVENTIONS = '.length, -1))(), shipped);
  assert.deepEqual([shipped.listToggles.canonical, shipped.listToggles.legacy], [undefined, undefined]);
  Object.keys(shipped.vocabularies).forEach((key) => assert.equal(shipped.vocabularies[key].codeOnly, undefined, key));
  assert.deepEqual(Object.keys(CONVENTIONS.vocabularies).filter((key) => !shipped.vocabularies[key]), ['fontSize'],
    'a vocabulary no role uses stays out');
  const active = CONVENTIONS.rules.filter((r) => CONVENTIONS.severityOrder.includes(r.severity));
  assert.deepEqual(shipped.rules, active.map((r) => ({ id: r.id, severity: r.severity })), 'no rule messages, no retired rule');
  assert.ok(CONVENTIONS.rules[0].message && CONVENTIONS.listToggles.legacy.length, 'conventions.js keeps the doc-only data');
  const described = fixtureRecords('button', 'alert', 'text_input', 'rule_table').map(describeComponent);
  assert.deepEqual(lintComponents(described, shipped), lintComponents(described, CONVENTIONS));
});

test('raw and vocab bundles leave out lint_lib.js; only vocab carries vocab_lib.js', () => {
  const has = (mode, symbol) => assemble(parseArgs(['--node', '1:1', '--mode', mode])).includes(symbol);
  assert.deepEqual(['findings', 'raw', 'vocab'].map((m) => has(m, 'function lintComponents')), [true, false, false]);
  assert.deepEqual(['findings', 'raw', 'vocab'].map((m) => has(m, 'function packVocabulary')), [false, false, true]);
  assert.deepEqual(['findings', 'raw', 'vocab'].map((m) => has(m, 'knownWords:')), [true, false, false]);
});

test('findings mode lints the listed pages, skips skip-rule pages, and ends with the summary line', async () => {
  const { result, loaded } = await run(['--pages', '0:1,0:2']);
  assert.deepEqual(loaded, ['0:1']);
  assert.deepEqual(result.pages, ['❖ Buttons']);
  assert.equal(result.summary, 'lint: 1 blocking, 0 convention, 0 advisory, 0 info');
  assert.deepEqual(result.errors, []);
  assert.deepEqual(result.rows.blocking, [['L01', '🚦 state', 'HOVERD', 'HOVERED', ['SocialButton']]]);
  assert.deepEqual(result.componentPages, { SocialButton: [0] });
});

test('a whole-file run skips documentation and example pages; --named lints the pages the user named', async () => {
  assert.deepEqual((await run(['--pages', '0:1,0:2,0:3,0:4'])).loaded, ['0:1']);
  assert.deepEqual((await run(['--pages', '0:1,0:2,0:3,0:4', '--named'])).loaded, ['0:1', '0:3', '0:4']);
  assert.equal(parseArgs(['--pages', '0:1']).named, false);
});

test('an INSTANCE_SWAP whose resolved default is a Slot or a ❖ set takes ❖, other swaps ✏️, a region name takes ❖', async () => {
  const { result } = await run(['--pages', '0:5']);
  const l05 = result.rows.convention.filter((row) => row[0] === 'L05').map((row) => [row[1], row[3]]);
  assert.deepEqual(l05.sort(), [['↻ right', '❖ right'], ['❖ icon', '✏️ icon'], ['✏️ body', '❖ body']].sort());
});

test('raw mode carries each resolved swap name and resolves each default id once', async () => {
  const { result, lookups } = await run(['--node', '6:1', '--mode', 'raw']);
  const props = result.components[0].properties;
  assert.deepEqual(Object.keys(props).map((key) => props[key].defaultName), ['Slot', 'Slot', '❖ Header', 'Star', undefined]);
  assert.equal(lookups.filter((id) => id === '9:1').length, 1);
});

test('node scope promotes a variant id to its set and loads only its page', async () => {
  const { result, loaded } = await run(['--node', '5-HOVERD']);
  assert.deepEqual(loaded, ['0:1']);
  assert.equal(result.rows.blocking[0][4][0], 'SocialButton');
});

test('raw mode returns readComponent records for fixture capture', async () => {
  const { result } = await run(['--node', '5:1', '--mode', 'raw']);
  assert.equal(result.components.length, 1);
  assert.deepEqual(Object.keys(result.components[0]), ['id', 'name', 'type', 'page', 'description', 'descriptionMarkdown', 'properties', 'variantCount', 'unboundPaints']);
});

test('vocab mode returns name and value use counts per batch', async () => {
  const { result } = await run(['--pages', '0:1', '--mode', 'vocab']);
  assert.deepEqual(result, { mode: 'vocab', pages: ['❖ Buttons'], names: { state: 1 }, values: { NORMAL: 1, HOVERD: 1 } });
});

test('assemble rejects a call without scope', () => {
  assert.throws(() => parseArgs(['--mode', 'raw']), /pass --pages or --node/);
});
