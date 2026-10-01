// Pure lint: rules L01-L20 (L17 retired) over describeComponent() output. Returns findings shaped
// { rule, severity, page, component, property, value, message, suggestion }; `message` holds only the detail the
// rule message in CONVENTIONS.rules cannot say, '' otherwise. Reads rule ids and severities, never rule messages.

// Shared helpers: in scope inside the Figma bundle; required from extract_lib.js under node.
const LINT_SHARED = typeof utf8Length === 'function' ? { utf8Length, normalizeName } : require('./extract_lib.js');

function stripVs(text) {
  return String(text).replace(/[︎️]/g, '');
}

// No-break, thin, ideographic, and other non-ASCII spaces: they look like a space but change the name or value.
const WIDE_SPACE = /[\u00a0\u2000-\u200a\u202f\u205f\u3000]/;

function capitalize(word) {
  return word.charAt(0).toUpperCase() + word.slice(1);
}

function nameHasKey(name, key) {
  return name === key || (name.length > key.length && name.slice(-key.length) === capitalize(key));
}

function startsWithWord(name, prefix) {
  return name.length > prefix.length && name.indexOf(prefix) === 0 && /[A-Z0-9]/.test(name.charAt(prefix.length));
}

function isBooleanOptions(options, conv) {
  if (options.length !== 2) return false;
  const lower = options.map((o) => o.toLowerCase());
  const b = conv.booleanValues;
  return lower.some((o) => b.falsy.indexOf(o) >= 0) && lower.some((o) => b.truthy.indexOf(o) >= 0);
}

function swapMatches(role, name) {
  return !role.swapName || name.indexOf(role.swapName.contains) >= 0 || name.indexOf(role.swapName.prefix) === 0;
}

// Role = the emoji-template row that matches the property type plus its name; axis = the matched name key.
// An INSTANCE_SWAP also matches on its default component's name (`defaultName`, '' when unresolved).
function resolveRole(prop, conv) {
  for (const role of conv.emojiRoles) {
    if (role.types.indexOf(prop.type) < 0) continue;
    if (role.prefix && !startsWithWord(prop.name, role.prefix)) continue;
    if (role.booleanOptions && !isBooleanOptions(prop.options, conv)) continue;
    if (!swapMatches(role, prop.defaultName || '')) continue;
    const axis = role.names ? role.names.find((key) => nameHasKey(prop.name, key)) : role.key;
    if (axis) return { key: role.key, emoji: role.emoji, axis, rename: role.rename };
  }
  return null;
}

function editDistance(a, b) {
  const x = Array.from(a);
  const y = Array.from(b);
  let prev = y.map((_, j) => j + 1);
  prev.unshift(0);
  for (let i = 1; i <= x.length; i++) {
    const row = [i];
    for (let j = 1; j <= y.length; j++) {
      row.push(Math.min(prev[j] + 1, row[j - 1] + 1, prev[j - 1] + (x[i - 1] === y[j - 1] ? 0 : 1)));
    }
    prev = row;
  }
  return prev[y.length];
}

function wordCore(text) {
  return String(text).replace(/^[^A-Za-z0-9]+/, '');
}

function isUpperSnake(value) {
  return /^[A-Z0-9]+(_[A-Z0-9]+)*$/.test(value);
}

// camelCase name -> words: showMenuItem1 -> show, Menu, Item1; macOS -> mac, OS.
function nameWords(name) {
  return String(name).replace(/([a-z0-9])([A-Z])/g, '$1 $2').replace(/([A-Z])([A-Z][a-z])/g, '$1 $2').split(' ').filter(Boolean);
}

// Lowercase word without its numeric suffix (LOADING1 -> loading); '' for a digits-only word.
function wordStem(word) {
  return word.replace(/[0-9]+$/, '').toLowerCase();
}

function toUpperSnake(value) {
  const words = wordCore(value).replace(/([a-z0-9])([A-Z])/g, '$1 $2').replace(/[^A-Za-z0-9]+/g, ' ').trim();
  return words.split(' ').filter(Boolean).join('_').toUpperCase();
}

// Pairs that differ only by digits or a plural ending are distinct values, never typos.
function isBenignPair(a, b) {
  const la = a.toLowerCase();
  const lb = b.toLowerCase();
  if (a.replace(/[0-9]+/g, '') === b.replace(/[0-9]+/g, '')) return true;
  return [la + 's', la + 'es'].indexOf(lb) >= 0 || [lb + 's', lb + 'es'].indexOf(la) >= 0;
}

// The enum mirror plus the design-only values, each also with a split control's part suffix (HOVERED_LEFT).
function vocabularyValues(vocab) {
  const values = vocab.values.map((row) => row.value).concat(vocab.designOnly || []);
  return values.concat.apply(values, (vocab.partSuffixes || []).map((suffix) => values.map((v) => v + suffix)));
}

