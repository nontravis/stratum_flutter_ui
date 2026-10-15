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
}
