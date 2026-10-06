import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/config/plain_by_window_size.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';
import 'package:stratum_ui/src/themes/config/theme_convert.dart';
import 'package:stratum_ui/src/themes/typography/typography_parser.dart';

const _yaml = '''
fonts:
  inter: { family: Google/Inter }
families:
  default:
    { header: inter, paragraph: inter, number: inter, code: inter,
      body: inter, table: inter }
scaleByWindowSize: { mobile: 0, desktop: 2 }
types:
  header:
    { weight: 700, sizes: { s16: { spaceHeight: 8 } },
      scaleByWindowSize: { desktop: 4 } }
  paragraph: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
  number: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
  code: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
  body: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
''';

/// [_yaml] read by `readTypography`, [exists] the Google family check.
(PlainTypography, ThemeErrors) _read({required bool Function(String) exists}) {
  final origins = <String, ThemeOrigin>{};
  final tree = plainOf(
    loadYamlNode(_yaml),
    path: 'typography',
    source: 0,
    origins: origins,
  );
  final errors = ThemeErrors(['theme']);
  final typography = readTypography(
    tree! as Map<String, Object?>,
    ThemeReader(errors, origins),
    googleFontExists: exists,
  );
  return (typography, errors);
}

void main() {
  group('s2/q9: the typography stage yields plain values', () {
    test('weights are numbers and window sizes are names', () {
      final (typography, errors) = _read(exists: (name) => true);

      expect(errors.sorted, isEmpty);
      expect(typography.types[FontType.header]!.weight, 700);
      expect(typography.types[FontType.header]!.scaleByWindowSize, {
        'desktop': const StratumDimension.fixed(4),
      });
      expect(typography.scaleByWindowSize.sizes, {
        'mobile': const StratumDimension.fixed(0),
        'desktop': const StratumDimension.fixed(2),
      });
    });

    test("oq-c: the Google family check is the caller's", () {
      final (_, errors) = _read(exists: (name) => false);

      expect(
        [for (final error in errors.sorted) error.code],
        [StratumThemeErrorCode.unknownGoogleFont],
      );
    });

    test('s2: the convert maps every weight and window size it is given', () {
      final (typography, _) = _read(exists: (name) => true);
      final converted = convertTypography(typography);

      expect(converted.types[FontType.header]!.weight, FontWeight.w700);
      expect(converted.types[FontType.header]!.scaleByWindowSize, {
        WindowSize.desktop: const StratumDimension.fixed(4),
      });
      expect(
        converted.scaleByWindowSize.valueFor(WindowSize.bigDesktop),
        const StratumDimension.fixed(2),
      );
      for (var weight = 100; weight <= 900; weight += 100) {
        expect(FontWeight.values[weight ~/ 100 - 1].value, weight);
      }
    });

    test('oq-b: windowSizeNames is WindowSize.values by name, in order', () {
      expect(windowSizeNames, [
        for (final size in WindowSize.values) size.name,
      ]);
    });
  });
}
