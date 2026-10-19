import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  test('Q18: PageLayoutStyle has value equality over every field', () {
    // Non-const values, so canonicalization cannot stand in for ==.
    PageLayoutStyle style([int? differ]) {
      WidgetStyle at(int field) => WidgetStyle(
        width: double.parse('$field') + (field == differ ? 100 : 0),
      );
      return PageLayoutStyle(
        outer: at(0),
        header: at(1),
        top: at(2),
        tab: at(3),
        left: at(4),
        body: at(5),
        right: at(6),
        bottom: at(7),
        footer: at(8),
        snack: at(9),
      );
    }

    expect(style(), isNot(same(style())));
    expect(style(), style());
    expect(style().hashCode, style().hashCode);
    for (var field = 0; field < 10; field++) {
      expect(style(field), isNot(style()), reason: 'field $field');
    }
  });

  test('fo06/us18/fr03: PageLayoutStyle has value equality and copyWith', () {
    // Built at run time from a parameter, so no const canonicalization
    // makes them one instance and the check reads `==`, not identity.
    PageLayoutStyle make(double width) =>
        PageLayoutStyle(header: WidgetStyle(width: width));
    final a = make(1);
    final b = make(1);
    expect(identical(a, b), isFalse);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    final c = a.copyWith(header: const WidgetStyle(width: 2));
    expect(c.header, const WidgetStyle(width: 2));
    expect(c.outer, a.outer);
  });

  test('fo06/us18/fr03: PageLayoutStyle copyWith sets a nullable field back to '
      'null', () {
    const a = PageLayoutStyle(header: WidgetStyle(width: 1));
    final c = a.copyWith(header: null);
    expect(c.header, isNull);
  });

  test(
    'fo06/us18/fr03: merge replaces only the fields the other style sets',
    () {
      const base = PageLayoutStyle(
        body: WidgetStyle(width: 1, height: 2),
        header: WidgetStyle(width: 3),
      );
      final merged = base.merge(
        const PageLayoutStyle(
          body: WidgetStyle(width: 10),
          footer: WidgetStyle(height: 4),
        ),
      );
      expect(merged.body, const WidgetStyle(width: 10, height: 2));
      expect(merged.header, const WidgetStyle(width: 3));
      expect(merged.footer, const WidgetStyle(height: 4));
      expect(base.merge(null), same(base));
    },
  );
}
