// Pure mapping from entry_read.js output to a contract draft: the deterministic rules of references/ (property
// classification, show* pairing, state split, size mapping, enum naming, token names, constructor order). Every value
// no rule covers becomes an ask, which the model puts to the user; the description prose is left to the model.
// No file, network, or Figma access: map_contract.js reads the repo and passes it in as `ctx`.
const path = require('path');

const LINT_SCRIPTS = path.join(__dirname, '..', '..', 'stratum-figma-lint', 'scripts');
const { CONVENTIONS } = require(path.join(LINT_SCRIPTS, 'conventions.js'));
const { normalizeName, describeProperty, stripPropertySuffix } = require(path.join(LINT_SCRIPTS, 'extract_lib.js'));
const { resolveRole } = require(path.join(LINT_SCRIPTS, 'lint_lib.js'));

const vocabulary = (key) => CONVENTIONS.vocabularies[key].values.map((row) => row.value);
const WIDGET_SIZES = vocabulary('size');
const FONT_SIZES = vocabulary('fontSize');
const WINDOW_SIZES = vocabulary('windowSize');
const COLORS = vocabulary('color');
const FEEDBACK = vocabulary('feedback');
const PART_SUFFIXES = CONVENTIONS.vocabularies.state.partSuffixes;
const INTERACTION = ['HOVERED', 'PRESSED', 'FOCUSED', 'DRAGGED'];
// Mirrors lib/src/themes/constant/font_type.dart; map_contract.js passes the live enum through ctx.libEnums.
const FONT_TYPES = ['header', 'paragraph', 'number', 'numberMono', 'code', 'body', 'table'];
const FONT_WEIGHTS = { thin: 'w100', extralight: 'w200', light: 'w300', regular: 'w400', medium: 'w500',
  semibold: 'w600', bold: 'w700', extrabold: 'w800', black: 'w900' };

// references/state_mapping.md, row for row: Figma value, the field it sets, the value it sets.
const STATE_ROWS = [
  ['NORMAL', 'state', 'FullWidgetState.normal'], ['HOVERED', 'state', 'FullWidgetState.hovered'],
  ['PRESSED', 'state', 'FullWidgetState.pressed'], ['FOCUSED', 'state', 'FullWidgetState.focused'],
  ['DRAGGED', 'state', 'FullWidgetState.dragged'], ['SELECTED', 'selected', 'true'], ['DISABLED', 'disabled', 'true'],
  ['LOADING', 'loading', 'true'], ['PROGRESS', 'loading', 'true'],
  ['🔵 INFO', 'feedbackState', 'FeedbackState.info'], ['🔴 NEGATIVE', 'feedbackState', 'FeedbackState.negative'],
  ['🟡 WARNING', 'feedbackState', 'FeedbackState.warning'], ['🟢 POSITIVE', 'feedbackState', 'FeedbackState.positive'],
];

// Fields a rule adds beyond the property's own. group and order give the constructor order of the approved Button
// example: 1 required, 2 enums (style first), 3 size and color, 4 content, 5 flags, 6 theme and window,
// 7 state family, 8 callbacks, 9 customStyle.
const FIELDS = {
  size: { base: true, type: 'WidgetSize?', shown: '`null` (theme default)', group: 3, order: 0 },
  color: { base: true, type: 'ColorEnum?', shown: '`null`', group: 3, order: 1 },
  themeMode: { base: true, type: 'ThemeMode?', shown: '`null` (app theme mode)', group: 6, order: 0 },
  windowSize: { base: true, type: 'WindowSize?', shown: '`null` (nearest WindowSizeScope)', group: 6, order: 1 },
  state: { base: true, type: 'FullWidgetState', shown: '`FullWidgetState.normal`', group: 7, order: 0 },
  // The component's own field: the base props have no `selected` (2026-10-01).
  selected: { type: 'bool', init: 'false', group: 7, order: 1 },
  feedbackState: { base: true, type: 'FeedbackState?', shown: '`null`', group: 7, order: 2 },
  disabled: { base: true, type: 'bool', shown: '`false`', group: 7, order: 3 },
  loading: { base: true, type: 'bool', shown: '`false`', group: 7, order: 4 },
  progress: { type: 'double?', group: 7, order: 5 },
  onPressed: { type: 'VoidCallback?', group: 8, order: 0 },
  onChanged: { type: 'ValueChanged<String>?', group: 8, order: 1 },
  customStyle: { base: true, type: 'WidgetStyle?', shown: '`null`', group: 9, order: 0 },
};

// Meanings the 2026-10-01 decisions give; the ask still goes to the user.
const VALUE_HINTS = {
  EXTRA_TINY: 'design-only per 2026-10-01, resolved when the widget is built',
  FILL_WIDTH: 'means full available width per 2026-10-01',
  BLACK: 'design-only per 2026-10-01, resolved when the widget is built',
  GHOST: 'design-only per 2026-10-01, resolved when the widget is built',
  CUSTOM: 'the caller passes the color per 2026-10-01',
};
const THEME_VALUES = { DARK: 'ThemeMode.dark', LIGHT: 'ThemeMode.light', AUTO: 'ThemeMode.system',
  True: 'ThemeMode.dark', False: 'ThemeMode.light' };