function feedbackValues(conv) {
  return vocabularyValues(conv.vocabularies.feedback);
}

function isFeedbackValue(value, conv) {
  const plain = stripVs(value);
  return feedbackValues(conv).some((v) => stripVs(v) === plain);
}

function hasFeedbackDot(value, conv) {
  const plain = stripVs(value);
  return feedbackValues(conv).some((v) => plain.indexOf(Array.from(stripVs(v))[0]) === 0);
}

// Feedback word (canonical or legacy, without dot) -> canonical feedback value; the design-only ⚫️ NORMAL is no row.
function feedbackCanonical(value, conv) {
  const vocab = conv.vocabularies.feedback;
  const word = wordCore(value).toUpperCase();
  const row = vocab.values.find((r) => wordCore(r.value) === word || (r.legacy || []).indexOf(word) >= 0);
  return row ? row.value : null;
}

// Vocabulary row a legacy value maps to, compared in UPPER_SNAKE so case does not matter (Hover -> HOVERED).
function legacyRow(vocab, value) {
  const snake = toUpperSnake(value);
  return vocab.values.find((row) => (row.legacy || []).indexOf(snake) >= 0);
}

// A legacy value is an old convention, not a typo: L10 (or L09 for feedback) reports it with its suggestion.
function isLegacyValue(value, conv) {
  return Object.keys(conv.vocabularies).some((key) => Boolean(legacyRow(conv.vocabularies[key], value)));
}

// Canonical value a legacy value maps to, within the vocabularies of one role axis.
function legacyTarget(value, axis, conv) {
  const key = roleVocabularyKeys(axis, conv).find((k) => legacyRow(conv.vocabularies[k], value));
  return key ? legacyRow(conv.vocabularies[key], value).value : null;
}

function directionRow(value, conv) {
  const plain = stripVs(value);
  return conv.directionArrows.find((row) => plain.indexOf(row.arrow) === 0);
}

function isDirectionValue(value, conv) {
  const row = directionRow(value, conv);
  const plain = stripVs(value);
  return Boolean(row) && plain.indexOf(row.arrow + ' ') === 0 && isUpperSnake(plain.slice(row.arrow.length + 1));
}

function isCanonicalBoolean(value, conv) {
  return conv.booleanValues.canonical.indexOf(value) >= 0;
}

function isAmbiguous(value, prop, conv) {
  return value === conv.ambiguousValue || (value === conv.ambiguousPartner && prop.options.indexOf(conv.ambiguousValue) >= 0);
}

function roleVocabularyKeys(axis, conv) {
  return Object.keys(conv.vocabularies).filter((key) => conv.vocabularies[key].roles.indexOf(axis) >= 0);
}

function roleVocabulary(axis, conv) {
  let values = [];
  roleVocabularyKeys(axis, conv).forEach((key) => { values = values.concat(vocabularyValues(conv.vocabularies[key])); });
  return values;
}

function allowedByVocabulary(value, prop, conv) {
  return roleVocabulary(prop.role.axis, conv).some((v) => stripVs(v) === stripVs(value));
}

function isFreeSize(value, prop, conv) {
  return prop.role.axis === 'size' && (/^[0-9]+$/.test(value) || value === conv.freeSize);
}

function makeFinding(ctx, rule, comp, property, value, message, suggestion, severity) {
  return {
    rule,
    severity: severity || ctx.severity[rule],
    page: comp.page,
    component: comp.name,
    property,
    value: value === undefined || value === null ? '' : String(value),
    message,
    suggestion: suggestion || '',
  };
}

function variantProps(comp) {
  return comp.properties.filter((p) => p.type === 'VARIANT' && p.role);
}

function expectedName(prop) {
  const role = prop.role || {};
  return (role.emoji || '') + ' ' + (role.rename ? role.rename + capitalize(prop.name) : prop.name);
}

// Variants whose values are words, not pictures: L09 and L15 skip picture roles.
function wordVariants(comp, conv) {
  return variantProps(comp).filter((p) => conv.pictureRoles.indexOf(p.role.key) < 0);
}

function knownList(groups) {
  return groups.join('|').split('|').filter(Boolean);
}

