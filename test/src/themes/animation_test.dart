import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

/// The package default theme, parsed from disk.
StratumThemeConfig _defaultConfig() => StratumThemeConfig.parse(
  base: StratumThemeSource(
    id: 'stratum-default',
    folder: 'packages/stratum_ui/assets/themes/default',
    yaml: File('assets/themes/default/theme.yaml').readAsStringSync(),
  ),
);

/// An animation config with the package default's values, [defaultLevel],
/// and [standard] as the standard curve.
StratumAnimationConfig _config({
  String defaultLevel = 'fast',
  StratumCurve standard = const StratumNamedCurve('easeInOutSine'),
  Map<String, Duration>? durations,
}) => StratumAnimationConfig(
  durations:
      durations ??
      const {
        'veryFast': Duration(milliseconds: 50),
        'fast': Duration(milliseconds: 125),
        'normal': Duration(milliseconds: 200),
        'slow': Duration(milliseconds: 300),
        'verySlow': Duration(milliseconds: 400),
      },
  defaultLevel: defaultLevel,
  reverseRatio: 0.64,
  curves: {
    'standard': standard,
    'enter': const StratumNamedCurve('easeOut'),
    'exit': const StratumNamedCurve('easeIn'),
  },
);

void main() {
  group('StratumAnimation.fromConfig', () {
    test('gives the five levels, each reversing at 64% on standard', () {
      final animation = StratumAnimation.fromConfig(_config());

      expect(
        {
          for (final level in StratumMotionLevel.values)
            level: (
              animation[level].duration,
              animation[level].reverseDuration,
            ),
        },
        {
          StratumMotionLevel.veryFast: (
            const Duration(milliseconds: 50),
            const Duration(milliseconds: 32),
          ),
          StratumMotionLevel.fast: (
            const Duration(milliseconds: 125),
            const Duration(milliseconds: 80),
          ),
          StratumMotionLevel.normal: (
            const Duration(milliseconds: 200),
            const Duration(milliseconds: 128),
          ),
          StratumMotionLevel.slow: (
            const Duration(milliseconds: 300),
            const Duration(milliseconds: 192),
          ),
          StratumMotionLevel.verySlow: (
            const Duration(milliseconds: 400),
            const Duration(milliseconds: 256),
          ),
        },
      );
      expect(animation.fast.curve, Curves.easeInOutSine);
      expect(animation.fast.reverseCurve, Curves.easeInOutSine);
    });

    test('appear runs forward on enter and back on exit', () {
      final animation = StratumAnimation.fromConfig(_config());

      expect(animation.appear.fast.duration, animation.fast.duration);
      expect(animation.appear.fast.curve, Curves.easeOut);
      expect(animation.appear.fast.reverseCurve, Curves.easeIn);
    });

    test('defaultStyle follows duration.default', () {
      expect(
        StratumAnimation.fromConfig(_config()).defaultStyle,
        StratumAnimation.fromConfig(_config()).fast,
      );
      final normal = StratumAnimation.fromConfig(
        _config(defaultLevel: 'normal'),
      );
      expect(normal.defaultLevel, StratumMotionLevel.normal);
      expect(normal.defaultStyle, normal.normal);
    });

    test('a reverse duration rounds to whole microseconds', () {
      final animation = StratumAnimation.fromConfig(
        _config(
          durations: const {
            'veryFast': Duration(microseconds: 1),
            'fast': Duration(milliseconds: 125),
            'normal': Duration(milliseconds: 200),
            'slow': Duration(milliseconds: 300),
            'verySlow': Duration(milliseconds: 400),
          },
        ),
      );

      expect(
        animation.veryFast.reverseDuration,
        const Duration(microseconds: 1),
      );
    });

    test('a cubic curve gives the same Cubic on every read', () {
      final config = _config(standard: StratumCubicCurve(0.37, 0, 0.63, 1));

      expect(
        StratumAnimation.fromConfig(config),
        StratumAnimation.fromConfig(config),
      );
      expect(StratumAnimation.fromConfig(config).fast.curve, isA<Cubic>());
    });

    test('a config without a level throws an ArgumentError', () {
      expect(
        () => StratumAnimation.fromConfig(_config(durations: const {})),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.invalidValue,
            'invalidValue',
            'veryFast',
          ),
        ),
      );
    });
  });

  group('StratumAnimation.packageDefault', () {
    test('equals fromConfig of the package default yaml', () {
      expect(
        StratumAnimation.packageDefault,
        StratumAnimation.fromConfig(_defaultConfig().animation),
      );
    });

    test("the default yaml's level keys equal StratumMotionLevel", () {
      final document = loadYaml(
        File('assets/themes/default/theme.yaml').readAsStringSync(),
      ) as YamlMap;
      final animation = document['animation'] as YamlMap;
      final duration = animation['duration'] as YamlMap;

      expect(
        [
          for (final key in duration.keys)
            if (key != 'default') '$key',
        ],
        [for (final level in StratumMotionLevel.values) level.name],
      );
    });

    test('runs fast at 125 and 80 ms on easeInOutSine', () {
      const fast = StratumAnimation.packageDefault;

      expect(fast.defaultStyle.duration, const Duration(milliseconds: 125));
      expect(
        fast.defaultStyle.reverseDuration,
        const Duration(milliseconds: 80),
      );
      expect(fast.defaultStyle.curve, Curves.easeInOutSine);
      expect(fast.slow.duration, const Duration(milliseconds: 300));
    });
  });
}