// Owner rulings of 2026-10-01: value-like 🔢 counts become numbers, 🔢 frame and the derived flags become no field.
const VALUE_COUNTS = ['rating', 'percent'];
const NO_FIELD = {
  frame: 'no field: animation frames',
  filled: 'no field: the widget derives it from its value',
  expanded: 'no field: the widget derives it from its open state',
};
const CONTRACTS_DIR = 'docs/specs/stratum_ui/components';
const TOKEN_COLUMNS = ['background', 'foreground', 'border', 'radius', 'padding', 'gap', 'text'];
const TOKEN_LABELS = ['Background', 'Foreground', 'Border', 'Radius', 'Padding (T R B L)', 'Gap', 'Text'];
const PADDING_SIDES = ['paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft'];

const code = (text) => '`' + text + '`';
const lowerFirst = (text) => text.charAt(0).toLowerCase() + text.slice(1);
const unique = (list) => list.filter((v, i) => list.indexOf(v) === i);

function pascal(text) {
  const name = normalizeName(text);
  return name.charAt(0).toUpperCase() + name.slice(1);
}

function snakeName(text) {
  return normalizeName(text).replace(/([a-z0-9])([A-Z])/g, '$1_$2').toLowerCase();
}

// UPPER_SNAKE (emoji and arrows dropped) to a Dart enum value; null when nothing usable is left.
function enumValueName(value) {
  let text = String(value);
  CONVENTIONS.directionArrows.forEach((row) => { text = text.split(row.arrow).join(' ' + row.word + ' '); });
  const name = normalizeName(text);
  if (!name || /^[0-9]/.test(name) || CONVENTIONS.dartReserved.indexOf(name) >= 0) return null;
  return name;
}

function isBoolLike(d) {
  return d.type === 'BOOLEAN' || (d.type === 'VARIANT' && d.options.length === 2 &&
    d.options.indexOf('False') >= 0 && d.options.indexOf('True') >= 0);
}

function describe(prop, index) {
  const d = describeProperty(prop.rawName, { type: prop.type, defaultValue: prop.defaultValue,
    variantOptions: prop.variantOptions, defaultName: prop.defaultName });
  return Object.assign(d, { index, role: resolveRole(d, CONVENTIONS) });
}

function ask(m, text) {
  if (m.asks.indexOf(text) < 0) m.asks.push(text);
}

function askValue(m, d, value, why) {
  ask(m, code(d.base) + ' value ' + code(value) + ': no mapping rule covers it' + (why ? ' (' + why + ')' : '') + '. How should it map?');
}

function fieldRow(field, figma, index, extra) {
  const def = FIELDS[field];
  return Object.assign({ field, figma: [].concat(figma), base: Boolean(def.base), required: false, type: def.type,
    init: def.init, shown: def.shown, group: def.group, order: def.order, index }, extra);
}

function ownRow(field, type, figma, index, group, extra) {
  return Object.assign({ field, figma: [].concat(figma), base: false, required: false, type, init: undefined,
    group, order: 0, index }, extra);
}

function addRow(m, row) {
  const same = m.rows.find((r) => r.field === row.field);
  if (!same) { m.rows.push(row); return; }
  if (same.type !== row.type) {
    ask(m, 'Field ' + code(row.field) + ' comes from ' + same.figma.join(' + ') + ' as ' + code(same.type) + ' and from ' +
      row.figma.join(' + ') + ' as ' + code(row.type) + ': which wins, or what is the second field named?');
    return;
  }
  row.figma.forEach((f) => { if (same.figma.indexOf(f) < 0) same.figma.push(f); });
}

function stateEntry(m, value) {
  const row = STATE_ROWS.find((r) => r[0] === value);
  if (row && !m.states.some((s) => s.value === value)) m.states.push({ value, field: row[1], dart: row[2] });
  return row;
}

// Numbered toggles (`👁️ show<Item><N>` with a sibling, or legacy `<N>. <Item>`) become one List<Widget>.
function mapListToggles(m, props, used) {
  const series = {};
  props.forEach((d) => {
    if (d.type !== 'BOOLEAN') return;
    const canonical = d.name.match(/^show([A-Z][A-Za-z]*?)([0-9]+)$/);
    const legacy = d.label.trim().match(/^([0-9]+)\.\s*([A-Za-z][A-Za-z ]*)$/);
    const item = canonical ? canonical[1] : legacy ? pascal(legacy[2]) : null;
    if (item) (series[item] = series[item] || { legacy: false, members: [] }).members.push(d);
    if (legacy) series[item].legacy = true;
  });
  Object.keys(series).forEach((item) => {
    const s = series[item];
    if (s.members.length < 2 && !s.legacy) return;
    s.members.forEach((d) => used.add(d.index));
    const plural = /(s|x|ch|sh)$/.test(item) ? item + 'es' : item + 's';
    addRow(m, ownRow(lowerFirst(plural), 'List<Widget>', s.members.map((d) => code(d.base)), s.members[0].index, 4,
      { init: 'const []' }));
  });
}