// Known spellings. values/names: file-wide typo references (knownWords, canonical and legacy names).
// valueSet/nameSet: never typos; they add vocabulary and boolean values, which are typo references only
// inside their own role. Legacy values are never known: they are reported and mapped to their canonical value.
// parts: the word stems of every known name and value, for compounds such as LEFT_RIGHT. A vocabulary no role uses
// (fontSize, digits only) mirrors its enum for the drift test only, so it adds nothing here and the sandbox omits it.
function knownSpellings(conv) {
  const values = knownList(conv.knownWords.values);
  let valid = values.concat(conv.booleanValues.canonical, conv.freeSize);
  Object.values(conv.vocabularies).filter((v) => v.roles.length).forEach((v) => { valid = valid.concat(vocabularyValues(v)); });
  let names = knownList(conv.knownWords.names);
  conv.canonicalNames.forEach((row) => { names = names.concat(row.name, row.legacy); });
  const parts = new Set();
  const addStems = (words) => words.map(wordStem).forEach((stem) => { if (stem.length > 1) parts.add(stem); });
  names.forEach((name) => addStems(nameWords(name)));
  valid.forEach((value) => addStems(wordCore(value).split('_')));
  return { names, values, parts, nameSet: new Set(names), valueSet: new Set(valid) };
}

// Deliberate spellings, never typos: a compound whose words are all known (LEFT_RIGHT, showLeftItems), or a known
// word with a numeric suffix (LOADING_1, slot2), which marks an animation frame or a numbered item.
function isKnownCompound(words, ctx) {
  const stems = words.map(wordStem).filter(Boolean);
  const numbered = /[0-9]$/.test(words[words.length - 1] || '');
  if (!stems.length || (words.length < 2 && !numbered)) return false;
  return stems.every((stem) => ctx.known.parts.has(stem));
}

// Frequency tables over the lint batch: value counts per property name, name counts per type and overall (list
// toggles excluded: L20 owns them), plus the option lists and name lists that tell two co-occurring spellings apart.
// nameRefs: the L01 name references in tie-break order, canonical names first, then by use count in the batch.
function buildLintContext(components, conv) {
  const ctx = { conv, known: knownSpellings(conv), severity: {}, values: {}, namesByType: {}, names: {}, optionSets: {}, nameSets: [] };
  conv.rules.forEach((row) => { ctx.severity[row.id] = row.severity; });
  const bump = (table, key) => { table[key] = (table[key] || 0) + 1; };
  components.forEach((comp) => {
    const seen = {};
    let listMembers = [];
    (comp.listToggles || []).forEach((s) => { listMembers = listMembers.concat(s.members.map((m) => m.prop)); });
    ctx.nameSets.push(comp.properties.map((p) => p.name));
    comp.properties.forEach((p) => {
      if (p.options.length) (ctx.optionSets[p.name] = ctx.optionSets[p.name] || []).push(p.options);
      if (!p.name || listMembers.indexOf(p) >= 0) return;
      if (!seen['n' + p.type + p.name]) { bump(ctx.namesByType[p.type] = ctx.namesByType[p.type] || {}, p.name); bump(ctx.names, p.name); seen['n' + p.type + p.name] = 1; }
      ctx.values[p.name] = ctx.values[p.name] || {};
      p.options.forEach((v) => {
        if (!seen['v' + p.name + '|' + v]) { bump(ctx.values[p.name], v); seen['v' + p.name + '|' + v] = 1; }
      });
    });
  });
  const canonical = conv.canonicalNames.map((row) => row.name);
  const rank = (name) => (canonical.indexOf(name) >= 0 ? -1e9 : 0) - (ctx.names[name] || 0);
  ctx.nameRefs = ctx.known.names.slice().sort((a, b) => rank(a) - rank(b));
  return ctx;
}

function frequentNeighbours(table, word) {
  const own = table[word] || 0;
  return Object.keys(table).filter((key) => key !== word && table[key] >= 2 && table[key] > own);
}

// Nearest ref within the length-scaled edit distance; skipRef drops refs that are distinct values.
function nearestTypo(word, refs, minLength, conv, skipRef) {
  const core = wordCore(word);
  if (core.length < minLength) return null;
  const max = core.length <= conv.typo.shortLength ? conv.typo.shortDistance : conv.typo.maxDistance;
  const length = Array.from(word).length;
  let best = null;
  let bestDistance = max + 1;
  refs.forEach((ref) => {
    if (ref === word || Math.abs(Array.from(ref).length - length) > max || isBenignPair(wordCore(word), wordCore(ref))) return;
    const d = editDistance(word, ref);
    if (d < bestDistance && !(skipRef && skipRef(ref))) { best = ref; bestDistance = d; }
  });
  return best;
}

// Two spellings used side by side (one property's options, one component's names) are distinct, not typos.
function usedTogether(lists, a, b) {
  return lists.some((list) => list.indexOf(a) >= 0 && list.indexOf(b) >= 0);
}

function frequencyTypo(word, table, lists, conv) {
  if (wordCore(word).length <= conv.typo.shortLength) return null;
  const refs = frequentNeighbours(table, word);
  return nearestTypo(word, refs, conv.typo.minValueLength, conv, (ref) => usedTogether(lists, word, ref));
}

