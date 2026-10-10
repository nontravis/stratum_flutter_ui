import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Path to the copyable skill, relative to the package root.
const _skillPath = 'skills/stratum-flutter-ui/SKILL.md';

/// The Agent Skills frontmatter caps on `name:` and `description:`.
const _nameCap = 64;
const _descriptionCap = 1024;

/// The value of the `key:` line in [frontmatter], or null when absent.
String? _frontmatterValue(List<String> frontmatter, String key) {
  for (final line in frontmatter) {
    if (line.startsWith('$key:')) return line.substring(key.length + 1).trim();
  }
  return null;
}

/// The lines between the first two `---` delimiters of [skillFile].
List<String> _frontmatterOf(File skillFile) {
  final lines = skillFile.readAsLinesSync();
  final start = lines.indexOf('---');
  final end = lines.indexOf('---', start + 1);
  return lines.sublist(start + 1, end);
}

void main() {
  final frontmatter = _frontmatterOf(File(_skillPath));
  final name = _frontmatterValue(frontmatter, 'name');
  final description = _frontmatterValue(frontmatter, 'description');

  test('name is present and fits the Agent Skills cap', () {
    expect(name, isNotNull, reason: '$_skillPath has no name: line');
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
      reason: '$_skillPath has no description: line',
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
