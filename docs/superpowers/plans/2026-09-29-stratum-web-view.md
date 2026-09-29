# StratumWebView Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `StratumWebView`, one web view widget for Android, iOS, macOS, Windows, Linux, and Web, with URL and HTML sources, navigation control, and an origin-checked two-way message bridge.

**Architecture:** A public widget and controller delegate to an internal `PlatformStratumWebView` contract. A conditional export picks the web implementation (own `<iframe>` via `package:web`) or the native one; on native, a runtime `defaultTargetPlatform` switch picks the `webview_flutter` adapter (Android, iOS, macOS) or the `webview_all_*` adapter (Windows, Linux). Security and bookkeeping rules live in pure Dart classes under `platform/shared/` so they are tested on the VM.

**Tech Stack:** Flutter ≥ 3.41, Dart 3.13, `webview_flutter` 4.14.1, `webview_all_windows` / `webview_all_linux` / `webview_platform_interface` 1.4.3, `package:web` 1.1.1, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-29-stratum-web-view-design.md`

## Global Constraints

- Environment: `sdk: ^3.13.3` (unchanged) and `flutter: ">=3.41.0"`.
- Dependencies, exact strings: `web: ^1.1.1`, `webview_all_linux: ^1.4.3`, `webview_all_windows: ^1.4.3`, `webview_flutter: ^4.14.1`, `webview_platform_interface: ^1.4.3`; dev: `webview_flutter_platform_interface: ^2.15.1`.
- **Never import `package:stratum_ui/src/src.dart` or `package:stratum_ui/stratum_ui.dart`** from any file under `lib/src/components/common/web_view/`, its tests, or the example. The package has about 190 compile errors outside `web_view/` (probe on 2026-09-29: a test importing `src.dart` fails with `'SystemUiOverlayStyle' isn't a type`). Import `package:flutter/foundation.dart`, `package:flutter/widgets.dart`, and web_view files by their `package:stratum_ui/src/components/common/web_view/...` path.
- Constructors use the repository's `new(...)` / `const new(...)` syntax (verified to analyze cleanly with Dart 3.13.3, including initializer lists, bodies, and `const factory X.named(...) = Y;`).
- Lines stay within 80 characters (`lines_longer_than_80_chars` from `very_good_analysis`); import directives are exempt. Run `dart format` on touched files.
- Scoped verification only; the whole-project `flutter analyze` and `flutter test` fail before this work starts (251 analyzer issues, and `test/stratum_ui_test.dart` references a missing `Calculator`):
  - `flutter analyze lib/src/components/common/web_view test/src/components/common/web_view` → `No issues found!`
  - `flutter test test/src/components/common/web_view` → all VM tests pass (the browser test is skipped by `@TestOn('browser')`).
  - `flutter test --platform chrome test/src/components/common/web_view/platform/platform_web_view_web_test.dart` → all pass.
- Bridge channel name on native: `StratumBridge`.
- An empty `allowedOrigins` disables the bridge entirely, HTML content included; the controller enforces this.
- Commits: the repository has no commits yet and the owner has not confirmed committing. Before the first commit step, ask the owner once. If the owner declines or does not answer, skip every commit step. Commit messages never carry a `Co-Authored-By` line or any AI attribution.

## Review Focus

1. **The source changes twice in quick succession** (for example a URL typed into a search box): the last source must win. Test in Task 8, `keeps the latest source when it changes twice`.
2. **`postMessage` before any page has loaded:** throws `StateError` instead of sending to an unknown page. Tests in Task 6 (`refuses to build a script before any page`), Task 9 contract (`refuses to post before any page starts`), Task 12 (`refuses to post before any content loads`).
3. **The page sends a non-string message on web** (`postMessage({...})`): dropped, never crashes the handler. Test in Task 12, `drops messages from other windows, other origins, and non-strings`.
4. **The web view is removed and re-inserted on web** (tab switch): the iframe reloads, and the HTML bridge must keep working. Test in Task 12, `re-inserting the view re-arms the HTML bridge`.
5. **An allowlist entry written with a path or trailing slash** (`https://app.example.com/app/`): still matches by origin. Test in Task 2, `allowlist entries with paths match by origin`.

## File Map

```
lib/src/components/common/
  common.dart                                   # modify: export web_view barrel
  web_view/
    web_view.dart                               # barrel (public symbols only)
    stratum_web_view.dart                       # StratumWebView widget
    stratum_web_view_controller.dart            # controller, configuration, listener
    stratum_web_view_types.dart                 # source, message, decision, error
    platform/
      platform_web_view_interface.dart          # PlatformStratumWebView + listener
      platform_web_view.dart                    # conditional export
      platform_web_view_stub.dart               # unsupported platforms
      platform_web_view_io.dart                 # native adapter selection
      platform_web_view_web.dart                # iframe implementation
      adapters/
        webview_flutter_adapter.dart            # Android, iOS, macOS
        webview_all_adapter.dart                # Windows, Linux
      shared/
        origin_policy.dart                      # originOf, isAllowedOrigin
        html_frame_guard.dart                   # own-HTML tracking
        web_view_history.dart                   # controller history (web)
        message_script.dart                     # Flutter-to-page script
        native_bridge_session.dart              # native bridge + error rules
test/src/components/common/web_view/
  stratum_web_view_types_test.dart
  stratum_web_view_controller_test.dart
  stratum_web_view_test.dart
  fakes/
    fake_platform_stratum_web_view.dart
    recording_listener.dart
    fake_webview_flutter_platform.dart
    fake_webview_all_platform.dart
  platform/
    platform_web_view_io_test.dart
    platform_web_view_web_test.dart
    adapters/
      native_adapter_contract.dart
      webview_flutter_adapter_test.dart
      webview_all_adapter_test.dart
    shared/
      origin_policy_test.dart
      html_frame_guard_test.dart
      web_view_history_test.dart
      message_script_test.dart
      native_bridge_session_test.dart
example/                                        # new Flutter app (Task 13)
```

---

### Task 1: Dependencies and public types

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/src/components/common/web_view/stratum_web_view_types.dart`
- Test: `test/src/components/common/web_view/stratum_web_view_types_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `sealed class StratumWebViewSource` with `const factory StratumWebViewSource.url(Uri url)` and `const factory StratumWebViewSource.html(String html)`; subclasses `StratumWebViewUrlSource { Uri url }`, `StratumWebViewHtmlSource { String html }` with value equality; `StratumWebViewMessage { String data; Uri? origin }`; `enum StratumNavigationDecision { navigate, prevent }`; `enum StratumWebViewErrorType { network, http }`; `StratumWebViewError { StratumWebViewErrorType type; String description; int? code; Uri? url }`. Message and error have value equality.

- [ ] **Step 1: Run the dependency check**

Invoke the `dart-engineer-pack:add-new-pubspec-decision` skill for the five new dependencies listed in Global Constraints. The spec (section 2) records the evaluation; stop only if the skill surfaces a blocker not covered there.

- [ ] **Step 2: Edit `pubspec.yaml`**

Replace the `environment`, `dependencies`, and `dev_dependencies` blocks with:

```yaml
environment:
  sdk: ^3.13.3
  flutter: ">=3.41.0"

dependencies:
  flutter:
    sdk: flutter
  country_flags: ^4.1.2
  freezed_annotation: ^3.1.0
  json_annotation: ^4.12.0
  web: ^1.1.1
  webview_all_linux: ^1.4.3
  webview_all_windows: ^1.4.3
  webview_flutter: ^4.14.1
  webview_platform_interface: ^1.4.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.16.1
  fake_async: ^1.3.3
  freezed: ^4.0.2
  very_good_analysis: ^11.0.0
  webview_flutter_platform_interface: ^2.15.1
```

Run: `flutter pub get`
Expected: `Got dependencies!` (or `Changed N dependencies!`) and exit code 0.

- [ ] **Step 3: Write the failing test**

Create `test/src/components/common/web_view/stratum_web_view_types_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

void main() {
  group('StratumWebViewSource', () {
    test('url sources compare by URL', () {
      expect(
        StratumWebViewSource.url(Uri.parse('https://app.example.com')),
        StratumWebViewSource.url(Uri.parse('https://app.example.com')),
      );
      expect(
        StratumWebViewSource.url(Uri.parse('https://app.example.com')),
        isNot(StratumWebViewSource.url(Uri.parse('https://example.net'))),
      );
    });

    test('html sources compare by content', () {
      expect(
        const StratumWebViewSource.html('<p>A</p>'),
        const StratumWebViewSource.html('<p>A</p>'),
      );
      expect(
        const StratumWebViewSource.html('<p>A</p>'),
        isNot(const StratumWebViewSource.html('<p>B</p>')),
      );
    });

    test('factories create the matching subclass', () {
      expect(
        StratumWebViewSource.url(Uri.parse('https://app.example.com')),
        isA<StratumWebViewUrlSource>(),
      );
      expect(
        const StratumWebViewSource.html('<p>A</p>'),
        isA<StratumWebViewHtmlSource>(),
      );
    });
  });

  test('messages compare by data and origin', () {
    final origin = Uri.parse('https://app.example.com');
    expect(
      StratumWebViewMessage(data: 'hi', origin: origin),
      StratumWebViewMessage(data: 'hi', origin: origin),
    );
    expect(
      const StratumWebViewMessage(data: 'hi'),
      isNot(StratumWebViewMessage(data: 'hi', origin: origin)),
    );
  });

  test('errors compare by every field', () {
    final url = Uri.parse('https://app.example.com');
    expect(
      StratumWebViewError(
        type: StratumWebViewErrorType.http,
        description: 'HTTP error 500',
        code: 500,
        url: url,
      ),
      StratumWebViewError(
        type: StratumWebViewErrorType.http,
        description: 'HTTP error 500',
        code: 500,
        url: url,
      ),
    );
  });
}
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `flutter test test/src/components/common/web_view/stratum_web_view_types_test.dart`
Expected: FAIL, compilation error `Target of URI doesn't exist` / `Undefined name 'StratumWebViewSource'`.

- [ ] **Step 5: Write the implementation**

Create `lib/src/components/common/web_view/stratum_web_view_types.dart`:

```dart
import 'package:flutter/foundation.dart';

/// Content displayed by a `StratumWebView`.
@immutable
sealed class StratumWebViewSource {
  const new();

  /// A page loaded from [url].
  const factory StratumWebViewSource.url(Uri url) = StratumWebViewUrlSource;

  /// A document rendered from an [html] string.
  const factory StratumWebViewSource.html(String html) =
      StratumWebViewHtmlSource;
}

/// A [StratumWebViewSource] that loads the page at [url].
final class StratumWebViewUrlSource extends StratumWebViewSource {
  const new(this.url);

  /// Address of the page.
  final Uri url;

  @override
  bool operator ==(Object other) =>
      other is StratumWebViewUrlSource && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'StratumWebViewSource.url($url)';
}

/// A [StratumWebViewSource] that renders an [html] string.
final class StratumWebViewHtmlSource extends StratumWebViewSource {
  const new(this.html);

  /// The HTML document.
  final String html;

  @override
  bool operator ==(Object other) =>
      other is StratumWebViewHtmlSource && other.html == html;

  @override
  int get hashCode => html.hashCode;

  @override
  String toString() => 'StratumWebViewSource.html(${html.length} chars)';
}

/// A message that the page sent through the bridge.
@immutable
final class StratumWebViewMessage {
  const new({required this.data, this.origin});

  /// Message payload. Encode structured data yourself, for example as JSON.
  final String data;

  /// Origin of the page that sent the message, or `null` for HTML content
  /// loaded from a [StratumWebViewHtmlSource].
  final Uri? origin;

  @override
  bool operator ==(Object other) =>
      other is StratumWebViewMessage &&
      other.data == data &&
      other.origin == origin;

  @override
  int get hashCode => Object.hash(data, origin);

  @override
  String toString() => 'StratumWebViewMessage(data: $data, origin: $origin)';
}

/// Whether a web view may continue a navigation.
enum StratumNavigationDecision {
  /// Continue loading the page.
  navigate,

  /// Stop the navigation.
  prevent,
}

/// Kind of failure reported through `StratumWebView.onError`.
enum StratumWebViewErrorType {
  /// The page could not be reached: DNS, TLS, connection, or timeout.
  network,

  /// The server answered the page request with an HTTP error status.
  http,
}

/// A main-frame loading failure on a native platform.
@immutable
final class StratumWebViewError {
  const new({
    required this.type,
    required this.description,
    this.code,
    this.url,
  });

  /// Kind of failure.
  final StratumWebViewErrorType type;

  /// Human-readable description from the platform.
  final String description;

  /// Platform error code for [StratumWebViewErrorType.network], HTTP status
  /// for [StratumWebViewErrorType.http].
  final int? code;

  /// Address that failed to load, when the platform reports it.
  final Uri? url;

  @override
  bool operator ==(Object other) =>
      other is StratumWebViewError &&
      other.type == type &&
      other.description == description &&
      other.code == code &&
      other.url == url;

  @override
  int get hashCode => Object.hash(type, description, code, url);

  @override
  String toString() =>
      'StratumWebViewError(${type.name}, $code, $description, $url)';
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/src/components/common/web_view/stratum_web_view_types_test.dart`
Expected: PASS, `All tests passed!`

- [ ] **Step 7: Analyze and format**

Run: `dart format lib/src/components/common/web_view test/src/components/common/web_view && flutter analyze lib/src/components/common/web_view test/src/components/common/web_view`
Expected: `No issues found!`

- [ ] **Step 8: Commit** (only if the owner confirmed committing; see Global Constraints)

```bash
git add pubspec.yaml pubspec.lock lib/src/components/common/web_view/stratum_web_view_types.dart test/src/components/common/web_view/stratum_web_view_types_test.dart
git commit -m "feat(web_view): add web view dependencies and public types"
```

---

### Task 2: Origin policy (owner contribution)

**Files:**
- Create: `lib/src/components/common/web_view/platform/shared/origin_policy.dart`
- Test: `test/src/components/common/web_view/platform/shared/origin_policy_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `Uri? originOf(Uri? url)` (lowercase scheme and host, port; `null` without host) and `bool isAllowedOrigin(Uri? origin, Set<Uri> allowed)`.

- [ ] **Step 1: Write the failing test**

Create `test/src/components/common/web_view/platform/shared/origin_policy_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/origin_policy.dart';

