import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  group('ModalLayoutStyle', () {
    test('NFR-E02: merge replaces each part field by field', () {
      const base = ModalLayoutStyle(
        surface: WidgetStyle(width: 1, height: 2),
        close: WidgetStyle(opacity: 0.5),
      );
      final merged = base.merge(
        const ModalLayoutStyle(
          surface: WidgetStyle(height: 3),
          top: WidgetStyle(width: 4),
        ),
      );
      expect(merged.surface, const WidgetStyle(width: 1, height: 3));
      expect(merged.top, const WidgetStyle(width: 4));
      expect(merged.close, const WidgetStyle(opacity: 0.5));
      expect(merged.tab, isNull);
      expect(base.merge(null), base);
    });

    test(
      'fo06/us20/fr01: ModalLayoutStyle copyWith changes only the given part',
      () {
        const base = ModalLayoutStyle(surface: WidgetStyle(width: 1));
        final copy = base.copyWith(top: const WidgetStyle(width: 2));
        expect(copy.top, const WidgetStyle(width: 2));
        expect(copy.surface, base.surface);
      },
    );

    test(
      'fo06/us20/fr01: equal part styles are equal, so an equal app-wide map '
      'rebuilds no modal layout',
      () {
        // Built at run time, so no const canonicalization makes them one
        // instance and the check reads `==`, not identity.
        ModalLayoutStyle make(double width) =>
            ModalLayoutStyle(surface: WidgetStyle(width: width));
        final a = make(1);
        final b = make(1);
        expect(identical(a, b), isFalse);
        expect(a == b, isTrue);
        expect(a.hashCode, b.hashCode);
        expect(a, isNot(make(2)));
        expect(a, isNot(const ModalLayoutStyle(handle: WidgetStyle(width: 1))));
      },
    );

    test('5.3: copyWith(surface: null) clears surface and keeps the rest', () {
      const base = ModalLayoutStyle(
        surface: WidgetStyle(width: 1),
        top: WidgetStyle(width: 2),
      );
      final cleared = base.copyWith(surface: null);

      expect(cleared.surface, isNull);
      expect(cleared.top, base.top);
    });
  });
}
