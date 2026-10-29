import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui_widgetbook/components.g.dart';
import 'package:stratum_ui_widgetbook/kit/story_set.dart';
import 'package:stratum_ui_widgetbook/shell/catalog_section.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

/// Whether [component] sits under the Foundation section, which has no story
/// set.
bool _isFoundation(Component component) =>
    component.path.split('/').first == CatalogSection.foundation.label;

void main() {
  test(
    'fo11/us03/fr02: the catalog holds component pages besides Foundation',
    () {
      expect(components.where((c) => !_isFoundation(c)), isNotEmpty);
    },
  );

  test('fo11/us03/fr02: every catalog page keeps the story set', () {
    final problems = {
      for (final component in components)
        if (!_isFoundation(component))
          component.fullPath: storySetProblems(component),
    };

    expect(
      problems.entries.where((entry) => entry.value.isNotEmpty),
      isEmpty,
      reason: '$problems',
    );
  });

  test('fo11/us04/fr01: only the Playground shows knobs', () {
    final shown = {
      for (final component in components)
        if (!_isFoundation(component))
          for (final story in component.stories)
            if (story.name != StoryNames.playground &&
                story.args.safeList.isNotEmpty)
              story.path: [for (final arg in story.args.safeList) arg.name],
    };

    expect(
      shown,
      isEmpty,
      reason:
          'these stories show knobs that change '
          'nothing: $shown',
    );
  });

  test('fo11/us03/fr01: every catalog page has a description', () {
    final missing = [
      for (final component in components)
        if (!_isFoundation(component) && component.docComment == null)
          component.fullPath,
    ];

    expect(missing, isEmpty, reason: 'no /// summary on: $missing');
  });
}
