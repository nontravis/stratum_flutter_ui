// Reads one component set for stratum-read-figma and returns the "Extracted data" JSON. Read-only: it assigns to no
// node and makes no write call. Pure helpers come first; readEntry makes the Figma calls through `api`. Under node the
// file exports its functions (tests); in the use_figma sandbox the last line runs readEntry.
// Placeholder: __NODE_ID__ takes a JSON literal such as "123:456" (assemble.js fills it).

// Shared helpers: in scope inside the Figma bundle; required from the lint skill's extract_lib.js under node.
const READ_SHARED = typeof normalizeName === 'function'
  ? { normalizeName, isSkippedFrame, promoteVariant, readPropertyDefinitions, utf8Length }
  : require('../../stratum-figma-lint/scripts/extract_lib.js');
// Mirrors the use_figma result limit observed on 2026-09-30 (about 20 KB), as entry_lint.js does.
const READ_RESULT_LIMIT = 18000;
// Parts dropped, in this order, when a result would pass the limit; the result lists them in `omitted`.
const READ_DROP_ORDER = ['tokens', 'slots', 'variantDocs'];
// A page whose name starts with this holds helpers (FocusBorder, Caret), never widgets.
const READ_HELPER_PAGE = '☀';
const READ_ENTITIES = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ' };

// Figma returned `description` with HTML entities (&quot;, &#39;) on 2026-09-30; decode named and numeric ones.
function unescapeHtml(text) {
  return String(text).replace(/&(#[xX][0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);/g, (match, body) => {
    if (body.charAt(0) === '#') {
      const hex = body.charAt(1) === 'x' || body.charAt(1) === 'X';
      const code = parseInt(body.slice(hex ? 2 : 1), hex ? 16 : 10);
      return code > 0 && code <= 0x10ffff ? String.fromCodePoint(code) : match;
    }
    const named = READ_ENTITIES[body.toLowerCase()];
    return named === undefined ? match : named;
  });
}

// descriptionMarkdown when non-empty, else description; `empty` flags a set Figma read without one.
function pickDescription(node) {
  const markdown = String(node.descriptionMarkdown || '');
  const plain = String(node.description || '');
  const source = markdown.trim() ? 'descriptionMarkdown' : plain.trim() ? 'description' : 'none';
  const text = unescapeHtml(source === 'descriptionMarkdown' ? markdown : plain).trim();
  return { text, source, empty: !text };
}

function readLinks(node) {
  return (node.documentationLinks || []).map((link) => link && link.uri).filter(Boolean);
}

// A variant's values from variantProperties, else parsed from its name `a=b, c=d`.
function variantValues(node) {
  let values = null;
  try { values = node.variantProperties || null; } catch (error) { values = null; }
  if (values) return values;
  const out = {};
  String(node.name).split(',').forEach((pair) => {
    const at = pair.indexOf('=');
    if (at > 0) out[pair.slice(0, at).trim()] = pair.slice(at + 1).trim();
  });
  return out;
}

// Every existing combination as option indexes per axis (-1: value not in variantOptions), in children order.
function variantMatrix(properties, variants) {
  const axes = properties.filter((prop) => prop.type === 'VARIANT');
  const combinations = variants.map((variant) => {
    const values = variantValues(variant);
    return axes.map((axis) => axis.variantOptions.indexOf(values[axis.rawName]));
  });
  const product = axes.reduce((n, axis) => n * axis.variantOptions.length, 1);
  return { axes: axes.map((axis) => axis.rawName), count: variants.length, product, combinations };
}

// Distinct records once, plus each variant's index into them (-1: no record in that variant).
function tableIndex(records) {
  const table = [];
  const keys = [];
  const byVariant = records.map((record) => {
    if (record === null) return -1;
    const key = JSON.stringify(record);
    let at = keys.indexOf(key);
    if (at < 0) { at = keys.length; keys.push(key); table.push(record); }
    return at;
  });
  return { table, byVariant };
}

function paintHex(color) {
  return '#' + [color.r, color.g, color.b].map((v) => Math.round(v * 255).toString(16).padStart(2, '0')).join('').toUpperCase();
}

