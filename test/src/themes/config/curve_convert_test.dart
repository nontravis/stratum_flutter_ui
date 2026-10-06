import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  group('s2, d-a: the curve names are a Flutter-free list', () {
    test('names equals the keys the convert maps to Curves, in order', () {
      expect(StratumNamedCurve.names, hasLength(43));
      expect(
        StratumCurveConvert.byName.keys.toList(),
        StratumNamedCurve.names.toList(),
      );
    });

    test('every name parses and converts to its Curves constant', () {
      for (final name in StratumNamedCurve.names) {
        final curve = StratumCurve.tryParse(name);

        expect(curve, StratumNamedCurve(name));
        expect(curve!.curve, same(StratumCurveConvert.byName[name]));
      }
      expect(
        const StratumNamedCurve('easeInOutSine').curve,
        same(Curves.easeInOutSine),
      );
    });
  });
}