// L01 references in order: knownWords (every scope), then more frequent neighbours in the batch. At equal distance
// the first ref in nameRefs wins.
function nameTypoTarget(prop, ctx) {
  const conv = ctx.conv;
  if (!prop.name || ctx.known.nameSet.has(prop.name) || isKnownCompound(nameWords(prop.name), ctx)) return null;
  const apart = (ref) => usedTogether(ctx.nameSets, prop.name, ref);
  return nearestTypo(prop.name, ctx.nameRefs, conv.typo.minNameLength, conv, apart) ||
    frequencyTypo(prop.name, ctx.namesByType[prop.type] || {}, ctx.nameSets, conv);
}

function valueTypoTarget(value, prop, ctx) {
  const conv = ctx.conv;
  const lower = value.toLowerCase();
  if (/^[0-9]+$/.test(value) || conv.booleanValues.falsy.concat(conv.booleanValues.truthy).indexOf(lower) >= 0) return null;
  if (isAmbiguous(value, prop, conv) || isFeedbackValue(value, conv) || allowedByVocabulary(value, prop, conv)) return null;
  // knownWords values carry no emoji: compare the word after a feedback dot or direction arrow.
  const core = wordCore(value);
  const prefix = value.slice(0, value.length - core.length);
  if (feedbackCanonical(value, conv) || isLegacyValue(core, conv) || ctx.known.valueSet.has(value) || ctx.known.valueSet.has(core)) return null;
  if (isUpperSnake(core) && isKnownCompound(core.split('_'), ctx)) return null;
  let refs = roleVocabulary(prop.role.axis, conv);
  if (hasFeedbackDot(value, conv)) refs = refs.concat(feedbackValues(conv));
  const options = ctx.optionSets[prop.name] || [];
  const known = nearestTypo(core, ctx.known.values, conv.typo.minValueLength, conv, (ref) => usedTogether(options, value, prefix + ref));
  return nearestTypo(value, refs, conv.typo.minValueLength, conv) || (known ? prefix + known : null) ||
    frequencyTypo(value, ctx.values[prop.name] || {}, options, conv);
}

// L01: a name or value within edit distance of a vocabulary entry or of a more frequent neighbour.
function checkTypos(comp, ctx) {
  const out = [];
  comp.properties.forEach((p) => {
    const nameRef = nameTypoTarget(p, ctx);
    if (nameRef) {
      const reserved = ctx.conv.dartReserved.indexOf(nameRef) >= 0 ? 'also a Dart reserved word, L04: pick another name' : '';
      out.push(makeFinding(ctx, 'L01', comp, p.base, '', reserved, nameRef));
    }
    if (p.type !== 'VARIANT' || !p.role) return;
    p.options.forEach((v) => {
      const ref = valueTypoTarget(v, p, ctx);
      if (ref) out.push(makeFinding(ctx, 'L01', comp, p.base, v, '', ref));
    });
  });
  return out;
}

// L02: two properties of one component normalize to the same name.
function checkCollisions(comp, ctx) {
  const groups = {};
  comp.properties.forEach((p) => { if (p.name) (groups[p.name] = groups[p.name] || []).push(p); });
  return Object.keys(groups).filter((name) => groups[name].length > 1).map((name) => {
    const group = groups[name];
    const text = group.find((p) => p.type === 'TEXT' && startsWithWord(p.name, 'show'));
    const suggestion = text ? 'rename the TEXT to `' + name.charAt(4).toLowerCase() + name.slice(5) + '`' : 'give each property a distinct name';
    const label = group.map((p) => p.base + ' (' + p.type + ')').join(' + ');
    return makeFinding(ctx, 'L02', comp, label, '', '', suggestion);
  });
}

// L03: a name that normalizes to an empty string.
function checkEmptyNames(comp, ctx) {
  return comp.properties.filter((p) => !p.name).map((p) =>
    makeFinding(ctx, 'L03', comp, p.base, '', '', (p.role ? p.role.emoji : '') + ' <camelCaseName>'));
}

// L04: a normalized name that is a Dart reserved word or built-in identifier.
function checkReservedNames(comp, ctx) {
  return comp.properties.filter((p) => ctx.conv.dartReserved.indexOf(p.name) >= 0).map((p) =>
    makeFinding(ctx, 'L04', comp, p.base, '', '', 'a non-reserved name'));
}

// L05: emoji missing or not matching the role template, or a role that renames the property (logo -> showLogo).
function checkEmojiTemplate(comp, ctx) {
  return comp.properties.filter((p) => p.role && (p.role.rename || stripVs(p.emoji) !== stripVs(p.role.emoji))).map((p) =>
    makeFinding(ctx, 'L05', comp, p.base, '', '', expectedName(p)));
}