// Token strings: `style:<id>`, `var:<id>` (renamed to names later), `hex:#RRGGBB`, `px:<n>`, `font:<...>`,
// `paint:<TYPE>`, `mixed`, or null when the layer has none.
function paintToken(paints, styleId, mixed) {
  if (styleId === mixed || paints === mixed) return 'mixed';
  if (typeof styleId === 'string' && styleId) return 'style:' + styleId;
  const paint = (Array.isArray(paints) ? paints : []).find((p) => p.visible !== false);
  if (!paint) return null;
  const alias = paint.boundVariables && paint.boundVariables.color;
  if (alias && alias.id) return 'var:' + alias.id;
  return paint.type === 'SOLID' ? 'hex:' + paintHex(paint.color) : 'paint:' + paint.type;
}

function numberToken(node, boundKey, valueKey, mixed) {
  const alias = node.boundVariables && node.boundVariables[boundKey];
  if (alias && alias.id) return 'var:' + alias.id;
  const value = node[valueKey];
  if (value === mixed || typeof value === 'symbol') return 'mixed';
  return typeof value === 'number' ? 'px:' + Math.round(value * 100) / 100 : null;
}

function textToken(text, mixed) {
  if (text.textStyleId === mixed) return 'mixed';
  if (typeof text.textStyleId === 'string' && text.textStyleId) return 'style:' + text.textStyleId;
  const font = text.fontName;
  if (!font || font === mixed || typeof text.fontSize !== 'number') return 'mixed';
  return 'font:' + font.family + ' ' + font.style + ' ' + text.fontSize;
}

// The first visible text layer of a variant, outside nested instances and Doc or Examples frames.
function firstText(node, conv) {
  for (const child of node.children || []) {
    if (child.visible === false || child.type === 'INSTANCE' || READ_SHARED.isSkippedFrame(child, conv)) continue;
    if (child.type === 'TEXT') return child;
    const found = firstText(child, conv);
    if (found) return found;
  }
  return null;
}

// Token columns, in order: background, border, radius, padding, and gap come from the variant frame; foreground and
// text from its first text layer.
const READ_TOKEN_COLUMNS = ['background', 'foreground', 'border', 'radius', 'paddingTop', 'paddingRight',
  'paddingBottom', 'paddingLeft', 'gap', 'text'];

function variantTokens(variant, conv, mixed) {
  const text = firstText(variant, conv);
  const auto = Boolean(variant.layoutMode) && variant.layoutMode !== 'NONE';
  const side = (key) => (auto ? numberToken(variant, key, key, mixed) : null);
  return {
    background: paintToken(variant.fills, variant.fillStyleId, mixed),
    foreground: text ? paintToken(text.fills, text.fillStyleId, mixed) : null,
    border: paintToken(variant.strokes, variant.strokeStyleId, mixed),
    radius: numberToken(variant, 'topLeftRadius', 'cornerRadius', mixed),
    paddingTop: side('paddingTop'),
    paddingRight: side('paddingRight'),
    paddingBottom: side('paddingBottom'),
    paddingLeft: side('paddingLeft'),
    gap: auto ? numberToken(variant, 'itemSpacing', 'itemSpacing', mixed) : null,
    text: text ? textToken(text, mixed) : null,
  };
}

// Columnar form that stays small on large sets: each distinct token string once in `values`, and per variant one row
// of indexes into it in `columns` order (-1: none).
function tokenColumns(records) {
  const values = [];
  const rows = records.map((record) => READ_TOKEN_COLUMNS.map((column) => {
    const value = record[column];
    if (value === null || value === undefined) return -1;
    let at = values.indexOf(value);
    if (at < 0) { at = values.length; values.push(value); }
    return at;
  }));
  return { columns: READ_TOKEN_COLUMNS.slice(), values, rows };
}

// Instance layers of a variant, outside Doc or Examples frames, each with the show toggle bound on the nearest wrapper
// frame between the variant and it (null: none). A nested instance's own children are its component's.
function instanceLayers(node, conv, wrapperToggle) {
  const out = [];
  (node.children || []).forEach((child) => {
    if (READ_SHARED.isSkippedFrame(child, conv)) return;
    if (child.type === 'INSTANCE') { out.push({ layer: child, wrapperToggle: wrapperToggle || null }); return; }
    const refs = child.componentPropertyReferences || {};
    out.push(...instanceLayers(child, conv, refs.visible || wrapperToggle));
  });
  return out;
}

