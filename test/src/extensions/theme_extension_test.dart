import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/extensions/theme_extension.dart';

void main() {
  group('BorderExtension', () {
    test('fo05/us06/s1, fo05/us06/s2, fo05/us06/fr01: a Border with sides of '
        'width 1, 2, 3, 4 '
        'has maxWidth 4; copy(color: c, width: w) replaces that field on all '
        "four sides while an omitted field keeps each side's own value", () {
      const border = Border(
        top: BorderSide(width: 1, color: Color(0xFF111111)),
        right: BorderSide(
          width: 2,
          color: Color(0xFF222222),
          style: BorderStyle.none,
        ),
        bottom: BorderSide(
          width: 3,
          color: Color(0xFF333333),
          strokeAlign: 0.5,
        ),
        left: BorderSide(
          width: 4,
          color: Color(0xFF444444),
          style: BorderStyle.none,
          strokeAlign: 1,
        ),
      );

      expect(border.maxWidth, 4);

      const newColor = Color(0xFF000000);
      final recolored = border.copy(color: newColor, width: 10);

      for (final side in [
        recolored.top,
        recolored.right,
        recolored.bottom,
        recolored.left,
      ]) {
        expect(side.color, newColor);
        expect(side.width, 10);
      }
      expect(recolored.top.style, border.top.style);
      expect(recolored.right.style, border.right.style);
      expect(recolored.bottom.strokeAlign, border.bottom.strokeAlign);
      expect(recolored.left.strokeAlign, border.left.strokeAlign);
    });
  });

  group('BorderRadiusGeometryExtension', () {
    test('fo05/us06/fr02: a BorderRadius with corners 2, 4, 6, 8 has maxRadius '
        '8; a uniform radius built by applying a caller function to that max '
        'gives every corner the mapped value', () {
      const radius = BorderRadius.only(
        topLeft: Radius.circular(2),
        topRight: Radius.circular(4),
        bottomLeft: Radius.circular(6),
        bottomRight: Radius.circular(8),
      );

      expect(radius.maxRadius, 8);

      final mapped = radius.mapMaxRadius((max) => max / 2);

      expect(mapped, BorderRadius.circular(4));
    });
  });
}