// L06: leading or trailing space or colon, missing or double space, not camelCase, or a non-ASCII space in a name or
// value. A value's L06 suggestion is its plain-space form; valueRuleOrder ranks L06 below L01 only.
function checkNameFormat(comp, ctx) {
  const out = [];
  const wide = 'non-ASCII space';
  comp.properties.forEach((p) => {
    const issues = [];
    p.options.forEach((v) => {
      if (WIDE_SPACE.test(v)) out.push(makeFinding(ctx, 'L06', comp, p.base, v, wide, v.split(WIDE_SPACE).join(' ')));
    });
    if (WIDE_SPACE.test(p.base)) issues.push(wide);
    if (p.leading) issues.push('leading space');
    if (p.emoji && !p.separator) issues.push('no space after emoji');
    if (p.separator.length > 1 || /\s\s/.test(p.label)) issues.push('double space');
    if (/:\s*$/.test(p.base)) issues.push('trailing colon');
    if (/\s$/.test(p.base)) issues.push('trailing space');
    if (!/^[a-z][A-Za-z0-9]*$/.test(p.label.replace(/[:\s]+$/, ''))) issues.push('not camelCase');
    if (issues.length) out.push(makeFinding(ctx, 'L06', comp, p.base, '', issues.join(', '), expectedName(p)));
  });
  return out;
}

// L07: value not UPPER_SNAKE, or emoji outside feedback and direction values.
function checkValueCase(comp, ctx) {
  const conv = ctx.conv;
  const out = [];
  variantProps(comp).forEach((p) => p.options.forEach((v) => {
    if (v === '--' || isUpperSnake(v) || isCanonicalBoolean(v, conv) || isFeedbackValue(v, conv) || isDirectionValue(v, conv) || isFreeSize(v, p, conv)) return;
    const arrow = directionRow(v, conv);
    const word = toUpperSnake(v) || (arrow ? arrow.word : '');
    // A Dart enum value cannot start with a digit: outside digitRoles, ask for a word instead of suggesting one.
    const digit = /^[0-9]/.test(word) && conv.digitRoles.indexOf(p.role.key) < 0;
    out.push(makeFinding(ctx, 'L07', comp, p.base, v, digit ? 'starts with a digit: use a word' : '', digit ? '' : arrow ? arrow.arrow + ' ' + word : word));
  }));
  return out;
}

// L08: boolean variant not False/True.
function checkBooleanValues(comp, ctx) {
  const b = ctx.conv.booleanValues;
  const out = [];
  variantProps(comp).forEach((p) => {
    const lower = p.options.map((o) => o.toLowerCase());
    if (!lower.some((o) => b.falsy.indexOf(o) >= 0) || !lower.some((o) => b.truthy.indexOf(o) >= 0)) return;
    p.options.forEach((v) => {
      const l = v.toLowerCase();
      if (isCanonicalBoolean(v, ctx.conv) || (b.falsy.indexOf(l) < 0 && b.truthy.indexOf(l) < 0)) return;
      const fix = b.falsy.indexOf(l) >= 0 ? b.canonical[0] : b.canonical[1];
      out.push(makeFinding(ctx, 'L08', comp, p.base, v, '', fix));
    });
  });
  return out;
}

// L09: a feedback word outside the feedback vocabulary (ERROR, NEGATIVE without dot, 🟢 SUCCESS).
function checkFeedbackValues(comp, ctx) {
  const out = [];
  wordVariants(comp, ctx.conv).forEach((p) => p.options.forEach((v) => {
    const canonical = feedbackCanonical(v, ctx.conv);
    if (canonical && stripVs(canonical) !== stripVs(v)) {
      out.push(makeFinding(ctx, 'L09', comp, p.base, v, '', canonical));
    }
  }));
  return out;
}

// L10: state, size, or color value outside its vocabulary; numeric sizes are info.
function checkVocabulary(comp, ctx) {
  const conv = ctx.conv;
  const out = [];
  variantProps(comp).filter((p) => conv.vocabularyRoles.indexOf(p.role.axis) >= 0).forEach((p) => {
    const numeric = [];
    p.options.forEach((v) => {
      if (isFreeSize(v, p, conv)) { numeric.push(v); return; }
      if (v === '--' || isAmbiguous(v, p, conv) || allowedByVocabulary(v, p, conv)) return;
      const snake = toUpperSnake(v);
      const match = legacyTarget(v, p.role.axis, conv) || roleVocabulary(p.role.axis, conv).find((x) => x === snake);
      const source = p.role.axis === 'state' ? 'the state vocabulary' : conv.vocabularies[p.role.axis].dartEnum;
      out.push(makeFinding(ctx, 'L10', comp, p.base, v, '', match || 'a value from ' + source));
    });
    if (numeric.length) {
      out.push(makeFinding(ctx, 'L10', comp, p.base, numeric.join('|'), 'numeric sizes map to FontSize or pixels', '', 'info'));
    }
  });
  return out;
}

