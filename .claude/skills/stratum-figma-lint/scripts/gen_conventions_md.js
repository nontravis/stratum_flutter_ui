#!/usr/bin/env node
// Rewrites the generated block of references/figma_conventions.md from conventions.js. Text outside the
// <!-- generated:start --> / <!-- generated:end --> markers is hand-written and left untouched.
// Usage: node gen_conventions_md.js
const fs = require('fs');
const path = require('path');
const { CONVENTIONS } = require('./conventions.js');

const DOC_PATH = path.join(__dirname, '..', 'references', 'figma_conventions.md');
const START = '<!-- generated:start -->';
const END = '<!-- generated:end -->';

function cell(text) {
  return String(text).replace(/\|/g, '\\|');
}

function code(values) {
  return values.map((v) => '`' + v + '`').join(', ');
}

function table(headers, rows) {
  const line = (cells) => '| ' + cells.map(cell).join(' | ') + ' |';
  return [line(headers), line(headers.map(() => '---'))].concat(rows.map(line)).join('\n');
}

function roleMatch(row) {
  if (row.swapName) return 'swapped component name contains `' + row.swapName.contains + '` or starts with `' + row.swapName.prefix + '`';
  if (row.prefix) return 'name starts with `' + row.prefix + '`';
  if (row.rename) return code(row.names) + ', renamed `' + row.rename + '<Name>`';
  if (row.names) return (row.types.indexOf('INSTANCE_SWAP') >= 0 ? 'any default, name ' : '') + code(row.names);
  return row.booleanOptions ? 'options `False`/`True`' : 'any name';
}

// Scopes a skip row applies in: page rows never reach scope 3; wholeFileOnly rows spare the pages a user names.
function skipScopes(row) {
  if (row.target !== 'page') return '1, 2, 3';
  return row.wholeFileOnly ? '1' : '1, 2';
}

function vocabularySection(key, vocab) {
  const notes = [];
  if (vocab.roles.length) notes.push('Roles: ' + code(vocab.roles) + '.');
  if (vocab.designOnly) notes.push('Figma only (allowed, not in the enum): ' + code(vocab.designOnly) + '.');
  if (vocab.codeOnly) notes.push('Dart only: ' + code(vocab.codeOnly) + '.');
  if (vocab.partSuffixes) notes.push('Any value may end in a part suffix: ' + code(vocab.partSuffixes) + '.');
  const rows = vocab.values.map((row) => [code([row.value]), code(row.legacy || [])]);
  return ['#### `' + key + '` (`' + vocab.dartEnum + '`)', notes.join(' '), table(['Value', 'Replaces'], rows)]
    .filter(Boolean).join('\n\n');
}

function renderTables(conv) {
  const words = (groups) => groups.map((group) => code(group.split('|')));
  return [
    '_Generated from `scripts/conventions.js` by `node scripts/gen_conventions_md.js`. Edit the data, then rerun it._',
    '### Rules',
    'The report takes each message from this table (results carry rule ids only) and appends a row\'s note, which ' +
      'holds only detail the message cannot say.',
    table(['Rule', 'Severity', 'Message'], conv.rules.map((r) => [r.id, r.severity, r.message])),
    '### Emoji by role',
    'First matching row wins.',
    table(['Role', 'Emoji', 'Property type', 'Match'], conv.emojiRoles.map((r) => [r.key, r.emoji, r.types.join(', '), roleMatch(r)])),
    '### Canonical property names',
    table(['Canonical', 'Type', 'Replaces'], conv.canonicalNames.map((r) => [code([r.name]), r.type || 'any', code(r.legacy)])),
    '### Numbered list toggles',
    'One BOOLEAN per list item, named ' + code([conv.listToggles.canonical]) + '. L20 reports these forms once per ' +
      'component; ' + code(conv.listToggles.silences) + ' stay silent on them.',
    table(['Legacy form', 'Examples'], conv.listToggles.legacy.map((r) => [code([r.form]), code(r.examples)])),
    '### Value vocabularies',
  ].concat(Object.keys(conv.vocabularies).map((key) => vocabularySection(key, conv.vocabularies[key])), [
    '### ACTIVE suggestions',
    table(['Components', 'Suggestion'], conv.activeSuggestions.map((r) => [r.components.join(', '), code([r.suggestion])])
      .concat([['any other', conv.activeDefault]])),
    '### Known words',
    table(['Kind', 'Words'], words(conv.knownWords.names).map((w) => ['name', w]).concat(words(conv.knownWords.values).map((w) => ['value', w]))),
    '### Skip rules',
    'Scope 1 lints the whole file, scope 2 the pages the user names, scope 3 one node.',
    table(['Target', 'Match', 'Value', 'Scopes'], conv.skip.map((r) => [r.target, r.match, code([r.value]), skipScopes(r)])),
  ]).join('\n\n');
}

function replaceBlock(doc, block) {
  const start = doc.indexOf(START);
  const end = doc.indexOf(END);
  if (start < 0 || end < start) throw new Error('generated markers not found in ' + DOC_PATH);
  return doc.slice(0, start + START.length) + '\n\n' + block + '\n\n' + doc.slice(end);
}

if (require.main === module) {
  const current = fs.readFileSync(DOC_PATH, 'utf8');
  const next = replaceBlock(current, renderTables(CONVENTIONS));
  if (next !== current) fs.writeFileSync(DOC_PATH, next);
  process.stdout.write((next === current ? 'unchanged ' : 'updated ') + DOC_PATH + '\n');
}

module.exports = { renderTables, replaceBlock, DOC_PATH };
