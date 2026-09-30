// Pure extraction: walk Figma-like nodes, apply skip rules, read definitions, normalize names.
// No `figma` global, no import, no top-level await. Shared with stratum-read-figma.

function matchesSkip(name, target, conv, named) {
  return conv.skip.some((row) => row.target === target && !(named && row.wholeFileOnly) &&
    (row.match === 'exact' ? name === row.value : row.match === 'contains' ? name.indexOf(row.value) >= 0 : name.indexOf(row.value) === 0));
}

// named: the user listed this page (scope 2), so wholeFileOnly rows do not apply.
function shouldSkipPage(name, conv, named) {
  return matchesSkip(name, 'page', conv, named);
}

function isSkippedFrame(node, conv) {
  return node.type !== 'COMPONENT' && node.type !== 'COMPONENT_SET' && matchesSkip(node.name, 'frame', conv);
}

function isPrivateName(name, conv) {
  return matchesSkip(name, 'component', conv);
}

function isVariantComponent(node) {
  return node.type === 'COMPONENT' && Boolean(node.parent) && node.parent.type === 'COMPONENT_SET';
}

// A variant never owns componentPropertyDefinitions (the getter throws); read its set instead.
function promoteVariant(node) {
  return isVariantComponent(node) ? node.parent : node;
}

function readPropertyDefinitions(node) {
  const defs = node.componentPropertyDefinitions || {};
  const out = {};
  Object.keys(defs).forEach((key) => {
    const def = defs[key];
    out[key] = { type: def.type, defaultValue: def.defaultValue };
    if (def.variantOptions) out[key].variantOptions = def.variantOptions.slice();
  });
  return out;
}

function readVariantMatrix(node) {
  if (node.type !== 'COMPONENT_SET') return 1;
  return node.children.filter((child) => child.type === 'COMPONENT').length;
}

function colorToHex(color) {
  const hex = [color.r, color.g, color.b].map((v) => Math.round(v * 255).toString(16).padStart(2, '0'));
  return '#' + hex.join('').toUpperCase();
}

function tallyUnboundPaints(node, field, styleField, kind, tally) {
  const paints = node[field];
  const style = node[styleField];
  if (!Array.isArray(paints) || (typeof style === 'string' && style)) return;
  paints.forEach((paint) => {
    if (paint.type !== 'SOLID' || paint.visible === false) return;
    if (paint.boundVariables && paint.boundVariables.color) return;
    const hex = colorToHex(paint.color);
    const key = kind + hex;
    tally[key] = tally[key] || { kind, hex, count: 0 };
    tally[key].count += 1;
  });
}

// Nested instances are skipped: their colors belong to their own main component.
function readUnboundPaints(node) {
  const tally = {};
  const visit = (current) => {
    if (current.type === 'INSTANCE') return;
    tallyUnboundPaints(current, 'fills', 'fillStyleId', 'fill', tally);
    tallyUnboundPaints(current, 'strokes', 'strokeStyleId', 'stroke', tally);
    (current.children || []).forEach(visit);
  };
  const roots = node.type === 'COMPONENT_SET' ? node.children : [node];
  roots.forEach(visit);
  return Object.keys(tally).map((key) => tally[key]);
}

// A set with Figma errors (for example duplicate variants) throws on read; keep it as readError.
function readComponent(node, pageName) {
  const record = {
    id: node.id,
    name: node.name,
    type: node.type,
    page: pageName,
    description: node.description || '',
    descriptionMarkdown: node.descriptionMarkdown || '',
    properties: {},
    variantCount: readVariantMatrix(node),
    unboundPaints: readUnboundPaints(node),
  };
  try {
    record.properties = readPropertyDefinitions(node);
  } catch (error) {
    record.readError = String(error && error.message ? error.message : error);
  }
  return record;
}

// Returns raw records for every component set and standalone component under root. The root itself is never
// skipped: a user who names a `Doc` frame or a private `_` set (scope 3) gets it linted.
function collectComponents(root, pageName, conv) {
  const out = [];
  const visit = (node, isRoot) => {
    if (!isRoot && isSkippedFrame(node, conv)) return;
    if (node.type === 'COMPONENT_SET' || node.type === 'COMPONENT') {
      if (isRoot || !isPrivateName(node.name, conv)) out.push(readComponent(node, pageName));
      return;
    }
    if (node.type === 'INSTANCE' || !node.children) return;
    node.children.forEach((child) => visit(child, false));
  };
  visit(promoteVariant(root), true);
  return out;
}

function stripPropertySuffix(rawName) {
  return rawName.replace(/#[0-9]+:[0-9]+$/, '');
}

// Strip the #id suffix, emoji and symbols, trim, collapse spaces, then camelCase.
function normalizeName(rawName) {
  const words = stripPropertySuffix(rawName).replace(/[^A-Za-z0-9]+/g, ' ').trim().split(' ').filter(Boolean);
  return words.map((word, index) => {
    const w = word.length > 1 && /^[A-Z0-9]+$/.test(word) ? word.toLowerCase() : word;
    const head = index === 0 ? w.charAt(0).toLowerCase() : w.charAt(0).toUpperCase();
    return head + w.slice(1);
  }).join('');
}

function parsePropertyName(rawName) {
  const base = stripPropertySuffix(rawName);
  const leading = base.match(/^\s*/)[0];
  let rest = base.slice(leading.length);
  const emoji = rest.match(/^[^A-Za-z0-9\s]*/)[0];
  rest = rest.slice(emoji.length);
  const separator = rest.match(/^\s*/)[0];
  return { base, leading, emoji, separator, label: rest.slice(separator.length), name: normalizeName(base) };
}

function describeProperty(rawName, def) {
  return Object.assign(parsePropertyName(rawName), {
    rawName,
    type: def.type,
    defaultValue: def.defaultValue,
    defaultName: def.defaultName || '',
    options: def.variantOptions || [],
  });
}

function describeComponent(record) {
  const defs = record.properties || {};
  return {
    id: record.id,
    name: record.name,
    type: record.type,
    page: record.page,
    hasDescription: Boolean((record.descriptionMarkdown || record.description || '').trim()),
    variantCount: record.variantCount,
    unboundPaints: record.unboundPaints || [],
    properties: Object.keys(defs).map((rawName) => describeProperty(rawName, defs[rawName])),
  };
}

// Byte length of the UTF-8 encoding, used to keep a returned result under the tool's result limit.
function utf8Length(text) {
  let n = 0;
  for (const ch of text) {
    const code = ch.codePointAt(0);
    n += code < 0x80 ? 1 : code < 0x800 ? 2 : code < 0x10000 ? 3 : 4;
  }
  return n;
}

if (typeof module !== 'undefined') module.exports = { utf8Length, shouldSkipPage, isSkippedFrame, isPrivateName, promoteVariant, readPropertyDefinitions, readVariantMatrix, readUnboundPaints, readComponent, collectComponents, stripPropertySuffix, normalizeName, parsePropertyName, describeProperty, describeComponent };
