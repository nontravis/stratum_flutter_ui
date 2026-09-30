const test = require('node:test');
const assert = require('node:assert/strict');
const { CONVENTIONS } = require('../conventions.js');
const X = require('../extract_lib.js');

// Mock Figma node: children get a parent link; a variant's componentPropertyDefinitions throws like Figma.
function node(type, name, extra, children) {
  const n = Object.assign({ id: name, type, name }, extra);
  if (children) {
    n.children = children;
    children.forEach((child) => { child.parent = n; });
  }
  return n;
}

function variantComponent(name, extra, children) {
  const n = node('COMPONENT', name, extra, children);
  Object.defineProperty(n, 'componentPropertyDefinitions', {
    get() { throw new Error('componentPropertyDefinitions read on a variant'); },
  });
  return n;
}

const solid = (r, g, b, extra) => Object.assign({ type: 'SOLID', color: { r, g, b } }, extra);

function buildPage() {
  const variantA = variantComponent('size=SMALL', { fills: [solid(1, 0, 0)] }, [
    node('TEXT', 'Label', { fills: [solid(0, 0, 0, { boundVariables: { color: { id: 'v1' } } })] }),
    node('INSTANCE', 'Icon', { fills: [solid(0, 1, 0)] }, [node('VECTOR', 'path', { fills: [solid(0, 1, 0)] })]),
    node('FRAME', 'Styled', { fills: [solid(0, 0, 1)], fillStyleId: 'S:1', strokes: [solid(1, 1, 1)] }),
  ]);
  const variantB = variantComponent('size=LARGE', { fills: [solid(1, 0, 0), solid(1, 0, 0, { visible: false })] });
  const set = node('COMPONENT_SET', 'Button', {
    description: '', descriptionMarkdown: 'Primary action.', strokes: [solid(0.59, 0.28, 1)],
    componentPropertyDefinitions: {
      '📐 size': { type: 'VARIANT', defaultValue: 'SMALL', variantOptions: ['SMALL', 'LARGE'] },
      '👁️ showIcon#1:0': { type: 'BOOLEAN', defaultValue: false },
    },
  }, [variantA, variantB]);
  const standalone = node('COMPONENT', 'Chip', { componentPropertyDefinitions: {} });
  return node('PAGE', '❖ Buttons', {}, [
    node('SECTION', 'Buttons', {}, [set, standalone]),
    node('FRAME', 'Doc', {}, [node('COMPONENT', 'DocOnly', {})]),
    node('FRAME', 'Examples', {}, [node('COMPONENT_SET', 'ExampleSet', {}, [])]),
    node('COMPONENT', '_PrivateBase', {}),
    node('INSTANCE', 'Button instance', {}, [node('COMPONENT', 'Nested', {})]),
  ]);
}

test('normalizeName strips the #id suffix, emoji, and symbols, then camelCases', () => {
  assert.equal(X.normalizeName('👁️ showLeftIcon#1234:0'), 'showLeftIcon');
  assert.equal(X.normalizeName('✏️ Label text:'), 'labelText');
  assert.equal(X.normalizeName('🚦state'), 'state');
  assert.equal(X.normalizeName(' ⏳ loading'), 'loading');
  assert.equal(X.normalizeName('✏️ InfoIcon#2:9'), 'infoIcon');
  assert.equal(X.normalizeName('🔘 SHOW_ICON'), 'showIcon');
  assert.equal(X.normalizeName('%'), '');
  assert.equal(X.normalizeName('⌘#10:163'), '');
});

test('parsePropertyName splits leading space, emoji, separator, and label', () => {
  assert.deepEqual(
    X.parsePropertyName(' ⏳  loading:#3:1'),
    { base: ' ⏳  loading:', leading: ' ', emoji: '⏳', separator: '  ', label: 'loading:', name: 'loading' },
  );
  assert.equal(X.parsePropertyName('🚦state').separator, '');
  assert.equal(X.parsePropertyName('size').emoji, '');
});

