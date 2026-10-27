import 'package:flutter_test/flutter_test.dart';

import '../../tools/perf_freeze.dart' hide main;

const _row = '''
import 'package:stratum_ui/src/src.dart';

/// Wraps an [AnimatedStyledBox]; see [GestureRowLayout] for taps.
class RowLayout extends StatelessWidget {
  const RowLayout({super.key});

  @override
  Widget build(BuildContext context) => const AnimatedStyledBox();
}

class _RowLayoutState {}
''';

const _box = '''
import 'package:stratum_ui/src/components/common/model/widget_style.dart';

typedef StyledBoxBuilder = Widget Function(WidgetStyle style, Widget box);

abstract class AnimatedStyledBox extends StatefulWidget {}

class _AnimatedStyledBoxState {}

extension on Widget {}
''';

const _boxLayout = '''
import 'package:stratum_ui/a/row_layout.dart';
import 'package:stratum_ui/src/src.dart';

class BoxLayout extends StatelessWidget {
  const BoxLayout({super.key});

  @override
  Widget build(BuildContext context) => const RowLayout();
}
''';

void main() {
  group('declaredNames', () {
    test('finds public classes and typedefs, never private names or '
        'unnamed extensions', () {
      expect(declaredNames([_row, _box]), {
        'RowLayout',
        'StyledBoxBuilder',
        'AnimatedStyledBox',
      });
    });
  });

  group('renameAll', () {
    test('renames declarations, constructors, uses, and doc references', () {
      final renamed = renameAll(_row, {'RowLayout', 'AnimatedStyledBox'});
      expect(renamed, contains('class BaselineRowLayout extends'));
      expect(renamed, contains('const BaselineRowLayout({super.key});'));
      expect(renamed, contains('=> const BaselineAnimatedStyledBox();'));
      expect(renamed, contains('/// Wraps an [BaselineAnimatedStyledBox];'));
    });

    test('renames whole identifiers only', () {
      final renamed = renameAll(_row, {'RowLayout'});
      expect(renamed, contains('[GestureRowLayout]'));
      expect(renamed, contains('class _RowLayoutState {}'));
      expect(renamed, contains("import 'package:stratum_ui/src/src.dart';"));
      expect(
        renameAll(_box, {'AnimatedStyledBox'}),
        contains('class _AnimatedStyledBoxState {}'),
      );
    });
  });

  group('freeze', () {
    final files = freeze(
      commit: 'fd59ffa',
      sources: {
        'lib/a/row_layout.dart': _row,
        'lib/b/animated_styled_box.dart': _box,
      },
    );

    test('f02/us01/s1, f02/us01/fr01: writes one file per source and a '
        'barrel that exports them', () {
      expect(files.keys, [
        'row_layout.dart',
        'animated_styled_box.dart',
        'baseline.dart',
      ]);
      expect(
        files['baseline.dart'],
        contains(
          "export 'row_layout.dart';\nexport 'animated_styled_box.dart';\n",
        ),
      );
    });

    test('names the commit and path in the header and imports the barrel '
        'before the source', () {
      final row = files['row_layout.dart']!;
      expect(
        row,
        startsWith(
          '// Frozen by tools/perf_freeze.dart from '
          'fd59ffa:lib/a/row_layout.dart.',
        ),
      );
      expect(
        row.indexOf("import 'baseline.dart';"),
        lessThan(row.indexOf("import 'package:stratum_ui/src/src.dart';")),
      );
      expect(row, contains('const BaselineAnimatedStyledBox()'));
    });

    test('rejects two sources with one file name', () {
      expect(
        () => freeze(
          commit: 'fd59ffa',
          sources: {
            'lib/a/row_layout.dart': _row,
            'lib/b/row_layout.dart': _row,
          },
        ),
        throwsArgumentError,
      );
    });

    test('rejects a source named like the barrel', () {
      expect(
        () => freeze(commit: 'fd59ffa', sources: {'lib/baseline.dart': _row}),
        throwsArgumentError,
      );
    });

    test('rejects a library or part directive', () {
      expect(
        () => freeze(
          commit: 'fd59ffa',
          sources: {'lib/a/row_layout.dart': 'library row;\n$_row'},
        ),
        throwsArgumentError,
      );
    });

    test('imports a frozen sibling by path once, never the live file', () {
      final withSibling = freeze(
        commit: 'fd59ffa',
        sources: {
          'lib/a/row_layout.dart': _row,
          'lib/c/box_layout.dart': _boxLayout,
        },
      );
      final box = withSibling['box_layout.dart']!;
      expect(box, isNot(contains('package:stratum_ui/a/row_layout.dart')));
      expect(RegExp("import 'row_layout.dart';").allMatches(box).length, 1);
      expect(box, contains("import 'package:stratum_ui/src/src.dart';"));
      expect(
        box,
        contains(
          '// ignore_for_file: type=lint, unused_import, '
          'unnecessary_import',
        ),
      );
    });
  });
}
