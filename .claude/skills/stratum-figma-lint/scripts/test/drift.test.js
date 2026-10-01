// Drift test: conventions.js vocabularies must match the Dart enums they mirror.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { fileURLToPath } = require('url');
const { CONVENTIONS } = require('../conventions.js');

function findPackageRoot(start) {
  let dir = start;
  while (dir !== path.dirname(dir)) {
    if (fs.existsSync(path.join(dir, 'pubspec.yaml')) && fs.existsSync(path.join(dir, 'lib/src/themes/constant'))) return dir;
    dir = path.dirname(dir);
  }
  throw new Error('stratum_ui package root not found above ' + start);
}

const ROOT = findPackageRoot(__dirname);
const CONSTANT_DIR = path.join(ROOT, 'lib/src/themes/constant');

function parseDartEnums(source) {
  const enums = {};
  const stripped = source.replace(/\/\/.*$/gm, '');
  const pattern = /enum\s+(\w+)\s*\{([^}]*)\}/g;
  let match;
  while ((match = pattern.exec(stripped))) {
    enums[match[1]] = match[2].split(';')[0].split(',').map((s) => s.trim()).filter((s) => /^[a-z]\w*$/.test(s));
  }
  return enums;
}

function readConstantEnums() {
  return fs.readdirSync(CONSTANT_DIR).filter((f) => f.endsWith('.dart'))
    .reduce((all, f) => Object.assign(all, parseDartEnums(fs.readFileSync(path.join(CONSTANT_DIR, f), 'utf8'))), {});
}

// FullWidgetState lives in flutter_falmodel, located through .dart_tool/package_config.json. Throws with the fix
// when any step fails, so a checkout without `flutter pub get` fails the drift test instead of skipping it.
function readFullWidgetState(root) {
  const fail = (what) => { throw new Error('FullWidgetState: ' + what + '; run `flutter pub get` in ' + root); };
  const configPath = path.join(root, '.dart_tool/package_config.json');
  if (!fs.existsSync(configPath)) fail(configPath + ' not found');
  const pkg = JSON.parse(fs.readFileSync(configPath, 'utf8')).packages.find((p) => p.name === 'flutter_falmodel');
  if (!pkg) fail('flutter_falmodel missing from ' + configPath);
  const rootDir = pkg.rootUri.startsWith('file:') ? fileURLToPath(pkg.rootUri) : path.resolve(path.dirname(configPath), pkg.rootUri);
  const file = path.join(rootDir, 'lib/models/constants.dart');
  if (!fs.existsSync(file)) fail(file + ' not found');
  return parseDartEnums(fs.readFileSync(file, 'utf8')).FullWidgetState || fail('enum FullWidgetState not in ' + file);
}

function upperSnake(camel) {
  return camel.replace(/([a-z0-9])([A-Z])/g, '$1_$2').toUpperCase();
}

// Enum members == vocabulary values plus codeOnly; designOnly values are extras outside the enum, never a values row.
// Feedback dots are dropped before comparing.
function assertMirrors(vocab, dartValues, label) {
  assert.ok(dartValues && dartValues.length, label + ': enum not found');
  const rows = vocab.values.map((row) => row.value);
  assert.deepEqual((vocab.designOnly || []).filter((v) => rows.includes(v)), [], label + ': designOnly repeats a values row');
  const expected = rows.map((v) => v.replace(/^[^A-Z0-9]+/, '')).concat(vocab.codeOnly || []);
  const actual = dartValues.map((v) => upperSnake(v.replace(/^s(\d+)$/, '$1')));
  assert.deepEqual(actual.sort(), expected.sort(), label + ' drifted from conventions.js');
}

const dart = readConstantEnums();
const V = CONVENTIONS.vocabularies;

test('ColorEnum matches the color vocabulary', () => assertMirrors(V.color, dart.ColorEnum, 'ColorEnum'));
test('WidgetSize matches the size vocabulary', () => assertMirrors(V.size, dart.WidgetSize, 'WidgetSize'));
test('WindowSize matches the windowSize vocabulary', () => assertMirrors(V.windowSize, dart.WindowSize, 'WindowSize'));

test('FontSize matches the font-size numbers', () => assertMirrors(V.fontSize, dart.FontSize, 'FontSize'));
test('FeedbackState matches the dotted feedback values', () => assertMirrors(V.feedback, dart.FeedbackState, 'FeedbackState'));

test('FullWidgetState matches the state vocabulary', () => assertMirrors(V.state, readFullWidgetState(ROOT), 'FullWidgetState'));

test('an unresolved flutter_falmodel fails the FullWidgetState check with the fix, never skips it', () => {
  const missing = path.join(ROOT, 'no-such-package-root');
  assert.throws(() => readFullWidgetState(missing), /FullWidgetState: .*package_config\.json not found; run `flutter pub get`/);
});

test('every vocabulary names the Dart enum it mirrors and the roles that use it', () => {
  Object.keys(V).forEach((key) => {
    assert.ok(V[key].dartEnum, key);
    assert.ok(Array.isArray(V[key].roles), key);
  });
});
