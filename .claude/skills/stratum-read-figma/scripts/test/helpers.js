// Shared test helpers: fixtures, a fixed repo context for map_lib.js, and the approved Button constructor.
const fs = require('fs');
const path = require('path');

const FIXTURES = path.join(__dirname, 'fixtures');
// Component keys of the reference file (fixtures/button.json and its nested Badge).
const BUTTON_KEY = '7687e83a1ce129a5ae07141a00699e2d0484a42c';
const BADGE_KEY = 'd89c5b014f3afa826c998478cdb8fecf27cdeee4';

function loadFixture(name) {
  return JSON.parse(fs.readFileSync(path.join(FIXTURES, name + '.json'), 'utf8'));
}

// What map_contract.js would read from a repo that holds a Badge and a Button contract, keyed by the real component
// keys. Contract paths follow <section>/<component>/<component>.md; theme keys mirror assets/themes/default/theme.yaml;
// folders mirror lib/src/components/; FontType mirrors lib/src/themes/constant/font_type.dart.
function testContext(overrides) {
  return Object.assign({
    fileKey: 'SYNTHETIC_FILE_KEY',
    contracts: [
      { file: 'docs/specs/stratum_ui/components/display/badge/badge.md', class: 'StratumBadge', componentKey: BADGE_KEY, enums: [] },
      { file: 'docs/specs/stratum_ui/components/control/button/button.md', class: 'StratumButton', componentKey: BUTTON_KEY,
        enums: [{ name: 'StratumButtonStyle', values: ['filledBrand', 'outline', 'ghost', 'shaded', 'filled', 'destructive'] }] },
    ],
    libEnums: [
      { file: 'lib/src/themes/constant/widget_size.dart', name: 'WidgetSize', values: ['tiny', 'extraSmall', 'small', 'medium', 'large', 'extraLarge', 'huge'] },
      { file: 'lib/src/themes/constant/font_type.dart', name: 'FontType', values: ['header', 'paragraph', 'number', 'numberMono', 'code', 'body', 'table'] },
    ],
    folders: ['common', 'control', 'disclosure', 'display', 'feedback', 'form', 'navigation', 'overlay'],
    themeKeys: {
      space: ['mobile-space', 'zero', '5xs', '4xs', '3xs', '2xs', 'xs', 'sm', 'md', 'lg', 'xl', '2xl', '3xl'],
      radius: ['full', 'zero', '2xs', 'xs', 'sm', 'md', 'lg', 'xl', '2xl'],
    },
  }, overrides);
}

// The Button constructor approved on 2026-09-30 (spec "contract_template.md" worked example).
const WORKED_EXAMPLE = [
  'const StratumButton({',
  '  required this.label,',
  '  this.style = StratumButtonStyle.filledBrand,',
  '  super.size,',
  '  this.leftIcon,',
  '  this.rightIcon,',
  '  this.badge,',
  '  super.state,',
  '  super.disabled,',
  '  super.loading,',
  '  this.progress,',
  '  this.onPressed,',
  '  super.customStyle,',
  '});',
].join('\n');

// A contract without its title block: frontmatter, then everything from `## Properties` on. The title block holds the
// description, which the model writes.
function withoutDescription(markdown) {
  const front = markdown.slice(0, markdown.indexOf('\n---', 4) + 4);
  return front + markdown.slice(markdown.indexOf('\n## Properties'));
}

function dartBlock(markdown) {
  const match = markdown.match(/## Properties[\s\S]*?```dart\n([\s\S]*?)\n```/);
  return match ? match[1] : null;
}

// The record stratum-figma-lint reads (its readComponent shape), built from an entry_read.js component, so a test can
// run the gate on the same fixture the mapper reads.
function lintRecord(component) {
  const properties = {};
  component.properties.forEach((p) => {
    properties[p.rawName] = Object.assign({ type: p.type, defaultValue: p.defaultValue },
      p.variantOptions ? { variantOptions: p.variantOptions } : {}, p.defaultName ? { defaultName: p.defaultName } : {});
  });
  return { id: component.id, name: component.name, type: component.type, page: component.page,
    description: component.description.text, descriptionMarkdown: '', properties,
    variantCount: component.variants.count, unboundPaints: [] };
}

module.exports = { BUTTON_KEY, BADGE_KEY, loadFixture, testContext, WORKED_EXAMPLE, withoutDescription, dartBlock, lintRecord };
