import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void _noop() {}

void main() {
  test(
    'co05_07/us01/fr06: StratumToastNotice has value equality and copyWith',
    () {
      StratumToastNotice notice({String message = 'Hi'}) => StratumToastNotice(
        message: message,
        kind: FeedbackState.info,
        placement: const StratumToastPlacement.solid(StratumToastEdge.bottom),
        insets: EdgeInsets.zero,
        pageSnack: null,
        customStyle: null,
        close: _noop,
        closeLabel: 'Close',
        kindLabel: 'Info',
      );
      final a = notice();
      final b = notice();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      final c = a.copyWith(message: 'Bye');
      expect(c.message, 'Bye');
      expect(c.kind, a.kind);
    },
  );
}