// L11: visual variants live in `style`, never `type`.
function checkStyleNamedType(comp, ctx) {
  const styles = ctx.conv.visualStyles;
  const out = [];
  variantProps(comp).filter((p) => p.role.axis === 'type').forEach((p) => {
    const hits = p.options.filter((v) => styles.some((s) => v === s || v.indexOf(s + '_') === 0));
    if (hits.length) out.push(makeFinding(ctx, 'L11', comp, p.base, hits.join('|'), '', '🕶️ style'));
  });
  return out;
}

// L12: fill or stroke color not bound to a variable.
function checkUnboundColors(comp, ctx) {
  return comp.unboundPaints.map((paint) =>
    makeFinding(ctx, 'L12', comp, paint.kind + 's', paint.hex, '', 'bind a color variable'));
}

// L13: ACTIVE is ambiguous; suggest by component context.
function checkActiveValues(comp, ctx) {
  const conv = ctx.conv;
  const key = comp.name.replace(/[^A-Za-z0-9]/g, '').toLowerCase();
  const row = conv.activeSuggestions.find((r) => r.components.some((c) => c.toLowerCase() === key));
  return variantProps(comp).filter((p) => p.options.indexOf(conv.ambiguousValue) >= 0).map((p) =>
    makeFinding(ctx, 'L13', comp, p.base, conv.ambiguousValue, '', row ? row.suggestion : conv.activeDefault));
}

// L14: variant with a single value.
function checkSingleValue(comp, ctx) {
  return variantProps(comp).filter((p) => p.options.length === 1).map((p) =>
    makeFinding(ctx, 'L14', comp, p.base, p.options[0], '', 'remove the property or add its other values'));
}

function slotEmoji(conv) {
  return conv.emojiRoles.find((role) => role.key === 'slot').emoji;
}

function isStateLike(value, conv) {
  const word = wordCore(value).toUpperCase();
  return conv.stateLike.exact.indexOf(word) >= 0 || conv.stateLike.prefixes.some((pre) => word.indexOf(pre) === 0);
}

// L15: interaction value outside state/status, or slot value inside position/type with no slot of its name. A slot
// value selects the layout that shows the ❖ slot of the same name (CONTENT with ❖ content), so that pair is one concept.
function checkMixedAxis(comp, ctx) {
  const conv = ctx.conv;
  const out = [];
  wordVariants(comp, conv).forEach((p) => {
    const axis = p.role.axis;
    p.options.forEach((v) => {
      if (axis !== 'state' && axis !== 'status' && isStateLike(v, conv)) {
        out.push(makeFinding(ctx, 'L15', comp, p.base, v, '', 'move it to 🚦 state or a flag'));
      } else if (conv.slotAxes.indexOf(axis) >= 0 && conv.slotValues.indexOf(v.toUpperCase()) >= 0 &&
        !comp.properties.some((q) => q.role && q.role.key === 'slot' && q.name === v.toLowerCase())) {
        out.push(makeFinding(ctx, 'L15', comp, p.base, v, '', 'use a ' + slotEmoji(conv) + ' slot INSTANCE_SWAP'));
      }
    });
  });
  return out;
}

function canonicalName(prop, conv) {
  const row = conv.canonicalNames.find((r) => r.legacy.indexOf(prop.name) >= 0 && (!r.type || r.type === prop.type));
  return row ? row.name : null;
}

// L16: a legacy name for a concept that has a canonical name.
function checkConceptNames(comp, ctx) {
  const out = [];
  comp.properties.forEach((p) => {
    const target = canonicalName(p, ctx.conv);
    if (target) out.push(makeFinding(ctx, 'L16', comp, p.base, '', '', target));
  });
  return out;
}

// L18: fewer variants than the product of the option counts.
function checkVariantMatrix(comp, ctx) {
  if (comp.type !== 'COMPONENT_SET') return [];
  const product = comp.properties.filter((p) => p.type === 'VARIANT').reduce((n, p) => n * Math.max(p.options.length, 1), 1);
  if (comp.variantCount >= product) return [];
  return [makeFinding(ctx, 'L18', comp, '', comp.variantCount + '/' + product, '', 'add the missing variants or confirm the gaps')];
}

// L19: component set without a description.
function checkDescription(comp, ctx) {
  if (comp.type !== 'COMPONENT_SET' || comp.hasDescription) return [];
  return [makeFinding(ctx, 'L19', comp, '', '', '', 'add a description; if one shows in Figma, re-publish the library')];
}