// show<X> pairs with a TEXT, INSTANCE_SWAP, or SLOT property <x>; else with the nested instance whose visibility it
// binds, on the instance or a wrapper frame (the worked example: showBadge + nested Badge -> badge). A ☀ helper never
// takes a toggle. Unpaired toggles stay bool show<X>; one that names a nested instance with no binding is asked.
function pairShowToggles(m, props, used) {
  const pairs = new Map();
  const nestedPairs = new Map();
  const nested = (m.component.nested || []).filter((n) => n.helper !== true);
  props.forEach((d) => {
    if (used.has(d.index) || !isBoolLike(d) || !/^show[A-Z0-9]/.test(d.name)) return;
    const target = lowerFirst(d.name.slice(4));
    const partner = props.find((p) => ['TEXT', 'INSTANCE_SWAP', 'SLOT'].indexOf(p.type) >= 0 && p.name === target && !pairs.has(p.index));
    if (partner) { pairs.set(partner.index, d); used.add(d.index); return; }
    const bound = nested.find((n) => n.visibleProperty === d.rawName && !nestedPairs.has(n));
    if (bound) { nestedPairs.set(bound, d); used.add(d.index); return; }
    const named = nested.find((n) => !n.visibleProperty && [normalizeName(n.layer), normalizeName(n.name)].indexOf(target) >= 0);
    if (named) {
      ask(m, code(d.base) + ' binds the visibility of no layer in the capture, and nested ' + code(named.name) +
        ' has no toggle: does it hide ' + code(named.name) + '? Yes merges it into the slot; rerun step 3 when the capture predates wrapper toggles.');
    }
  });
  return { pairs, nestedPairs };
}

function splitState(m, d) {
  const sources = {};
  d.options.forEach((value) => {
    const part = PART_SUFFIXES.find((suffix) => value.slice(-suffix.length) === suffix);
    const row = stateEntry(m, value);
    if (!row) {
      askValue(m, d, value, part ? 'per 2026-10-01 a ' + part + ' suffix is the state of that half of a split control' : '');
      if (part && INTERACTION.indexOf(value.slice(0, -part.length)) >= 0) m.interactive = true;
      return;
    }
    (sources[row[1]] = sources[row[1]] || []).push(value);
    if (value === 'PROGRESS') (sources.progress = sources.progress || []).push(value);
    if (INTERACTION.indexOf(value) >= 0) m.interactive = true;
    if (value === 'HOVERED' || value === 'PRESSED') m.pressable = true;
  });
  Object.keys(sources).forEach((field) => addRow(m, fieldRow(field, code(d.base) + ' (' + sources[field].join(', ') + ')', d.index)));
}

// A `size` property with font-size or pixel values cannot reuse the base WidgetSize field.
function sizeFieldName(m, d, provisional) {
  if (d.name !== 'size') return d.name;
  ask(m, code(d.base) + ' holds ' + d.options.join(', ') + ', which the base `size` (WidgetSize) cannot take: name the field (provisional ' + code(provisional) + ').');
  return provisional;
}

function mapSize(m, d) {
  const isFree = (v) => v === CONVENTIONS.freeSize;
  const isNumber = (v) => /^[0-9]+(\.[0-9]+)?$/.test(v);
  if (d.options.some(isFree) && d.options.every((v) => isFree(v) || isNumber(v))) {
    const init = isFree(d.defaultValue) ? undefined : String(Number(d.defaultValue));
    addRow(m, ownRow(sizeFieldName(m, d, 'customSize'), 'double?', code(d.base) + ' (Free = null)', d.index, 5, { init }));
    return;
  }
  if (d.options.every((v) => FONT_SIZES.indexOf(v) >= 0)) {
    addRow(m, ownRow(sizeFieldName(m, d, 'fontSize'), 'FontSize', code(d.base), d.index, 5, { init: 'FontSize.s' + d.defaultValue }));
    return;
  }
  const known = d.options.filter((v) => WIDGET_SIZES.indexOf(v) >= 0);
  d.options.filter((v) => WIDGET_SIZES.indexOf(v) < 0).forEach((v) => askValue(m, d, v, VALUE_HINTS[v]));
  if (!known.length) return;
  const figma = code(d.base) + ' (' + known.join(', ') + ')';
  if (d.name === 'size') { addRow(m, fieldRow('size', figma, d.index)); return; }
  const init = known.indexOf(d.defaultValue) >= 0 ? 'WidgetSize.' + normalizeName(d.defaultValue) : undefined;
  addRow(m, ownRow(d.name, 'WidgetSize', figma, d.index, 5, { init }));
}

// LOADING and feedback values map to loading and feedbackState in any variant (2026-10-01).
function moveStateValues(m, d, values) {
  const sources = {};
  values.forEach((value) => {
    const row = stateEntry(m, value);
    (sources[row[1]] = sources[row[1]] || []).push(value);
  });
  Object.keys(sources).forEach((field) => addRow(m, fieldRow(field, code(d.base) + ' (' + sources[field].join(', ') + ')', d.index)));
}

function mapColor(m, d) {
  const colors = d.options.filter((v) => COLORS.indexOf(v) >= 0);
  const moved = d.options.filter((v) => v === 'LOADING' || FEEDBACK.indexOf(v) >= 0);
  d.options.filter((v) => colors.indexOf(v) < 0 && moved.indexOf(v) < 0).forEach((v) => askValue(m, d, v, VALUE_HINTS[v]));
  if (colors.length) addRow(m, fieldRow('color', code(d.base) + ' (' + colors.join(', ') + ')', d.index));
  moveStateValues(m, d, moved);
}

function mapTheme(m, d) {
  const known = d.options.filter((v) => THEME_VALUES[v]);
  d.options.filter((v) => !THEME_VALUES[v]).forEach((v) => askValue(m, d, v));
  if (known.length) addRow(m, fieldRow('themeMode', code(d.base) + ' (' + known.map((v) => v + ' → ' + THEME_VALUES[v].split('.')[1]).join(', ') + ')', d.index));
}

