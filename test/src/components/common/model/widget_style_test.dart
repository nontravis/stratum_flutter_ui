import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/model/image_blur_filter.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';

void main() {
  const base = WidgetStyle(
    padding: EdgeInsets.all(8),
    borderRadius: BorderRadius.all(Radius.circular(4)),
    backgroundColor: Color(0xFF000000),
    backgroundBlur: ImageBlurFilter(sigmaX: 4, sigmaY: 4),
    dropShadow: [BoxShadow(blurRadius: 2)],
  );

  group('merge', () {
    test('returns the same instance when other is null', () {
      expect(identical(base.merge(null), base), isTrue);
    });

    test('non-null fields of other replace this values', () {
      final merged = base.merge(
        const WidgetStyle(
          padding: EdgeInsets.all(16),
          backgroundColor: Color(0xFFFFFFFF),
        ),
      );

      expect(merged.padding, const EdgeInsets.all(16));
      expect(merged.backgroundColor, const Color(0xFFFFFFFF));
    });

    test('null fields of other keep this values', () {
      final merged = base.merge(const WidgetStyle(opacity: 0.5));

      expect(
        merged,
        const WidgetStyle(
          opacity: 0.5,
          padding: EdgeInsets.all(8),
          borderRadius: BorderRadius.all(Radius.circular(4)),
          backgroundColor: Color(0xFF000000),
          backgroundBlur: ImageBlurFilter(sigmaX: 4, sigmaY: 4),
          dropShadow: [BoxShadow(blurRadius: 2)],
        ),
      );
    });

    test('keeps every field when the other side is empty', () {
      const full = WidgetStyle(
        opacity: 0.5,
        padding: EdgeInsets.all(8),
        margin: EdgeInsets.all(4),
        width: 120,
        height: 48,
        minWidth: 40,
        maxWidth: 320,
        minHeight: 24,
        maxHeight: 96,
        alignment: Alignment.center,
        border: Border.fromBorderSide(BorderSide()),
        borderRadius: BorderRadius.all(Radius.circular(4)),
        backgroundColor: Color(0xFF000000),
        backgroundGradient: LinearGradient(
          colors: [Color(0xFF000000), Color(0xFFFFFFFF)],
        ),
        backgroundImage: DecorationImage(image: AssetImage('background.png')),
        backgroundBlur: ImageBlurFilter(sigmaX: 4, sigmaY: 4),
        foregroundColor: Color(0x1F000000),
        foregroundGradient: LinearGradient(
          colors: [Color(0x00000000), Color(0x1F000000)],
        ),
        foregroundImage: DecorationImage(image: AssetImage('foreground.png')),
        foregroundBlur: ImageBlurFilter(sigmaX: 2, sigmaY: 2),
        clipBehavior: Clip.antiAlias,
        innerShadow: [BoxShadow(blurRadius: 1)],
        dropShadow: [BoxShadow(blurRadius: 2)],
        animationStyle: AnimationStyle.noAnimation,
      );

      expect(full.merge(const WidgetStyle()), full);
      expect(const WidgetStyle().merge(full), full);
    });

    test('lists are replaced, and an empty list clears them', () {
      final replaced = base.merge(
        const WidgetStyle(dropShadow: [BoxShadow(blurRadius: 8)]),
      );
      final cleared = base.merge(const WidgetStyle(dropShadow: []));

      expect(replaced.dropShadow, const [BoxShadow(blurRadius: 8)]);
      expect(cleared.dropShadow, isEmpty);
    });
  });

  group('lerp', () {
    const a = WidgetStyle(
      opacity: 1,
      padding: EdgeInsets.all(8),
      width: 100,
      backgroundColor: Color(0xFF000000),
      clipBehavior: Clip.none,
      animationStyle: AnimationStyle(duration: Duration(milliseconds: 100)),
    );
    const b = WidgetStyle(
      opacity: 0.5,
      padding: EdgeInsets.all(16),
      width: 200,
      backgroundColor: Color(0xFFFFFFFF),
      clipBehavior: Clip.antiAlias,
      animationStyle: AnimationStyle(duration: Duration(milliseconds: 300)),
    );

    test('returns a at t = 0 and b at t = 1', () {
      expect(identical(WidgetStyle.lerp(a, b, 0), a), isTrue);
      expect(identical(WidgetStyle.lerp(a, b, 1), b), isTrue);
    });

    test('interpolates opacity, spacing, sizes, and colors', () {
      final mid = WidgetStyle.lerp(a, b, 0.5)!;

      expect(mid.opacity, 0.75);
      expect(mid.padding, const EdgeInsets.all(12));
      expect(mid.width, 150);
      expect(
        mid.backgroundColor,
        Color.lerp(a.backgroundColor, b.backgroundColor, 0.5),
      );
    });

    test('switches clipBehavior at t = 0.5 and takes animationStyle from b',
        () {
      expect(WidgetStyle.lerp(a, b, 0.4)!.clipBehavior, Clip.none);
      expect(WidgetStyle.lerp(a, b, 0.6)!.clipBehavior, Clip.antiAlias);
      expect(WidgetStyle.lerp(a, b, 0.1)!.animationStyle, b.animationStyle);
    });

    test('switches a size at t = 0.5 when one side is null', () {
      const unsized = WidgetStyle();
      const sized = WidgetStyle(height: 48);

      expect(WidgetStyle.lerp(unsized, sized, 0.4)!.height, isNull);
      expect(WidgetStyle.lerp(unsized, sized, 0.6)!.height, 48);
    });

    test('treats a null style as an empty style', () {
      const target = WidgetStyle(
        backgroundColor: Color(0xFFFFFFFF),
        opacity: 0.5,
      );
      final mid = WidgetStyle.lerp(null, target, 0.5)!;

      expect(
        mid.backgroundColor,
        Color.lerp(null, const Color(0xFFFFFFFF), 0.5),
      );
      expect(mid.opacity, 0.75);
    });

    test('keeps values legal when the curve overshoots', () {
      final over = WidgetStyle.lerp(b, a, 2.5)!;

      expect(over.opacity, 1);
      expect(over.padding!.isNonNegative, isTrue);
      expect(over.width, 0);
    });
  });
}
