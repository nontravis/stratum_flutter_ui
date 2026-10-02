import 'package:stratum_ui/src/src.dart';

/// Where a [StratumFontData]'s physical family comes from.
enum StratumFontSource {
  /// A font the app registers itself, bundled or from a package.
  app,

  /// A Google Fonts family, named `Google/<Name>` in `theme.yaml`.
  google,
}

/// A physical font family plus its own size correction, as one entry of
/// `typography.fonts` in `theme.yaml`.
@immutable
class StratumFontData {
  const new({
    required this.family,
    this.package,
    this.adjustSize = const StratumDimension.fixed(0),
    this.source = StratumFontSource.app,
  });

  /// The family name the font is registered under when [source] is
  /// [StratumFontSource.app]; the bare Google Fonts family name (the
  /// `Google/` prefix already stripped) when [source] is
  /// [StratumFontSource.google].
  final String family;

  /// The package that bundles the font, or null for a font of the app.
  /// Always null when [source] is [StratumFontSource.google].
  final String? package;

  /// Added to the font size so this font looks as large as the others; a
  /// percent resolves against the requested size.
  final StratumDimension adjustSize;

  /// Where [family] comes from.
  final StratumFontSource source;

  /// `packages/<package>/<family>` when [package] is set, else [family].
  ///
  /// Meaningful only when [source] is [StratumFontSource.app]: the
  /// resolver asks [GoogleFontsLookup] for a [StratumFontSource.google]
  /// font's family instead of reading this getter, since that family
  /// depends on the requested weight and style.
  String get qualifiedFamily =>
      package == null ? family : 'packages/$package/$family';

  @override
  bool operator ==(Object other) =>
      other is StratumFontData &&
      other.family == family &&
      other.package == package &&
      other.adjustSize == adjustSize &&
      other.source == source;

  @override
  int get hashCode => Object.hash(family, package, adjustSize, source);

  @override
  String toString() =>
      'StratumFontData(family: $family, package: $package, '
      'adjustSize: $adjustSize, source: $source)';
}

/// Test seam for the two `GoogleFonts` calls a [StratumFontSource.google]
/// font needs.
///
/// Replace [exists] or [family] in a test and restore both in `tearDown`;
/// no test calls `GoogleFonts.getFont` for real, since it starts an HTTP
/// fetch. A parse test may keep the real [exists] default: it reads
/// `GoogleFonts.asMap()`, a const map with no network. Production code may
/// only read [exists] and [family]; only a test may replace them.
abstract final class GoogleFontsLookup {
  static bool Function(String name) _exists = (name) =>
      GoogleFonts.asMap().containsKey(name);

  static String Function(
    String name, {
    required FontWeight weight,
    required FontStyle? style,
  })
  _family = (name, {required weight, required style}) => GoogleFonts.getFont(
    name,
    fontWeight: weight,
    fontStyle: style,
  ).fontFamily!;

  /// Whether `GoogleFonts.asMap()` has an entry for the given Google Fonts
  /// family name; case-sensitive.
  static bool Function(String name) get exists => _exists;

  @visibleForTesting
  static set exists(bool Function(String name) value) => _exists = value;

  /// The family `GoogleFonts.getFont(name, fontWeight: weight, fontStyle:
  /// style).fontFamily` resolves.
  static String Function(
    String name, {
    required FontWeight weight,
    required FontStyle? style,
  })
  get family => _family;

  @visibleForTesting
  static set family(
    String Function(
      String name, {
      required FontWeight weight,
      required FontStyle? style,
    })
    value,
  ) => _family = value;
}