function mapPlatform(m, d) {
  const windows = d.options.filter((v) => WINDOW_SIZES.indexOf(v) >= 0);
  if (d.name === 'platform' && windows.length === d.options.length) {
    addRow(m, fieldRow('windowSize', code(d.base) + ' (' + windows.join(', ') + ')', d.index));
  } else if (d.name !== 'platform' || !windows.length) {
    m.skipped.push({ figma: code(d.base), type: 'no field: the widget checks the platform at runtime' });
  } else {
    ask(m, code(d.base) + ' mixes window sizes (' + windows.join(', ') + ') with other values: which field carries them?');
  }
}

// An enum with exactly the same value set: in lib/ reuse it; in another contract reuse a shared enum, and ask for a
// shared name when the other enum is that component's own (the first repeat).
function findEnumReuse(m, values) {
  const same = (list) => list.length === values.length && values.every((v) => list.indexOf(v) >= 0);
  const lib = (m.ctx.libEnums || []).find((e) => same(e.values));
  if (lib) return { name: lib.name, source: lib.file || 'lib/' };
  for (const contract of m.ctx.contracts || []) {
    if (contract.componentKey && contract.componentKey === m.component.key) continue;
    const hit = (contract.enums || []).find((e) => same(e.values));
    if (hit) return { name: hit.name, source: contract.file, first: hit.name.indexOf(contract.class) === 0 };
  }
  return null;
}

function mapEnum(m, d) {
  const moved = d.options.filter((v) => v === 'LOADING' || FEEDBACK.indexOf(v) >= 0);
  const rest = d.options.filter((v) => moved.indexOf(v) < 0);
  moveStateValues(m, d, moved);
  if (moved.length && rest.length) {
    ask(m, code(d.base) + ' mixes ' + moved.join(', ') + ' with other values; they map to `loading` or `feedbackState` (2026-10-01). Keep them in a component enum as well (Spinner, ModalContent)?');
  }
  if (!rest.length) return;
  const values = rest.map((v) => ({ figma: v, dart: enumValueName(v) }));
  values.filter((v) => !v.dart).forEach((v) => askValue(m, d, v.figma, 'symbol-only, starts with a digit, or a Dart reserved word'));
  const dartValues = values.filter((v) => v.dart).map((v) => v.dart);
  if (unique(dartValues).length < dartValues.length) ask(m, code(d.base) + ' has values that map to the same Dart name: rename them in Figma or name them here.');
  let name = m.cls + pascal(d.name);
  let status = 'new';
  const reuse = findEnumReuse(m, dartValues);
  if (reuse && !reuse.first) { name = reuse.name; status = 'reused from ' + reuse.source; }
  if (reuse && reuse.first) {
    status = 'new; same values as ' + code(reuse.name) + ' in ' + reuse.source;
    ask(m, code(d.base) + ' has the same values as ' + code(reuse.name) + ' (' + reuse.source + '): name the shared enum (for example `StratumFieldStyle`).');
  }
  m.enums.push({ name, status, values });
  const def = values.find((v) => v.figma === d.defaultValue);
  if (!def || !def.dart) ask(m, 'Default of ' + code(d.base) + ' (' + d.defaultValue + ') is no enum value: which value is the default?');
  addRow(m, ownRow(d.name, name, code(d.base), d.index, 2, { init: def && def.dart ? name + '.' + def.dart : undefined, order: d.name === 'style' ? -1 : 0 }));
}

// 🔢 item counts are List<Widget> children; value-like ones (rating, percent) are int when every option is a whole
// number, else double; 🔢 frame is no field.
function mapCount(m, d) {
  if (NO_FIELD[d.name]) { m.skipped.push({ figma: code(d.base), type: NO_FIELD[d.name] }); return; }
  if (VALUE_COUNTS.indexOf(d.name) < 0) { addRow(m, ownRow(d.name, 'List<Widget>', code(d.base), d.index, 4, { init: 'const []' })); return; }
  const numeric = (v) => /^[0-9]+(\.[0-9]+)?$/.test(v);
  d.options.filter((v) => !numeric(v)).forEach((v) => askValue(m, d, v, 'a value-like count takes numbers only'));
  const type = d.options.filter(numeric).every((v) => /^[0-9]+$/.test(v)) ? 'int' : 'double';
  addRow(m, ownRow(d.name, type, code(d.base), d.index, 5, { init: numeric(d.defaultValue) ? String(Number(d.defaultValue)) : undefined }));
}

function mapVariant(m, d) {
  const key = d.role ? d.role.key : 'variant';
  if (/^example/i.test(d.name)) m.skipped.push({ figma: code(d.base), type: 'skipped (demo data)' });
  else if (d.name === 'state') splitState(m, d);
  else if (key === 'size') mapSize(m, d);
  else if (d.name === 'color') mapColor(m, d);
  else if (key === 'theme') mapTheme(m, d);
  else if (key === 'platform') mapPlatform(m, d);
  else if (key === 'count' || d.emoji === '🔢') mapCount(m, d);
  else mapEnum(m, d);
}