// One list item toggle: `<N>. <Item>`, `<Item> <N>`, `<Item> <N> (first|last)` (legacy), or `show<Item><N>`.
function listToggleMember(prop, conv) {
  if (prop.type !== 'BOOLEAN') return null;
  const label = prop.label.trim();
  const numbered = label.match(/^([0-9]+)\.\s*([A-Za-z][A-Za-z ]*)$/);
  if (numbered) return { item: numbered[2], n: Number(numbered[1]), legacy: true };
  const trailing = label.match(/^([A-Za-z][A-Za-z ]*?)\s+([0-9]+)(\s*\((first|last)\))?$/);
  if (trailing) return { item: trailing[1], n: Number(trailing[2]), legacy: true };
  const canonical = prop.name.match(new RegExp('^' + conv.listToggles.prefix + '([A-Z][A-Za-z]*)([0-9]+)$'));
  return canonical ? { item: canonical[1], n: Number(canonical[2]), legacy: false } : null;
}

// Series of list toggles by item: a legacy form counts alone; show<Item><N> needs a sibling of the same item.
function findListToggles(properties, conv) {
  const byItem = {};
  const series = [];
  properties.forEach((prop) => {
    const member = listToggleMember(prop, conv);
    if (!member) return;
    const item = capitalize(LINT_SHARED.normalizeName(member.item));
    if (!byItem[item]) { byItem[item] = { item, members: [] }; series.push(byItem[item]); }
    byItem[item].members.push({ prop, n: member.n, legacy: member.legacy });
  });
  return series.filter((s) => s.members.length > 1 || s.members.some((m) => m.legacy));
}

function listToggleName(item, n, conv) {
  return conv.listToggles.emoji + ' ' + conv.listToggles.prefix + item + n;
}

// L20: numbered list toggles not named `👁️ show<Item><N>`, one finding per component.
function checkListToggles(comp, ctx) {
  const conv = ctx.conv;
  const wrong = [];
  const suggestions = [];
  comp.listToggles.forEach((series) => {
    const off = series.members.filter((m) => stripVs(m.prop.base) !== stripVs(listToggleName(series.item, m.n, conv)));
    if (!off.length) return;
    const ns = series.members.map((m) => m.n);
    const low = Math.min.apply(null, ns);
    const high = Math.max.apply(null, ns);
    off.forEach((m) => wrong.push(m.prop.base));
    suggestions.push(listToggleName(series.item, low === high ? low : low + '..' + high, conv));
  });
  return wrong.length ? [makeFinding(ctx, 'L20', comp, wrong.join(', '), '', '', suggestions.join('; '))] : [];
}

const LINT_RULES = [checkTypos, checkCollisions, checkEmptyNames, checkReservedNames, checkEmojiTemplate, checkNameFormat,
  checkValueCase, checkBooleanValues, checkFeedbackValues, checkVocabulary, checkStyleNamedType, checkUnboundColors,
  checkActiveValues, checkSingleValue, checkMixedAxis, checkConceptNames, checkVariantMatrix, checkDescription, checkListToggles];

function findingKey(page, component, property, value) {
  return [page, component, property, value].join('\u0001');
}

// Each problem once: the first rule in valueRuleOrder wins per value; an empty name silences its other name rules;
// L20 owns its list toggles (listOwned: findingKey -> true for each member property).
function dedupeFindings(findings, conv, listOwned) {
  const order = conv.valueRuleOrder;
  const owned = listOwned || {};
  const keyOf = (f) => findingKey(f.page, f.component, f.property, f.value);
  const ranked = (f) => f.value !== '' && f.severity !== 'info' && order.indexOf(f.rule) >= 0;
  const empty = {};
  findings.forEach((f) => { if (f.rule === 'L03') empty[keyOf(f)] = true; });
  const best = {};
  findings.forEach((f, i) => {
    if (!ranked(f)) return;
    const k = keyOf(f);
    if (best[k] === undefined || order.indexOf(f.rule) < order.indexOf(findings[best[k]].rule)) best[k] = i;
  });
  return findings.filter((f, i) => {
    if (conv.emptyNameSilences.indexOf(f.rule) >= 0 && empty[keyOf(f)]) return false;
    if (conv.listToggles.silences.indexOf(f.rule) >= 0 && owned[keyOf(f)]) return false;
    return !ranked(f) || best[keyOf(f)] === i;
  });
}

function lintComponents(components, conv) {
  const owned = {};
  const prepared = components.map((comp) => {
    const properties = comp.properties.map((p) => Object.assign({}, p, { role: resolveRole(p, conv) }));
    const listToggles = findListToggles(properties, conv);
    listToggles.forEach((s) => s.members.forEach((m) => { owned[findingKey(comp.page, comp.name, m.prop.base, '')] = true; }));
    return Object.assign({}, comp, { properties, listToggles });
  });
  const ctx = buildLintContext(prepared, conv);
  let findings = [];
  LINT_RULES.forEach((rule) => prepared.forEach((comp) => { findings = findings.concat(rule(comp, ctx)); }));
  return dedupeFindings(findings, conv, owned);
}

