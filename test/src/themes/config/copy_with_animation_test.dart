import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  group('n1/q8: the animation models are freezed', () {
    test('StratumAnimationConfig gains copyWith and refuses map changes', () {
      final durations = {'fast': const Duration(milliseconds: 100)};
      final config = StratumAnimationConfig(
        durations: durations,
        defaultLevel: 'fast',
        reverseRatio: 0.64,
        curves: {'standard': const StratumNamedCurve('easeIn')},
      );

      expect(config.copyWith(defaultLevel: 'slow').defaultLevel, 'slow');
      expect(
        () => config.durations['slow'] = Duration.zero,
        throwsUnsupportedError,
      );
      expect(
        () => config.curves['exit'] = const StratumNamedCurve('linear'),
        throwsUnsupportedError,
      );
      expect(config.toString(), startsWith('StratumAnimationConfig('));
    });

    test('the curve union gains copyWith and keeps its toString', () {
      const cubic = StratumCubicCurve(0.2, 0, 0.4, 1);

      expect(cubic.copyWith(d: 0.5), const StratumCubicCurve(0.2, 0, 0.4, 0.5));
      expect(cubic.toString(), 'StratumCubicCurve(0.2, 0.0, 0.4, 1.0)');
      expect(
        const StratumNamedCurve('easeIn').copyWith(name: 'linear'),
        const StratumNamedCurve('linear'),
      );
      expect(
        const StratumNamedCurve('easeIn').toString(),
        'StratumNamedCurve(easeIn)',
      );
    });

    test('s2: curve reads through the StratumCurveConvert extension', () {
      const cubic = StratumCubicCurve(0.2, 0, 0.4, 1);

      expect(const StratumNamedCurve('easeIn').curve, same(Curves.easeIn));
      expect(cubic.curve, isA<Cubic>());
      expect(cubic.curve, same(cubic.curve));
    });
  });
}
