import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void _noop() {}

void main() {
  test(
    'co05_07/us01/fr04: StratumToastAction has value equality and copyWith',
    () {
      // Built at run time from a parameter, so no const canonicalization
      // makes them one instance and the check reads `==`, not identity.
      StratumToastAction make(String label) =>
          StratumToastAction(label: label, onPressed: _noop);
      final a = make('Undo');
      final b = make('Undo');
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      final c = a.copyWith(label: 'Redo');
      expect(c.label, 'Redo');
      expect(c.onPressed, _noop);
    },
  );
}
