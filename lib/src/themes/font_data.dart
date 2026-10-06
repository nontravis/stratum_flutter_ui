import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/typography/dimension.dart';

/// Where a [StratumFontData]'s physical family comes from.
enum StratumFontSource {
  /// A font the app registers itself, bundled or from a package.
  app,

  /// A Google Fonts family, named `Google/<Name>` in `theme.yaml`.
  google,

  /// A family whose files the theme lists under
  /// `typography.fonts.<key>.files`; the theme runtime registers them under
  /// `<source theme id>/<family>`.
  theme,
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
    this.files = const [],
  });

  /// The family name the font is registered under: as written for
  /// [StratumFontSource.app]; `<source theme id>/<family>` for
  /// [StratumFontSource.theme], the source theme being the one whose file
  /// set [files]; the bare Google Fonts family name (the `Google/` prefix
  /// already stripped) for [StratumFontSource.google].
  final String family;

  /// The package that bundles the font, or null for a font of the app.
  /// Always null when [source] is [StratumFontSource.google] or
  /// [StratumFontSource.theme].
  final String? package;

  /// Added to the font size so this font looks as large as the others; a
  /// percent resolves against the requested size.
  final StratumDimension adjustSize;

  /// Where [family] comes from.
  final StratumFontSource source;

  /// The asset path of each font file the theme lists, already joined to
  /// the folder of the theme file that set them; empty unless [source] is
  /// [StratumFontSource.theme].
  final List<String> files;

  /// `packages/<package>/<family>` when [package] is set, else [family].
  ///
  /// Meaningful for [StratumFontSource.app] and [StratumFontSource.theme]:
  /// the resolver asks the `GoogleFontsLookup` seam for a
  /// [StratumFontSource.google] font's family instead of reading this
  /// getter, since that family depends on the requested weight and style.
  String get qualifiedFamily =>
      package == null ? family : 'packages/$package/$family';

  @override
  bool operator ==(Object other) =>
      other is StratumFontData &&
      other.family == family &&
      other.package == package &&
      other.adjustSize == adjustSize &&
      other.source == source &&
      const DeepCollectionEquality().equals(other.files, files);

  @override
  int get hashCode =>
      Object.hash(family, package, adjustSize, source, Object.hashAll(files));

  @override
  String toString() =>
      'StratumFontData(family: $family, package: $package, '
      'adjustSize: $adjustSize, source: $source, files: $files)';
}
