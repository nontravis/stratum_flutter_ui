import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  group('StratumSchemaVersion.tryParse', () {
    test('reads stratum-theme/v<major>.<minor>.<patch>', () {
      expect(
        StratumSchemaVersion.tryParse('stratum-theme/v1.0.0'),
        StratumSchemaVersion.current,
      );
      expect(
        StratumSchemaVersion.tryParse('stratum-theme/v1.0.7'),
        const StratumSchemaVersion(1, 0, 7),
      );
    });

    test('gives null for any other form', () {
      for (final value in [
        'stratum-theme/1.0.0',
        'stratum-theme/v1.0',
        'stratum/v1.0.0',
      ]) {
        expect(StratumSchemaVersion.tryParse(value), isNull, reason: value);
      }
    });
  });

  group('StratumSchemaVersion.isSupported', () {
    test('holds for the current major and minor with any patch', () {
      expect(StratumSchemaVersion.current.isSupported, isTrue);
      expect(const StratumSchemaVersion(1, 0, 7).isSupported, isTrue);
    });

    test('fails for a newer minor and for any other major', () {
      expect(const StratumSchemaVersion(1, 1, 0).isSupported, isFalse);
      expect(const StratumSchemaVersion(2, 0, 0).isSupported, isFalse);
      expect(const StratumSchemaVersion(0, 9, 0).isSupported, isFalse);
    });
  });

  test('the current version is stratum-theme/v1.0.0', () {
    expect('${StratumSchemaVersion.current}', 'stratum-theme/v1.0.0');
  });
}
