import 'package:stratum_ui/src/src.dart';

/// A physical font family plus its own size correction, as one entry of
/// `typography.fonts` in `theme.yaml`.
@immutable
class StratumFontData {
  const new({
    required this.family,
    this.package,
    this.adjustSize = const StratumDimension.fixed(0),
  });

  /// The family name the font is registered under.
  final String family;

  /// The package that bundles the font, or null for a font of the app.
  final String? package;

  /// Added to the font size so this font looks as large as the others; a
  /// percent resolves against the requested size.
  final StratumDimension adjustSize;

  /// `packages/<package>/<family>` when [package] is set, else [family].
  String get qualifiedFamily =>
      package == null ? family : 'packages/$package/$family';

  @override
  bool operator ==(Object other) =>
      other is StratumFontData &&
      other.family == family &&
      other.package == package &&
      other.adjustSize == adjustSize;

  @override
  int get hashCode => Object.hash(family, package, adjustSize);

  @override
  String toString() =>
      'StratumFontData(family: $family, package: $package, '
      'adjustSize: $adjustSize)';
}
