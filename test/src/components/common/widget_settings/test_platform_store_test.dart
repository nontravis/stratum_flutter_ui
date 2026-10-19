import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'fo10/us06/fr01: a test writes to the in-memory platform store',
    () async {
      await SharedPreferencesAsync().setBool('probe', true);
      expect(await SharedPreferencesAsync().getBool('probe'), isTrue);
    },
  );
  test(
    'fo10/us06/fr01: the next test starts on an empty platform store',
    () async {
      expect(await SharedPreferencesAsync().getKeys(), isEmpty);
    },
  );
}