function mapProperty(m, d, pairs) {
  const role = d.role ? d.role.key : '';
  if ((role === 'filled' || role === 'expanded') && NO_FIELD[role]) { m.skipped.push({ figma: code(d.base), type: NO_FIELD[role] }); return; }
  const show = pairs.get(d.index);
  const figma = [code(d.base)].concat(show ? [code(show.base)] : []);
  if (d.type === 'TEXT') {
    addRow(m, show ? ownRow(d.name, 'String?', figma, d.index, 4) : ownRow(d.name, 'String', figma, d.index, 1, { required: true, shown: 'required' }));
  } else if (d.type === 'INSTANCE_SWAP' || d.type === 'SLOT') {
    addRow(m, ownRow(d.name, 'Widget?', figma, d.index, 4));
    m.slots.push({ field: d.name, rawName: d.rawName, kind: d.type === 'SLOT' || (d.role && d.role.key === 'slot') ? 'slot' : 'icon' });
  } else if (isBoolLike(d) && !(d.role && d.role.key === 'theme')) {
    if (d.name === 'loading' || d.name === 'disabled' || d.name === 'selected') addRow(m, fieldRow(d.name, figma, d.index));
    else addRow(m, ownRow(d.name, 'bool', figma, d.index, 5, { init: String(d.type === 'BOOLEAN' ? d.defaultValue === true : d.defaultValue === 'True') }));
  } else if (d.type === 'VARIANT') {
    mapVariant(m, d);
  }
}

// A size word at a word start of a PascalCase name: Huge, Large, Medium, Small, Tiny, and their Extra forms.
const SIZE_WORD = /(?:^|(?<=[a-z0-9]))(?:Extra)?(?:Huge|Large|Medium|Small|Tiny)(?![a-z])/;

// Non-helper instances whose names differ only by a size word (LargeTextInputLeftItem, MediumTextInputLeftItem) are one
// slot, named without the size word and the parent component name (leftItem); the widget picks the size from its own
// `size` (2026-10-01). A name whose size word has no sibling with another size word stays as it is.
function sizeGroups(m, nested) {
  const byStem = {};
  nested.forEach((n) => {
    const name = pascal(n.name);
    const word = n.helper !== true && name.match(SIZE_WORD);
    if (!word) return;
    const stem = name.replace(SIZE_WORD, '');
    (byStem[stem] = byStem[stem] || []).push({ n, word: word[0] });
  });
  const parent = new RegExp('(?:^|(?<=[a-z0-9]))' + pascal(m.component.name) + '(?![a-z])');
  const groups = new Map();
  Object.keys(byStem).forEach((stem) => {
    if (!stem || unique(byStem[stem].map((e) => e.word)).length < 2) return;
    const group = { field: lowerFirst(stem.replace(parent, '') || stem), members: byStem[stem].map((e) => e.n) };
    group.members.forEach((n) => groups.set(n, group));
  });
  return groups;
}

// A nested instance with its own class is a typed slot only: the caller configures it, so its exposed properties are not
// flattened, and its show toggle merges into the slot. A ☀ helper, or an instance no property toggles or exposes,
// maps to no field: the widget draws it. A size group adds its slot once, at its first member.
function mapNested(m, nestedPairs) {
  const nested = m.component.nested || [];
  const unknown = unique(nested.filter((n) => typeof n.helper !== 'boolean').map((n) => code(n.name)));
  if (unknown.length) {
    ask(m, 'The capture records no main-component page for nested ' + unknown.join(', ') + ' (entry_read.js before ' +
      '2026-10-01), so a ☀ helper cannot be told apart: rerun step 3, or say which of them are helpers.');
  }
  const classOf = (n) => {
    const contract = (m.ctx.contracts || []).find((c) => c.componentKey && c.componentKey === n.key);
    return contract ? contract.class : null;
  };
  const groups = sizeGroups(m, nested);
  nested.forEach((n, i) => {
    const group = groups.get(n);
    const members = group ? group.members : [n];
    const show = members.map((x) => nestedPairs.get(x)).find(Boolean);
    const entry = { component: n.name, layer: n.layer, dartClass: classOf(n), helper: n.helper === true, field: null,
      exposed: n.exposedProperties.map((p) => normalizeName(p.name)) };
    m.nested.push(entry);
    if (entry.helper || (!show && !members.some((x) => x.exposed))) return;
    const field = show ? lowerFirst(show.name.slice(4)) : group ? group.field : normalizeName(n.layer);
    entry.field = field;
    if (members[0] !== n) return;
    const index = 1000 + i * 100;
    const sources = members.map((x) => 'nested ' + code(x.name));
    const unresolved = members.filter((x) => !classOf(x));
    const classes = unique(members.map(classOf));
    const many = unresolved.length > 1;
    if (unresolved.length) {
      ask(m, 'Nested ' + unresolved.map((x) => code(x.name)).join(', ') + (many ? ' have' : ' has') + ' no contract (componentKey ' +
        unresolved.map((x) => code(x.key)).join(', ') + '): read ' + (many ? 'them' : 'it') + ' first with stratum-read-figma? Until then ' +
        code(field) + ' is `Widget?`.');
    } else if (classes.length > 1) {
      ask(m, 'Nested ' + members.map((x) => code(x.name)).join(', ') + ' resolve to ' + classes.map(code).join(', ') +
        ': which class does ' + code(field) + ' take? Until then it is `Widget?`.');
    }
    const type = !unresolved.length && classes.length === 1 ? classes[0] : 'Widget';
    addRow(m, ownRow(field, type + '?', sources.concat(show ? [code(show.base)] : []), index, 4));
    if (/Button$/.test(n.name)) addRow(m, ownRow('on' + pascal(field) + 'Pressed', 'VoidCallback?', sources, index, 8, { order: 2 }));
  });
}

