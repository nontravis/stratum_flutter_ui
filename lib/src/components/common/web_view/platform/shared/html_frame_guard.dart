/// Tracks whether a frame still shows HTML that the controller loaded.
///
/// Native only. The web implementation uses a different mechanism (see
/// `html_bridge_bootstrap.dart`), because on web a navigated-to page
/// controls when its own `load` event fires, so counting iframe `load`
/// events cannot tell it apart from our own HTML.
///
/// HTML content has no verifiable origin (native reports `about:blank`). A
/// page that the user reaches from that HTML can look the same, so the
/// guard counts loads instead:
///
/// * Call [expectOwnHtml] right before loading HTML content.
/// * Call [expectNavigation] right before loading a URL.
/// * Call [didLoadFrame] for every main-frame load that the platform
///   reports (`onPageStarted`).
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
