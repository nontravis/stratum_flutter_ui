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
