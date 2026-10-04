import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  group('StratumTextStyle entry points', () {
    test('each type starts at s16, its yaml weight, and primary color', () {
      final body = StratumTextStyle.body;

      expect(body.fontType, FontType.body);
      expect(body.fontSize, FontSize.s16);
      expect(body.customSize, isNull);
      expect(body.fontWeight, isNull);
      expect(body.isMono, isFalse);
      expect(body.colorRole, FontColor.primary);
      expect(body.customColor, isNull);
    });

    test('the static getters and type() give the same recipe', () {
      expect(
        {
          FontType.header: StratumTextStyle.header,
          FontType.paragraph: StratumTextStyle.paragraph,
          FontType.number: StratumTextStyle.number,
          FontType.code: StratumTextStyle.code,
          FontType.body: StratumTextStyle.body,
          FontType.table: StratumTextStyle.table,
        },
        {for (final type in FontType.values) type: StratumTextStyle.type(type)},
      );
    });
  });

  group('StratumTextStyle getters', () {
    final body = StratumTextStyle.body;

    test('size getters pick each FontSize', () {
      expect(
        [
          body.s10,
          body.s12,
          body.s14,
          body.s16,
          body.s18,
          body.s20,
          body.s24,
          body.s36,
          body.s48,
          body.s56,
        ].map((style) => style.fontSize),
        FontSize.values,
      );
    });

    test('weight getters pick w300 to w700', () {
      expect(
        [
          body.light,
          body.regular,
          body.medium,
          body.semiBold,
          body.bold,
        ].map((style) => style.fontWeight),
        [
          FontWeight.w300,
          FontWeight.w400,
          FontWeight.w500,
          FontWeight.w600,
          FontWeight.w700,
        ],
      );
      expect(body.weight(FontWeight.w800).fontWeight, FontWeight.w800);
    });

    test('color getters pick each FontColor', () {
      expect(
        [
          body.colorBrandPrimary,
          body.colorBrandSecondary,
          body.colorBrandTertiary,
          body.colorPrimary,
          body.colorPrimaryInverse,
          body.colorPrimaryOnColor,
          body.colorSecondary,
          body.colorSecondaryInverse,
          body.colorTertiary,
          body.colorTertiaryInverse,
        ].map((style) => style.colorRole),
        FontColor.values,
      );
      expect(
        body.fontColor(FontColor.secondary).colorRole,
        FontColor.secondary,
      );
    });

    test('style getters set mono, italic, and the decoration', () {
      expect(body.mono.isMono, isTrue);
      expect(body.italic.fontStyle, FontStyle.italic);
      expect(body.underline.textDecoration, TextDecoration.underline);
      expect(body.lineThrough.textDecoration, TextDecoration.lineThrough);
    });

    test('theme-mode shortcuts set the override', () {
      expect(body.darkTheme.themeModeOverride, ThemeMode.dark);
      expect(body.lightTheme.themeModeOverride, ThemeMode.light);
    });

    test('the last size or color call wins', () {
      final sized = body.size(13).s12;
      expect(sized.fontSize, FontSize.s12);
      expect(sized.customSize, isNull);
      expect(body.s12.size(13).customSize, 13);

      final colored = body.color(const Color(0xFF123456)).colorTertiary;
      expect(colored.customColor, isNull);
      expect(colored.colorRole, FontColor.tertiary);
    });
  });

  group('StratumTextStyle immutability', () {
    test('us01/s2: a stored style is not changed by a later getter', () {
      final caption = StratumTextStyle.body.s12.colorTertiary;
      final medium = caption.medium;

      expect(medium.fontWeight, FontWeight.w500);
      expect(caption.fontWeight, isNull);
      expect(caption, StratumTextStyle.body.s12.colorTertiary);
    });

    test('every getter returns a new instance', () {
      final caption = StratumTextStyle.body.s12;

      expect(identical(caption.s12, caption), isFalse);
      expect(caption.s12, caption);
    });
  });

  group('StratumTextStyle equality', () {
    final base = StratumTextStyle.body;
    final variants = <String, StratumTextStyle Function()>{
      'type': () => StratumTextStyle.header,
      'size': () => base.s12,
      'custom size': () => base.size(13),
      'weight': () => base.bold,
      'mono': () => base.mono,
      'italic': () => base.italic,
      'decoration': () => base.underline,
      'shadows': () => base.shadows([const Shadow(blurRadius: 2)]),
      'font color': () => base.colorBrandPrimary,
      'color': () => base.color(const Color(0xFF123456)),
      'theme mode': () => base.darkTheme,
      'locale': () => base.locale(const Locale('th')),
      'window size': () => base.windowSize(WindowSize.desktop),
      'text scaler': () => base.textScaler(const TextScaler.linear(2)),
    };

    for (final MapEntry(key: name, value: make) in variants.entries) {
      test('$name takes part in == and hashCode', () {
        expect(make(), isNot(base));
        expect(make(), make());
        expect(make().hashCode, make().hashCode);
      });
    }

    test('shadows compare by list content', () {
      final a = base.shadows([const Shadow(blurRadius: 2)]);
      final b = base.shadows([const Shadow(blurRadius: 2)]);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(base.shadows([const Shadow(blurRadius: 3)])));
    });
  });
}
