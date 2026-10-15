@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fo08/us01/fr01/e04: neither base nor StratumWidgetProps declares '
      'customStyle; each component that takes one declares its own', () {
    for (final path in const [
      'lib/src/components/common/base/widget_props.dart',
      'lib/src/components/common/base/stateless_widget.dart',
      'lib/src/components/common/base/stateful_widget.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('get customStyle')), reason: path);
      expect(source, isNot(contains('this.customStyle')), reason: path);
      expect(source, isNot(contains('customStyle;')), reason: path);
    }
    for (final path in const [
      'lib/src/components/common/utility/caret.dart',
      'lib/src/components/common/utility/focus_border.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('super.customStyle')), reason: path);
      expect(source, contains('this.customStyle'), reason: path);
    }
  });

  test('R1, R10(1), co01_03/us01/fr04: the caret forwards no state, '
      'feedback tone, loading value, or window size', () {
    final source = File('lib/src/components/common/utility/caret.dart')
        .readAsStringSync();
    for (final prop in const [
      'super.state',
      'super.feedbackState',
      'super.loading',
      'super.windowSize',
    ]) {
      expect(source, isNot(contains(prop)), reason: prop);
    }
  });

  test('fo03/us06/fr01/e05: (j), base s03 invariant 21, the ring reads no '
      'styles-map entry', () {
    final source = File('lib/src/components/common/utility/focus_border.dart')
        .readAsStringSync();
    expect(source, isNot(contains('styleOf(')));
    expect(source, isNot(contains('resolveStyle(')));
    expect(source, contains('debugCheckNoComponentStyle('));
  });

  test('fo03/us06/fr01/e05: (j), caret s03 invariant 14, the caret reads no '
      'styles-map entry', () {
    final source = File('lib/src/components/common/utility/caret.dart')
        .readAsStringSync();
    expect(source, isNot(contains('resolveStyle(')));
    expect(source, isNot(contains('styleOf(')));
    expect(source, contains('debugCheckNoComponentStyle('));
  });

  test('R1, (g): NestedScrollViewLayout takes no scrollFocusStyle, since its '
      'box is never focusable and shows no ring', () {
    expect(
      File('lib/src/components/common/layout/nested_scroll_view_layout.dart')
          .readAsStringSync(),
      isNot(contains('scrollFocusStyle')),
    );
  });
}
