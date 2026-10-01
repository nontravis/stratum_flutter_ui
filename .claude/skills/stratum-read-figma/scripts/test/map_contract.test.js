// map_contract.js: repo parsing (contracts, Dart enums, theme keys) and the CLI against a temporary repo.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');
const { parseContract, parseDartEnums, parseThemeKeys, parseArgs } = require('../map_contract.js');
const { BUTTON_KEY, BADGE_KEY } = require('./helpers.js');

const SCRIPT = path.join(__dirname, '..', 'map_contract.js');
const FIXTURE = path.join(__dirname, 'fixtures', 'button.json');
const GOLDEN = fs.readFileSync(path.join(__dirname, 'expected', 'button.md'), 'utf8');

test('a contract yields its componentKey, class, and enums; the golden parses back', () => {
  const parsed = parseContract(GOLDEN, 'button.md');
  assert.deepEqual([parsed.class, parsed.componentKey], ['StratumButton', BUTTON_KEY]);
  assert.deepEqual(parsed.enums, [{ name: 'StratumButtonStyle', values: ['filledBrand', 'outline', 'ghost', 'shaded', 'filled', 'destructive'] }]);
  assert.deepEqual(parseContract('# No frontmatter', 'x.md'), { file: 'x.md', class: '', componentKey: '', enums: [] });
});

test('Dart enums: plain and enhanced, comments and annotations ignored, private skipped', () => {
  const text = [
    'enum WidgetSize {', '  tiny,', '  // a comment', '  huge;', '  bool get isTiny => this == tiny;', '}',
    'enum _Hidden { a, b }',
    'enum Mode with Foo { @Deprecated(\'x\') light(1), dark(2); const Mode(this.v); final int v; }',
  ].join('\n');
  assert.deepEqual(parseDartEnums(text, 'a.dart'), [
    { file: 'a.dart', name: 'WidgetSize', values: ['tiny', 'huge'] },
    { file: 'a.dart', name: 'Mode', values: ['light', 'dark'] },
  ]);
});

test('theme keys come from the top-level space and radius maps only', () => {
  const yaml = 'space:\n  sm: 12\n  md: 16\n\nradius:\n  full: 999\n  sm: 8\ncolor:\n  light:\n    sm:\n';
  assert.deepEqual(parseThemeKeys(yaml), { space: ['sm', 'md'], radius: ['full', 'sm'] });
});

test('the CLI needs --data and --file-key', () => {
  assert.throws(() => parseArgs(['--data', 'x.json']), /--file-key/);
  const run = spawnSync(process.execPath, [SCRIPT], { encoding: 'utf8' });
  assert.equal(run.status, 1);
  assert.match(run.stderr, /map_contract: pass --data/);
});

test('the CLI writes the draft from a temporary repo and reports its asks and the contract path', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'stratum-read-figma-'));
  const put = (rel, text) => { fs.mkdirSync(path.dirname(path.join(root, rel)), { recursive: true }); fs.writeFileSync(path.join(root, rel), text); };
  put('lib/src/components/control/.keep', '');
  put('lib/src/themes/constant/font_type.dart', 'enum FontType { header, paragraph, number, numberMono, code, body, table }\n');
  put('assets/themes/default/theme.yaml', 'space:\n  3xs: 6\n  2xs: 8\n  xs: 10\n  sm: 12\n  md: 16\n  lg: 20\n  xl: 24\nradius:\n  sm: 8\n  md: 10\n');
  put('docs/specs/stratum_ui/components/display/badge/badge.md', '---\nname: Badge\nfigma:\n  fileKey: "k"\n  nodeId: "1:1"\n  componentKey: "' + BADGE_KEY + '"\ndart:\n  class: StratumBadge\n---\n');
  const out = path.join(root, 'button.md');
  const run = spawnSync(process.execPath, [SCRIPT, '--data', FIXTURE, '--file-key', 'FROM_URL', '--out', out], { cwd: root, encoding: 'utf8' });
  assert.equal(run.status, 0, run.stderr);
  assert.equal(run.stderr, 'asks: 0\ncontract: docs/specs/stratum_ui/components/control/button/button.md\n');
  const draft = fs.readFileSync(out, 'utf8');
  assert.ok(draft.includes('  fileKey: "FROM_URL"'));
  assert.ok(draft.includes('| nested `Badge` + `👁️ showBadge` | `badge` | `StratumBadge?` | `null` |'));
  assert.ok(draft.includes('<!-- MODEL: replace this block'));
  fs.rmSync(root, { recursive: true, force: true });
});
