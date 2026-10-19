import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Path to the copyable skill, relative to the package root.
const _skillPath = 'skills/stratum-flutter-ui/SKILL.md';

/// The Agent Skills frontmatter caps on `name:` and `description:`.
const _nameCap = 64;
const _descriptionCap = 1024;

/// The string value of [key] in [frontmatter], or null when absent or not
/// a string.
String? _frontmatterValue(YamlMap frontmatter, String key) {
  final value = frontmatter[key];
  return value is String ? value : null;
}

/// Parses the YAML block between the first two `---` delimiters of [skillFile].
///
/// Throws [StateError] naming the reason when the closing `---` is missing or
/// the block does not parse as a YAML map.
YamlMap _frontmatterOf(File skillFile) {
  final lines = skillFile.readAsLinesSync();
  final start = lines.indexOf('---');
  final end = lines.indexOf('---', start + 1);
  if (start == -1 || end == -1) {
    throw StateError(
      '${skillFile.path} has no closing --- for its frontmatter',
    );
  }
  final block = lines.sublist(start + 1, end).join('\n');
  final parsed = loadYaml(block);
  if (parsed is! YamlMap) {
    throw StateError(
      '${skillFile.path} frontmatter did not parse as a YAML map',
    );
  }
  return parsed;
}

void main() {
  final frontmatter = _frontmatterOf(File(_skillPath));
  final name = _frontmatterValue(frontmatter, 'name');
  final description = _frontmatterValue(frontmatter, 'description');

  test('name is present and fits the Agent Skills cap', () {
    expect(
      name,
      isNotNull,
      reason: '$_skillPath has no name: line, or it is not a string',
    );
    expect(
      name!.length,
      lessThanOrEqualTo(_nameCap),
      reason: 'name is ${name.length} chars, over the $_nameCap-char cap',
    );
  });

  test('description is present and fits the Agent Skills cap', () {
    expect(
      description,
      isNotNull,
      reason: '$_skillPath has no description: line, or it is not a string',
    );
    expect(
      description!.length,
      lessThanOrEqualTo(_descriptionCap),
      reason:
          'description is ${description.length} chars, over the '
          '$_descriptionCap-char cap',
    );
  });
}