function countBySeverity(findings, conv) {
  const counts = {};
  conv.severityOrder.forEach((s) => { counts[s] = 0; });
  findings.forEach((f) => { counts[f.severity] += 1; });
  return counts;
}

function summaryLine(counts) {
  return 'lint: ' + counts.blocking + ' blocking, ' + counts.convention + ' convention, ' + counts.advisory + ' advisory, ' + counts.info + ' info';
}

// One row per repeated finding (same rule, property, value, suggestion, and detail) listing its components;
// the list is capped at maxNames and `more` counts the rest. Rows sort by severity, then rule.
function groupFindings(findings, conv, maxNames) {
  const rows = {};
  const list = [];
  findings.forEach((f) => {
    const key = [f.rule, f.severity, f.property, f.value, f.message, f.suggestion].join('\u0001');
    if (!rows[key]) {
      rows[key] = { rule: f.rule, severity: f.severity, property: f.property, value: f.value, suggestion: f.suggestion, note: f.message, components: [] };
      list.push(rows[key]);
    }
    if (rows[key].components.indexOf(f.component) < 0) rows[key].components.push(f.component);
  });
  list.forEach((row) => {
    if (row.components.length > maxNames) { row.more = row.components.length - maxNames; row.components = row.components.slice(0, maxNames); }
  });
  const rank = (row) => conv.severityOrder.indexOf(row.severity) * 100 + Number(row.rule.slice(1));
  return list.sort((a, b) => rank(a) - rank(b));
}

// Result row cells, in RESULT_COLUMNS order; `note` only when the finding carries detail.
const RESULT_COLUMNS = ['rule', 'property', 'value', 'suggestion', 'components', 'note'];

function rowCells(row) {
  const cells = [row.rule, row.property, row.value, row.suggestion, row.more ? row.components.concat('+' + row.more) : row.components];
  return row.note ? cells.concat(row.note) : cells;
}

// Component name -> indexes into pages (a name can repeat across pages); unknown pages are appended to pages.
function componentPageIndexes(findings, pages) {
  const where = {};
  findings.forEach((f) => {
    if (pages.indexOf(f.page) < 0) pages.push(f.page);
    const at = pages.indexOf(f.page);
    where[f.component] = where[f.component] || [];
    if (where[f.component].indexOf(at) < 0) where[f.component].push(at);
  });
  return where;
}

// Rows by severity and pages once per component: nothing per row that the rule id already says. Rule messages
// stay out of the sandbox; the report takes them from the reference Rules table.
function shapeLintResult(base, rows, where, conv) {
  const out = { columns: RESULT_COLUMNS, rows: {}, componentPages: {} };
  conv.severityOrder.forEach((s) => { out.rows[s] = []; });
  rows.forEach((row) => {
    out.rows[row.severity].push(rowCells(row));
    row.components.forEach((name) => { out.componentPages[name] = where[name]; });
  });
  return Object.assign({}, base, out);
}

// Fit the result under `limit` UTF-8 bytes: cap component lists at 10, 3, then 1; then keep the most severe rows
// that fit and flag truncation. errors lists components Figma could not read ({ page, component, error }).
function packLintResult(findings, pages, conv, errors, limit) {
  const counts = countBySeverity(findings, conv);
  const pageList = pages.slice();
  const where = componentPageIndexes(findings, pageList);
  const base = { pages: pageList, counts, summary: summaryLine(counts), errors: errors || [] };
  const fits = (res) => LINT_SHARED.utf8Length(JSON.stringify(res)) <= limit;
  for (const cap of [10, 3, 1]) {
    const res = shapeLintResult(base, groupFindings(findings, conv, cap), where, conv);
    if (fits(res)) return res;
  }
  const rows = groupFindings(findings, conv, 1);
  const keep = (n) => shapeLintResult(Object.assign({}, base, { truncated: true, omittedRows: rows.length - n }), rows.slice(0, n), where, conv);
  let low = 0;
  let high = rows.length;
  while (low < high) {
    const mid = Math.ceil((low + high) / 2);
    if (fits(keep(mid))) low = mid; else high = mid - 1;
  }
  return keep(low);
}

if (typeof module !== 'undefined') module.exports = { resolveRole, editDistance, toUpperSnake, lintComponents, dedupeFindings, groupFindings, countBySeverity, summaryLine, packLintResult, LINT_RULES, RESULT_COLUMNS };
