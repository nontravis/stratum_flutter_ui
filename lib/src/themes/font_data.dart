import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/typography/dimension.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/font_data.freezed.dart';

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
@valueModel
abstract class StratumFontData with _$StratumFontData {
  const factory({
    /// The family name the font is registered under: as written for
    /// [StratumFontSource.app]; `<source theme id>/<family>` for
    /// [StratumFontSource.theme], the source theme being the one whose file
    /// set [files]; the bare Google Fonts family name (the `Google/` prefix
    /// already stripped) for [StratumFontSource.google].
    required String family,

    /// The package that bundles the font, or null for a font of the app.
    /// Always null when [source] is [StratumFontSource.google] or
    /// [StratumFontSource.theme].
    String? package,

    /// Added to the font size so this font looks as large as the others; a
    /// percent resolves against the requested size.
    @Default(StratumDimension.fixed(0)) StratumDimension adjustSize,

    /// Where [family] comes from.
    @Default(StratumFontSource.app) StratumFontSource source,

    /// The asset path of each font file the theme lists, already joined to
    /// the folder of the theme file that set them; empty unless [source] is
    /// [StratumFontSource.theme].
    @Default(<String>[]) List<String> files,
  }) = _StratumFontData;

  const new _();

  /// `packages/<package>/<family>` when [package] is set, else [family].
  ///
  /// Meaningful for [StratumFontSource.app] and [StratumFontSource.theme]:
  /// the resolver asks the `GoogleFontsLookup` seam for a
  /// [StratumFontSource.google] font's family instead of reading this
  /// getter, since that family depends on the requested weight and style.
  String get qualifiedFamily =>
      package == null ? family : 'packages/$package/$family';

  @override
  String toString() =>
      'StratumFontData(family: $family, package: $package, '
      'adjustSize: $adjustSize, source: $source, files: $files)';
}