function sortedRows(m) {
  return m.rows.slice().sort((a, b) => a.group - b.group || a.order - b.order || a.index - b.index);
}

function buildContract(component, ctx) {
  const m = { component, ctx: ctx || {}, cls: 'Stratum' + pascal(component.name), rows: [], skipped: [], enums: [],
    states: [], slots: [], nested: [], asks: [], interactive: false, pressable: false };
  const props = (component.properties || []).map(describe);
  const used = new Set();
  mapListToggles(m, props, used);
  const { pairs, nestedPairs } = pairShowToggles(m, props, used);
  props.forEach((d) => { if (!used.has(d.index)) mapProperty(m, d, pairs); });
  mapNested(m, nestedPairs);
  // Captures before 2026-10-01 keep the separator's trailing decoration in the label (`Control ───`).
  const section = component.section ? String(component.section.label).replace(/[\s─-]+$/, '') : '';
  m.folder = section ? snakeName(section) : '';
  if (m.folder === 'form') {
    addRow(m, fieldRow('onChanged', '—', 9001));
    ask(m, 'Value type of `onChanged` for this input (provisional `ValueChanged<String>?`)?');
  } else if (m.pressable) {
    addRow(m, fieldRow('onPressed', '—', 9000));
  }
  addRow(m, fieldRow('customStyle', '—', 9002));
  m.base = m.interactive ? 'StratumStatefulWidget' : 'StratumStatelessWidget';
  const snake = snakeName(component.name);
  if (m.folder && (m.ctx.folders || []).indexOf(m.folder) >= 0) {
    m.path = 'lib/src/components/' + m.folder + '/' + snake + '/' + snake + '.dart';
    m.contractPath = CONTRACTS_DIR + '/' + m.folder + '/' + snake + '/' + snake + '.md';
  } else {
    m.path = null;
    m.contractPath = null;
    ask(m, (section ? 'Section ' + code(section) + ' matches no folder' : 'No section separator page sits above this page') + ' under `lib/src/components/`: which folder holds the widget?');
  }
  if (component.description && component.description.empty) ask(m, 'The set description is empty (Figma can read it empty): give one, or re-publish the library and read again?');
  m.slotRows = slotRows(m);
  m.tokenTables = tokenTables(m);
  return m;
}

// ---- Slots and visual tokens, grouped by the `size` axis.

function axisOptions(m, axis) {
  const prop = (m.component.properties || []).find((p) => p.rawName === axis);
  return prop && prop.variantOptions ? prop.variantOptions : [];
}

function sizeAxis(m) {
  return (m.component.variants.axes || []).findIndex((axis) => normalizeName(axis) === 'size');
}

function sizeLabel(value) {
  return value === null ? '—' : WIDGET_SIZES.indexOf(value) >= 0 ? code(normalizeName(value)) : code(value);
}

function slotRows(m) {
  const at = sizeAxis(m);
  const sizes = at >= 0 ? axisOptions(m, m.component.variants.axes[at]) : [null];
  const rows = [];
  m.slots.forEach((slot) => {
    const data = m.component.slots && m.component.slots[slot.rawName];
    if (!data) { ask(m, 'Slot sizes were omitted from the result (over the size limit): read them per slot or give them.'); return; }
    sizes.forEach((size, sizeIndex) => {
      const found = unique(data.byVariant.filter((idx, i) => idx >= 0 && (at < 0 || m.component.variants.combinations[i][at] === sizeIndex)));
      if (!found.length) return;
      const entries = found.map((idx) => data.table[idx]);
      const join = (key) => unique(entries.map((e) => e[key])).join(' / ');
      const sizing = unique(entries.map((e) => e.sizingH + ' × ' + e.sizingV)).join(' / ');
      let wrapper = 'SizedBox';
      if (slot.kind === 'slot') {
        const modes = unique(entries.flatMap((e) => [e.sizingH, e.sizingV]));
        if (modes.indexOf('FIXED') >= 0) ask(m, 'Slot ' + code(slot.field) + ' is FIXED in Figma; the rule covers HUG and FILL: how is it sized?');
        wrapper = modes.indexOf('FILL') >= 0 ? 'Expanded or SizedBox.expand (FILL)' : 'none (HUG)';
      }
      rows.push([code(slot.field), sizeLabel(size), join('width'), join('height'), sizing, wrapper]);
    });
    if (!data.byVariant.some((idx) => idx >= 0)) rows.push([code(slot.field), '—', '—', '—', 'not placed in any variant', '—']);
  });
  return rows;
}

function themeKey(m, name, section) {
  const segment = name.split('/').pop();
  const keys = (m.ctx.themeKeys && m.ctx.themeKeys[section]) || [];
  if (keys.indexOf(segment) >= 0) return code(section + '.' + segment);
  ask(m, 'Variable ' + code(name) + ' matches no `' + section + '` key in the theme YAML: which key is it?');
  return code(name);
}

function fontTypes(m) {
  const live = (m.ctx.libEnums || []).find((e) => e.name === 'FontType');
  return live ? live.values : FONT_TYPES;
}

