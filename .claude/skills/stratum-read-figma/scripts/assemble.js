#!/usr/bin/env node
// Prints the use_figma `code` that reads one component set: the lint skill's CONVENTIONS (skip rows only) as one JSON
// line, then the lint skill's extract_lib.js and this skill's entry_read.js with comment lines, the node-only export
// line, and leading indentation stripped, and __NODE_ID__ filled. Exits 1 when the code is over MAX_CODE_CHARS.
// Usage: node assemble.js --node <id>   (URL form 123-456 accepted)
const fs = require('fs');
const path = require('path');

const LINT_SCRIPTS = path.join(__dirname, '..', '..', 'stratum-figma-lint', 'scripts');
// The lint assembler owns the sandbox form of CONVENTIONS and the code limit; reuse both so the skills never drift.
const { sandboxConventions, MAX_CODE_CHARS } = require(path.join(LINT_SCRIPTS, 'assemble.js'));
const FILES = [path.join(LINT_SCRIPTS, 'extract_lib.js'), path.join(__dirname, 'entry_read.js')];
// entry_read.js reads only the skip rows (Doc and Examples frames).
const CONVENTION_KEYS = ['skip'];

function parseArgs(argv) {
  const args = { node: null };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    const value = argv[++i];
    if (flag === '--node' && value) args.node = value.replace('-', ':');
    else throw new Error('unknown or empty argument: ' + flag);
  }
  if (!args.node) throw new Error('pass --node <id>');
  return args;
}

function assemble(args) {
  const libraries = FILES.map((file) => fs.readFileSync(file, 'utf8')).join('\n')
    .split('\n')
    .filter((line) => !/^\s*(\/\/.*)?$/.test(line) && !/^#!/.test(line) && line.indexOf("if (typeof module !== 'undefined')") !== 0)
    .map((line) => line.trimStart())
    .join('\n');
  const conventions = 'const CONVENTIONS = ' + JSON.stringify(sandboxConventions(CONVENTION_KEYS)) + ';';
  return (conventions + '\n' + libraries).replace('__NODE_ID__', () => JSON.stringify(args.node));
}

// Characters as JavaScript counts them (UTF-16 code units): never fewer than the code points, never bytes.
function checkSize(code, limit) {
  const max = limit === undefined ? MAX_CODE_CHARS : limit;
  if (code.length > max) throw new Error('code is ' + code.length + ' characters, limit ' + max);
  return code;
}

if (require.main === module) {
  try {
    process.stdout.write(checkSize(assemble(parseArgs(process.argv.slice(2)))) + '\n');
  } catch (error) {
    process.stderr.write('assemble: ' + error.message + '\n');
    process.exit(1);
  }
}

module.exports = { assemble, parseArgs, checkSize, MAX_CODE_CHARS };
