import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

/// The toolbar's text scale setting, with a link's factor held to the
/// slider's range (fo11/us02/fr01).
///
/// Widgetbook's own addon decodes any number from a link, so a negative or
/// not-a-number factor fails `TextScaler.linear`'s assert, and a huge one
/// draws at a scale the slider cannot show.
class CatalogTextScaleAddon extends TextScaleAddon {
  CatalogTextScaleAddon();

  /// The smallest factor the slider offers.
  static const double minFactor = 0.25;

  /// The largest factor the slider offers.
  static const double maxFactor = 3;

  /// The factor a link that names no finite number falls back to.
  static const double defaultFactor = 1;

  @override
  double valueFromQueryGroup(QueryGroup? group) {
    final factor = super.valueFromQueryGroup(group);
    if (!factor.isFinite) return defaultFactor;
    return factor.clamp(minFactor, maxFactor);
  }
}
