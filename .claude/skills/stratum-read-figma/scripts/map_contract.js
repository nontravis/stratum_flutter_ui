#!/usr/bin/env node
// Writes the contract draft for one entry_read.js result (map_lib.js does the mapping). Reads the repo for context:
// contracts under docs/specs/stratum_ui/components/ (nested componentKey -> class, their enums), enums in lib/, the
// folders of lib/src/components/, and the theme YAML's space and radius keys. Run from the repo root.
// Usage: node map_contract.js --data <result.json> --file-key <key> [--out <draft.md>]
// Prints `asks: <n>` and `contract: <path>` to stderr; each ask is an `- ASK:` line under `## Open questions` in the
// draft. The contract path is <section>/<component>/<component>.md under docs/specs/stratum_ui/components/.
const fs = require('fs');
const path = require('path');
const { mapContract } = require('./map_lib.js');

const CONTRACTS_DIR = 'docs/specs/stratum_ui/components';
const COMPONENTS_DIR = 'lib/src/components';
const THEMES_DIR = 'assets/themes';

function parseArgs(argv) {
  const args = { data: null, fileKey: null, out: null };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    const value = argv[++i];
    if (flag === '--data' && value) args.data = value;
    else if (flag === '--file-key' && value) args.fileKey = value;
    else if (flag === '--out' && value) args.out = value;
    else throw new Error('unknown or empty argument: ' + flag);
  }
  if (!args.data || !args.fileKey) throw new Error('pass --data <result.json> and --file-key <key from the URL>');
  return args;
}

function walk(dir, extension) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    if (entry.name.charAt(0) === '.') return [];
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return walk(full, extension);
    return entry.name.endsWith(extension) ? [full] : [];
  });
}

// Frontmatter `figma.componentKey` and `dart.class`, plus each `### `Name`` table under `## Enums`.
function parseContract(text, file) {
  const front = text.match(/^---\n([\s\S]*?)\n---/);
  const field = (name) => {
    const match = front && front[1].match(new RegExp('^\\s*' + name + ':\\s*"?([^"\\n]*?)"?\\s*$', 'm'));
    return match ? match[1] : '';
  };
  const enums = [];
  const start = text.indexOf('\n## Enums');
  if (start >= 0) {
    const end = text.indexOf('\n## ', start + 1);
    let current = null;
    text.slice(start, end < 0 ? undefined : end).split('\n').forEach((line) => {
      const heading = line.match(/^### `(\w+)`/);
      if (heading) { current = { name: heading[1], values: [] }; enums.push(current); return; }
      const row = current && line.match(/^\| `[^`]*` \| `(\w+)` \|/);
      if (row) current.values.push(row[1]);
    });
  }
  return { file, class: field('class'), componentKey: field('componentKey'), enums };
}

// `enum Name { a, b(1), c; ... }` -> values up to the first `;` or `}`; private enums are skipped.
function parseDartEnums(text, file) {
  const clean = text.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');
  const out = [];
  const pattern = /\benum\s+([A-Za-z]\w*)[^{]*\{([^}]*)\}/g;
  let match;
  while ((match = pattern.exec(clean))) {
    const values = match[2].split(';')[0].split(',')
      .map((v) => (v.replace(/@\w+(\([^)]*\))?/g, '').trim().match(/^([a-zA-Z]\w*)/) || [])[1]).filter(Boolean);
    out.push({ file, name: match[1], values });
  }
  return out;
}

// Top-level `space:` and `radius:` maps of the theme YAML: their two-space-indented keys.
function parseThemeKeys(text) {
  const keys = { space: [], radius: [] };
  let section = null;
  text.split('\n').forEach((line) => {
    const top = line.match(/^([A-Za-z][\w-]*):/);
    if (top) { section = keys[top[1]] ? top[1] : null; return; }
    const child = section && line.match(/^ {2}([\w-]+):/);
    if (child) keys[section].push(child[1]);
  });
  return keys;
}

function themeFile(root) {
  const preferred = path.join(root, THEMES_DIR, 'default', 'theme.yaml');
  if (fs.existsSync(preferred)) return preferred;
  return walk(path.join(root, THEMES_DIR), '.yaml')[0] || null;
}

function readContext(root, fileKey) {
  const rel = (file) => path.relative(root, file);
  const contracts = walk(path.join(root, CONTRACTS_DIR), '.md').map((file) => parseContract(fs.readFileSync(file, 'utf8'), rel(file)));
  const libEnums = walk(path.join(root, 'lib'), '.dart').flatMap((file) => parseDartEnums(fs.readFileSync(file, 'utf8'), rel(file)));
  const componentsDir = path.join(root, COMPONENTS_DIR);
  const folders = fs.existsSync(componentsDir)
    ? fs.readdirSync(componentsDir, { withFileTypes: true }).filter((e) => e.isDirectory()).map((e) => e.name) : [];
  const theme = themeFile(root);
  const themeKeys = theme ? parseThemeKeys(fs.readFileSync(theme, 'utf8')) : { space: [], radius: [] };
  return { fileKey, contracts, libEnums, folders, themeKeys };
}

if (require.main === module) {
  try {
    const args = parseArgs(process.argv.slice(2));
    const data = JSON.parse(fs.readFileSync(args.data, 'utf8'));
    if (!data.component) throw new Error('no `component` in ' + args.data + '; pass the use_figma result unchanged');
    const { markdown, asks, model } = mapContract(data.component, readContext(process.cwd(), args.fileKey));
    if (args.out) fs.writeFileSync(args.out, markdown); else process.stdout.write(markdown);
    process.stderr.write('asks: ' + asks.length + (data.omitted ? '; omitted: ' + data.omitted.join(', ') : '') + '\n' +
      'contract: ' + (model.contractPath || 'none until the folder ask is answered') + '\n');
  } catch (error) {
    process.stderr.write('map_contract: ' + error.message + '\n');
    process.exit(1);
  }
}

module.exports = { parseArgs, parseContract, parseDartEnums, parseThemeKeys, readContext };