function slotSize(layer) {
  const round = (n) => (typeof n === 'number' ? Math.round(n * 100) / 100 : null);
  return { width: round(layer.width), height: round(layer.height),
    sizingH: layer.layoutSizingHorizontal || 'FIXED', sizingV: layer.layoutSizingVertical || 'FIXED' };
}

// A separator page is named with leading box-drawing or hyphen characters (`─── Control ───`); its label sits between
// them and any trailing ones.
function separatorLabel(name) {
  const match = String(name).match(/^[─-]+\s*(.*?)[\s─-]*$/);
  return match ? match[1] : null;
}

function sectionOf(pages, pageId) {
  const at = pages.findIndex((page) => page.id === pageId);
  for (let i = at - 1; i >= 0; i -= 1) {
    const label = separatorLabel(pages[i].name);
    if (label !== null) return { page: pages[i].name, label };
  }
  return null;
}

// Definitions in Figma order, with the normalized name and the INSTANCE_SWAP preferred values.
function readProperties(node) {
  const defs = node.componentPropertyDefinitions || {};
  const flat = READ_SHARED.readPropertyDefinitions(node);
  return Object.keys(flat).map((rawName) => {
    const prop = Object.assign({ rawName, name: READ_SHARED.normalizeName(rawName) }, flat[rawName]);
    const preferred = defs[rawName].preferredValues;
    if (preferred && preferred.length) prop.preferredValues = preferred.map((v) => ({ type: v.type, key: v.key }));
    return prop;
  });
}

function tokenIds(value, kind, out) {
  if (typeof value === 'string' && value.indexOf(kind + ':') === 0) out.add(value.slice(kind.length + 1));
  else if (Array.isArray(value)) value.forEach((v) => tokenIds(v, kind, out));
  else if (value && typeof value === 'object') Object.keys(value).forEach((key) => tokenIds(value[key], kind, out));
  return out;
}

// Replaces `var:<id>` and `style:<id>` with the resolved names; an id without a name stays as it is.
function renameTokens(value, names) {
  if (typeof value === 'string') {
    const at = value.indexOf(':');
    const kind = value.slice(0, at);
    const name = (kind === 'var' || kind === 'style') && names[kind][value.slice(at + 1)];
    return name ? kind + ':' + name : value;
  }
  if (Array.isArray(value)) return value.map((v) => renameTokens(v, names));
  if (value && typeof value === 'object') {
    const out = {};
    Object.keys(value).forEach((key) => { out[key] = renameTokens(value[key], names); });
    return out;
  }
  return value;
}

function fitResult(result, limit) {
  const omitted = [];
  READ_DROP_ORDER.forEach((key) => {
    if (READ_SHARED.utf8Length(JSON.stringify(result)) <= limit || !(key in result.component)) return;
    delete result.component[key];
    omitted.push(key);
  });
  if (omitted.length) result.omitted = omitted;
  return result;
}

async function safeName(lookup) {
  try { const found = await lookup(); return found ? found.name : ''; } catch (error) { return ''; }
}

// The name of the page that holds node; '' when none is reachable (a component from another file).
function pageNameOf(node) {
  let current = node;
  try { while (current && current.type !== 'PAGE') current = current.parent; } catch (error) { current = null; }
  return current ? current.name : '';
}

// The set (or standalone component) a nested instance comes from: its key, name, and page.
async function mainOf(layer) {
  let main = null;
  try { main = await layer.getMainComponentAsync(); } catch (error) { main = null; }
  if (!main) return { name: layer.name, key: '', page: '' };
  const owner = READ_SHARED.promoteVariant(main);
  return { name: owner.name, key: owner.key || '', page: pageNameOf(owner) };
}

