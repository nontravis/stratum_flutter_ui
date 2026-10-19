@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The 12 names of ruling R4 (focus-style-cleanup design, 2026-10-15),
/// each removed outright before the first release tag, with the name that
/// replaces it.
const _removed = <String, String>{
  'FocusSpread': 'StratumFocusBorder',
  'StratumTapTargetSize': 'TapTargetSize',
  'StratumFocusGroup': 'FocusGroup',
  'StratumInteraction': 'Interaction',
  'StratumScroll': 'Scroll',
  'StratumShow': 'Show',
  'StratumShowTransition': 'ShowTransition',
  'StratumShowSlideDirection': 'ShowSlideDirection',
  'StratumReorderableItemsController': 'ReorderableItemsController',
  'Slot': 'StratumSlot',
  'HighContrastMode': 'StratumHighContrastMode',
  'resolveSize': 'resolveDefaultSize',
};

/// Every hand-written Dart file under `lib/src`, generated files left out.
List<File> _sources() =>
    Directory('lib/src')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.contains('/generated/'))
        .where((file) => !file.path.endsWith('.g.dart'))
        .toList();

/// [source] with every `//` comment line dropped, so the commented-out
/// code of `extensions/svg_extension.dart` counts for nothing.
String _code(String source) => source
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('R4: no @Deprecated declaration is left in lib/src', () {
    for (final file in _sources()) {
      expect(
        _code(file.readAsStringSync()),
        isNot(contains('@Deprecated')),
        reason: file.path,
      );
    }
  });

  for (final MapEntry(key: old, value: renamed) in _removed.entries) {
    test('R4: $old is gone, $renamed stays', () {
      final declares = RegExp(
        '(typedef $old\\b|class $old\\b|\\b$old\\(BuildContext)',
      );
      final named = RegExp('\\b$renamed\\b');
      var found = false;
      for (final file in _sources()) {
        final code = _code(file.readAsStringSync());
        expect(code, isNot(contains(declares)), reason: file.path);
        found = found || code.contains(named);
      }
      expect(found, isTrue, reason: '$renamed is still declared');
      expect(
        File('lib/src/components/common/utility/focus_spread.dart')
            .existsSync(),
        isFalse,
      );
    });
  }
}
