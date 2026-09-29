import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/html_frame_guard.dart';

void main() {
  late HtmlFrameGuard guard;

  setUp(() => guard = HtmlFrameGuard());

  test('starts without own HTML', () {
    expect(guard.isShowingOwnHtml, isFalse);
  });

  test('trusts the frame while own HTML is loading', () {
    guard.expectOwnHtml();
    expect(guard.isShowingOwnHtml, isTrue);
  });

  test('trusts the frame after the first load', () {
    guard
      ..expectOwnHtml()
      ..didLoadFrame();
    expect(guard.isShowingOwnHtml, isTrue);
  });

  test('stops trusting the frame after a second load', () {
    guard
      ..expectOwnHtml()
      ..didLoadFrame()
      ..didLoadFrame();
    expect(guard.isShowingOwnHtml, isFalse);
  });

  test('a new HTML load trusts the frame again', () {
    guard
      ..expectOwnHtml()
      ..didLoadFrame()
      ..didLoadFrame()
      ..expectOwnHtml();
    expect(guard.isShowingOwnHtml, isTrue);
  });

  test('a URL load clears trust, and later loads keep it cleared', () {
    guard
      ..expectOwnHtml()
      ..expectNavigation()
      ..didLoadFrame();
    expect(guard.isShowingOwnHtml, isFalse);
  });

  test('loads without an expectation change nothing', () {
    guard.didLoadFrame();
    expect(guard.isShowingOwnHtml, isFalse);
  });
}
