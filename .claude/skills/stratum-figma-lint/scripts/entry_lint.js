// Figma calls only. Placeholders take JSON literals: __PAGE_IDS__ = ["0:1", ...] or [], __NODE_ID__ = "123:456" or
// null, __MODE__ = "findings", "raw", or "vocab", __NAMED__ = true when the user named the pages (scope 2).
const LINT_PAGE_IDS = __PAGE_IDS__;
const LINT_NODE_ID = __NODE_ID__;
const LINT_MODE = __MODE__;
const LINT_NAMED = __NAMED__;
// Mirrors the use_figma result limit observed on 2026-09-30 (about 20 KB); lower it when results come back cut off.
const LINT_RESULT_LIMIT = 18000;

async function loadLintRoots() {
  if (LINT_NODE_ID) {
    const node = await figma.getNodeByIdAsync(String(LINT_NODE_ID).replace('-', ':'));
    if (!node) throw new Error('node not found: ' + LINT_NODE_ID);
    let page = node;
    while (page && page.type !== 'PAGE') page = page.parent;
    if (!page) throw new Error('node has no page: ' + LINT_NODE_ID);
    await page.loadAsync();
    return [{ page, node }];
  }
  const roots = [];
  for (const id of LINT_PAGE_IDS) {
    const page = await figma.getNodeByIdAsync(id);
    if (!page || page.type !== 'PAGE' || shouldSkipPage(page.name, CONVENTIONS, LINT_NAMED)) continue;
    await page.loadAsync();
    roots.push({ page, node: page });
  }
  return roots;
}

// Name of an INSTANCE_SWAP default: the main component for an instance, the set for a variant, '' when not found.
async function swapDefaultName(id) {
  try {
    const node = await figma.getNodeByIdAsync(id);
    const main = node && node.type === 'INSTANCE' ? await node.getMainComponentAsync() : node;
    return main ? promoteVariant(main).name : '';
  } catch (error) {
    return '';
  }
}

// Resolves each INSTANCE_SWAP default id once and stores its name as `defaultName` on the property data.
async function attachSwapNames(records) {
  const defs = [];
  records.forEach((r) => Object.values(r.properties).forEach((def) => { if (def.type === 'INSTANCE_SWAP' && def.defaultValue) defs.push(def); }));
  const ids = Array.from(new Set(defs.map((def) => def.defaultValue)));
  const names = await Promise.all(ids.map(swapDefaultName));
  defs.forEach((def) => { const name = names[ids.indexOf(def.defaultValue)]; if (name) def.defaultName = name; });
}

const lintRoots = await loadLintRoots();
let lintRecords = [];
for (const root of lintRoots) lintRecords = lintRecords.concat(collectComponents(root.node, root.page.name, CONVENTIONS));
const lintPages = lintRoots.map((root) => root.page.name);
// Each mode's bundle holds only the libraries it calls; the returns keep the other modes' symbols unreached.
if (LINT_MODE === 'vocab') return packVocabulary(collectVocabulary(lintRecords.map(describeComponent)), lintPages, LINT_RESULT_LIMIT);
await attachSwapNames(lintRecords);
if (LINT_MODE === 'raw') return { components: lintRecords };
const lintFindings = lintComponents(lintRecords.map(describeComponent), CONVENTIONS);
const lintErrors = lintRecords.filter((r) => r.readError).map((r) => ({ page: r.page, component: r.name, error: r.readError }));
return packLintResult(lintFindings, lintPages, CONVENTIONS, lintErrors, LINT_RESULT_LIMIT);
