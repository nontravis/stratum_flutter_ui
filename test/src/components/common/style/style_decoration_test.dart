import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/style/style_decoration.dart';

const _radius = BorderRadius.all(Radius.circular(16));
const _shadowColor = Color(0x40000000);
const _shadow = [BoxShadow(blurRadius: 4, color: _shadowColor)];

Widget _box(StyleDecoration decoration) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: DecoratedBox(
        decoration: decoration,
        child: const SizedBox(width: 100, height: 60),
      ),
    ),
  );
}

void main() {
  group('StyleDecoration value semantics', () {
    test('equal fields give equal decorations and hash codes', () {
      const a = StyleDecoration(
        color: Color(0xFF112233),
        dropShadow: _shadow,
      );
      // A separate instance and list with equal contents.
      // ignore: prefer_const_constructors
      final b = StyleDecoration(
        color: const Color(0xFF112233),
        // The spread builds a new list on purpose.
        // ignore: prefer_const_literals_to_create_immutables
        dropShadow: [..._shadow],
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('hitTest is false in a rounded corner', () {
      const decoration = StyleDecoration(borderRadius: _radius);
      const size = Size(100, 60);

      expect(decoration.hitTest(size, const Offset(1, 1)), isFalse);
      expect(decoration.hitTest(size, const Offset(50, 30)), isTrue);
    });

    test('isComplex is true only with shadows', () {
      expect(
        const StyleDecoration(color: Color(0xFF000000)).isComplex,
        isFalse,
      );
      expect(const StyleDecoration(dropShadow: _shadow).isComplex, isTrue);
      expect(const StyleDecoration(innerShadow: _shadow).isComplex, isTrue);
    });

    test('isOpaque needs a fill with no transparency', () {
      const opaqueGradient = LinearGradient(
        colors: [Color(0xFF000000), Color(0xFFFFFFFF)],
      );
      const fadingGradient = LinearGradient(
        colors: [Color(0xFF000000), Color(0x00FFFFFF)],
      );

      expect(const StyleDecoration().isOpaque, isFalse);
      expect(
        const StyleDecoration(color: Color(0xFF000000)).isOpaque,
        isTrue,
      );
      expect(
        const StyleDecoration(color: Color(0x80000000)).isOpaque,
        isFalse,
      );
      expect(
        const StyleDecoration(gradient: opaqueGradient).isOpaque,
        isTrue,
      );
      expect(
        const StyleDecoration(gradient: fadingGradient).isOpaque,
        isFalse,
      );
      expect(
        const StyleDecoration(
          image: DecorationImage(image: AssetImage('a.png')),
        ).isOpaque,
        isFalse,
      );
    });
  });

  group('StyleDecoration painting', () {
    testWidgets('paints the shadow, then the fill, with no clip when opaque',
        (tester) async {
      await tester.pumpWidget(
        _box(
          const StyleDecoration(
            color: Color(0xFFFFFFFF),
            borderRadius: _radius,
            dropShadow: _shadow,
          ),
        ),
      );

      final box = find.byType(DecoratedBox);
      expect(
        box,
        paints
          ..rrect(color: _shadowColor)
          ..rrect(color: const Color(0xFFFFFFFF)),
      );
      expect(box, paintsExactlyCountTimes(#clipPath, 0));
    });

    testWidgets('clips the shadow to the outside when the fill is translucent',
        (tester) async {
      await tester.pumpWidget(
        _box(
          const StyleDecoration(
            color: Color(0x80FFFFFF),
            borderRadius: _radius,
            dropShadow: _shadow,
          ),
        ),
      );

      expect(
        find.byType(DecoratedBox),
        paints
          ..save()
          ..clipPath()
          ..rrect(color: _shadowColor)
          ..restore()
          ..rrect(color: const Color(0x80FFFFFF)),
      );
    });

    testWidgets('paints inset shadows inside the box, above the fill',
        (tester) async {
      await tester.pumpWidget(
        _box(
          const StyleDecoration(
            color: Color(0xFFFFFFFF),
            borderRadius: _radius,
            innerShadow: _shadow,
          ),
        ),
      );

      expect(
        find.byType(DecoratedBox),
        paints
          ..rrect(color: const Color(0xFFFFFFFF))
          ..save()
          ..clipRRect()
          ..path(color: _shadowColor, hasMaskFilter: true)
          ..restore(),
      );
    });

    testWidgets('paints a zero-blur inset shadow without a mask filter',
        (tester) async {
      await tester.pumpWidget(
        _box(
          const StyleDecoration(
            color: Color(0xFFFFFFFF),
            innerShadow: [
              BoxShadow(color: _shadowColor, offset: Offset(0, 2)),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.byType(DecoratedBox),
        paints
          ..clipRRect()
          ..path(color: _shadowColor, hasMaskFilter: false),
      );
    });
  });
}
