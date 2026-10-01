#!/usr/bin/env node
// Prints the use_figma `code` for one call: CONVENTIONS as one JSON line, then the mode's library files with
// comment lines, export guards, and leading indentation stripped, placeholders filled. Exits 1 at MAX_CODE_CHARS.
// The libraries hold no multi-line strings, so stripping indentation cannot change a value.
// Usage: node assemble.js --pages <id,id,...> [--named] | --node <id>   [--mode findings|raw|vocab]
// --named: the user named these pages (scope 2), so documentation and example pages are linted too.
const fs = require('fs');
const path = require('path');
const { CONVENTIONS } = require('./conventions.js');

// Each mode ships only what it calls: the CONVENTIONS keys (null = all) and the library files, in order.
const BUNDLES = {
  findings: { keys: null, files: ['extract_lib.js', 'lint_lib.js', 'entry_lint.js'] },
  raw: { keys: ['skip'], files: ['extract_lib.js', 'entry_lint.js'] },
  vocab: { keys: ['skip'], files: ['extract_lib.js', 'vocab_lib.js', 'entry_lint.js'] },
};
// Mirrors the use_figma code limit observed on 2026-09-30; lower it when the tool rejects the code.
const MAX_CODE_CHARS = 50000;

function parseArgs(argv) {
  const args = { pages: [], node: null, mode: 'findings', named: false };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    if (flag === '--named') { args.named = true; continue; }
    const value = argv[++i];
    if (flag === '--pages') args.pages = value.split(',').map((id) => id.trim()).filter(Boolean);
    else if (flag === '--node') args.node = value.replace('-', ':');
    else if (flag === '--mode') args.mode = value;
    else throw new Error('unknown argument: ' + flag);
  }
  if (!args.node && !args.pages.length) throw new Error('pass --pages or --node');
  if (!BUNDLES[args.mode]) throw new Error('mode must be one of ' + Object.keys(BUNDLES).join(', '));
  return args;
}

// The CONVENTIONS keys a bundle ships (null = all), without doc-only data. Rule messages, retired rules, the
// list-toggle canonical and legacy forms, each vocabulary's codeOnly gaps, and vocabularies no role uses reach the
// report through the generated reference tables (gen_conventions_md.js) and the drift test, never through the sandbox.
function sandboxConventions(keys) {
  const data = JSON.parse(JSON.stringify(CONVENTIONS));
  const out = {};
  (keys || Object.keys(data)).forEach((key) => { out[key] = data[key]; });
  if (out.rules) out.rules = out.rules.filter((rule) => data.severityOrder.indexOf(rule.severity) >= 0);
  (out.rules || []).forEach((rule) => { delete rule.message; });
  if (out.listToggles) { delete out.listToggles.canonical; delete out.listToggles.legacy; }
  Object.keys(out.vocabularies || {}).forEach((key) => {
    if (out.vocabularies[key].roles.length) delete out.vocabularies[key].codeOnly; else delete out.vocabularies[key];
  });
  return out;
}

function conventionsLine(keys) {
  return 'const CONVENTIONS = ' + JSON.stringify(sandboxConventions(keys)) + ';';
}

function assemble(args) {
  const bundle = BUNDLES[args.mode];
  const libraries = bundle.files.map((file) => fs.readFileSync(path.join(__dirname, file), 'utf8')).join('\n')
    .split('\n')
    .filter((line) => !/^\s*(\/\/.*)?$/.test(line) && !/^#!/.test(line) && line.indexOf("if (typeof module !== 'undefined')") !== 0)
    .map((line) => line.trimStart())
    .join('\n');
  return (conventionsLine(bundle.keys) + '\n' + libraries)
    .replace('= __PAGE_IDS__;', '= ' + JSON.stringify(args.pages) + ';')
    .replace('= __NODE_ID__;', '= ' + JSON.stringify(args.node) + ';')
    .replace('= __MODE__;', '= ' + JSON.stringify(args.mode) + ';')
    .replace('= __NAMED__;', '= ' + JSON.stringify(args.named) + ';');
}

if (require.main === module) {
  try {
    const code = assemble(parseArgs(process.argv.slice(2)));
    if (code.length >= MAX_CODE_CHARS) throw new Error('code is ' + code.length + ' characters, limit ' + MAX_CODE_CHARS);
    process.stdout.write(code + '\n');
  } catch (error) {
    process.stderr.write('assemble: ' + error.message + '\n');
    process.exit(1);
  }
}

module.exports = { assemble, parseArgs, sandboxConventions, BUNDLES, MAX_CODE_CHARS };
