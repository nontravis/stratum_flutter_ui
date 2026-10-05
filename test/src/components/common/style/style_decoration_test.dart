import 'package:flutter/foundation.dart';
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

/// A subtype with no fields of its own, for the `runtimeType` check.
class _TintedDecoration extends StyleDecoration {
  const new({super.color});
}

void main() {
  group('StyleDecoration value semantics', () {
    test('equal fields give equal decorations and hash codes', () {
      const a = StyleDecoration(color: Color(0xFF112233), dropShadow: _shadow);
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

    test('a subtype with equal fields is not equal', () {
      const plain = StyleDecoration(color: Color(0xFF112233));
      const tinted = _TintedDecoration(color: Color(0xFF112233));

      expect(plain == tinted, isFalse);
      expect(tinted == plain, isFalse);
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
      expect(const StyleDecoration(color: Color(0xFF000000)).isOpaque, isTrue);
      expect(const StyleDecoration(color: Color(0x80000000)).isOpaque, isFalse);
      expect(const StyleDecoration(gradient: opaqueGradient).isOpaque, isTrue);
      expect(const StyleDecoration(gradient: fadingGradient).isOpaque, isFalse);
      expect(
        const StyleDecoration(
          image: DecorationImage(image: AssetImage('a.png')),
        ).isOpaque,
        isFalse,
      );
    });

    test('debugFillProperties lists the six fields', () {
      const decoration = StyleDecoration(
        color: Color(0xFF112233),
        gradient: LinearGradient(
          colors: [Color(0xFF000000), Color(0xFFFFFFFF)],
        ),
        image: DecorationImage(image: AssetImage('a.png')),
        borderRadius: _radius,
        dropShadow: _shadow,
        innerShadow: _shadow,
      );
      final builder = DiagnosticPropertiesBuilder();
      decoration.debugFillProperties(builder);

      expect(builder.properties.map((property) => property.name), [
        'color',
        'gradient',
        'image',
        'borderRadius',
        'dropShadow',
        'innerShadow',
      ]);
    });

    test('debugFillProperties hides the unset fields', () {
      final builder = DiagnosticPropertiesBuilder();
      const StyleDecoration(color: Color(0xFF112233))
          .debugFillProperties(builder);

      expect(
        builder.properties
            .where((property) => !property.isFiltered(DiagnosticLevel.info))
            .map((property) => property.name),
        ['color'],
      );
    });
  });

  group('StyleDecoration in Container', () {
    testWidgets('clips to the rounded shape when Container asks for a clip', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: Container(
              decoration: const StyleDecoration(
                color: Color(0xFFFFFFFF),
                borderRadius: _radius,
              ),
              clipBehavior: Clip.antiAlias,
              child: const SizedBox(width: 100, height: 60),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(ClipPath), paints..clipPath());
    });
  });

  group('StyleDecoration painting', () {
    testWidgets('paints the shadow, then the fill, with no clip when opaque', (
      tester,
    ) async {
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

    testWidgets(
      'clips the shadow to the outside when the fill is translucent',
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
      },
    );

    testWidgets('s03/inv6: paints inset shadows inside the box, above the '
        'fill', (tester) async {
      debugDisableShadows = false;
      try {
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
      } finally {
        debugDisableShadows = true;
      }
    });

    testWidgets('paints an offset zero-blur inset shadow without error', (
      tester,
    ) async {
      await tester.pumpWidget(
        _box(
          const StyleDecoration(
            color: Color(0xFFFFFFFF),
            innerShadow: [BoxShadow(color: _shadowColor, offset: Offset(0, 2))],
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

    testWidgets('s03/inv6: an inner shadow honors its blurStyle', (
      tester,
    ) async {
      debugDisableShadows = false;
      try {
        await tester.pumpWidget(
          _box(
            const StyleDecoration(
              color: Color(0xFFFFFFFF),
              innerShadow: [
                BoxShadow(
                  color: _shadowColor,
                  blurRadius: 4,
                  blurStyle: BlurStyle.outer,
                ),
              ],
            ),
          ),
        );

        expect(
          find.byType(DecoratedBox),
          paints
            ..clipRRect()
            ..something((method, arguments) {
              if (method != #drawPath) return false;
              final filter = (arguments[1] as Paint).maskFilter;
              return '$filter'.contains('BlurStyle.outer');
            }),
        );
      } finally {
        debugDisableShadows = true;
      }
    });

    testWidgets('s03/inv6: an inner shadow drops its blur under '
        'debugDisableShadows', (tester) async {
      expect(debugDisableShadows, isTrue);
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
          ..clipRRect()
          ..path(color: _shadowColor, hasMaskFilter: false),
      );
    });
  });
}
