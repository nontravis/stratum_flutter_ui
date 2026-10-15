@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  const fill = Color(0xFFEEEEEE);

  test('co01_03/us01/fr04: R10(2), caret s03 invariant 14, the box style '
      'builds a WidgetStyle of its 16 fields and no other', () {
    final style = StratumCaretStyle(
      opacity: 0.5,
      margin: const EdgeInsets.all(4),
      width: 40,
      height: 30,
      border: Border.all(color: fill),
      borderRadius: const BorderRadius.all(Radius.circular(4)),
      backgroundColor: fill,
      backgroundGradient: const LinearGradient(colors: [fill, fill]),
      backgroundBlur: const ImageBlurFilter(sigmaX: 2, sigmaY: 2),
      foregroundColor: fill,
      foregroundGradient: const LinearGradient(colors: [fill, fill]),
      innerShadow: const [BoxShadow(blurRadius: 2)],
      dropShadow: const [BoxShadow(blurRadius: 3)],
      animationStyle: AnimationStyle.noAnimation,
    );

    expect(
      style.toWidgetStyle(),
      WidgetStyle(
        opacity: 0.5,
        margin: const EdgeInsets.all(4),
        width: 40,
        height: 30,
        border: Border.all(color: fill),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        backgroundColor: fill,
        backgroundGradient: const LinearGradient(colors: [fill, fill]),
        backgroundBlur: const ImageBlurFilter(sigmaX: 2, sigmaY: 2),
        foregroundColor: fill,
        foregroundGradient: const LinearGradient(colors: [fill, fill]),
        innerShadow: const [BoxShadow(blurRadius: 2)],
        dropShadow: const [BoxShadow(blurRadius: 3)],
        animationStyle: AnimationStyle.noAnimation,
      ),
    );
    expect(const StratumCaretStyle().toWidgetStyle(), const WidgetStyle());
  });

  test('R10(2): the box style leaves out the eight fields a childless box '
      'cannot show', () {
    final source = File(
      'lib/src/components/common/model/caret/stratum_caret_style.dart',
    ).readAsStringSync();
    for (final field in const [
      'padding',
      'alignment',
      'clipBehavior',
      'foregroundBlur',
      'minWidth',
      'maxWidth',
      'minHeight',
      'maxHeight',
    ]) {
      expect(source, isNot(contains('$field:')), reason: field);
      expect(source, isNot(contains(' $field,')), reason: field);
    }
  });

  test('co01_03/us01/fr04: freezed-models convention, value ==, copyWith, '
      'and toString', () {
    // Built at run time from a parameter, so the checks read `==`.
    StratumCaretStyle make(double width) => StratumCaretStyle(width: width);

    expect(make(40), make(40));
    expect(make(40).hashCode, make(40).hashCode);
    expect(make(40), isNot(make(41)));
    expect(make(40).copyWith(height: 30).height, 30);
    expect(make(40).toString(), startsWith('StratumCaretStyle('));
  });
}
