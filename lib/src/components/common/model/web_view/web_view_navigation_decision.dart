/// Whether a web view may continue a navigation.
enum StratumNavigationDecision {
  /// Continue loading the page.
  navigate,

  /// Stop the navigation.
  prevent,
}
