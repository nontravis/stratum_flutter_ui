import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/config/transition_names.dart';

import '../components/common/fakes/fake_stratum_theme.dart';

/// The package default theme, parsed from disk.
StratumThemeConfig _defaultConfig() => StratumThemeConfig.parse(
  base: StratumThemeSource(
    id: 'stratum-default',
    folder: 'packages/stratum_ui/assets/themes/default',
    yaml: File('assets/themes/default/theme.yaml').readAsStringSync(),
  ),
);

/// The package default's six forward durations.
const _durations = {
  'micro': Duration(milliseconds: 30),
  'veryFast': Duration(milliseconds: 75),
  'fast': Duration(milliseconds: 125),
  'normal': Duration(milliseconds: 200),
  'slow': Duration(milliseconds: 300),
  'verySlow': Duration(milliseconds: 400),
};

/// An animation config with the package default's values, [defaultLevel],
/// and [standard] as the standard curve.
StratumAnimationConfig _config({
  String defaultLevel = 'fast',
  StratumCurve standard = const StratumNamedCurve('easeInOutSine'),
  Map<String, Duration>? durations,
}) => StratumAnimationConfig(
  durations: durations ?? _durations,
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
    test('us11/fr01: gives the six levels, each reversing at 64% on '
        'standard', () {
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
          StratumMotionLevel.micro: (
            const Duration(milliseconds: 30),
            const Duration(microseconds: 19200),
          ),
          StratumMotionLevel.veryFast: (
            const Duration(milliseconds: 75),
            const Duration(milliseconds: 48),
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
      expect(animation.micro.curve, Curves.easeInOutSine);
      expect(animation.micro.reverseCurve, Curves.easeInOutSine);
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

    test('us11/fr01: defaultStyle follows a micro default', () {
      final micro = StratumAnimation.fromConfig(_config(defaultLevel: 'micro'));

      expect(micro.defaultLevel, StratumMotionLevel.micro);
      expect(micro.defaultStyle, micro.micro);
      expect(micro.defaultStyle.duration, const Duration(milliseconds: 30));
    });

    test('us11/fr01/e01: two animations that differ only in micro '
        'are not equal', () {
      const base = StratumAnimation.packageDefault;
      StratumAnimation withMicro(AnimationStyle micro) => StratumAnimation(
        micro: micro,
        veryFast: base.veryFast,
        fast: base.fast,
        normal: base.normal,
        slow: base.slow,
        verySlow: base.verySlow,
        appear: base.appear,
        defaultLevel: base.defaultLevel,
        transition: base.transition,
      );
      final other = withMicro(
        const AnimationStyle(duration: Duration(milliseconds: 31)),
      );

      expect(withMicro(base.micro), base);
      expect(withMicro(base.micro).hashCode, base.hashCode);
      expect(other, isNot(base));
      expect(other.hashCode, isNot(base.hashCode));
      expect(other[StratumMotionLevel.micro], same(other.micro));
    });

    test('a reverse duration rounds to whole microseconds', () {
      final animation = StratumAnimation.fromConfig(
        _config(
          durations: {
            ..._durations,
            'veryFast': const Duration(microseconds: 1),
          },
        ),
      );

      expect(
        animation.veryFast.reverseDuration,
        const Duration(microseconds: 1),
      );
    });

    test('a cubic curve gives the same Cubic on every read', () {
      final config = _config(
        standard: const StratumCubicCurve(0.37, 0, 0.63, 1),
      );

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
            'micro',
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

    test('us11/s1: a change that animates forward runs 125 ms on '
        'easeInOutSine', () {
      const fast = StratumAnimation.packageDefault;

      expect(fast.defaultStyle.duration, const Duration(milliseconds: 125));
      expect(fast.defaultStyle.curve, Curves.easeInOutSine);
    });

    test('us11/s2: a change that animates back runs 80 ms on '
        'easeInOutSine', () {
      const fast = StratumAnimation.packageDefault;

      expect(
        fast.defaultStyle.reverseDuration,
        const Duration(milliseconds: 80),
      );
      expect(fast.defaultStyle.reverseCurve, Curves.easeInOutSine);
    });

    test('us11/fr01: carries micro at 30 and 19.2 ms and veryFast at 75 '
        'and 48 ms', () {
      const motion = StratumAnimation.packageDefault;

      expect(motion.micro.duration, const Duration(milliseconds: 30));
      expect(motion.micro.reverseDuration, const Duration(microseconds: 19200));
      expect(motion.micro.curve, Curves.easeInOutSine);
      expect(motion.micro.reverseCurve, Curves.easeInOutSine);
      expect(motion.appear.micro.duration, const Duration(milliseconds: 30));
      expect(
        motion.appear.micro.reverseDuration,
        const Duration(microseconds: 19200),
      );
      expect(motion.appear.micro.curve, Curves.easeOut);
      expect(motion.appear.micro.reverseCurve, Curves.easeIn);
      expect(motion.veryFast.duration, const Duration(milliseconds: 75));
      expect(motion.veryFast.reverseDuration, const Duration(milliseconds: 48));
      expect(motion[StratumMotionLevel.micro], same(motion.micro));
      expect(motion.defaultLevel, StratumMotionLevel.fast);
    });
  });

  group('C1: reduced motion keeps the yaml durations', () {
    Future<(StratumAnimation, StratumAnimation?)> read(
      WidgetTester tester, {
      required bool disableAnimations,
    }) async {
      late StratumAnimation view;
      StratumAnimation? data;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: StratumThemeApplication(
            themes: StratumThemeSet(light: motionTheme()),
            themeMode: ThemeMode.light,
            child: Builder(
              builder: (context) {
                view = StratumAnimation.of(context);
                data = StratumThemeApplication.maybeOf(context)?.animation;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      return (view, data);
    }

    testWidgets('fr01: with disableAnimations both readers give 77 ms', (
      tester,
    ) async {
      final (view, data) = await read(tester, disableAnimations: true);

      expect(view.fast.duration, const Duration(milliseconds: 77));
      expect(data, same(view));
    });

    testWidgets('us11/fr01/e02: with disableAnimations StratumAnimation.of '
        'gives the yaml micro level', (tester) async {
      final (view, _) = await read(tester, disableAnimations: true);

      expect(view.micro.duration, const Duration(milliseconds: 30));
      expect(view.micro.reverseDuration, const Duration(microseconds: 19200));
    });

    testWidgets("fr01: with the platform's reduceMotion both readers give "
        '77 ms', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      final (view, data) = await read(tester, disableAnimations: false);

      expect(view.fast.duration, const Duration(milliseconds: 77));
      expect(data?.fast.duration, const Duration(milliseconds: 77));
    });

    testWidgets('StratumAnimation.of throws with no application', (
      tester,
    ) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            StratumAnimation.of(context);
            return const SizedBox();
          },
        ),
      );

      expect(tester.takeException(), isA<FlutterError>());
    });
  });

  group('StratumAnimation.fromConfig transition', () {
    test('us05/fr04: maps each window size name to its type', () {
      final animation = StratumAnimation.fromConfig(
        _config().copyWith(
          transitions: transitionsOf(
            ScreenTransitionType.fade,
            sizes: {WindowSize.desktop: ScreenTransitionType.rightToLeft},
          ),
        ),
      );

      expect(
        animation.transition[WindowSize.mobile],
        ScreenTransitionType.fade,
      );
      expect(
        animation.transition[WindowSize.desktop],
        ScreenTransitionType.rightToLeft,
      );
    });

    test('a config with no type for a window size throws an '
        'ArgumentError', () {
      expect(
        () => StratumAnimation.fromConfig(
          _config().copyWith(transitions: const {}),
        ),
        throwsArgumentError,
      );
    });

    test('a config that names no type throws an ArgumentError', () {
      expect(
        () => StratumAnimation.fromConfig(
          _config().copyWith(
            transitions: transitionsOf(ScreenTransitionType.fade)
              ..['mobile'] = 'slideUp',
          ),
        ),
        throwsArgumentError,
      );
    });

    test('two animations that differ only in transition are not equal', () {
      expect(
        StratumAnimation.fromConfig(_config()),
        isNot(
          StratumAnimation.fromConfig(
            _config().copyWith(
              transitions: transitionsOf(ScreenTransitionType.fade),
            ),
          ),
        ),
      );
    });

    test('a hand-built animation names platform for every window size', () {
      expect(
        StratumAnimation.fromConfig(_config()).transition,
        StratumThemeTransitions.platform,
      );
      expect(
        StratumAnimation.packageDefault.transition,
        StratumThemeTransitions.platform,
      );
    });
  });

  test('transitionTypeNames is ScreenTransitionType.values by name, in '
      'order', () {
    expect(transitionTypeNames, [
      for (final type in ScreenTransitionType.values) type.name,
    ]);
  });

  test("fo01/us01/fr01: the default yaml's transition keys equal WindowSize "
      'and each names platform', () {
    final document = loadYaml(
      File('assets/themes/default/theme.yaml').readAsStringSync(),
    ) as YamlMap;
    final transition =
        (document['animation'] as YamlMap)['transition'] as YamlMap;

    expect(transition.keys.toList(), [
      for (final size in WindowSize.values) size.name,
    ]);
    expect(transition.values.toSet(), {'platform'});
  });
}
