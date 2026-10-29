import 'package:flutter/material.dart' show Theme;
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart' show WindowSize;
import 'package:stratum_ui_widgetbook/components.g.dart';
import 'package:stratum_ui_widgetbook/kit/preset.dart';
import 'package:stratum_ui_widgetbook/kit/story_set.dart';
import 'package:stratum_ui_widgetbook/shell/catalog_section.dart';

import 'support/open_story.dart';

/// The Playground of each component page that has a story set.
final _playgrounds = [
  for (final component in components)
    if (component.path.split('/').first != CatalogSection.foundation.label)
      for (final story in component.stories)
        if (story.name == StoryNames.playground) story,
];

/// The pages that cannot open on the VM: `webview_flutter` has no platform
/// implementation there, so the view throws before any preset matters.
const _needsBrowser = {'Utility/Web view/Playground'};

void main() {
  test('fo11/us04/fr04: the guard reaches the preset knobs of the catalog', () {
    expect(_playgrounds, isNotEmpty);
    expect(
      _playgrounds.where(
        (story) => story.args.safeList.any((arg) => arg is PresetArgBase),
      ),
      isNotEmpty,
    );
  });

  for (final story in _playgrounds) {
    testWidgets(
      'fo11/us04/fr04: ${story.path} builds with each preset of each preset '
      'knob picked',
      skip: _needsBrowser.contains(story.path),
      (tester) async {
        for (final arg in story.args.safeList) {
          if (arg is! PresetArgBase) continue;
          for (final preset in arg.values) {
            // The desktop window: the test font is wider than the catalog's,
            // so row layouts overflow the mobile width here and not there.
            await openStory<Theme>(
              tester,
              story.path,
              knobs: {arg.name: preset.name},
              toolbar: {
                'viewport': {'name': WindowSize.desktop.name},
              },
            );

            expect(
              tester.takeException(),
              isNull,
              reason: '${story.path}: ${arg.name} = ${preset.name}',
            );
          }
        }
      },
    );
  }
}
