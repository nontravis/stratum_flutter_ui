// Pure vocabulary census for mode vocab: seeds and refreshes knownWords. Needs extract_lib.js only.

// Shared helpers: in scope inside the Figma bundle; required from extract_lib.js under node.
const VOCAB_SHARED = typeof utf8Length === 'function' ? { utf8Length } : require('./extract_lib.js');

// Mode vocab: how many components use each normalized property name and each value.
function collectVocabulary(components) {
  const names = {};
  const values = {};
  components.forEach((comp) => {
    const seen = {};
    comp.properties.forEach((p) => {
      if (p.name && !seen['n' + p.name]) { names[p.name] = (names[p.name] || 0) + 1; seen['n' + p.name] = 1; }
      p.options.forEach((v) => { if (!seen['v' + v]) { values[v] = (values[v] || 0) + 1; seen['v' + v] = 1; } });
    });
  });
  return { names, values };
}

function keepCounts(table, min) {
  const out = {};
  Object.keys(table).forEach((key) => { if (table[key] >= min) out[key] = table[key]; });
  return out;
}

// Fit under `limit` UTF-8 bytes: drop count-1 tokens first (droppedSingles), then raise minCount (truncated).
function packVocabulary(vocab, pages, limit) {
  const res = { mode: 'vocab', pages, names: vocab.names, values: vocab.values };
  const fits = () => VOCAB_SHARED.utf8Length(JSON.stringify(res)) <= limit;
  const total = Object.keys(vocab.names).length + Object.keys(vocab.values).length;
  let min = 1;
  while (!fits() && (Object.keys(res.names).length || Object.keys(res.values).length)) {
    min += 1;
    res.names = keepCounts(vocab.names, min);
    res.values = keepCounts(vocab.values, min);
    res.droppedSingles = true;
    res.droppedTokens = total - Object.keys(res.names).length - Object.keys(res.values).length;
    if (min > 2) Object.assign(res, { truncated: true, minCount: min });
  }
  return res;
}

if (typeof module !== 'undefined') module.exports = { collectVocabulary, packVocabulary };