// `<type>[-<scale>]/<size>-<weight>`: `body-large/16-semi-bold` -> FontType.body, FontSize.s16, FontWeight.w600. The
// longest leading run of `-` parts that names a FontType value is the type (`number-mono` -> numberMono); the rest is
// the scale, which repeats the size and is ignored. null when a part matches nothing.
function parseTextStyle(name, types) {
  const match = String(name).match(/^([A-Za-z0-9]+(?:-[A-Za-z0-9]+)*)\/([0-9]+)-([A-Za-z-]+)$/);
  if (!match) return null;
  const parts = match[1].split('-');
  let type = null;
  for (let n = parts.length; n > 0 && !type; n -= 1) {
    const candidate = normalizeName(parts.slice(0, n).join(' '));
    type = (types || FONT_TYPES).find((t) => t === candidate) || null;
  }
  const weight = FONT_WEIGHTS[match[3].toLowerCase().replace(/-/g, '')];
  if (!type || FONT_SIZES.indexOf(match[2]) < 0 || !weight) return null;
  return 'FontType.' + type + ', FontSize.s' + match[2] + ', FontWeight.' + weight;
}

function renderToken(m, token, column) {
  if (token === null || token === undefined) return '—';
  if (token === 'mixed') return 'mixed';
  const at = token.indexOf(':');
  const kind = token.slice(0, at);
  const value = token.slice(at + 1);
  if (kind === 'hex' || kind === 'px' || kind === 'font' || kind === 'paint') return value + ' (hard-coded)';
  if (column === 'text') {
    const parsed = kind === 'style' ? parseTextStyle(value, fontTypes(m)) : null;
    if (!parsed) ask(m, 'Text style ' + code(value) + ' matches no FontType, FontSize, and weight: how does it map?');
    return parsed ? code(value) + ' → ' + parsed.split(', ').map(code).join(', ') : code(value);
  }
  if (column === 'radius' && kind === 'var') return themeKey(m, value, 'radius');
  if ((column === 'padding' || column === 'gap') && kind === 'var') return themeKey(m, value, 'space');
  return code(kind === 'var' ? value.split('/').join('.') : value);
}

function tokenTables(m) {
  const t = m.component.tokens;
  if (!t) { ask(m, 'Visual tokens were omitted from the result (over the size limit): read them per variant or give them.'); return null; }
  const { axes, combinations } = m.component.variants;
  const at = sizeAxis(m);
  const rowAxes = axes.map((axis, i) => i).filter((i) => i !== at);
  const raw = (i, column) => {
    const idx = t.columns.indexOf(column) < 0 ? -1 : t.rows[i][t.columns.indexOf(column)];
    return idx < 0 ? null : t.values[idx];
  };
  const cell = (i, column) => (column === 'padding' ? JSON.stringify(PADDING_SIDES.map((side) => raw(i, side))) : raw(i, column));
  const keyOf = (i) => rowAxes.map((a) => combinations[i][a]).join(',');
  const keys = unique(combinations.map((c, i) => keyOf(i))).sort((a, b) => {
    const x = a.split(',').map(Number);
    const y = b.split(',').map(Number);
    for (let k = 0; k < x.length; k += 1) if (x[k] !== y[k]) return x[k] - y[k];
    return 0;
  });
  const bySize = {};
  TOKEN_COLUMNS.forEach((column) => {
    if (at < 0) return;
    const perSize = {};
    let consistent = true;
    combinations.forEach((c, i) => {
      const value = cell(i, column);
      // A variant without that layer (no text while LOADING) neither breaks nor sets the size rule.
      if (value === null) return;
      const size = c[at];
      if (size in perSize && perSize[size] !== value) consistent = false;
      perSize[size] = value;
    });
    if (consistent && unique(Object.values(perSize)).length > 1) bySize[column] = perSize;
  });
  const show = (value, column) => {
    if (column !== 'padding') return renderToken(m, value, column);
    const sides = JSON.parse(value);
    return unique(sides).length === 1 ? renderToken(m, sides[0], column) : sides.map((side) => renderToken(m, side, column)).join(' ');
  };
  const header = rowAxes.map((a) => pascal(stripPropertySuffix(axes[a])));
  const rows = keys.map((key) => {
    const members = combinations.map((c, i) => i).filter((i) => keyOf(i) === key);
    const labels = key ? key.split(',').map((idx, k) => code(axisOptions(m, axes[rowAxes[k]])[Number(idx)])) : [];
    const bySizeCell = (column) => (members.every((i) => cell(i, column) === null) ? '—' : 'by size');
    return labels.concat(TOKEN_COLUMNS.map((column) => (bySize[column] ? bySizeCell(column) :
      unique(members.map((i) => cell(i, column))).map((value) => show(value, column)).join(', '))));
  });
  const sizeColumns = TOKEN_COLUMNS.filter((column) => bySize[column]);
  const sizeRows = !sizeColumns.length ? [] : axisOptions(m, axes[at]).map((value, s) =>
    [sizeLabel(value)].concat(sizeColumns.map((column) => (s in bySize[column] ? show(bySize[column][s], column) : '—'))));
  return { header: header.length ? header : ['Variant'], rows: header.length ? rows : rows.map((r) => ['all'].concat(r)), sizeColumns, sizeRows };
}

// ---- Markdown.

function table(header, rows) {
  return ['| ' + header.join(' | ') + ' |', '|' + header.map(() => '---').join('|') + '|']
    .concat(rows.map((row) => '| ' + row.join(' | ') + ' |'));
}

function constructorLines(m) {
  const param = (r) => (r.base ? 'super.' + r.field : r.required ? 'required this.' + r.field :
    'this.' + r.field + (r.init !== undefined ? ' = ' + r.init : ''));
  return ['const ' + m.cls + '({'].concat(sortedRows(m).map((r) => '  ' + param(r) + ','), ['});']);
}

