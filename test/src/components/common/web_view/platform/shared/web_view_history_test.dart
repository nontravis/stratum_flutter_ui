import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/web_view_history.dart';

void main() {
  late WebViewHistory<String> history;

  setUp(() => history = WebViewHistory<String>());

  test('starts empty', () {
    expect(history.current, isNull);
    expect(history.canGoBack, isFalse);
    expect(history.canGoForward, isFalse);
    expect(history.back(), isNull);
    expect(history.forward(), isNull);
  });

  test('push makes the entry current', () {
    history
      ..push('a')
      ..push('b');
    expect(history.current, 'b');
    expect(history.canGoBack, isTrue);
    expect(history.canGoForward, isFalse);
  });

  test('back and forward move through entries', () {
    history
      ..push('a')
      ..push('b');
    expect(history.back(), 'a');
    expect(history.canGoForward, isTrue);
    expect(history.forward(), 'b');
    expect(history.current, 'b');
  });

  test('push after back drops forward entries', () {
    history
      ..push('a')
      ..push('b')
      ..back()
      ..push('c');
    expect(history.current, 'c');
    expect(history.canGoForward, isFalse);
    expect(history.back(), 'a');
  });
}
