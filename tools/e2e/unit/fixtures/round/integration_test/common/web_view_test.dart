// Fixture for the entry unit tests: read as text, never compiled.
void main() {
  testWidgets('co01_02/us03/s1, co01_02/us03/s2: a page on the allowlist and the app '
      'trade messages both ways', (WidgetTester tester) async {
    expect(true, isTrue);
  });

  group('group B, native only', () {
    testWidgets('co01_02/us03/s3: a native-only case', (WidgetTester tester) async {
      expect(1, equals(1));
    });
  });
}
