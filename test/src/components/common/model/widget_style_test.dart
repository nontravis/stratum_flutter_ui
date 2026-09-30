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
}
