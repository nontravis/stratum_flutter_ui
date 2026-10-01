// Mock `figma` API built from plain node specs, for entry_read.js tests and the synthetic fixtures. Every node is
// wrapped in a Proxy that records writes instead of applying them, so a test can prove the read never mutates.
// Node spec: { id, type, name, ...fields, children: [specs], main: '<component id>' (INSTANCE only) }.
const { assemble, parseArgs } = require('../assemble.js');

const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const MIXED = Symbol('mixed');

function buildFigma(spec) {
  const byId = {};
  const writes = [];
  const proxies = new Map();
  const guard = (raw) => {
    if (!raw || typeof raw !== 'object') return raw;
    if (proxies.has(raw)) return proxies.get(raw);
    const record = (target, key) => { writes.push((target.id || '?') + '.' + String(key)); return true; };
    const proxy = new Proxy(raw, {
      get(target, key) {
        const value = target[key];
        if (key === 'children' && Array.isArray(value)) return value.map(guard);
        if (key === 'parent') return guard(value);
        return value;
      },
      set: record,
      defineProperty: record,
      deleteProperty: record,
    });
    proxies.set(raw, proxy);
    return proxy;
  };
  const link = (node, parent) => {
    const raw = Object.assign({}, node);
    delete raw.main;
    raw.parent = parent || null;
    byId[raw.id] = raw;
    if (node.type === 'INSTANCE') raw.getMainComponentAsync = async () => guard(byId[node.main] || null);
    if (node.type === 'PAGE') raw.loadAsync = async () => { spec.loaded = (spec.loaded || []).concat(raw.id); };
    if (node.children) raw.children = node.children.map((child) => link(child, raw));
    return raw;
  };
  const pages = spec.pages.map((page) => link(Object.assign({ type: 'PAGE' }, page), null));
  const figma = {
    mixed: MIXED,
    root: { children: pages.map(guard) },
    getNodeByIdAsync: async (id) => guard(byId[id] || null),
    getStyleByIdAsync: async (id) => (spec.styles && spec.styles[id] ? { id, name: spec.styles[id] } : null),
    variables: { getVariableByIdAsync: async (id) => (spec.variables && spec.variables[id] ? { id, name: spec.variables[id] } : null) },
  };
  return { figma, writes };
}

// Runs the assembled use_figma code for one node against a mock built from spec.
async function runRead(spec, nodeId) {
  const { figma, writes } = buildFigma(spec);
  const result = await new AsyncFunction('figma', assemble(parseArgs(['--node', nodeId])))(figma);
  return { result, writes };
}

const solid = (hex, extra) => Object.assign({ type: 'SOLID', color: {
  r: parseInt(hex.slice(1, 3), 16) / 255, g: parseInt(hex.slice(3, 5), 16) / 255, b: parseInt(hex.slice(5, 7), 16) / 255,
} }, extra);
const boundPaint = (variableId) => solid('#000000', { boundVariables: { color: { type: 'VARIABLE_ALIAS', id: variableId } } });
const alias = (id) => ({ type: 'VARIABLE_ALIAS', id });

module.exports = { buildFigma, runRead, solid, boundPaint, alias, MIXED };
