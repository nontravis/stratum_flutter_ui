@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Each old name, its new name, and the file that declares both (design
/// section 6, "Renames now — 2026-10-10", with D10 Q5).
const _renames = [
  (
    'StratumInteraction',
    'Interaction',
    'lib/src/components/common/model/interaction.dart',
  ),
  ('StratumScroll', 'Scroll', 'lib/src/components/common/model/scroll.dart'),
  (
    'StratumTapTargetSize',
    'TapTargetSize',
    'lib/src/components/common/ink_well.dart',
  ),
  (
    'StratumFocusGroup',
    'FocusGroup',
    'lib/src/components/common/model/focus_group.dart',
  ),
  (
    'StratumReorderableItemsController',
    'ReorderableItemsController',
    'lib/src/components/common/layout/reorderable_list_view_layout.dart',
  ),
  ('StratumShow', 'Show', 'lib/src/components/common/utility/show.dart'),
  (
    'StratumShowTransition',
    'ShowTransition',
    'lib/src/components/common/utility/show.dart',
  ),
  (
    'StratumShowSlideDirection',
    'ShowSlideDirection',
    'lib/src/components/common/utility/show.dart',
  ),
  ('Slot', 'StratumSlot', 'lib/src/components/common/utility/slot.dart'),
  (
    'HighContrastMode',
    'StratumHighContrastMode',
    'lib/src/themes/theme_set.dart',
  ),
];

/// [source] with adjacent string literals joined, so a message the
/// formatter splits across lines reads as one literal.
String _joinStrings(String source) => source.replaceAll(RegExp(r"'\s*'"), '');

void main() {
  for (final (old, renamed, path) in _renames) {
    test('renames: $old is a @Deprecated alias of $renamed', () {
      final source = _joinStrings(File(path).readAsStringSync());

      expect(
        source,
        contains(RegExp('\\b(class|enum) $renamed\\b')),
        reason: '$path declares $renamed',
      );
      expect(
        source,
        isNot(contains(RegExp('\\b(class|enum) $old\\b'))),
        reason: '$path no longer declares $old',
      );
      expect(
        source,
        contains(
          RegExp(
            "@Deprecated\\(\\s*'Use $renamed instead\\. $old will be "
            r"removed after one minor version\.',?\s*\)\s*"
            'typedef $old = $renamed;',
          ),
        ),
        reason: '$path keeps $old as a deprecated alias of $renamed',
      );
    });
  }
}
