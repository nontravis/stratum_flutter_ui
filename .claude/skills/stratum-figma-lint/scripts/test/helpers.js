// Shared test helpers: load fixtures, lint raw records, find findings.
const path = require('path');
const { CONVENTIONS } = require('../conventions.js');
const { describeComponent } = require('../extract_lib.js');
const { lintComponents } = require('../lint_lib.js');

function loadFixture(name) {
  return require(path.join(__dirname, 'fixtures', name + '.json'));
}

function fixtureRecords(...names) {
  return names.flatMap((name) => loadFixture(name).components);
}

function lintRecords(records) {
  return lintComponents(records.map(describeComponent), CONVENTIONS);
}

// Minimal raw record: props maps a property name to [type, defaultValue, variantOptions?, defaultName?].
function record(name, props, extra) {
  const properties = {};
  Object.keys(props).forEach((key) => {
    const [type, defaultValue, variantOptions, defaultName] = props[key];
    properties[key] = variantOptions ? { type, defaultValue, variantOptions } : { type, defaultValue };
    if (defaultName) properties[key].defaultName = defaultName;
  });
  return Object.assign({ id: name, name, type: 'COMPONENT_SET', page: '❖ Test', description: '', descriptionMarkdown: 'Doc.', properties, variantCount: 999, unboundPaints: [] }, extra);
}

function variant(options) {
  return ['VARIANT', options[0], options];
}

function find(findings, rule, component, match) {
  return findings.filter((f) => f.rule === rule && f.component === component &&
    Object.keys(match || {}).every((key) => f[key] === match[key]));
}

module.exports = { CONVENTIONS, loadFixture, fixtureRecords, lintRecords, record, variant, find };
