import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui_widgetbook/components.g.dart';
import 'package:stratum_ui_widgetbook/kit/story_set.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

/// Whether [component] sits under the Foundation section, which has no story
/// set.
bool _isFoundation(Component component) =>
    component.path.split('/').first == 'Foundation';

void main() {
  test('fo11/us03/fr02: every catalog page keeps the story set', () {
    // Vacuous until the first component page lands (M2-T8); it gates every
    // later page.
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
}