void main() {
  group('originOf', () {
    test('drops path, query, and fragment', () {
      expect(
        originOf(Uri.parse('https://app.example.com/a/b?q=1#top')),
        Uri.parse('https://app.example.com'),
      );
    });

    test('lowercases scheme and host', () {
      expect(
        originOf(Uri.parse('HTTPS://App.Example.COM')),
        Uri.parse('https://app.example.com'),
      );
    });

    test('keeps a non-default port', () {
      expect(
        originOf(Uri.parse('https://app.example.com:8443/x')),
        Uri.parse('https://app.example.com:8443'),
      );
    });

    test('returns null without a host', () {
      expect(originOf(null), isNull);
      expect(originOf(Uri.parse('about:blank')), isNull);
      expect(originOf(Uri.parse('null')), isNull);
    });
  });

  group('isAllowedOrigin', () {
    final allowed = {Uri.parse('https://app.example.com')};

    test('matches the same origin with any path', () {
      expect(
        isAllowedOrigin(Uri.parse('https://app.example.com/page'), allowed),
        isTrue,
      );
    });

    test('treats an explicit default port as equal', () {
      expect(
        isAllowedOrigin(Uri.parse('https://app.example.com:443'), allowed),
        isTrue,
      );
    });

    test('compares hosts case-insensitively', () {
      expect(
        isAllowedOrigin(Uri.parse('https://APP.example.com'), allowed),
        isTrue,
      );
    });

    test('rejects another scheme', () {
      expect(
        isAllowedOrigin(Uri.parse('http://app.example.com'), allowed),
        isFalse,
      );
    });

    test('rejects another port', () {
      expect(
        isAllowedOrigin(Uri.parse('https://app.example.com:8443'), allowed),
        isFalse,
      );
    });

    test('rejects a subdomain and a lookalike suffix', () {
      expect(
        isAllowedOrigin(Uri.parse('https://evil.app.example.com'), allowed),
        isFalse,
      );
      expect(
        isAllowedOrigin(Uri.parse('https://app.example.com.evil.io'), allowed),
        isFalse,
      );
    });

    test('rejects null and host-less origins', () {
      expect(isAllowedOrigin(null, allowed), isFalse);
      expect(isAllowedOrigin(Uri.parse('null'), allowed), isFalse);
    });

    test('rejects everything when the allowlist is empty', () {
      expect(
        isAllowedOrigin(Uri.parse('https://app.example.com'), const {}),
        isFalse,
      );
    });

    test('allowlist entries with paths match by origin', () {
      expect(
        isAllowedOrigin(
          Uri.parse('https://app.example.com/other'),
          {Uri.parse('https://app.example.com/app/')},
        ),
        isTrue,
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/src/components/common/web_view/platform/shared/origin_policy_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write `originOf` and the `isAllowedOrigin` signature**

Create `lib/src/components/common/web_view/platform/shared/origin_policy.dart`:

```dart
/// Returns the origin of [url]: lowercase scheme and host, plus the port.
///
/// Returns `null` when [url] is `null` or has no host, for example
/// `about:blank` or the opaque origin string `null`.
Uri? originOf(Uri? url) {
  if (url == null || url.host.isEmpty) return null;
  return Uri(
    scheme: url.scheme.toLowerCase(),
    host: url.host.toLowerCase(),
    port: url.port,
  );
}

/// Whether [origin] belongs to one of the [allowed] origins.
///
/// Entries match on scheme, host, and port. Host comparison ignores case, a
/// default port equals an explicit one (`https://a.com` matches
/// `https://a.com:443`), and path, query, and fragment are ignored. A `null`
/// or host-less [origin] never matches.
bool isAllowedOrigin(Uri? origin, Set<Uri> allowed) {
  // Owner contribution: see Task 2, Step 4.
  throw UnimplementedError('isAllowedOrigin');
}
```

- [ ] **Step 4: Owner contribution (learning mode)**

Pause and ask the owner to replace the body of `isAllowedOrigin`. Explain: this function decides which pages may talk to the app over the bridge; the tests from Step 1 define the contract; `originOf` already normalizes both sides. Wait for the owner's code. Use this reference implementation only if the owner declines:

```dart
bool isAllowedOrigin(Uri? origin, Set<Uri> allowed) {
  final candidate = originOf(origin);
  if (candidate == null) return false;
  return allowed.any((entry) => originOf(entry) == candidate);
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/src/components/common/web_view/platform/shared/origin_policy_test.dart`
Expected: PASS, `All tests passed!`

- [ ] **Step 6: Analyze and format**

Run: `dart format lib/src/components/common/web_view test/src/components/common/web_view && flutter analyze lib/src/components/common/web_view test/src/components/common/web_view`
Expected: `No issues found!`

- [ ] **Step 7: Commit** (only if confirmed)

```bash
git add lib/src/components/common/web_view/platform/shared/origin_policy.dart test/src/components/common/web_view/platform/shared/origin_policy_test.dart
git commit -m "feat(web_view): add origin policy for the message bridge"
```

---

### Task 3: HtmlFrameGuard

**Files:**
- Create: `lib/src/components/common/web_view/platform/shared/html_frame_guard.dart`
- Test: `test/src/components/common/web_view/platform/shared/html_frame_guard_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `final class HtmlFrameGuard` with `bool get isShowingOwnHtml`, `void expectOwnHtml()`, `void expectNavigation()`, `void didLoadFrame()`.

- [ ] **Step 1: Write the failing test**

Create `test/src/components/common/web_view/platform/shared/html_frame_guard_test.dart`:

```dart
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/src/components/common/web_view/platform/shared/html_frame_guard_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

Create `lib/src/components/common/web_view/platform/shared/html_frame_guard.dart`:

```dart
/// Tracks whether a frame still shows HTML that the controller loaded.
///
/// HTML content has no verifiable origin (web reports the opaque origin
/// `null`, native reports `about:blank`). A page that the user reaches from
/// that HTML can look the same, so the guard counts loads instead:
///
/// * Call [expectOwnHtml] right before loading HTML content.
/// * Call [expectNavigation] right before loading a URL.
/// * Call [didLoadFrame] for every main-frame load that the platform reports
///   (the iframe `load` event on web, `onPageStarted` on native).
///
/// The first load after [expectOwnHtml] is the controller's HTML. Any later
/// load means the frame navigated away.
final class HtmlFrameGuard {
  _FrameState _state = _FrameState.idle;

  /// Whether messages without a verifiable origin may be exchanged.
  bool get isShowingOwnHtml =>
      _state == _FrameState.awaitingLoad || _state == _FrameState.showing;

  /// Marks that the controller is about to load HTML content.
  void expectOwnHtml() {
    _state = _FrameState.awaitingLoad;
  }

  /// Marks that the controller is about to load a URL.
  void expectNavigation() {
    _state = _FrameState.idle;
  }

  /// Records a main-frame load reported by the platform.
  void didLoadFrame() {
    _state = switch (_state) {
      _FrameState.awaitingLoad => _FrameState.showing,
      _FrameState.showing => _FrameState.navigatedAway,
      _FrameState.idle => _FrameState.idle,
      _FrameState.navigatedAway => _FrameState.navigatedAway,
    };
  }
}

enum _FrameState { idle, awaitingLoad, showing, navigatedAway }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/src/components/common/web_view/platform/shared/html_frame_guard_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze and format**

Run: `dart format lib/src/components/common/web_view test/src/components/common/web_view && flutter analyze lib/src/components/common/web_view test/src/components/common/web_view`
Expected: `No issues found!`

- [ ] **Step 6: Commit** (only if confirmed)

```bash
git add lib/src/components/common/web_view/platform/shared/html_frame_guard.dart test/src/components/common/web_view/platform/shared/html_frame_guard_test.dart
git commit -m "feat(web_view): track whether a frame still shows loaded HTML"
```

---

### Task 4: WebViewHistory

**Files:**
- Create: `lib/src/components/common/web_view/platform/shared/web_view_history.dart`
- Test: `test/src/components/common/web_view/platform/shared/web_view_history_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `final class WebViewHistory<T>` with `T? get current`, `bool get canGoBack`, `bool get canGoForward`, `void push(T entry)`, `T? back()`, `T? forward()`.

- [ ] **Step 1: Write the failing test**

Create `test/src/components/common/web_view/platform/shared/web_view_history_test.dart`:

```dart
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/src/components/common/web_view/platform/shared/web_view_history_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

Create `lib/src/components/common/web_view/platform/shared/web_view_history.dart`:

```dart
/// Linear history of loads that the controller started.
///
/// The web implementation keeps its own history because the browser hides a
/// cross-origin iframe's history from the parent page.
final class WebViewHistory<T> {
  final List<T> _entries = <T>[];
  int _index = -1;

  /// The entry currently shown, or `null` before the first [push].
  T? get current => _index < 0 ? null : _entries[_index];

  /// Whether [back] has an entry to return.
  bool get canGoBack => _index > 0;

  /// Whether [forward] has an entry to return.
  bool get canGoForward => _index < _entries.length - 1;

  /// Adds [entry] after the current entry and drops any forward entries.
  void push(T entry) {
    _entries
      ..removeRange(_index + 1, _entries.length)
      ..add(entry);
    _index = _entries.length - 1;
  }

  /// Moves one entry back and returns it, or returns `null` at the start.
  T? back() {
    if (!canGoBack) return null;
    _index--;
    return current;
  }

  /// Moves one entry forward and returns it, or returns `null` at the end.
  T? forward() {
    if (!canGoForward) return null;
    _index++;
    return current;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/src/components/common/web_view/platform/shared/web_view_history_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze and format**

Run: `dart format lib/src/components/common/web_view test/src/components/common/web_view && flutter analyze lib/src/components/common/web_view test/src/components/common/web_view`
Expected: `No issues found!`

- [ ] **Step 6: Commit** (only if confirmed)

```bash
git add lib/src/components/common/web_view/platform/shared/web_view_history.dart test/src/components/common/web_view/platform/shared/web_view_history_test.dart
git commit -m "feat(web_view): add controller navigation history"
```

---

### Task 5: Message script

**Files:**
- Create: `lib/src/components/common/web_view/platform/shared/message_script.dart`
- Test: `test/src/components/common/web_view/platform/shared/message_script_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `String buildMessageDispatchScript(String data)`, returning exactly `'window.dispatchEvent(new MessageEvent("message", {data: <literal>}));'`.

- [ ] **Step 1: Write the failing test**

Create `test/src/components/common/web_view/platform/shared/message_script_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/message_script.dart';

const _prefix = 'window.dispatchEvent(new MessageEvent("message", {data: ';
const _suffix = '}));';

/// Returns the JavaScript string literal embedded in [script].
String _literal(String script) {
  expect(script, startsWith(_prefix));
  expect(script, endsWith(_suffix));
  return script.substring(_prefix.length, script.length - _suffix.length);
}

void main() {
  test('wraps the data in a message event', () {
    expect(
      buildMessageDispatchScript('hello'),
      '$_prefix"hello"$_suffix',
    );
  });

  test('round-trips data that needs escaping', () {
    const samples = [
      'say "hi"',
      r'back\slash',
      'line\nbreak',
      '</script><script>alert(1)</script>',
      '{"type":"refresh","id":7}',
      'emoji 🎉 and ไทย',
    ];
    for (final sample in samples) {
      final literal = _literal(buildMessageDispatchScript(sample));
      expect(jsonDecode(literal), sample, reason: sample);
    }
  });

  test('escapes U+2028 and U+2029 for pre-ES2019 engines', () {
    final literal = _literal(buildMessageDispatchScript('a b c'));
    expect(literal, isNot(contains(' ')));
    expect(literal, isNot(contains(' ')));
    expect(literal, r'"a b c"');
    expect(jsonDecode(literal), 'a b c');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/src/components/common/web_view/platform/shared/message_script_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

Create `lib/src/components/common/web_view/platform/shared/message_script.dart`:

```dart
import 'dart:convert';

/// Builds a script that delivers [data] to the page as a `message` event.
///
/// [jsonEncode] turns [data] into a valid JavaScript string literal: quotes,
/// backslashes, and control characters are escaped. U+2028 and U+2029 are
/// escaped too, because engines older than ES2019 reject them inside string
/// literals. `</script>` needs no escaping: native platforms evaluate the
/// script directly, without an HTML parser.
String buildMessageDispatchScript(String data) {
  final literal = jsonEncode(
    data,
  ).replaceAll(' ', r' ').replaceAll(' ', r' ');
  return 'window.dispatchEvent(new MessageEvent("message", '
      '{data: $literal}));';
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/src/components/common/web_view/platform/shared/message_script_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze and format**

Run: `dart format lib/src/components/common/web_view test/src/components/common/web_view && flutter analyze lib/src/components/common/web_view test/src/components/common/web_view`
Expected: `No issues found!`

- [ ] **Step 6: Commit** (only if confirmed)

```bash
git add lib/src/components/common/web_view/platform/shared/message_script.dart test/src/components/common/web_view/platform/shared/message_script_test.dart
git commit -m "feat(web_view): build the Flutter-to-page message script"
```

---

### Task 6: NativeBridgeSession

**Files:**
- Create: `lib/src/components/common/web_view/platform/shared/native_bridge_session.dart`
- Test: `test/src/components/common/web_view/platform/shared/native_bridge_session_test.dart`

**Interfaces:**
- Consumes: `HtmlFrameGuard` (Task 3); `originOf`, `isAllowedOrigin` (Task 2); `buildMessageDispatchScript` (Task 5); `StratumWebViewMessage`, `StratumWebViewError`, `StratumWebViewErrorType` (Task 1).
- Produces: `const String bridgeChannelName = 'StratumBridge';` and `final class NativeBridgeSession` with `new({required Set<Uri> Function() allowedOrigins})`, `Uri? get pageUrl`, `void willLoadUrl()`, `void willLoadHtml()`, `void willReload()`, `void didStartPage(String url)`, `void didChangeUrl(String? url)`, `StratumWebViewMessage? acceptMessage(String data)`, `String scriptForMessage(String data)` (throws `StateError`), `StratumWebViewError? networkError({required int code, required String description, required bool? isForMainFrame, required String? url})`, `StratumWebViewError? httpError({required int? statusCode, required Uri? requestUrl})`.

- [ ] **Step 1: Write the failing test**

Create `test/src/components/common/web_view/platform/shared/native_bridge_session_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/message_script.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/native_bridge_session.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

void main() {
  final appOrigin = Uri.parse('https://app.example.com');
  late Set<Uri> allowed;
  late NativeBridgeSession session;

  setUp(() {
    allowed = {appOrigin};
    session = NativeBridgeSession(allowedOrigins: () => allowed);
  });

  group('messages from URL pages', () {
    test('accepts an allowed page and reports its origin', () {
      session
        ..willLoadUrl()
        ..didStartPage('https://app.example.com/home');
      expect(
        session.acceptMessage('hi'),
        StratumWebViewMessage(data: 'hi', origin: appOrigin),
      );
    });

    test('drops a page outside the allowlist', () {
      session
        ..willLoadUrl()
        ..didStartPage('https://evil.example.net/');
      expect(session.acceptMessage('hi'), isNull);
    });

    test('follows URL changes without a page load', () {
      session
        ..willLoadUrl()
        ..didStartPage('https://app.example.com/home')
        ..didChangeUrl('https://evil.example.net/');
      expect(session.acceptMessage('hi'), isNull);
    });

    test('reads the allowlist at message time', () {
      session
        ..willLoadUrl()
        ..didStartPage('https://app.example.com/home');
      allowed = {Uri.parse('https://other.example.net')};
      expect(session.acceptMessage('hi'), isNull);
    });
  });

  group('messages from loaded HTML', () {
    test('accepts messages without an origin', () {
      session
        ..willLoadHtml()
        ..didStartPage('about:blank');
      expect(
        session.acceptMessage('hi'),
        const StratumWebViewMessage(data: 'hi'),
      );
    });

    test('drops messages after the page navigates away', () {
      session
        ..willLoadHtml()
        ..didStartPage('about:blank')
        ..didStartPage('https://evil.example.net/');
      expect(session.acceptMessage('hi'), isNull);
    });

    test('reload keeps the HTML trusted', () {
      session
        ..willLoadHtml()
        ..didStartPage('about:blank')
        ..willReload()
        ..didStartPage('about:blank');
      expect(session.acceptMessage('hi'), isNotNull);
    });

    test('reload after navigating away does not restore trust', () {
      session
        ..willLoadHtml()
        ..didStartPage('about:blank')
        ..didStartPage('https://evil.example.net/')
        ..willReload()
        ..didStartPage('https://evil.example.net/');
      expect(session.acceptMessage('hi'), isNull);
    });
  });

  group('scriptForMessage', () {
    test('builds the dispatch script for an allowed page', () {
      session
        ..willLoadUrl()
        ..didStartPage('https://app.example.com/');
      expect(
        session.scriptForMessage('ping'),
        buildMessageDispatchScript('ping'),
      );
    });

    test('refuses a page outside the allowlist', () {
      session
        ..willLoadUrl()
        ..didStartPage('https://evil.example.net/');
      expect(() => session.scriptForMessage('ping'), throwsStateError);
    });

    test('refuses to build a script before any page', () {
      expect(() => session.scriptForMessage('ping'), throwsStateError);
    });

    test('allows loaded HTML', () {
      session
        ..willLoadHtml()
        ..didStartPage('about:blank');
      expect(session.scriptForMessage('ping'), isNotEmpty);
    });
  });

  group('errors', () {
    test('maps main-frame network errors, treating null as main frame', () {
      const expected = StratumWebViewError(
        type: StratumWebViewErrorType.network,
        description: 'offline',
        code: -2,
      );
      expect(
        session.networkError(
          code: -2,
          description: 'offline',
          isForMainFrame: true,
          url: null,
        ),
        expected,
      );
      expect(
        session.networkError(
          code: -2,
          description: 'offline',
          isForMainFrame: null,
          url: null,
        ),
        expected,
      );
    });

    test('drops sub-frame network errors', () {
      expect(
        session.networkError(
          code: -2,
          description: 'offline',
          isForMainFrame: false,
          url: 'https://ads.example.net/',
        ),
        isNull,
      );
    });

    test('maps HTTP errors for the current page only', () {
      session.didStartPage('https://app.example.com/home');
      expect(
        session.httpError(
          statusCode: 404,
          requestUrl: Uri.parse('https://app.example.com/logo.png'),
        ),
        isNull,
      );
      expect(
        session.httpError(
          statusCode: 500,
          requestUrl: Uri.parse('https://app.example.com/home#top'),
        ),
        StratumWebViewError(
          type: StratumWebViewErrorType.http,
          description: 'HTTP error 500',
          code: 500,
          url: Uri.parse('https://app.example.com/home#top'),
        ),
      );
    });

    test('drops HTTP errors before any page', () {
      expect(
        session.httpError(
          statusCode: 500,
          requestUrl: Uri.parse('https://app.example.com/'),
        ),
        isNull,
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/src/components/common/web_view/platform/shared/native_bridge_session_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

Create `lib/src/components/common/web_view/platform/shared/native_bridge_session.dart`:

```dart
import 'package:stratum_ui/src/components/common/web_view/platform/shared/html_frame_guard.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/message_script.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/origin_policy.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

/// Name of the JavaScript channel that pages call on native platforms.
const String bridgeChannelName = 'StratumBridge';

/// Bridge and error rules shared by the native adapters.
///
/// Adapters report platform events here and ask whether a message may pass.
/// The class holds no platform types, so both adapters use it unchanged.
final class NativeBridgeSession {
  new({required Set<Uri> Function() allowedOrigins})
    : _allowedOrigins = allowedOrigins;

  final Set<Uri> Function() _allowedOrigins;
  final HtmlFrameGuard _guard = HtmlFrameGuard();
  Uri? _pageUrl;
  bool _lastLoadWasHtml = false;

  /// URL of the current top-level page, as last reported by the platform.
  Uri? get pageUrl => _pageUrl;

  /// Call right before the adapter loads a URL.
  void willLoadUrl() {
    _lastLoadWasHtml = false;
    _guard.expectNavigation();
  }

  /// Call right before the adapter loads an HTML string.
  void willLoadHtml() {
    _lastLoadWasHtml = true;
    _guard.expectOwnHtml();
  }

  /// Call right before the adapter reloads the current page.
  void willReload() {
    if (_lastLoadWasHtml && _guard.isShowingOwnHtml) _guard.expectOwnHtml();
  }

  /// Call when the platform reports that a main-frame page started loading.
  void didStartPage(String url) {
    _pageUrl = Uri.tryParse(url);
    _guard.didLoadFrame();
  }

  /// Call when the platform reports a URL change without a page load.
  void didChangeUrl(String? url) {
    if (url != null) _pageUrl = Uri.tryParse(url);
  }

  /// Returns the message to deliver for [data], or `null` to drop it.
  StratumWebViewMessage? acceptMessage(String data) {
    if (_guard.isShowingOwnHtml) return StratumWebViewMessage(data: data);
    if (!isAllowedOrigin(_pageUrl, _allowedOrigins())) return null;
    return StratumWebViewMessage(data: data, origin: originOf(_pageUrl));
  }

  /// Returns the script that delivers [data] to the current page.
  ///
  /// Throws a [StateError] when the current page may not receive messages.
  String scriptForMessage(String data) {
    final allowed =
        _guard.isShowingOwnHtml ||
        isAllowedOrigin(_pageUrl, _allowedOrigins());
    if (!allowed) {
      throw StateError(
        'The current page ($_pageUrl) is not an allowed message destination.',
      );
    }
    return buildMessageDispatchScript(data);
  }

  /// Maps a platform resource error, or returns `null` for a sub-frame error.
  StratumWebViewError? networkError({
    required int code,
    required String description,
    required bool? isForMainFrame,
    required String? url,
  }) {
    if (!(isForMainFrame ?? true)) return null;
    return StratumWebViewError(
      type: StratumWebViewErrorType.network,
      description: description,
      code: code,
      url: url == null ? null : Uri.tryParse(url),
    );
  }

  /// Maps a platform HTTP error, or returns `null` when it concerns a
  /// sub-resource instead of the current page.
  ///
  /// Android reports HTTP errors for images and scripts too, without a
  /// main-frame flag, so the request URL is compared with the page URL.
  StratumWebViewError? httpError({
    required int? statusCode,
    required Uri? requestUrl,
  }) {
    final pageUrl = _pageUrl;
    if (requestUrl == null || pageUrl == null) return null;
    if (requestUrl.removeFragment() != pageUrl.removeFragment()) return null;
    return StratumWebViewError(
      type: StratumWebViewErrorType.http,
      description: statusCode == null ? 'HTTP error' : 'HTTP error $statusCode',
      code: statusCode,
      url: requestUrl,
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/src/components/common/web_view/platform/shared/native_bridge_session_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze and format**

Run: `dart format lib/src/components/common/web_view test/src/components/common/web_view && flutter analyze lib/src/components/common/web_view test/src/components/common/web_view`
Expected: `No issues found!`

- [ ] **Step 6: Commit** (only if confirmed)

```bash
git add lib/src/components/common/web_view/platform/shared/native_bridge_session.dart test/src/components/common/web_view/platform/shared/native_bridge_session_test.dart
git commit -m "feat(web_view): share native bridge and error rules"
```

---

### Task 7: Platform contract, stub, and controller

**Files:**
- Create: `lib/src/components/common/web_view/platform/platform_web_view_interface.dart`
- Create: `lib/src/components/common/web_view/platform/platform_web_view_stub.dart`
- Create: `lib/src/components/common/web_view/platform/platform_web_view.dart`
- Create: `lib/src/components/common/web_view/stratum_web_view_controller.dart`
- Create: `test/src/components/common/web_view/fakes/fake_platform_stratum_web_view.dart`
- Test: `test/src/components/common/web_view/stratum_web_view_controller_test.dart`

**Interfaces:**
- Consumes: types from Task 1.
- Produces:
  - `abstract interface class PlatformStratumWebViewListener` with `Set<Uri> get allowedOrigins`, `void onMessage(StratumWebViewMessage)`, `StratumNavigationDecision onNavigationRequest(Uri)`, `void onPageStarted(Uri?)`, `void onPageFinished(Uri?)`, `void onError(StratumWebViewError)`.
  - `abstract interface class PlatformStratumWebView` with `Future<void> setJavaScriptEnabled(bool enabled)`, `Future<void> load(StratumWebViewSource source)`, `Future<void> reload()`, `Future<void> goBack()`, `Future<void> goForward()`, `Future<bool> canGoBack()`, `Future<bool> canGoForward()`, `Future<Uri?> currentUrl()`, `Future<void> postMessage(String data)`, `Widget buildView(BuildContext context)`, `void dispose()`. A new instance starts with JavaScript enabled.
  - `typedef PlatformStratumWebViewFactory = PlatformStratumWebView Function(PlatformStratumWebViewListener listener);`
  - Top-level `PlatformStratumWebView createPlatformStratumWebView(PlatformStratumWebViewListener listener)` exported by `platform_web_view.dart`.
  - `@visibleForTesting PlatformStratumWebViewFactory? debugStratumWebViewPlatformFactory;`
  - `@internal final class StratumWebViewConfiguration` with fields `allowedOrigins`, `javaScriptEnabled`, `onMessage`, `onNavigationRequest`, `onPageStarted`, `onPageFinished`, `onError`.
  - `final class StratumWebViewController` with `new()`, `loadUrl(Uri)`, `loadHtml(String)`, `reload()`, `goBack()`, `goForward()`, `canGoBack()`, `canGoForward()`, `currentUrl()`, `postMessage(String)`, `dispose()`, and `@internal` `configure(StratumWebViewConfiguration)`, `buildView(BuildContext)`.
  - Test helper `List<FakePlatformStratumWebView> installFakePlatform()` and `const Key fakePlatformViewKey`.

- [ ] **Step 1: Write the platform contract**

Create `lib/src/components/common/web_view/platform/platform_web_view_interface.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

/// Receives events from a [PlatformStratumWebView].
///
/// `StratumWebViewController` implements this contract.
abstract interface class PlatformStratumWebViewListener {
  /// Origins allowed to use the bridge, read at event time.
  Set<Uri> get allowedOrigins;

  /// Delivers a message that passed the platform's origin rules.
  void onMessage(StratumWebViewMessage message);

  /// Decides whether a main-frame navigation to [url] may proceed.
  StratumNavigationDecision onNavigationRequest(Uri url);

  /// Reports that a page started loading.
  void onPageStarted(Uri? url);

  /// Reports that a page finished loading.
  void onPageFinished(Uri? url);

  /// Reports a main-frame loading failure.
  void onError(StratumWebViewError error);
}

/// One web view on the current platform.
///
/// A new instance starts with JavaScript enabled and no content.
abstract interface class PlatformStratumWebView {
  /// Enables or disables JavaScript for later loads.
  Future<void> setJavaScriptEnabled(bool enabled);

  /// Loads [source] and records it in the navigation history.
  Future<void> load(StratumWebViewSource source);

  /// Reloads the current page.
  Future<void> reload();

  /// Goes back one history entry, if any.
  Future<void> goBack();

  /// Goes forward one history entry, if any.
  Future<void> goForward();

  /// Whether [goBack] has an entry.
  Future<bool> canGoBack();

  /// Whether [goForward] has an entry.
  Future<bool> canGoForward();

  /// Best known URL of the current page.
  Future<Uri?> currentUrl();

  /// Sends [data] to the page as a `message` event.
  ///
  /// Throws a [StateError] when the current page may not receive messages.
  Future<void> postMessage(String data);

  /// Builds the widget that displays the page.
  Widget buildView(BuildContext context);

  /// Releases platform resources and stops event delivery.
  void dispose();
}

/// Creates the [PlatformStratumWebView] for the current platform.
typedef PlatformStratumWebViewFactory =
    PlatformStratumWebView Function(PlatformStratumWebViewListener listener);
```

- [ ] **Step 2: Write the stub and the (temporary) platform export**

Create `lib/src/components/common/web_view/platform/platform_web_view_stub.dart`:

```dart
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';

/// Fallback when neither `dart:io` nor `dart:js_interop` is available.
PlatformStratumWebView createPlatformStratumWebView(
  PlatformStratumWebViewListener listener,
) {
  throw UnsupportedError('StratumWebView is not supported on this platform.');
}
```

Create `lib/src/components/common/web_view/platform/platform_web_view.dart` (Tasks 11 and 12 add the conditional targets):

```dart
export 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_stub.dart';
```

- [ ] **Step 3: Write the test fake**

Create `test/src/components/common/web_view/fakes/fake_platform_stratum_web_view.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_controller.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

/// Key of the widget that [FakePlatformStratumWebView.buildView] returns.
const Key fakePlatformViewKey = ValueKey<String>('fake-platform-web-view');

/// Records every call that the controller makes.
final class FakePlatformStratumWebView implements PlatformStratumWebView {
  new(this.listener);

  final PlatformStratumWebViewListener listener;
  final List<StratumWebViewSource> loads = [];
  final List<bool> javaScriptChanges = [];
  final List<String> sentMessages = [];
  int reloadCount = 0;
  int backCount = 0;
  int forwardCount = 0;
  bool canGoBackValue = false;
  bool canGoForwardValue = false;
  Uri? currentUrlValue;
  StateError? postMessageError;
  bool disposed = false;

  @override
  Future<void> setJavaScriptEnabled(bool enabled) async =>
      javaScriptChanges.add(enabled);

  @override
  Future<void> load(StratumWebViewSource source) async => loads.add(source);

  @override
  Future<void> reload() async => reloadCount++;

  @override
  Future<void> goBack() async => backCount++;

  @override
  Future<void> goForward() async => forwardCount++;

  @override
  Future<bool> canGoBack() async => canGoBackValue;

  @override
  Future<bool> canGoForward() async => canGoForwardValue;

  @override
  Future<Uri?> currentUrl() async => currentUrlValue;

  @override
  Future<void> postMessage(String data) async {
    final error = postMessageError;
    if (error != null) throw error;
    sentMessages.add(data);
  }

  @override
  Widget buildView(BuildContext context) =>
      const SizedBox(key: fakePlatformViewKey);

  @override
  void dispose() => disposed = true;
}

/// Makes new controllers use fakes, and returns every fake they create.
///
/// Call from a test or `setUp`; the override is removed after the test.
List<FakePlatformStratumWebView> installFakePlatform() {
  final created = <FakePlatformStratumWebView>[];
  debugStratumWebViewPlatformFactory = (listener) {
    final fake = FakePlatformStratumWebView(listener);
    created.add(fake);
    return fake;
  };
  addTearDown(() => debugStratumWebViewPlatformFactory = null);
  return created;
}
```

- [ ] **Step 4: Write the failing controller test**

Create `test/src/components/common/web_view/stratum_web_view_controller_test.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_controller.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

import 'fakes/fake_platform_stratum_web_view.dart';

void main() {
  final appOrigin = Uri.parse('https://app.example.com');
  late List<FakePlatformStratumWebView> platforms;
  late StratumWebViewController controller;

  FakePlatformStratumWebView platform() => platforms.single;

  setUp(() {
    platforms = installFakePlatform();
    controller = StratumWebViewController();
  });

  test('loadUrl and loadHtml forward the source', () async {
    await controller.loadUrl(appOrigin);
    await controller.loadHtml('<p>Hi</p>');
    expect(platform().loads, [
      StratumWebViewSource.url(appOrigin),
      const StratumWebViewSource.html('<p>Hi</p>'),
    ]);
  });

  test('navigation methods forward to the platform', () async {
    platform()
      ..canGoBackValue = true
      ..canGoForwardValue = true
      ..currentUrlValue = Uri.parse('https://app.example.com/a');
    await controller.reload();
    await controller.goBack();
    await controller.goForward();
    expect(await controller.canGoBack(), isTrue);
    expect(await controller.canGoForward(), isTrue);
    expect(
      await controller.currentUrl(),
      Uri.parse('https://app.example.com/a'),
    );
    expect(
      [platform().reloadCount, platform().backCount, platform().forwardCount],
      [1, 1, 1],
    );
  });

  test('postMessage throws while allowedOrigins is empty', () async {
    await expectLater(controller.postMessage('x'), throwsStateError);
    expect(platform().sentMessages, isEmpty);
  });

  test('postMessage forwards once an origin is allowed', () async {
    controller.configure(
      StratumWebViewConfiguration(allowedOrigins: {appOrigin}),
    );
    await controller.postMessage('x');
    expect(platform().sentMessages, ['x']);
  });

  test('postMessage surfaces platform refusals', () async {
    controller.configure(
      StratumWebViewConfiguration(allowedOrigins: {appOrigin}),
    );
    platform().postMessageError = StateError('blocked');
    await expectLater(controller.postMessage('x'), throwsStateError);
  });

  test('configure forwards JavaScript only when it changes', () {
    controller
      ..configure(const StratumWebViewConfiguration())
      ..configure(const StratumWebViewConfiguration(javaScriptEnabled: false))
      ..configure(const StratumWebViewConfiguration(javaScriptEnabled: false));
    expect(platform().javaScriptChanges, [false]);
  });

  test('dispose releases the platform once and blocks later use', () async {
    controller
      ..dispose()
      ..dispose();
    expect(platform().disposed, isTrue);
    await expectLater(controller.loadUrl(appOrigin), throwsStateError);
    expect(
      () => controller.configure(const StratumWebViewConfiguration()),
      throwsStateError,
    );
  });

  group('listener', () {
    late List<StratumWebViewMessage> messages;

    setUp(() => messages = []);

    test('drops messages while allowedOrigins is empty', () {
      controller.configure(StratumWebViewConfiguration(onMessage: messages.add));
      platform().listener.onMessage(const StratumWebViewMessage(data: 'x'));
      expect(messages, isEmpty);
    });

    test('delivers messages when an origin is allowed', () {
      controller.configure(
        StratumWebViewConfiguration(
          allowedOrigins: {appOrigin},
          onMessage: messages.add,
        ),
      );
      platform().listener.onMessage(const StratumWebViewMessage(data: 'x'));
      expect(messages, [const StratumWebViewMessage(data: 'x')]);
    });

    test('reports a throwing callback without rethrowing', () {
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);
      controller.configure(
        StratumWebViewConfiguration(
          allowedOrigins: {appOrigin},
          onMessage: (_) => throw StateError('boom'),
        ),
      );
      platform().listener.onMessage(const StratumWebViewMessage(data: 'x'));
      expect(reported.single.exception, isStateError);
    });

    test('navigation defaults to navigate and fails closed on errors', () {
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);
      final listener = platform().listener;
      expect(
        listener.onNavigationRequest(appOrigin),
        StratumNavigationDecision.navigate,
      );
      controller.configure(
        StratumWebViewConfiguration(
          onNavigationRequest: (_) => throw StateError('boom'),
        ),
      );
      expect(
        listener.onNavigationRequest(appOrigin),
        StratumNavigationDecision.prevent,
      );
      expect(reported, hasLength(1));
    });

    test('forwards page and error events', () {
      final started = <Uri?>[];
      final finished = <Uri?>[];
      final errors = <StratumWebViewError>[];
      controller.configure(
        StratumWebViewConfiguration(
          onPageStarted: started.add,
          onPageFinished: finished.add,
          onError: errors.add,
        ),
      );
      const error = StratumWebViewError(
        type: StratumWebViewErrorType.network,
        description: 'offline',
      );
      platform().listener
        ..onPageStarted(appOrigin)
        ..onPageFinished(appOrigin)
        ..onError(error);
      expect(started, [appOrigin]);
      expect(finished, [appOrigin]);
      expect(errors, [error]);
    });

    test('ignores events after dispose', () {
      final started = <Uri?>[];
      controller
        ..configure(
          StratumWebViewConfiguration(
            allowedOrigins: {appOrigin},
            onMessage: messages.add,
            onPageStarted: started.add,
          ),
        )
        ..dispose();
      platform().listener
        ..onMessage(const StratumWebViewMessage(data: 'x'))
        ..onPageStarted(appOrigin);
      expect(messages, isEmpty);
      expect(started, isEmpty);
    });
  });
}
```

- [ ] **Step 5: Run the test to verify it fails**

Run: `flutter test test/src/components/common/web_view/stratum_web_view_controller_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:stratum_ui/src/components/common/web_view/stratum_web_view_controller.dart'`.

- [ ] **Step 6: Write the controller**

Create `lib/src/components/common/web_view/stratum_web_view_controller.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

/// Replaces the platform implementation for new controllers in tests.
@visibleForTesting
PlatformStratumWebViewFactory? debugStratumWebViewPlatformFactory;

/// Settings and callbacks that `StratumWebView` hands to its controller.
@internal
@immutable
final class StratumWebViewConfiguration {
  const new({
    this.allowedOrigins = const <Uri>{},
    this.javaScriptEnabled = true,
    this.onMessage,
    this.onNavigationRequest,
    this.onPageStarted,
    this.onPageFinished,
    this.onError,
  });

  final Set<Uri> allowedOrigins;
  final bool javaScriptEnabled;
  final ValueChanged<StratumWebViewMessage>? onMessage;
  final StratumNavigationDecision Function(Uri url)? onNavigationRequest;
  final ValueChanged<Uri?>? onPageStarted;
  final ValueChanged<Uri?>? onPageFinished;
  final ValueChanged<StratumWebViewError>? onError;
}

/// Loads content into a `StratumWebView`, controls its navigation, and sends
/// messages to the page.
///
/// A controller passed to `StratumWebView.controller` belongs to the caller,
/// who must call [dispose]. Every method throws a [StateError] after
/// [dispose].
final class StratumWebViewController {
  new() {
    final factory =
        debugStratumWebViewPlatformFactory ?? createPlatformStratumWebView;
    _platform = factory(_ControllerListener(this));
  }

  late final PlatformStratumWebView _platform;
  StratumWebViewConfiguration _configuration =
      const StratumWebViewConfiguration();
  bool _disposed = false;

  /// Loads the page at [url].
  Future<void> loadUrl(Uri url) async {
    _ensureActive();
    await _platform.load(StratumWebViewSource.url(url));
  }

  /// Renders the [html] document.
  Future<void> loadHtml(String html) async {
    _ensureActive();
    await _platform.load(StratumWebViewSource.html(html));
  }

  /// Reloads the current page.
  Future<void> reload() async {
    _ensureActive();
    await _platform.reload();
  }

  /// Goes back one page. On web, only pages the controller loaded count.
  Future<void> goBack() async {
    _ensureActive();
    await _platform.goBack();
  }

  /// Goes forward one page. On web, only pages the controller loaded count.
  Future<void> goForward() async {
    _ensureActive();
    await _platform.goForward();
  }

  /// Whether [goBack] has a page to return to.
  Future<bool> canGoBack() async {
    _ensureActive();
    return _platform.canGoBack();
  }

  /// Whether [goForward] has a page to return to.
  Future<bool> canGoForward() async {
    _ensureActive();
    return _platform.canGoForward();
  }

  /// URL of the current page. On web, a cross-origin page reports the last
  /// URL the controller loaded.
  Future<Uri?> currentUrl() async {
    _ensureActive();
    return _platform.currentUrl();
  }

  /// Sends [data] to the page as a `message` event.
  ///
  /// Throws a [StateError] when `StratumWebView.allowedOrigins` is empty or
  /// the current page is not an allowed destination.
  Future<void> postMessage(String data) async {
    _ensureActive();
    if (_configuration.allowedOrigins.isEmpty) {
      throw StateError(
        'The bridge is disabled because allowedOrigins is empty.',
      );
    }
    await _platform.postMessage(data);
  }

  /// Releases the platform web view. Later calls throw a [StateError].
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _platform.dispose();
  }

  /// Applies the settings of the `StratumWebView` that shows this controller.
  @internal
  void configure(StratumWebViewConfiguration configuration) {
    _ensureActive();
    final javaScriptChanged =
        configuration.javaScriptEnabled != _configuration.javaScriptEnabled;
    _configuration = configuration;
    if (javaScriptChanged) {
      unawaited(
        _platform.setJavaScriptEnabled(configuration.javaScriptEnabled),
      );
    }
  }

  /// Builds the platform view that displays the page.
  @internal
  Widget buildView(BuildContext context) {
    _ensureActive();
    return _platform.buildView(context);
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('A StratumWebViewController was used after dispose().');
    }
  }
}

final class _ControllerListener implements PlatformStratumWebViewListener {
  new(this._controller);

  final StratumWebViewController _controller;

  StratumWebViewConfiguration get _configuration => _controller._configuration;

  bool get _active => !_controller._disposed;

  @override
  Set<Uri> get allowedOrigins => _configuration.allowedOrigins;

  @override
  void onMessage(StratumWebViewMessage message) {
    final callback = _configuration.onMessage;
    if (!_active || allowedOrigins.isEmpty || callback == null) return;
    _guard('onMessage', () => callback(message));
  }

  @override
  StratumNavigationDecision onNavigationRequest(Uri url) {
    if (!_active) return StratumNavigationDecision.prevent;
    final callback = _configuration.onNavigationRequest;
    if (callback == null) return StratumNavigationDecision.navigate;
    try {
      return callback(url);
    } on Object catch (error, stack) {
      _report('onNavigationRequest', error, stack);
      return StratumNavigationDecision.prevent;
    }
  }

  @override
  void onPageStarted(Uri? url) {
    final callback = _configuration.onPageStarted;
    if (!_active || callback == null) return;
    _guard('onPageStarted', () => callback(url));
  }

  @override
  void onPageFinished(Uri? url) {
    final callback = _configuration.onPageFinished;
    if (!_active || callback == null) return;
    _guard('onPageFinished', () => callback(url));
  }

  @override
  void onError(StratumWebViewError error) {
    final callback = _configuration.onError;
    if (!_active || callback == null) return;
    _guard('onError', () => callback(error));
  }

  void _guard(String callbackName, VoidCallback body) {
    try {
      body();
    } on Object catch (error, stack) {
      _report(callbackName, error, stack);
    }
  }

  void _report(String callbackName, Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'stratum_ui',
        context: ErrorDescription('while calling StratumWebView.$callbackName'),
      ),
    );
  }
}
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `flutter test test/src/components/common/web_view/stratum_web_view_controller_test.dart`
Expected: PASS.

- [ ] **Step 8: Analyze and format**

Run: `dart format lib/src/components/common/web_view test/src/components/common/web_view && flutter analyze lib/src/components/common/web_view test/src/components/common/web_view`
Expected: `No issues found!`

- [ ] **Step 9: Commit** (only if confirmed)

```bash
git add lib/src/components/common/web_view/platform/platform_web_view_interface.dart lib/src/components/common/web_view/platform/platform_web_view_stub.dart lib/src/components/common/web_view/platform/platform_web_view.dart lib/src/components/common/web_view/stratum_web_view_controller.dart test/src/components/common/web_view/fakes/fake_platform_stratum_web_view.dart test/src/components/common/web_view/stratum_web_view_controller_test.dart
git commit -m "feat(web_view): add platform contract and StratumWebViewController"
```

---

### Task 8: StratumWebView widget and exports

**Files:**
- Create: `lib/src/components/common/web_view/stratum_web_view.dart`
- Create: `lib/src/components/common/web_view/web_view.dart`
- Modify: `lib/src/components/common/common.dart` (append one line)
- Test: `test/src/components/common/web_view/stratum_web_view_test.dart`

**Interfaces:**
- Consumes: `StratumWebViewController`, `StratumWebViewConfiguration`, `installFakePlatform`, `fakePlatformViewKey` (Task 7); types (Task 1).
- Produces: `class StratumWebView extends StatefulWidget` with `const new({Key? key, required StratumWebViewSource source, StratumWebViewController? controller, Set<Uri> allowedOrigins = const <Uri>{}, bool javaScriptEnabled = true, ValueChanged<StratumWebViewMessage>? onMessage, StratumNavigationDecision Function(Uri url)? onNavigationRequest, ValueChanged<Uri?>? onPageStarted, ValueChanged<Uri?>? onPageFinished, ValueChanged<StratumWebViewError>? onError})`; barrel `web_view.dart`.

- [ ] **Step 1: Write the failing widget test**

Create `test/src/components/common/web_view/stratum_web_view_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_controller.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

import 'fakes/fake_platform_stratum_web_view.dart';

void main() {
  final appOrigin = Uri.parse('https://app.example.com');
  final urlA = StratumWebViewSource.url(Uri.parse('https://app.example.com/a'));
  final urlB = StratumWebViewSource.url(Uri.parse('https://app.example.com/b'));
  late List<FakePlatformStratumWebView> platforms;

  setUp(() => platforms = installFakePlatform());

  testWidgets('creates a controller, loads the source, shows the view', (
    tester,
  ) async {
    await tester.pumpWidget(StratumWebView(source: urlA));
    expect(platforms.single.loads, [urlA]);
    expect(find.byKey(fakePlatformViewKey), findsOneWidget);
  });

  testWidgets('disposes the controller it created', (tester) async {
    await tester.pumpWidget(StratumWebView(source: urlA));
    await tester.pumpWidget(const SizedBox());
    expect(platforms.single.disposed, isTrue);
  });

  testWidgets('leaves an external controller undisposed', (tester) async {
    final controller = StratumWebViewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      StratumWebView(controller: controller, source: urlA),
    );
    await tester.pumpWidget(const SizedBox());
    expect(platforms.single.disposed, isFalse);
  });

  testWidgets('loads again only when the source changes', (tester) async {
    await tester.pumpWidget(StratumWebView(source: urlA));
    await tester.pumpWidget(
      StratumWebView(
        source: StratumWebViewSource.url(
          Uri.parse('https://app.example.com/a'),
        ),
      ),
    );
    expect(platforms.single.loads, [urlA]);
    await tester.pumpWidget(StratumWebView(source: urlB));
    expect(platforms.single.loads, [urlA, urlB]);
  });

  testWidgets('keeps the latest source when it changes twice', (
    tester,
  ) async {
    const html = StratumWebViewSource.html('<p>C</p>');
    await tester.pumpWidget(StratumWebView(source: urlA));
    await tester.pumpWidget(StratumWebView(source: urlB));
    await tester.pumpWidget(const StratumWebView(source: html));
    expect(platforms.single.loads, [urlA, urlB, html]);
  });

  testWidgets('forwards the latest callbacks', (tester) async {
    final first = <StratumWebViewMessage>[];
    final second = <StratumWebViewMessage>[];
    await tester.pumpWidget(
      StratumWebView(
        source: urlA,
        allowedOrigins: {appOrigin},
        onMessage: first.add,
      ),
    );
    await tester.pumpWidget(
      StratumWebView(
        source: urlA,
        allowedOrigins: {appOrigin},
        onMessage: second.add,
      ),
    );
    platforms.single.listener.onMessage(
      const StratumWebViewMessage(data: 'x'),
    );
    expect(first, isEmpty);
    expect(second, [const StratumWebViewMessage(data: 'x')]);
  });

  testWidgets('applies javaScriptEnabled changes', (tester) async {
    await tester.pumpWidget(StratumWebView(source: urlA));
    await tester.pumpWidget(
      StratumWebView(source: urlA, javaScriptEnabled: false),
    );
    expect(platforms.single.javaScriptChanges, [false]);
  });

  testWidgets('switching to an external controller disposes the owned one', (
    tester,
  ) async {
    await tester.pumpWidget(StratumWebView(source: urlA));
    final owned = platforms.single;
    final controller = StratumWebViewController();
    addTearDown(controller.dispose);
    final external = platforms.last;
    await tester.pumpWidget(
      StratumWebView(controller: controller, source: urlA),
    );
    expect(owned.disposed, isTrue);
    expect(external.loads, [urlA]);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/src/components/common/web_view/stratum_web_view_test.dart`
Expected: FAIL, `Target of URI doesn't exist: '.../stratum_web_view.dart'`.

- [ ] **Step 3: Write the widget**

Create `lib/src/components/common/web_view/stratum_web_view.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_controller.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

/// Displays a web page or an HTML document on Android, iOS, macOS, Windows,
/// Linux, and the web.
///
/// **Bridge.** Pages send messages with `StratumBridge.postMessage(data)` on
/// native platforms and `window.parent.postMessage(data, appOrigin)` on the
/// web; both reach [onMessage]. `StratumWebViewController.postMessage`
/// delivers a `message` event to the page. The bridge stays off while
/// [allowedOrigins] is empty. HTML content is trusted until the user
/// navigates away from it.
///
/// **Limitations.**
/// * Web: the page is an `<iframe>`. [onError] never fires, and
///   [onNavigationRequest] only sees loads started by the controller. Many
///   sites refuse to be framed; offer an "open in new tab" fallback. Flutter
///   overlays drawn above the view need `PointerInterceptor`.
/// * Linux: the page is a native GTK widget, so Flutter widgets cannot draw
///   above it, and scale or rotation transforms hide it.
/// * Native: the bridge channel is visible to every frame of an allowed
///   page. Allow only pages that embed no untrusted iframes.
class StratumWebView extends StatefulWidget {
  const new({
    super.key,
    required this.source,
    this.controller,
    this.allowedOrigins = const <Uri>{},
    this.javaScriptEnabled = true,
    this.onMessage,
    this.onNavigationRequest,
    this.onPageStarted,
    this.onPageFinished,
    this.onError,
  });

  ///========== Content ==========///
  /// Content to display. A new value that is not equal loads again.
  final StratumWebViewSource source;

  /// Controller to drive the view. When `null`, the widget owns one.
  final StratumWebViewController? controller;

  ///========== Bridge ==========///
  /// Origins allowed to exchange messages. Empty disables the bridge.
  final Set<Uri> allowedOrigins;

  /// Whether pages may run JavaScript. The bridge needs JavaScript.
  final bool javaScriptEnabled;

  /// Receives messages from allowed pages and from loaded HTML.
  final ValueChanged<StratumWebViewMessage>? onMessage;

  ///========== Navigation ==========///
  /// Decides whether a main-frame navigation may proceed.
  final StratumNavigationDecision Function(Uri url)? onNavigationRequest;

  /// Called when a page starts loading.
  final ValueChanged<Uri?>? onPageStarted;

  /// Called when a page finishes loading.
  final ValueChanged<Uri?>? onPageFinished;

  /// Called for main-frame loading failures on native platforms.
  final ValueChanged<StratumWebViewError>? onError;

  @override
  State<StratumWebView> createState() => _StratumWebViewState();
}

class _StratumWebViewState extends State<StratumWebView> {
  StratumWebViewController? _ownedController;

  StratumWebViewController get _controller =>
      widget.controller ?? (_ownedController ??= StratumWebViewController());

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(StratumWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller == null) {
        _ownedController?.dispose();
        _ownedController = null;
      }
      _attach();
      return;
    }
    _controller.configure(_configuration());
    if (oldWidget.source != widget.source) unawaited(_load());
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  void _attach() {
    _controller.configure(_configuration());
    unawaited(_load());
  }

  Future<void> _load() => switch (widget.source) {
    StratumWebViewUrlSource(:final url) => _controller.loadUrl(url),
    StratumWebViewHtmlSource(:final html) => _controller.loadHtml(html),
  };

  StratumWebViewConfiguration _configuration() => StratumWebViewConfiguration(
    allowedOrigins: widget.allowedOrigins,
    javaScriptEnabled: widget.javaScriptEnabled,
    onMessage: widget.onMessage,
    onNavigationRequest: widget.onNavigationRequest,
    onPageStarted: widget.onPageStarted,
    onPageFinished: widget.onPageFinished,
    onError: widget.onError,
  );

  @override
  Widget build(BuildContext context) => _controller.buildView(context);
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/src/components/common/web_view/stratum_web_view_test.dart`
Expected: PASS.

- [ ] **Step 5: Add the barrel and export it**

Create `lib/src/components/common/web_view/web_view.dart`:

```dart
export 'stratum_web_view.dart' show StratumWebView;
export 'stratum_web_view_controller.dart' show StratumWebViewController;
export 'stratum_web_view_types.dart';
```

Append to `lib/src/components/common/common.dart` so it reads:

```dart
export 'layout/layout.dart';
export 'responsive/responsive.dart';
export 'web_view/web_view.dart';
```

- [ ] **Step 6: Run all VM tests, analyze, and format**

Run: `dart format lib/src/components/common/web_view test/src/components/common/web_view && flutter analyze lib/src/components/common/web_view test/src/components/common/web_view && flutter test test/src/components/common/web_view`
Expected: `No issues found!`, then `All tests passed!`

- [ ] **Step 7: Commit** (only if confirmed)

```bash
git add lib/src/components/common/web_view/stratum_web_view.dart lib/src/components/common/web_view/web_view.dart lib/src/components/common/common.dart test/src/components/common/web_view/stratum_web_view_test.dart
git commit -m "feat(web_view): add StratumWebView widget and exports"
```

---

### Task 9: webview_flutter adapter and the native adapter contract

**Files:**
- Create: `lib/src/components/common/web_view/platform/adapters/webview_flutter_adapter.dart`
- Create: `test/src/components/common/web_view/fakes/recording_listener.dart`
- Create: `test/src/components/common/web_view/fakes/fake_webview_flutter_platform.dart`
- Create: `test/src/components/common/web_view/platform/adapters/native_adapter_contract.dart`
- Test: `test/src/components/common/web_view/platform/adapters/webview_flutter_adapter_test.dart`

**Interfaces:**
- Consumes: `PlatformStratumWebView`, `PlatformStratumWebViewListener` (Task 7); `NativeBridgeSession`, `bridgeChannelName` (Task 6); `buildMessageDispatchScript` (Task 5); types (Task 1).
- Produces: `final class WebviewFlutterAdapter implements PlatformStratumWebView` with `new(PlatformStratumWebViewListener listener)`; test helpers `RecordingListener`, `NativeAdapterHarness`, `runNativeAdapterContract(String description, NativeAdapterHarness Function() createHarness)`, `FakeWebViewFlutterPlatform`.

- [ ] **Step 1: Write the recording listener**

Create `test/src/components/common/web_view/fakes/recording_listener.dart`:

```dart
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

/// Records every event that a platform web view reports.
final class RecordingListener implements PlatformStratumWebViewListener {
  new({this.allowedOrigins = const <Uri>{}});

  @override
  Set<Uri> allowedOrigins;

  StratumNavigationDecision decision = StratumNavigationDecision.navigate;
  void Function(StratumWebViewMessage message)? onMessageCallback;

  final List<StratumWebViewMessage> messages = [];
  final List<Uri> navigationRequests = [];
  final List<Uri?> pagesStarted = [];
  final List<Uri?> pagesFinished = [];
  final List<StratumWebViewError> errors = [];

  @override
  void onMessage(StratumWebViewMessage message) {
    messages.add(message);
    onMessageCallback?.call(message);
  }

  @override
  StratumNavigationDecision onNavigationRequest(Uri url) {
    navigationRequests.add(url);
    return decision;
  }

  @override
  void onPageStarted(Uri? url) => pagesStarted.add(url);

  @override
  void onPageFinished(Uri? url) => pagesFinished.add(url);

  @override
  void onError(StratumWebViewError error) => errors.add(error);
}
```

- [ ] **Step 2: Write the webview_flutter fake platform**

Create `test/src/components/common/web_view/fakes/fake_webview_flutter_platform.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// Records every platform object that `webview_flutter` creates.
final class FakeWebViewFlutterPlatform extends WebViewPlatform {
  final List<FakeWebViewFlutterController> controllers = [];
  final List<FakeWebViewFlutterNavigationDelegate> delegates = [];

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = FakeWebViewFlutterController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    final delegate = FakeWebViewFlutterNavigationDelegate(params);
    delegates.add(delegate);
    return delegate;
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => FakeWebViewFlutterWidget(params);
}

final class FakeWebViewFlutterController extends PlatformWebViewController {
  new(super.params) : super.implementation();

  final List<Uri> loadedUrls = [];
  final List<String> loadedHtml = [];
  final List<String> scripts = [];
  final List<JavaScriptMode> javaScriptModes = [];
  final Map<String, void Function(JavaScriptMessage)> channels = {};
  int reloadCount = 0;
  String? currentUrlValue;

  @override
  Future<void> loadRequest(LoadRequestParams params) async =>
      loadedUrls.add(params.uri);

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async =>
      loadedHtml.add(html);

  @override
  Future<void> runJavaScript(String javaScript) async =>
      scripts.add(javaScript);

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async =>
      javaScriptModes.add(javaScriptMode);

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {
    channels[javaScriptChannelParams.name] =
        javaScriptChannelParams.onMessageReceived;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> reload() async => reloadCount++;

  @override
  Future<void> goBack() async {}

  @override
  Future<void> goForward() async {}

  @override
  Future<bool> canGoBack() async => false;

  @override
  Future<bool> canGoForward() async => false;

  @override
  Future<String?> currentUrl() async => currentUrlValue;
}

final class FakeWebViewFlutterNavigationDelegate
    extends PlatformNavigationDelegate {
  new(super.params) : super.implementation();

  NavigationRequestCallback? navigationRequestCallback;
  PageEventCallback? pageStartedCallback;
  PageEventCallback? pageFinishedCallback;
  UrlChangeCallback? urlChangeCallback;
  WebResourceErrorCallback? webResourceErrorCallback;
  HttpResponseErrorCallback? httpErrorCallback;

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async => navigationRequestCallback = onNavigationRequest;

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async =>
      pageStartedCallback = onPageStarted;

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async =>
      pageFinishedCallback = onPageFinished;

  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async =>
      urlChangeCallback = onUrlChange;

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async => webResourceErrorCallback = onWebResourceError;

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback onHttpError) async =>
      httpErrorCallback = onHttpError;
}

final class FakeWebViewFlutterWidget extends PlatformWebViewWidget {
  new(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(key: ValueKey<String>('fake-webview-flutter'));
}
```

- [ ] **Step 3: Write the shared adapter contract**

Create `test/src/components/common/web_view/platform/adapters/native_adapter_contract.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/message_script.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

import '../../fakes/recording_listener.dart';

/// Drives one native adapter through its fake platform.
abstract interface class NativeAdapterHarness {
  PlatformStratumWebView createAdapter(PlatformStratumWebViewListener listener);
  List<Uri> get loadedUrls;
  List<String> get loadedHtml;
  List<String> get scripts;
  List<bool> get javaScriptEnabledStates;
  Set<String> get channelNames;
  int get reloadCount;
  void setCurrentUrl(String? url);
  void startPage(String url);
  void finishPage(String url);
  void changeUrl(String? url);
  void sendBridgeMessage(String message);
  Future<bool> requestNavigation(String url, {required bool isMainFrame});
  void failResource({
    required int code,
    required String description,
    required bool? isForMainFrame,
    required String? url,
  });
  void failHttp({required int statusCode, required Uri requestUrl});
}

/// Runs the behavior every native adapter must share.
void runNativeAdapterContract(
  String description,
  NativeAdapterHarness Function() createHarness,
) {
  group(description, () {
    final appOrigin = Uri.parse('https://app.example.com');
    final appPage = Uri.parse('https://app.example.com/home');
    late NativeAdapterHarness harness;
    late RecordingListener listener;
    late PlatformStratumWebView adapter;

    setUp(() async {
      harness = createHarness();
      listener = RecordingListener(allowedOrigins: {appOrigin});
      adapter = harness.createAdapter(listener);
      await pumpEventQueue();
    });

    test('enables JavaScript and registers the bridge channel', () {
      expect(harness.javaScriptEnabledStates, [true]);
      expect(harness.channelNames, contains('StratumBridge'));
    });

    test('loads URL and HTML sources', () async {
      await adapter.load(StratumWebViewSource.url(appPage));
      await adapter.load(const StratumWebViewSource.html('<p>Hi</p>'));
      expect(harness.loadedUrls, [appPage]);
      expect(harness.loadedHtml, ['<p>Hi</p>']);
    });

    test('accepts a message from an allowed page', () async {
      await adapter.load(StratumWebViewSource.url(appPage));
      harness
        ..startPage(appPage.toString())
        ..sendBridgeMessage('hello');
      expect(listener.messages, [
        StratumWebViewMessage(data: 'hello', origin: appOrigin),
      ]);
    });

    test('drops a message from a page outside the allowlist', () async {
      await adapter.load(StratumWebViewSource.url(appPage));
      harness
        ..startPage('https://evil.example.net/')
        ..sendBridgeMessage('hello');
      expect(listener.messages, isEmpty);
    });

    test('follows URL changes reported without a page load', () async {
      await adapter.load(StratumWebViewSource.url(appPage));
      harness
        ..startPage(appPage.toString())
        ..changeUrl('https://evil.example.net/')
        ..sendBridgeMessage('hello');
      expect(listener.messages, isEmpty);
    });

    test('trusts loaded HTML until the page navigates away', () async {
      await adapter.load(const StratumWebViewSource.html('<p>Hi</p>'));
      harness
        ..startPage('about:blank')
        ..sendBridgeMessage('from html')
        ..startPage('https://evil.example.net/')
        ..sendBridgeMessage('spoofed');
      expect(listener.messages, [
        const StratumWebViewMessage(data: 'from html'),
      ]);
    });

    test('reloading HTML keeps the bridge open', () async {
      await adapter.load(const StratumWebViewSource.html('<p>Hi</p>'));
      harness.startPage('about:blank');
      await adapter.reload();
      harness
        ..startPage('about:blank')
        ..sendBridgeMessage('after reload');
      expect(harness.reloadCount, 1);
      expect(listener.messages, [
        const StratumWebViewMessage(data: 'after reload'),
      ]);
    });

    test('posts a message to an allowed page', () async {
      await adapter.load(StratumWebViewSource.url(appPage));
      harness.startPage(appPage.toString());
      await adapter.postMessage('ping');
      expect(harness.scripts, [buildMessageDispatchScript('ping')]);
    });

    test('refuses to post to a page outside the allowlist', () async {
      await adapter.load(StratumWebViewSource.url(appPage));
      harness.startPage('https://evil.example.net/');
      await expectLater(adapter.postMessage('ping'), throwsStateError);
      expect(harness.scripts, isEmpty);
    });

    test('refuses to post before any page starts', () async {
      await expectLater(adapter.postMessage('ping'), throwsStateError);
    });

    test('asks the listener about main-frame navigation', () async {
      listener.decision = StratumNavigationDecision.prevent;
      final allowed = await harness.requestNavigation(
        'https://evil.example.net/',
        isMainFrame: true,
      );
      expect(allowed, isFalse);
      expect(listener.navigationRequests, [
        Uri.parse('https://evil.example.net/'),
      ]);
    });

    test('lets sub-frame and about: navigation through', () async {
      listener.decision = StratumNavigationDecision.prevent;
      expect(
        await harness.requestNavigation(
          'https://ads.example.net/',
          isMainFrame: false,
        ),
        isTrue,
      );
      expect(
        await harness.requestNavigation('about:blank', isMainFrame: true),
        isTrue,
      );
      expect(listener.navigationRequests, isEmpty);
    });

    test('reports page start and finish', () {
      harness
        ..startPage(appPage.toString())
        ..finishPage(appPage.toString());
      expect(listener.pagesStarted, [appPage]);
      expect(listener.pagesFinished, [appPage]);
    });

    test('forwards main-frame network errors only', () {
      harness
        ..failResource(
          code: -2,
          description: 'ads offline',
          isForMainFrame: false,
          url: 'https://ads.example.net/',
        )
        ..failResource(
          code: -2,
          description: 'offline',
          isForMainFrame: true,
          url: appPage.toString(),
        );
      expect(listener.errors, [
        StratumWebViewError(
          type: StratumWebViewErrorType.network,
          description: 'offline',
          code: -2,
          url: appPage,
        ),
      ]);
    });

    test('forwards HTTP errors for the current page only', () {
      harness
        ..startPage(appPage.toString())
        ..failHttp(
          statusCode: 404,
          requestUrl: Uri.parse('https://app.example.com/logo.png'),
        )
        ..failHttp(statusCode: 500, requestUrl: appPage);
      expect(listener.errors, [
        StratumWebViewError(
          type: StratumWebViewErrorType.http,
          description: 'HTTP error 500',
          code: 500,
          url: appPage,
        ),
      ]);
    });

    test('toggles JavaScript', () async {
      await adapter.setJavaScriptEnabled(false);
      expect(harness.javaScriptEnabledStates.last, isFalse);
    });

    test('parses the current URL', () async {
      harness.setCurrentUrl('https://app.example.com/now');
      expect(
        await adapter.currentUrl(),
        Uri.parse('https://app.example.com/now'),
      );
      harness.setCurrentUrl(null);
      expect(await adapter.currentUrl(), isNull);
    });
  });
}
```

- [ ] **Step 4: Write the failing adapter test**

Create `test/src/components/common/web_view/platform/adapters/webview_flutter_adapter_test.dart`:

```dart
import 'package:stratum_ui/src/components/common/web_view/platform/adapters/webview_flutter_adapter.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../../fakes/fake_webview_flutter_platform.dart';
import 'native_adapter_contract.dart';

void main() {
  runNativeAdapterContract('WebviewFlutterAdapter', _Harness.new);
}

final class _Harness implements NativeAdapterHarness {
  new() {
    WebViewPlatform.instance = _platform;
  }

  final FakeWebViewFlutterPlatform _platform = FakeWebViewFlutterPlatform();

  FakeWebViewFlutterController get _controller =>
      _platform.controllers.single;

  FakeWebViewFlutterNavigationDelegate get _delegate =>
      _platform.delegates.single;

  @override
  PlatformStratumWebView createAdapter(
    PlatformStratumWebViewListener listener,
  ) => WebviewFlutterAdapter(listener);

  @override
  List<Uri> get loadedUrls => _controller.loadedUrls;

  @override
  List<String> get loadedHtml => _controller.loadedHtml;

  @override
  List<String> get scripts => _controller.scripts;

  @override
  List<bool> get javaScriptEnabledStates => [
    for (final mode in _controller.javaScriptModes)
      mode == JavaScriptMode.unrestricted,
  ];

  @override
  Set<String> get channelNames => _controller.channels.keys.toSet();

  @override
  int get reloadCount => _controller.reloadCount;

  @override
  void setCurrentUrl(String? url) => _controller.currentUrlValue = url;

  @override
  void startPage(String url) => _delegate.pageStartedCallback!(url);

  @override
  void finishPage(String url) => _delegate.pageFinishedCallback!(url);

  @override
  void changeUrl(String? url) =>
      _delegate.urlChangeCallback!(UrlChange(url: url));

  @override
  void sendBridgeMessage(String message) =>
      _controller.channels['StratumBridge']!(
        JavaScriptMessage(message: message),
      );

  @override
  Future<bool> requestNavigation(
    String url, {
    required bool isMainFrame,
  }) async {
    final decision = await _delegate.navigationRequestCallback!(
      NavigationRequest(url: url, isMainFrame: isMainFrame),
    );
    return decision == NavigationDecision.navigate;
  }

  @override
  void failResource({
    required int code,
    required String description,
    required bool? isForMainFrame,
    required String? url,
  }) => _delegate.webResourceErrorCallback!(
    WebResourceError(
      errorCode: code,
      description: description,
      isForMainFrame: isForMainFrame,
      url: url,
    ),
  );

  @override
  void failHttp({required int statusCode, required Uri requestUrl}) =>
      _delegate.httpErrorCallback!(
        HttpResponseError(
          request: WebResourceRequest(uri: requestUrl),
          response: WebResourceResponse(
            uri: requestUrl,
            statusCode: statusCode,
          ),
        ),
      );
}
```

- [ ] **Step 5: Run the test to verify it fails**

Run: `flutter test test/src/components/common/web_view/platform/adapters/webview_flutter_adapter_test.dart`
Expected: FAIL, `Target of URI doesn't exist: '.../webview_flutter_adapter.dart'`.

- [ ] **Step 6: Write the adapter**

Create `lib/src/components/common/web_view/platform/adapters/webview_flutter_adapter.dart`:

```dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/native_bridge_session.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';
import 'package:webview_flutter/webview_flutter.dart' as wf;

/// [PlatformStratumWebView] for Android, iOS, and macOS, backed by
/// `webview_flutter`.
final class WebviewFlutterAdapter implements PlatformStratumWebView {
  new(this._listener)
    : _session = NativeBridgeSession(
        allowedOrigins: () => _listener.allowedOrigins,
      ) {
    _ready = _configure();
  }

  final PlatformStratumWebViewListener _listener;
  final NativeBridgeSession _session;
  final wf.WebViewController _controller = wf.WebViewController();
  late final Future<void> _ready;

  Future<void> _configure() async {
    await _controller.setJavaScriptMode(wf.JavaScriptMode.unrestricted);
    await _controller.setNavigationDelegate(
      wf.NavigationDelegate(
        onNavigationRequest: _handleNavigationRequest,
        onPageStarted: _handlePageStarted,
        onPageFinished: _handlePageFinished,
        onUrlChange: (change) => _session.didChangeUrl(change.url),
        onWebResourceError: _handleResourceError,
        onHttpError: _handleHttpError,
      ),
    );
    await _controller.addJavaScriptChannel(
      bridgeChannelName,
      onMessageReceived: (message) => _handleBridgeMessage(message.message),
    );
  }

  @override
  Future<void> setJavaScriptEnabled(bool enabled) async {
    await _ready;
    await _controller.setJavaScriptMode(
      enabled ? wf.JavaScriptMode.unrestricted : wf.JavaScriptMode.disabled,
    );
  }

  @override
  Future<void> load(StratumWebViewSource source) async {
    await _ready;
    switch (source) {
      case StratumWebViewUrlSource(:final url):
        _session.willLoadUrl();
        await _controller.loadRequest(url);
      case StratumWebViewHtmlSource(:final html):
        _session.willLoadHtml();
        await _controller.loadHtmlString(html);
    }
  }

  @override
  Future<void> reload() async {
    await _ready;
    _session.willReload();
    await _controller.reload();
  }

  @override
  Future<void> goBack() async {
    await _ready;
    await _controller.goBack();
  }

  @override
  Future<void> goForward() async {
    await _ready;
    await _controller.goForward();
  }

  @override
  Future<bool> canGoBack() async {
    await _ready;
    return _controller.canGoBack();
  }

  @override
  Future<bool> canGoForward() async {
    await _ready;
    return _controller.canGoForward();
  }

  @override
  Future<Uri?> currentUrl() async {
    await _ready;
    final url = await _controller.currentUrl();
    return url == null ? null : Uri.tryParse(url);
  }

  @override
  Future<void> postMessage(String data) async {
    await _ready;
    await _controller.runJavaScript(_session.scriptForMessage(data));
  }

  @override
  Widget buildView(BuildContext context) =>
      wf.WebViewWidget(controller: _controller);

  @override
  void dispose() {
    // webview_flutter releases the native view when WebViewWidget leaves the
    // tree. The controller ignores events that arrive after dispose.
  }

  wf.NavigationDecision _handleNavigationRequest(wf.NavigationRequest request) {
    if (!request.isMainFrame) return wf.NavigationDecision.navigate;
    final url = Uri.tryParse(request.url);
    if (url == null) return wf.NavigationDecision.prevent;
    if (url.isScheme('about')) return wf.NavigationDecision.navigate;
    final decision = _listener.onNavigationRequest(url);
    return decision == StratumNavigationDecision.navigate
        ? wf.NavigationDecision.navigate
        : wf.NavigationDecision.prevent;
  }

  void _handlePageStarted(String url) {
    _session.didStartPage(url);
    _listener.onPageStarted(Uri.tryParse(url));
  }

  void _handlePageFinished(String url) {
    _listener.onPageFinished(Uri.tryParse(url));
  }

  void _handleBridgeMessage(String data) {
    final message = _session.acceptMessage(data);
    if (message != null) _listener.onMessage(message);
  }

  void _handleResourceError(wf.WebResourceError error) {
    final mapped = _session.networkError(
      code: error.errorCode,
      description: error.description,
      isForMainFrame: error.isForMainFrame,
      url: error.url,
    );
    if (mapped != null) _listener.onError(mapped);
  }

  void _handleHttpError(wf.HttpResponseError error) {
    final mapped = _session.httpError(
      statusCode: error.response?.statusCode,
      requestUrl: error.request?.uri,
    );
    if (mapped != null) _listener.onError(mapped);
  }
}
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `flutter test test/src/components/common/web_view/platform/adapters/webview_flutter_adapter_test.dart`
Expected: PASS (17 tests).

- [ ] **Step 8: Analyze and format**

Run: `dart format lib/src/components/common/web_view test/src/components/common/web_view && flutter analyze lib/src/components/common/web_view test/src/components/common/web_view`
Expected: `No issues found!`

- [ ] **Step 9: Commit** (only if confirmed)

```bash
git add lib/src/components/common/web_view/platform/adapters/webview_flutter_adapter.dart test/src/components/common/web_view/fakes/recording_listener.dart test/src/components/common/web_view/fakes/fake_webview_flutter_platform.dart test/src/components/common/web_view/platform/adapters/native_adapter_contract.dart test/src/components/common/web_view/platform/adapters/webview_flutter_adapter_test.dart
git commit -m "feat(web_view): add webview_flutter adapter for Android, iOS, macOS"
```

---

### Task 10: webview_all adapter

**Files:**
- Create: `lib/src/components/common/web_view/platform/adapters/webview_all_adapter.dart`
- Create: `test/src/components/common/web_view/fakes/fake_webview_all_platform.dart`
- Test: `test/src/components/common/web_view/platform/adapters/webview_all_adapter_test.dart`

**Interfaces:**
- Consumes: everything Task 9 consumes, plus `NativeAdapterHarness` and `runNativeAdapterContract` (Task 9).
- Produces: `final class WebviewAllAdapter implements PlatformStratumWebView` with `new(PlatformStratumWebViewListener listener)`; test fake `FakeWebviewAllPlatform`.

- [ ] **Step 1: Write the webview_all fake platform**

Create `test/src/components/common/web_view/fakes/fake_webview_all_platform.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:webview_platform_interface/webview_platform_interface.dart';

/// Records every platform object that the webview_all adapter creates.
final class FakeWebviewAllPlatform extends WebViewPlatform {
  final List<FakeWebviewAllController> controllers = [];
  final List<FakeWebviewAllNavigationDelegate> delegates = [];

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = FakeWebviewAllController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    final delegate = FakeWebviewAllNavigationDelegate(params);
    delegates.add(delegate);
    return delegate;
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => FakeWebviewAllWidget(params);
}

final class FakeWebviewAllController extends PlatformWebViewController {
  new(super.params) : super.implementation();

  final List<Uri> loadedUrls = [];
  final List<String> loadedHtml = [];
  final List<String> scripts = [];
  final List<JavaScriptMode> javaScriptModes = [];
  final Map<String, void Function(JavaScriptMessage)> channels = {};
  int reloadCount = 0;
  String? currentUrlValue;

  @override
  Future<void> loadRequest(LoadRequestParams params) async =>
      loadedUrls.add(params.uri);

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async =>
      loadedHtml.add(html);

  @override
  Future<void> runJavaScript(String javaScript) async =>
      scripts.add(javaScript);

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async =>
      javaScriptModes.add(javaScriptMode);

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {
    channels[javaScriptChannelParams.name] =
        javaScriptChannelParams.onMessageReceived;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> reload() async => reloadCount++;

  @override
  Future<void> goBack() async {}

  @override
  Future<void> goForward() async {}

  @override
  Future<bool> canGoBack() async => false;

  @override
  Future<bool> canGoForward() async => false;

  @override
  Future<String?> currentUrl() async => currentUrlValue;
}

final class FakeWebviewAllNavigationDelegate
    extends PlatformNavigationDelegate {
  new(super.params) : super.implementation();

  NavigationRequestCallback? navigationRequestCallback;
  PageEventCallback? pageStartedCallback;
  PageEventCallback? pageFinishedCallback;
  UrlChangeCallback? urlChangeCallback;
  WebResourceErrorCallback? webResourceErrorCallback;
  HttpResponseErrorCallback? httpErrorCallback;

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async => navigationRequestCallback = onNavigationRequest;

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async =>
      pageStartedCallback = onPageStarted;

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async =>
      pageFinishedCallback = onPageFinished;

  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async =>
      urlChangeCallback = onUrlChange;

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async => webResourceErrorCallback = onWebResourceError;

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback onHttpError) async =>
      httpErrorCallback = onHttpError;
}

final class FakeWebviewAllWidget extends PlatformWebViewWidget {
  new(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(key: ValueKey<String>('fake-webview-all'));
}
```

- [ ] **Step 2: Write the failing adapter test**

Create `test/src/components/common/web_view/platform/adapters/webview_all_adapter_test.dart`:

```dart
import 'package:stratum_ui/src/components/common/web_view/platform/adapters/webview_all_adapter.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:webview_platform_interface/webview_platform_interface.dart';

import '../../fakes/fake_webview_all_platform.dart';
import 'native_adapter_contract.dart';

void main() {
  runNativeAdapterContract('WebviewAllAdapter', _Harness.new);
}

final class _Harness implements NativeAdapterHarness {
  new() {
    WebViewPlatform.instance = _platform;
  }

  final FakeWebviewAllPlatform _platform = FakeWebviewAllPlatform();

  FakeWebviewAllController get _controller => _platform.controllers.single;

  FakeWebviewAllNavigationDelegate get _delegate =>
      _platform.delegates.single;

  @override
  PlatformStratumWebView createAdapter(
    PlatformStratumWebViewListener listener,
  ) => WebviewAllAdapter(listener);

  @override
  List<Uri> get loadedUrls => _controller.loadedUrls;

  @override
  List<String> get loadedHtml => _controller.loadedHtml;

  @override
  List<String> get scripts => _controller.scripts;

  @override
  List<bool> get javaScriptEnabledStates => [
    for (final mode in _controller.javaScriptModes)
      mode == JavaScriptMode.unrestricted,
  ];

  @override
  Set<String> get channelNames => _controller.channels.keys.toSet();

  @override
  int get reloadCount => _controller.reloadCount;

  @override
  void setCurrentUrl(String? url) => _controller.currentUrlValue = url;

  @override
  void startPage(String url) => _delegate.pageStartedCallback!(url);

  @override
  void finishPage(String url) => _delegate.pageFinishedCallback!(url);

  @override
  void changeUrl(String? url) =>
      _delegate.urlChangeCallback!(UrlChange(url: url));

  @override
  void sendBridgeMessage(String message) =>
      _controller.channels['StratumBridge']!(
        JavaScriptMessage(message: message),
      );

  @override
  Future<bool> requestNavigation(
    String url, {
    required bool isMainFrame,
  }) async {
    final decision = await _delegate.navigationRequestCallback!(
      NavigationRequest(url: url, isMainFrame: isMainFrame),
    );
    return decision == NavigationDecision.navigate;
  }

  @override
  void failResource({
    required int code,
    required String description,
    required bool? isForMainFrame,
    required String? url,
  }) => _delegate.webResourceErrorCallback!(
    WebResourceError(
      errorCode: code,
      description: description,
      isForMainFrame: isForMainFrame,
      url: url,
    ),
  );

  @override
  void failHttp({required int statusCode, required Uri requestUrl}) =>
      _delegate.httpErrorCallback!(
        HttpResponseError(
          request: WebResourceRequest(uri: requestUrl),
          response: WebResourceResponse(
            uri: requestUrl,
            statusCode: statusCode,
          ),
        ),
      );
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/src/components/common/web_view/platform/adapters/webview_all_adapter_test.dart`
Expected: FAIL, `Target of URI doesn't exist: '.../webview_all_adapter.dart'`.

- [ ] **Step 4: Write the adapter**

Create `lib/src/components/common/web_view/platform/adapters/webview_all_adapter.dart`:

```dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/native_bridge_session.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';
import 'package:webview_platform_interface/webview_platform_interface.dart'
    as wa;

/// [PlatformStratumWebView] for Windows and Linux, backed by
/// `webview_all_windows` and `webview_all_linux`.
///
/// Those packages register themselves as `wa.WebViewPlatform.instance`, so
/// this adapter talks to the platform interface directly.
final class WebviewAllAdapter implements PlatformStratumWebView {
  new(this._listener)
    : _session = NativeBridgeSession(
        allowedOrigins: () => _listener.allowedOrigins,
      ),
      _controller = wa.PlatformWebViewController(
        const wa.PlatformWebViewControllerCreationParams(),
      ),
      _delegate = wa.PlatformNavigationDelegate(
        const wa.PlatformNavigationDelegateCreationParams(),
      ) {
    _ready = _configure();
  }

  final PlatformStratumWebViewListener _listener;
  final NativeBridgeSession _session;
  final wa.PlatformWebViewController _controller;
  final wa.PlatformNavigationDelegate _delegate;
  late final Future<void> _ready;

  Future<void> _configure() async {
    await _delegate.setOnNavigationRequest(_handleNavigationRequest);
    await _delegate.setOnPageStarted(_handlePageStarted);
    await _delegate.setOnPageFinished(_handlePageFinished);
    await _delegate.setOnUrlChange(
      (change) => _session.didChangeUrl(change.url),
    );
    await _delegate.setOnWebResourceError(_handleResourceError);
    await _delegate.setOnHttpError(_handleHttpError);
    await _controller.setPlatformNavigationDelegate(_delegate);
    await _controller.setJavaScriptMode(wa.JavaScriptMode.unrestricted);
    await _controller.addJavaScriptChannel(
      wa.JavaScriptChannelParams(
        name: bridgeChannelName,
        onMessageReceived: (message) => _handleBridgeMessage(message.message),
      ),
    );
  }

  @override
  Future<void> setJavaScriptEnabled(bool enabled) async {
    await _ready;
    await _controller.setJavaScriptMode(
      enabled ? wa.JavaScriptMode.unrestricted : wa.JavaScriptMode.disabled,
    );
  }

  @override
  Future<void> load(StratumWebViewSource source) async {
    await _ready;
    switch (source) {
      case StratumWebViewUrlSource(:final url):
        _session.willLoadUrl();
        await _controller.loadRequest(wa.LoadRequestParams(uri: url));
      case StratumWebViewHtmlSource(:final html):
        _session.willLoadHtml();
        await _controller.loadHtmlString(html);
    }
  }

  @override
  Future<void> reload() async {
    await _ready;
    _session.willReload();
    await _controller.reload();
  }

  @override
  Future<void> goBack() async {
    await _ready;
    await _controller.goBack();
  }

  @override
  Future<void> goForward() async {
    await _ready;
    await _controller.goForward();
  }

  @override
  Future<bool> canGoBack() async {
    await _ready;
    return _controller.canGoBack();
  }

  @override
  Future<bool> canGoForward() async {
    await _ready;
    return _controller.canGoForward();
  }

  @override
  Future<Uri?> currentUrl() async {
    await _ready;
    final url = await _controller.currentUrl();
    return url == null ? null : Uri.tryParse(url);
  }

  @override
  Future<void> postMessage(String data) async {
    await _ready;
    await _controller.runJavaScript(_session.scriptForMessage(data));
  }

  @override
  Widget buildView(BuildContext context) => wa.PlatformWebViewWidget(
    wa.PlatformWebViewWidgetCreationParams(controller: _controller),
  ).build(context);

  @override
  void dispose() {
    // The native view is released when its platform view leaves the tree.
    // The controller ignores events that arrive after dispose.
  }

  wa.NavigationDecision _handleNavigationRequest(wa.NavigationRequest request) {
    if (!request.isMainFrame) return wa.NavigationDecision.navigate;
    final url = Uri.tryParse(request.url);
    if (url == null) return wa.NavigationDecision.prevent;
    if (url.isScheme('about')) return wa.NavigationDecision.navigate;
    final decision = _listener.onNavigationRequest(url);
    return decision == StratumNavigationDecision.navigate
        ? wa.NavigationDecision.navigate
        : wa.NavigationDecision.prevent;
  }

  void _handlePageStarted(String url) {
    _session.didStartPage(url);
    _listener.onPageStarted(Uri.tryParse(url));
  }

  void _handlePageFinished(String url) {
    _listener.onPageFinished(Uri.tryParse(url));
  }

  void _handleBridgeMessage(String data) {
    final message = _session.acceptMessage(data);
    if (message != null) _listener.onMessage(message);
  }

  void _handleResourceError(wa.WebResourceError error) {
    final mapped = _session.networkError(
      code: error.errorCode,
      description: error.description,
      isForMainFrame: error.isForMainFrame,
      url: error.url,
    );
    if (mapped != null) _listener.onError(mapped);
  }

  void _handleHttpError(wa.HttpResponseError error) {
    final mapped = _session.httpError(
      statusCode: error.response?.statusCode,
      requestUrl: error.request?.uri,
    );
    if (mapped != null) _listener.onError(mapped);
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/src/components/common/web_view/platform/adapters/webview_all_adapter_test.dart`
Expected: PASS (17 tests).

- [ ] **Step 6: Analyze and format**

Run: `dart format lib/src/components/common/web_view test/src/components/common/web_view && flutter analyze lib/src/components/common/web_view test/src/components/common/web_view`
Expected: `No issues found!`

- [ ] **Step 7: Commit** (only if confirmed)

```bash
git add lib/src/components/common/web_view/platform/adapters/webview_all_adapter.dart test/src/components/common/web_view/fakes/fake_webview_all_platform.dart test/src/components/common/web_view/platform/adapters/webview_all_adapter_test.dart
git commit -m "feat(web_view): add webview_all adapter for Windows and Linux"
```

---

### Task 11: Native platform selection

**Files:**
- Create: `lib/src/components/common/web_view/platform/platform_web_view_io.dart`
- Modify: `lib/src/components/common/web_view/platform/platform_web_view.dart`
- Test: `test/src/components/common/web_view/platform/platform_web_view_io_test.dart`

**Interfaces:**
- Consumes: `WebviewFlutterAdapter` (Task 9), `WebviewAllAdapter` (Task 10), `RecordingListener`, `FakeWebViewFlutterPlatform`, `FakeWebviewAllPlatform`.
- Produces: `PlatformStratumWebView createPlatformStratumWebView(PlatformStratumWebViewListener listener)` in `platform_web_view_io.dart`, selected on native builds.

- [ ] **Step 1: Write the failing test**

Create `test/src/components/common/web_view/platform/platform_web_view_io_test.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/adapters/webview_all_adapter.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/adapters/webview_flutter_adapter.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_io.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart'
    as official;
import 'package:webview_platform_interface/webview_platform_interface.dart'
    as fork;

import '../fakes/fake_webview_all_platform.dart';
import '../fakes/fake_webview_flutter_platform.dart';
import '../fakes/recording_listener.dart';

void main() {
  setUp(() {
    official.WebViewPlatform.instance = FakeWebViewFlutterPlatform();
    fork.WebViewPlatform.instance = FakeWebviewAllPlatform();
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
  });

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    test('uses webview_flutter on ${platform.name}', () {
      debugDefaultTargetPlatformOverride = platform;
      expect(
        createPlatformStratumWebView(RecordingListener()),
        isA<WebviewFlutterAdapter>(),
      );
    });
  }

  for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
    test('uses webview_all on ${platform.name}', () {
      debugDefaultTargetPlatformOverride = platform;
      expect(
        createPlatformStratumWebView(RecordingListener()),
        isA<WebviewAllAdapter>(),
      );
    });
  }

  test('rejects fuchsia', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    expect(
      () => createPlatformStratumWebView(RecordingListener()),
      throwsUnsupportedError,
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/src/components/common/web_view/platform/platform_web_view_io_test.dart`
Expected: FAIL, `Target of URI doesn't exist: '.../platform_web_view_io.dart'`.

- [ ] **Step 3: Write the selector and wire the conditional export**

Create `lib/src/components/common/web_view/platform/platform_web_view_io.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/adapters/webview_all_adapter.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/adapters/webview_flutter_adapter.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';

/// Picks the native adapter for the running platform.
///
/// Conditional imports only separate web from native, so native platforms
/// are told apart here, at runtime.
PlatformStratumWebView createPlatformStratumWebView(
  PlatformStratumWebViewListener listener,
) {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS => WebviewFlutterAdapter(listener),
    TargetPlatform.windows ||
    TargetPlatform.linux => WebviewAllAdapter(listener),
    TargetPlatform.fuchsia => throw UnsupportedError(
      'StratumWebView is not supported on fuchsia.',
    ),
  };
}
```

Replace the content of `lib/src/components/common/web_view/platform/platform_web_view.dart` with:

```dart
export 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_stub.dart'
    if (dart.library.io) 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_io.dart';
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/src/components/common/web_view/platform/platform_web_view_io_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Run all VM tests, analyze, and format**

Run: `dart format lib/src/components/common/web_view test/src/components/common/web_view && flutter analyze lib/src/components/common/web_view test/src/components/common/web_view && flutter test test/src/components/common/web_view`
Expected: `No issues found!`, then `All tests passed!`

- [ ] **Step 6: Commit** (only if confirmed)

```bash
git add lib/src/components/common/web_view/platform/platform_web_view_io.dart lib/src/components/common/web_view/platform/platform_web_view.dart test/src/components/common/web_view/platform/platform_web_view_io_test.dart
git commit -m "feat(web_view): select the native adapter per platform"
```

---

### Task 12: Web iframe implementation

**Files:**
- Create: `lib/src/components/common/web_view/platform/platform_web_view_web.dart`
- Modify: `lib/src/components/common/web_view/platform/platform_web_view.dart`
- Test: `test/src/components/common/web_view/platform/platform_web_view_web_test.dart`

**Interfaces:**
- Consumes: `PlatformStratumWebView`, `PlatformStratumWebViewListener` (Task 7); `HtmlFrameGuard` (Task 3); `WebViewHistory` (Task 4); `originOf`, `isAllowedOrigin` (Task 2); `RecordingListener` (Task 9); types (Task 1).
- Produces: `final class WebPlatformStratumWebView implements PlatformStratumWebView` with `new(PlatformStratumWebViewListener listener)`, `@visibleForTesting web.HTMLIFrameElement get iframe`, `@visibleForTesting web.HTMLElement createView()`; top-level `createPlatformStratumWebView` for web builds.

- [ ] **Step 1: Write the failing browser test**

Create `test/src/components/common/web_view/platform/platform_web_view_web_test.dart`:

```dart
@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_web.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';
import 'package:web/web.dart' as web;

import '../fakes/recording_listener.dart';

void main() {
  final appOrigin = Uri.parse(web.window.location.origin);
  late RecordingListener listener;
  late WebPlatformStratumWebView view;

  setUp(() {
    listener = RecordingListener(allowedOrigins: {appOrigin});
    view = WebPlatformStratumWebView(listener);
    addTearDown(() {
      view.dispose();
      view.iframe.remove();
    });
  });

  void attach() => web.document.body!.appendChild(view.iframe);

  Future<void> nextLoad() {
    final completer = Completer<void>();
    late final JSFunction handler;
    handler = ((web.Event _) {
      view.iframe.removeEventListener('load', handler);
      completer.complete();
    }).toJS;
    view.iframe.addEventListener('load', handler);
    return completer.future.timeout(const Duration(seconds: 5));
  }

  void dispatchMessage(
    JSAny data, {
    required String origin,
    JSObject? source,
  }) {
    web.window.dispatchEvent(
      web.MessageEvent(
        'message',
        web.MessageEventInit(
          data: data,
          origin: origin,
          source: source ?? view.iframe.contentWindow,
        ),
      ),
    );
  }

  StratumWebViewSource missingPage() =>
      StratumWebViewSource.url(appOrigin.replace(path: '/missing'));

  test('renders HTML in a scripts-only sandbox', () async {
    await view.load(const StratumWebViewSource.html('<p>Hi</p>'));
    expect(view.iframe.getAttribute('sandbox'), 'allow-scripts');
    expect(view.iframe.hasAttribute('srcdoc'), isTrue);
    expect(listener.pagesStarted, [null]);
  });

  test('loads a URL without a sandbox after asking the listener', () async {
    final url = Uri.parse('https://app.example.com/home');
    await view.load(StratumWebViewSource.url(url));
    expect(view.iframe.src, url.toString());
    expect(view.iframe.hasAttribute('sandbox'), isFalse);
    expect(listener.navigationRequests, [url]);
    expect(listener.pagesStarted, [url]);
  });

  test('does not load or record a prevented URL', () async {
    listener.decision = StratumNavigationDecision.prevent;
    await view.load(
      StratumWebViewSource.url(Uri.parse('https://evil.example.net')),
    );
    expect(view.iframe.hasAttribute('src'), isFalse);
    expect(await view.canGoBack(), isFalse);
    expect(await view.currentUrl(), isNull);
  });

  test('removes scripts from the sandbox when JavaScript is off', () async {
    await view.setJavaScriptEnabled(false);
    await view.load(const StratumWebViewSource.html('<p>Hi</p>'));
    expect(view.iframe.getAttribute('sandbox'), '');
    await view.load(missingPage());
    expect(
      view.iframe.getAttribute('sandbox'),
      'allow-same-origin allow-forms allow-popups',
    );
  });

  test('delivers a message from the iframe with an allowed origin', () async {
    await view.load(missingPage());
    attach();
    dispatchMessage('hello'.toJS, origin: appOrigin.toString());
    expect(listener.messages, [
      StratumWebViewMessage(data: 'hello', origin: appOrigin),
    ]);
  });

  test(
    'drops messages from other windows, other origins, and non-strings',
    () async {
      await view.load(missingPage());
      attach();
      dispatchMessage(
        'from app window'.toJS,
        origin: appOrigin.toString(),
        source: web.window,
      );
      dispatchMessage('from evil'.toJS, origin: 'https://evil.example.net');
      dispatchMessage(42.toJS, origin: appOrigin.toString());
      expect(listener.messages, isEmpty);
    },
  );

  test('trusts its own HTML until the frame navigates away', () async {
    final loaded = nextLoad();
    await view.load(const StratumWebViewSource.html('<p>Hi</p>'));
    attach();
    await loaded;
    dispatchMessage('from html'.toJS, origin: 'null');
    view.iframe.dispatchEvent(web.Event('load'));
    dispatchMessage('after navigation'.toJS, origin: 'null');
    expect(listener.messages, [
      const StratumWebViewMessage(data: 'from html'),
    ]);
    await expectLater(view.postMessage('ping'), throwsStateError);
  });

  test('receives a real postMessage from sandboxed HTML', () async {
    final received = Completer<StratumWebViewMessage>();
    listener.onMessageCallback = received.complete;
    await view.load(
      const StratumWebViewSource.html(
        '<script>parent.postMessage("ready", "*");</script>',
      ),
    );
    attach();
    expect(
      await received.future.timeout(const Duration(seconds: 5)),
      const StratumWebViewMessage(data: 'ready'),
    );
  });

  test('re-inserting the view re-arms the HTML bridge', () async {
    final loaded = nextLoad();
    await view.load(const StratumWebViewSource.html('<p>Hi</p>'));
    attach();
    await loaded;
    view.iframe.dispatchEvent(web.Event('load'));
    view.createView();
    dispatchMessage('after re-insert'.toJS, origin: 'null');
    expect(listener.messages, [
      const StratumWebViewMessage(data: 'after re-insert'),
    ]);
  });

  test('posts to the current URL origin and refuses others', () async {
    await view.load(missingPage());
    attach();
    await view.postMessage('ping');
    listener.allowedOrigins = {Uri.parse('https://other.example.net')};
    await expectLater(view.postMessage('ping'), throwsStateError);
  });

  test('refuses to post before any content loads', () async {
    attach();
    await expectLater(view.postMessage('ping'), throwsStateError);
  });

  test('navigates the controller history', () async {
    await view.load(
      StratumWebViewSource.url(appOrigin.replace(path: '/one')),
    );
    await view.load(const StratumWebViewSource.html('<p>Two</p>'));
    expect(await view.canGoBack(), isTrue);
    await view.goBack();
    expect(view.iframe.hasAttribute('srcdoc'), isFalse);
    expect(view.iframe.src, endsWith('/one'));
    expect(await view.canGoForward(), isTrue);
    await view.goForward();
    expect(view.iframe.hasAttribute('srcdoc'), isTrue);
  });

  test('stops delivering messages after dispose', () async {
    await view.load(missingPage());
    attach();
    final frameWindow = view.iframe.contentWindow;
    view.dispose();
    dispatchMessage(
      'late'.toJS,
      origin: appOrigin.toString(),
      source: frameWindow,
    );
    expect(listener.messages, isEmpty);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test --platform chrome test/src/components/common/web_view/platform/platform_web_view_web_test.dart`
Expected: FAIL, `Target of URI doesn't exist: '.../platform_web_view_web.dart'`.

- [ ] **Step 3: Write the web implementation**

Create `lib/src/components/common/web_view/platform/platform_web_view_web.dart`:

```dart
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/html_frame_guard.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/origin_policy.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/web_view_history.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';
import 'package:web/web.dart' as web;

/// Creates the iframe-based web view used on the web.
PlatformStratumWebView createPlatformStratumWebView(
  PlatformStratumWebViewListener listener,
) => WebPlatformStratumWebView(listener);

/// [PlatformStratumWebView] for the web, built on an `<iframe>`.
///
/// Pages reach Flutter with `window.parent.postMessage`. A message is
/// accepted only when it comes from this iframe's window and either its
/// origin is allowed, or the iframe still shows HTML loaded by the
/// controller.
final class WebPlatformStratumWebView implements PlatformStratumWebView {
  new(this._listener) : _viewType = 'stratum-web-view-${_nextViewId++}' {
    _iframe.style
      ..border = 'none'
      ..width = '100%'
      ..height = '100%';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => createView(),
    );
    web.window.addEventListener('message', _messageListener);
    _iframe.addEventListener('load', _loadListener);
  }

  static int _nextViewId = 0;

  final PlatformStratumWebViewListener _listener;
  final String _viewType;
  final web.HTMLIFrameElement _iframe = web.HTMLIFrameElement();
  final HtmlFrameGuard _guard = HtmlFrameGuard();
  final WebViewHistory<StratumWebViewSource> _history =
      WebViewHistory<StratumWebViewSource>();
  late final JSFunction _messageListener = _handleMessage.toJS;
  late final JSFunction _loadListener = _handleLoad.toJS;
  bool _javaScriptEnabled = true;
  bool _disposed = false;

  /// The iframe that shows the page.
  @visibleForTesting
  web.HTMLIFrameElement get iframe => _iframe;

  /// Returns the element for a new platform view.
  ///
  /// Flutter calls this each time the view is inserted into the page.
  /// Re-inserting an iframe reloads it, so loaded HTML is expected again.
  @visibleForTesting
  web.HTMLElement createView() {
    if (_history.current is StratumWebViewHtmlSource) _guard.expectOwnHtml();
    return _iframe;
  }

  @override
  Future<void> setJavaScriptEnabled(bool enabled) async {
    _javaScriptEnabled = enabled;
    final current = _history.current;
    if (current != null) _applySandbox(current);
  }

  @override
  Future<void> load(StratumWebViewSource source) async {
    if (source case StratumWebViewUrlSource(:final url)) {
      final decision = _listener.onNavigationRequest(url);
      if (decision == StratumNavigationDecision.prevent) return;
    }
    _history.push(source);
    _show(source);
  }

  @override
  Future<void> reload() async {
    final current = _history.current;
    if (current != null) _show(current);
  }

  @override
  Future<void> goBack() async {
    final previous = _history.back();
    if (previous != null) _show(previous);
  }

  @override
  Future<void> goForward() async {
    final next = _history.forward();
    if (next != null) _show(next);
  }

  @override
  Future<bool> canGoBack() async => _history.canGoBack;

  @override
  Future<bool> canGoForward() async => _history.canGoForward;

  @override
  Future<Uri?> currentUrl() async {
    final current = _history.current;
    if (current is! StratumWebViewUrlSource) return null;
    try {
      final href = _iframe.contentWindow?.location.href;
      if (href != null) return Uri.tryParse(href);
    } on Object {
      // Cross-origin frame: the browser hides its location.
    }
    return current.url;
  }

  @override
  Future<void> postMessage(String data) async {
    final frameWindow = _iframe.contentWindow;
    final current = _history.current;
    if (frameWindow == null || current == null) {
      throw StateError('The web view has no page to receive messages.');
    }
    switch (current) {
      case StratumWebViewHtmlSource():
        if (!_guard.isShowingOwnHtml) {
          throw StateError('The frame navigated away from the loaded HTML.');
        }
        frameWindow.postMessage(data.toJS, '*'.toJS);
      case StratumWebViewUrlSource(:final url):
        final origin = originOf(url);
        if (origin == null ||
            !isAllowedOrigin(origin, _listener.allowedOrigins)) {
          throw StateError('$url is not an allowed message destination.');
        }
        frameWindow.postMessage(data.toJS, origin.toString().toJS);
    }
  }

  @override
  Widget buildView(BuildContext context) =>
      HtmlElementView(viewType: _viewType);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    web.window.removeEventListener('message', _messageListener);
    _iframe
      ..removeEventListener('load', _loadListener)
      ..removeAttribute('srcdoc')
      ..src = 'about:blank';
  }

  void _show(StratumWebViewSource source) {
    _applySandbox(source);
    switch (source) {
      case StratumWebViewUrlSource(:final url):
        _guard.expectNavigation();
        _iframe
          ..removeAttribute('srcdoc')
          ..src = url.toString();
        _listener.onPageStarted(url);
      case StratumWebViewHtmlSource(:final html):
        _guard.expectOwnHtml();
        _iframe.srcdoc = html.toJS;
        _listener.onPageStarted(null);
    }
  }

  void _applySandbox(StratumWebViewSource source) {
    final value = switch (source) {
      StratumWebViewHtmlSource() => _javaScriptEnabled ? 'allow-scripts' : '',
      StratumWebViewUrlSource() =>
        _javaScriptEnabled
            ? null
            : 'allow-same-origin allow-forms allow-popups',
    };
    if (value == null) {
      _iframe.removeAttribute('sandbox');
    } else {
      _iframe.setAttribute('sandbox', value);
    }
  }

  void _handleLoad(web.Event event) {
    if (_disposed) return;
    final current = _history.current;
    if (current == null) return;
    _guard.didLoadFrame();
    _listener.onPageFinished(
      current is StratumWebViewUrlSource ? current.url : null,
    );
  }

  void _handleMessage(web.MessageEvent event) {
    if (_disposed) return;
    final frameWindow = _iframe.contentWindow;
    if (frameWindow == null) return;
    if (!event.source.strictEquals(frameWindow).toDart) return;
    final data = event.data;
    if (data == null || !data.isA<JSString>()) return;
    final text = (data as JSString).toDart;
    if (event.origin == 'null') {
      final showingHtml =
          _history.current is StratumWebViewHtmlSource &&
          _guard.isShowingOwnHtml;
      if (showingHtml) _listener.onMessage(StratumWebViewMessage(data: text));
      return;
    }
    final origin = Uri.tryParse(event.origin);
    if (!isAllowedOrigin(origin, _listener.allowedOrigins)) return;
    _listener.onMessage(
      StratumWebViewMessage(data: text, origin: originOf(origin)),
    );
  }
}
```

- [ ] **Step 4: Wire the web target into the conditional export**

Replace the content of `lib/src/components/common/web_view/platform/platform_web_view.dart` with:

```dart
export 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_stub.dart'
    if (dart.library.js_interop) 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_web.dart'
    if (dart.library.io) 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_io.dart';
```

- [ ] **Step 5: Run the browser test to verify it passes**

Run: `flutter test --platform chrome test/src/components/common/web_view/platform/platform_web_view_web_test.dart`
Expected: PASS (13 tests). If Chrome is not installed, stop and report; do not mark the task done.

- [ ] **Step 6: Run all tests, analyze, and format**

Run: `dart format lib/src/components/common/web_view test/src/components/common/web_view && flutter analyze lib/src/components/common/web_view test/src/components/common/web_view && flutter test test/src/components/common/web_view`
Expected: `No issues found!`, then `All tests passed!` (the browser test file is skipped on the VM).

- [ ] **Step 7: Commit** (only if confirmed)

```bash
git add lib/src/components/common/web_view/platform/platform_web_view_web.dart lib/src/components/common/web_view/platform/platform_web_view.dart test/src/components/common/web_view/platform/platform_web_view_web_test.dart
git commit -m "feat(web_view): add iframe implementation for the web"
```

---

### Task 13: Example app and manual verification

**Files:**
- Create: `example/` (generated by `flutter create`)
- Modify: `example/pubspec.yaml`, `example/lib/main.dart`, `example/android/app/src/main/AndroidManifest.xml`, `example/macos/Runner/DebugProfile.entitlements`, `example/macos/Runner/Release.entitlements`
- Delete: `example/test/widget_test.dart`

**Interfaces:**
- Consumes: the public barrel `package:stratum_ui/src/components/common/web_view/web_view.dart` (Task 8).
- Produces: a runnable demo with URL, HTML, and Bridge tabs.

- [ ] **Step 1: Generate the app**

Run: `flutter create --org dev.stratum --project-name stratum_ui_example --platforms=android,ios,macos,web,windows,linux example`
Expected: `All done!`

Then delete `example/test/widget_test.dart` (it tests the counter template).

- [ ] **Step 2: Depend on stratum_ui**

In `example/pubspec.yaml`, add under `dependencies:` (after `flutter:`):

```yaml
  stratum_ui:
    path: ../
```

Run: `cd example && flutter pub get`
Expected: exit code 0.

- [ ] **Step 3: Allow network access**

In `example/android/app/src/main/AndroidManifest.xml`, add as the first child of `<manifest>`:

```xml
    <uses-permission android:name="android.permission.INTERNET"/>
```

In both `example/macos/Runner/DebugProfile.entitlements` and `example/macos/Runner/Release.entitlements`, add inside `<dict>`:

```xml
	<key>com.apple.security.network.client</key>
	<true/>
```

- [ ] **Step 4: Write the demo**

Replace `example/lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
// The package barrel `package:stratum_ui/stratum_ui.dart` does not compile
// yet because of errors outside web_view, so the demo imports the web_view
// barrel directly.
// ignore: implementation_imports
import 'package:stratum_ui/src/components/common/web_view/web_view.dart';

void main() => runApp(const StratumWebViewExampleApp());

class StratumWebViewExampleApp extends StatelessWidget {
  const StratumWebViewExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('StratumWebView'),
            bottom: const TabBar(
              tabs: [Tab(text: 'URL'), Tab(text: 'HTML'), Tab(text: 'Bridge')],
            ),
          ),
          body: const TabBarView(
            physics: NeverScrollableScrollPhysics(),
            children: [_UrlTab(), _HtmlTab(), _BridgeTab()],
          ),
        ),
      ),
    );
  }
}

class _UrlTab extends StatefulWidget {
  const _UrlTab();

  @override
  State<_UrlTab> createState() => _UrlTabState();
}

class _UrlTabState extends State<_UrlTab> {
  final _controller = StratumWebViewController();
  var _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _update(VoidCallback change) {
    if (mounted) setState(change);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                if (await _controller.canGoBack()) await _controller.goBack();
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _controller.reload,
            ),
            if (_loading)
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (_error != null)
              Expanded(
                child: Text(_error!, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
        Expanded(
          child: StratumWebView(
            controller: _controller,
            source: StratumWebViewSource.url(Uri.parse('https://flutter.dev')),
            onPageStarted: (_) => _update(() {
              _loading = true;
              _error = null;
            }),
            onPageFinished: (_) => _update(() => _loading = false),
            onError: (error) => _update(
              () => _error = '${error.type.name}: ${error.description}',
            ),
          ),
        ),
      ],
    );
  }
}

class _HtmlTab extends StatelessWidget {
  const _HtmlTab();

  @override
  Widget build(BuildContext context) {
    return const StratumWebView(
      source: StratumWebViewSource.html(
        '<h1 style="font-family: sans-serif">Terms</h1>'
        '<p style="font-family: sans-serif">Rendered from an HTML string.</p>',
      ),
    );
  }
}

const _bridgeHtml = r'''
<!doctype html>
<html>
  <body style="font-family: sans-serif">
    <button id="send">Send to Flutter</button>
    <pre id="log"></pre>
    <script>
      function sendToFlutter(data) {
        if (window.StratumBridge) StratumBridge.postMessage(data);
        else window.parent.postMessage(data, '*');
      }
      let count = 0;
      document.getElementById('send').onclick =
          () => sendToFlutter('page message ' + ++count);
      window.addEventListener('message', (event) => {
        document.getElementById('log').textContent += event.data + '\n';
      });
    </script>
  </body>
</html>
''';

class _BridgeTab extends StatefulWidget {
  const _BridgeTab();

  @override
  State<_BridgeTab> createState() => _BridgeTabState();
}

class _BridgeTabState extends State<_BridgeTab> {
  final _controller = StratumWebViewController();
  final _received = <String>[];
  var _sent = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    _sent++;
    try {
      await _controller.postMessage('flutter message $_sent');
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ElevatedButton(
                onPressed: _send,
                child: const Text('Send to page'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _received.isEmpty ? 'No messages yet' : _received.last,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StratumWebView(
            controller: _controller,
            source: const StratumWebViewSource.html(_bridgeHtml),
            // The bridge stays off while the allowlist is empty, even for
            // HTML content, so the demo lists the one site it trusts.
            allowedOrigins: {Uri.parse('https://flutter.dev')},
            onMessage: (message) =>
                setState(() => _received.add(message.data)),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Analyze the example**

Run: `cd example && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Manual verification**

Run each available target and check the three tabs. Record the result for every row, including the ones that could not run.

| Target | Command | Expected |
|---|---|---|
| macOS | `cd example && flutter run -d macos` | URL tab loads flutter.dev, spinner shows then hides; HTML tab shows "Terms"; Bridge tab: page button updates the Flutter label, Flutter button appends to the page log. |
| Chrome | `cd example && flutter run -d chrome` | Same as macOS. The URL tab may stay blank if flutter.dev refuses framing; that is the documented web limitation, not a failure. |
| iOS simulator | `cd example && flutter run -d "iPhone"` (any available simulator) | Same as macOS. |
| Android emulator | `cd example && flutter run -d emulator` (any running emulator) | Same as macOS. |
| Windows | not available on this machine | Mark "not verified". |
| Linux | not available on this machine | Mark "not verified"; needs `libwebkit2gtk-4.1-dev`. |

- [ ] **Step 7: Commit** (only if confirmed)

```bash
git add example
git commit -m "docs(web_view): add StratumWebView example app"
```

---

## Completion

After Task 13, run the full scoped verification from Global Constraints once more (VM tests, browser test, analyzer) and report the results together with the manual verification table. Windows and Linux remain unverified on real hardware (spec section 9).
