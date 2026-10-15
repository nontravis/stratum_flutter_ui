import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  test('R5, R7(1), freezed-models convention: the scrolling area style holds '
      'its focus look, with value == and copyWith', () {
    // Built at run time from a parameter, so the checks read `==`.
    ScrollFocusStyle make(Color color) => ScrollFocusStyle(
      focus: StratumFocusBorderStyle(color: WidgetStatePropertyAll(color)),
    );
    const red = Color(0xFFFF0000);

    expect(const ScrollFocusStyle().focus, isNull);
    expect(make(red), make(red));
    expect(make(red).hashCode, make(red).hashCode);
    expect(make(red), isNot(make(const Color(0xFF00FF00))));
    expect(make(red).copyWith(focus: null).focus, isNull);
  });
}