async function readEntry(api, nodeId, conv) {
  const found = await api.getNodeByIdAsync(String(nodeId).replace('-', ':'));
  if (!found) throw new Error('node not found: ' + nodeId);
  const node = READ_SHARED.promoteVariant(found);
  if (node.type !== 'COMPONENT_SET' && node.type !== 'COMPONENT') throw new Error('not a component set: ' + nodeId + ' is ' + node.type);
  let page = node;
  while (page && page.type !== 'PAGE') page = page.parent;
  if (page && page.loadAsync) await page.loadAsync();
  const pages = api.root.children.map((p) => ({ id: p.id, name: p.name }));
  const variants = node.type === 'COMPONENT_SET' ? node.children.filter((c) => c.type === 'COMPONENT') : [node];
  const properties = readProperties(node);
  for (const prop of properties) {
    if (prop.type !== 'INSTANCE_SWAP' || !prop.defaultValue) continue;
    const swap = await api.getNodeByIdAsync(prop.defaultValue).catch(() => null);
    const owner = swap && swap.type === 'INSTANCE' ? await swap.getMainComponentAsync().catch(() => null) : swap;
    if (owner) prop.defaultName = READ_SHARED.promoteVariant(owner).name;
  }
  const slotSizes = {};
  const slotToggles = {};
  properties.filter((p) => p.type === 'INSTANCE_SWAP').forEach((p) => { slotSizes[p.rawName] = variants.map(() => null); });
  const nested = [];
  const tokenRecords = [];
  const variantDocs = [];
  for (let i = 0; i < variants.length; i += 1) {
    const variant = variants[i];
    tokenRecords.push(variantTokens(variant, conv, api.mixed));
    const doc = pickDescription(variant);
    const links = readLinks(variant);
    if (doc.text || links.length) variantDocs.push({ variant: i, text: doc.text, links });
    for (const { layer, wrapperToggle } of instanceLayers(variant, conv)) {
      const refs = layer.componentPropertyReferences || {};
      // The toggle bound on the instance itself wins over one bound on a wrapper frame.
      const toggle = refs.visible || wrapperToggle;
      if (refs.mainComponent && slotSizes[refs.mainComponent]) {
        slotSizes[refs.mainComponent][i] = slotSize(layer);
        if (toggle) slotToggles[refs.mainComponent] = toggle;
        continue;
      }
      const main = await mainOf(layer);
      let entry = nested.find((n) => n.layer === layer.name && n.key === main.key);
      if (!entry) {
        entry = { layer: layer.name, name: main.name, key: main.key, page: main.page,
          helper: main.page.indexOf(READ_HELPER_PAGE) === 0, visibleProperty: toggle || null,
          exposed: layer.isExposedInstance === true, exposedProperties: [], variants: 0 };
        if (entry.exposed) {
          const own = layer.componentProperties || {};
          entry.exposedProperties = Object.keys(own).map((name) => ({ name, type: own[name].type }));
        }
        nested.push(entry);
      }
      if (!entry.visibleProperty && toggle) entry.visibleProperty = toggle;
      entry.variants += 1;
    }
  }
  const slots = {};
  Object.keys(slotSizes).forEach((rawName) => {
    slots[rawName] = Object.assign({ visibleProperty: slotToggles[rawName] || null }, tableIndex(slotSizes[rawName]));
  });
  const tokens = tokenColumns(tokenRecords);
  const varNames = {};
  const styleNames = {};
  for (const id of tokenIds(tokens.values, 'var', new Set())) varNames[id] = await safeName(() => api.variables.getVariableByIdAsync(id));
  for (const id of tokenIds(tokens.values, 'style', new Set())) styleNames[id] = await safeName(() => api.getStyleByIdAsync(id));
  tokens.values = renameTokens(tokens.values, { var: varNames, style: styleNames });
  const description = pickDescription(node);
  return fitResult({ component: {
    id: node.id, key: node.key || '', name: node.name, type: node.type, page: page ? page.name : '',
    section: page ? sectionOf(pages, page.id) : null, description, documentationLinks: readLinks(node),
    properties, variants: variantMatrix(properties, variants), variantDocs, nested, slots, tokens,
  } }, READ_RESULT_LIMIT);
}

if (typeof module !== 'undefined') module.exports = { READ_RESULT_LIMIT, unescapeHtml, pickDescription, readLinks, variantValues, variantMatrix, tableIndex, paintToken, numberToken, textToken, firstText, variantTokens, tokenColumns, instanceLayers, slotSize, separatorLabel, sectionOf, pageNameOf, readProperties, tokenIds, renameTokens, fitResult, readEntry };
if (typeof module === 'undefined') return readEntry(figma, __NODE_ID__, CONVENTIONS);