test('shouldSkipPage skips dot, separator, documentation, and example pages; a named page skips the first two only', () => {
  const skipped = ['.utilities', '─── Control ──────', '----------', '☀ Handoff & Helpers', 'Example Screens', 'Login Examples'];
  skipped.forEach((name) => assert.ok(X.shouldSkipPage(name, CONVENTIONS), name));
  ['❖ Buttons', '⬒ Layouts', 'Cover', 'example'].forEach((name) => assert.ok(!X.shouldSkipPage(name, CONVENTIONS), name));
  assert.deepEqual(skipped.filter((name) => X.shouldSkipPage(name, CONVENTIONS, true)), skipped.slice(0, 3));
});

test('collectComponents applies the skip rules and never reads a variant on its own', () => {
  const records = X.collectComponents(buildPage(), '❖ Buttons', CONVENTIONS);
  assert.deepEqual(records.map((r) => r.name), ['Button', 'Chip']);
  const button = records[0];
  assert.equal(button.page, '❖ Buttons');
  assert.equal(button.variantCount, 2);
  assert.deepEqual(Object.keys(button.properties), ['📐 size', '👁️ showIcon#1:0']);
  assert.deepEqual(button.properties['📐 size'].variantOptions, ['SMALL', 'LARGE']);
});

test('collectComponents promotes a variant root to its component set', () => {
  const page = buildPage();
  const variantNode = page.children[0].children[0].children[0];
  const records = X.collectComponents(variantNode, '❖ Buttons', CONVENTIONS);
  assert.deepEqual(records.map((r) => r.name), ['Button']);
});

test('collectComponents lints a private set the user names as the root, and still skips private sets below it', () => {
  const page = buildPage();
  const privateSet = node('COMPONENT_SET', '_Base', { componentPropertyDefinitions: {} }, [node('COMPONENT', 'a=1', {})]);
  page.children.push(privateSet);
  privateSet.parent = page;
  assert.deepEqual(X.collectComponents(privateSet, '❖ Buttons', CONVENTIONS).map((r) => r.name), ['_Base']);
  assert.deepEqual(X.collectComponents(privateSet.children[0], '❖ Buttons', CONVENTIONS).map((r) => r.name), ['_Base']);
  assert.ok(!X.collectComponents(page, '❖ Buttons', CONVENTIONS).some((r) => r.name.startsWith('_')));
});

test('readUnboundPaints counts hard-coded solid paints and skips bound, styled, hidden, instance, and set paints', () => {
  const set = buildPage().children[0].children[0];
  assert.deepEqual(X.readUnboundPaints(set), [
    { kind: 'fill', hex: '#FF0000', count: 2 },
    { kind: 'stroke', hex: '#FFFFFF', count: 1 },
  ]);
});

test('describeComponent turns a raw record into parsed properties', () => {
  const [button] = X.collectComponents(buildPage(), '❖ Buttons', CONVENTIONS);
  const described = X.describeComponent(button);
  assert.equal(described.hasDescription, true);
  assert.deepEqual(described.properties.map((p) => [p.name, p.type, p.emoji, p.options.length]), [
    ['size', 'VARIANT', '📐', 2],
    ['showIcon', 'BOOLEAN', '👁️', 0],
  ]);
  assert.equal(X.describeComponent(Object.assign({}, button, { descriptionMarkdown: '  ' })).hasDescription, false);
});

test('readComponent keeps a set whose definitions throw, with readError', () => {
  const broken = node('COMPONENT_SET', 'Broken', {}, [node('COMPONENT', 'a=1', {}), node('COMPONENT', 'a=1', {})]);
  Object.defineProperty(broken, 'componentPropertyDefinitions', { get() { throw new Error('Component set has existing errors'); } });
  const record = X.readComponent(broken, '❖ Test');
  assert.deepEqual([record.properties, record.variantCount, record.readError], [{}, 2, 'Component set has existing errors']);
});