function descriptionBlock(m) {
  const d = m.component.description || { text: '', source: 'none' };
  const notes = ['<!-- MODEL: replace this block with the class dartdoc per references/contract_template.md.',
    'Source: ' + d.source + '.'];
  (m.component.documentationLinks || []).forEach((uri) => notes.push('documentationLinks: ' + uri));
  (m.component.variantDocs || []).forEach((doc) => {
    const values = m.component.variants.axes.map((axis, k) => stripPropertySuffix(axis) + '=' +
      axisOptions(m, axis)[m.component.variants.combinations[doc.variant][k]]).join(', ');
    notes.push('variant ' + values + ': ' + doc.text.replace(/--/g, '- -') + (doc.links.length ? ' (links: ' + doc.links.join(', ') + ')' : ''));
  });
  return [notes.join('\n') + ' -->', ''].concat(d.text ? ['~~~markdown', d.text, '~~~'] : ['(empty)']);
}

function renderContract(m) {
  const c = m.component;
  const out = ['---', 'name: ' + c.name, 'figma:', '  fileKey: ' + JSON.stringify(m.ctx.fileKey || ''),
    '  nodeId: ' + JSON.stringify(c.id), '  componentKey: ' + JSON.stringify(c.key || ''), 'dart:', '  class: ' + m.cls,
    '  base: ' + m.base, '  path: ' + (m.path || 'null'), '---', '', '# ' + c.name, ''];
  out.push(...descriptionBlock(m), '', '## Properties', '');
  const rows = sortedRows(m).map((r) => [r.figma.join(' + '), code(r.field) + (r.base ? ' (base)' : ''), code(r.type),
    r.required ? 'required' : r.base ? r.shown : r.init !== undefined ? code(r.init) : '`null`']);
  m.skipped.forEach((s) => rows.push([s.figma, '—', s.type, '—']));
  out.push(...table(['Figma', 'Dart field', 'Type', 'Default'], rows), '', '```dart', ...constructorLines(m), '```', '', '## Enums', '');
  if (!m.enums.length) out.push('None.', '');
  m.enums.forEach((e) => out.push('### ' + code(e.name) + ' (' + e.status + ')', '',
    ...table(['Figma value', 'Dart value', 'Doc'], e.values.map((v) => [code(v.figma), v.dart ? code(v.dart) : '—', ''])), ''));
  out.push('## States', '');
  out.push(...(m.states.length ? table(['Figma value', 'Dart'], m.states.map((s) => [code(s.value), code(s.field + ': ' + s.dart) +
    (s.value === 'PROGRESS' ? ' plus `progress: double?`' : '')])) : ['None.']), '', '## Slots', '');
  out.push(...(m.slotRows.length ? table(['Slot', 'Size', 'Width', 'Height', 'Sizing (H × V)', 'Wrapper'], m.slotRows) : ['None.']), '');
  out.push('## Visual tokens', '');
  const t = m.tokenTables;
  if (!t) out.push('Omitted from the result; see Open questions.', '');
  else {
    out.push(...table(t.header.concat(TOKEN_LABELS), t.rows), '');
    if (t.sizeColumns.length) out.push(...table(['Size'].concat(t.sizeColumns.map((column) => TOKEN_LABELS[TOKEN_COLUMNS.indexOf(column)])), t.sizeRows), '');
  }
  out.push('## Nested', '');
  out.push(...(m.nested.length ? table(['Figma component', 'Layer', 'Dart class', 'Field', 'Exposed properties'], m.nested.map((n) =>
    [code(n.component), code(n.layer), n.helper ? '—' : n.dartClass ? code(n.dartClass) : 'unresolved',
      n.field ? code(n.field) : n.helper ? 'none (helper)' : 'none (internal)',
      n.exposed.length ? n.exposed.map(code).join(', ') : '—'])) : ['None.']), '');
  const v = c.variants;
  if (v.count < v.product) {
    out.push('## Variant combinations', '', v.count + ' of ' + v.product + ' combinations exist:', '');
    v.combinations.forEach((combo) => out.push('- ' + v.axes.map((axis, k) => stripPropertySuffix(axis) + '=' + axisOptions(m, axis)[combo[k]]).join(', ')));
    out.push('');
  }
  out.push('## Open questions', '');
  out.push(...(m.asks.length ? m.asks.map((text) => '- ASK: ' + text) : ['None.']));
  return out.join('\n') + '\n';
}

function mapContract(component, ctx) {
  const model = buildContract(component, ctx);
  return { markdown: renderContract(model), asks: model.asks, model };
}

// The gate: `lint: <n> blocking, <n> convention, <n> advisory, <n> info`, the last line of a stratum-figma-lint report.
function parseLintSummary(text) {
  const match = String(text).match(/lint: (\d+) blocking, (\d+) convention, (\d+) advisory, (\d+) info/);
  return match ? { blocking: Number(match[1]), convention: Number(match[2]), advisory: Number(match[3]), info: Number(match[4]) } : null;
}

function gateStops(text) {
  const counts = parseLintSummary(text);
  if (!counts) throw new Error('no lint summary line');
  return counts.blocking > 0;
}

module.exports = { STATE_ROWS, enumValueName, snakeName, parseTextStyle, buildContract, renderContract, mapContract,
  constructorLines, parseLintSummary, gateStops };
