import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';
import 'package:stratum_ui/src/themes/config/theme_model.dart';
import 'package:stratum_ui/src/themes/typography/google_fonts_lookup.dart';

part 'generated/typography.freezed.dart';

/// The fonts one type uses under one locale tag.
@immutable
@themeModel
class StratumFontRef with _$StratumFontRef {
  const new({required this.font, this.mono});

  /// Key into [StratumTypography.fonts].
  final String font;

  /// Key into [StratumTypography.fonts] that `.mono` swaps to, or null.
  final String? mono;

  @override
  String toString() => 'StratumFontRef(font: $font, mono: $mono)';
}

/// The fonts of one `typography.families` entry, that is one locale tag.
@themeModel
abstract class StratumFamilySet with _$StratumFamilySet {
  const factory({
    /// The fonts of each type this tag names.
    required Map<FontType, StratumFontRef> types,

    /// Key of the theme-wide mono font of this tag, for `.mono` on a type
    /// without a mono font of its own, or null.
    String? mono,
  }) = _StratumFamilySet;

  const new _();

  @override
  String toString() => 'StratumFamilySet(types: $types, mono: $mono)';
}

/// The line spacing and tracking of one type at one size.
@immutable
@themeModel
class StratumSizeMetrics with _$StratumSizeMetrics {
  const new({
    required this.spaceHeight,
    this.letterSpacing = const StratumDimension.fixed(0),
  });

  /// Added to the size to give the line box; a percent resolves against
  /// the scaled requested size, before the window scale.
  final StratumDimension spaceHeight;

  /// The tracking; a percent resolves against the scaled size.
  final StratumDimension letterSpacing;

  @override
  String toString() =>
      'StratumSizeMetrics(spaceHeight: $spaceHeight, '
      'letterSpacing: $letterSpacing)';
}

/// One entry of `typography.types`. There is no `table` entry: `table`
/// reads `body`'s style in code and always draws tabular figures.
@themeModel
abstract class StratumTypeStyle with _$StratumTypeStyle {
  const factory({
    /// The weight when the text style sets none.
    required FontWeight weight,

    /// The metrics of each size this type defines, smallest first.
    required Map<FontSize, StratumSizeMetrics> sizes,

    /// The window scale of this type, or null for the theme-wide one.
    Map<WindowSize, StratumDimension>? scaleByWindowSize,
  }) = _StratumTypeStyle;

  const new _();

  @override
  String toString() =>
      'StratumTypeStyle(weight: $weight, '
      'scaleByWindowSize: $scaleByWindowSize, sizes: $sizes)';
}

/// The typography of a theme: the `typography:` subtree of `theme.yaml`.
@themeModel
abstract class StratumTypography with _$StratumTypography {
  const factory({
    /// Each font by its key.
    required Map<String, StratumFontData> fonts,

    /// Each family set by its locale tag (`default`, `th`, `th_TH`), in
    /// yaml order.
    required Map<String, StratumFamilySet> families,

    /// The style of every type except `table`, which has no entry here:
    /// its style is `body`'s, read in code.
    required Map<FontType, StratumTypeStyle> types,

    /// The size each window size adds. A window size the yaml map omits
    /// takes the value of the nearest smaller window size it names, else
    /// of the smallest one it names; a theme without the map adds 0
    /// everywhere.
    @Default(
      StratumByWindowSize<StratumDimension>.all(StratumDimension.fixed(0)),
    )
    StratumByWindowSize<StratumDimension> scaleByWindowSize,
  }) = _StratumTypography;

  /// Parses the `typography:` node of one `theme.yaml` file.
  ///
  /// Collects every problem, an unknown key included, and throws one
  /// [StratumThemeFormatException] that lists them all; each error carries
  /// [source] as its file id. A font's `files` resolve against [folder],
  /// the folder of that file, and register under `<source>/<family>`.
  factory fromYaml(
    YamlMap node, {
    String source = 'theme',
    String folder = '',
  }) {
    final origins = <String, ThemeOrigin>{};
    final tree = plainOf(node, path: 'typography', source: 0, origins: origins);
    final errors = ThemeErrors([source]);
    final typography = readTypography(
      tree! as Map<String, Object?>,
      ThemeReader(errors, origins),
      sources: [(id: source, folder: folder)],
    );
    errors.throwIfAny();
    return typography;
  }
}

/// Reads the `typography` subtree [node], which sits at the path
/// `typography`, and reports every problem through [reader].
///
/// [sources] lists the id and the folder of each file of the parse, in the
/// order of the source indexes [reader]'s origins hold; a font's `files`
/// take the id and the folder of the file that set them. An empty [sources]
/// reads as one file with the id `theme` and no folder.
///
/// Internal: `lib/src/themes/themes.dart` hides it from the public API.
/// `StratumTypography.fromYaml` runs it on one file, and stage 5 of
/// `StratumThemeConfig.parse` on the merged layers.
StratumTypography readTypography(
  Map<String, Object?> node,
  ThemeReader reader, {
  List<({String id, String folder})> sources = const [],
}) => _TypographyParser(reader, sources).parse(node);

class _TypographyParser {
  new(this._reader, this._sources);

  static const _path = 'typography';
  static const _googlePrefix = 'Google/';
  static final _tagPattern = RegExp(r'^([a-z]{2,3})(?:[-_]([A-Z]{2}))?$');
  static final _fontFile = RegExp(r'\.(ttf|otf)$', caseSensitive: false);

  final ThemeReader _reader;
  final List<({String id, String folder})> _sources;

  StratumTypography parse(Map<String, Object?> node) {
    _checkKeys(node, _path, const {
      'fonts',
      'families',
      'scaleByWindowSize',
      'types',
    });
    final fontsNode = _reader.map(node['fonts'], '$_path.fonts');
    final fontKeys = {...?fontsNode?.keys};
    final fonts = _fonts(fontsNode, '$_path.fonts');
    final familiesNode = _reader.map(node['families'], '$_path.families');
    final families = _families(familiesNode, '$_path.families', fontKeys);
    final scale = _scale(node['scaleByWindowSize'], '$_path.scaleByWindowSize');
    final types = _types(
      _reader.map(node['types'], '$_path.types'),
      '$_path.types',
    );
    if (familiesNode != null) {
      _checkDefaultFamily(familiesNode, '$_path.families.default');
    }
    return StratumTypography(
      fonts: fonts,
      families: families,
      scaleByWindowSize: scale == null || scale.isEmpty
          ? const StratumByWindowSize.all(StratumDimension.fixed(0))
          : StratumByWindowSize(scale),
      types: types,
    );
  }

  Map<String, StratumFontData> _fonts(Map<String, Object?>? node, String path) {
    if (node == null) return const {};
    if (node.isEmpty) {
      _error(
        StratumThemeErrorCode.emptyFonts,
        path,
        'expected at least one font',
      );
    }
    final fonts = <String, StratumFontData>{};
    for (final MapEntry(:key, :value) in node.entries) {
      final fontPath = '$path.$key';
      final font = _reader.map(value, fontPath);
      if (font == null) continue;
      _checkKeys(font, fontPath, const {
        'family',
        'package',
        'adjustSize',
        'files',
      });
      final rawFamily = _reader.string(font['family'], '$fontPath.family');
      final package = _reader.string(
        font['package'],
        '$fontPath.package',
        required: false,
      );
      final adjustSize = _reader.dimension(
        font['adjustSize'],
        '$fontPath.adjustSize',
      );
      final files = font.containsKey('files')
          ? _files(font['files'], '$fontPath.files')
          : null;
      if (rawFamily == null) continue;
      final google = rawFamily.startsWith(_googlePrefix);
      if (files != null && google) {
        _error(
          StratumThemeErrorCode.googleFontFiles,
          '$fontPath.files',
          'files are not allowed with a Google font',
        );
      }
      final resolved = _googleFamily(rawFamily, package, fontPath);
      if (resolved == null) continue;
      if (files != null && !google && package != null) {
        _error(
          StratumThemeErrorCode.fontFilesPackage,
          '$fontPath.package',
          'package is not allowed with files',
        );
      }
      if (files == null || google) {
        fonts[key] = StratumFontData(
          family: resolved.family,
          package: google ? null : package,
          adjustSize: adjustSize ?? const StratumDimension.fixed(0),
          source: resolved.source,
        );
        continue;
      }
      final origin = _sourceOf('$fontPath.files');
      fonts[key] = StratumFontData(
        family: '${origin.id}/${resolved.family}',
        adjustSize: adjustSize ?? const StratumDimension.fixed(0),
        source: StratumFontSource.theme,
        files: List.unmodifiable([
          for (final file in files) _join(origin.folder, file),
        ]),
      );
    }
    return frozenMap(fonts);
  }

  /// The entries of a font's `files` list that pass: reports
  /// `empty_font_files` for an empty list, and `invalid_font_file` for a
  /// value that is not a list and for each entry that is not a relative
  /// path inside the theme folder ending in `ttf` or `otf` (any case).
  List<String> _files(Object? value, String path) {
    if (value is! List<Object?>) {
      _invalidFontFile(path, value);
      return const [];
    }
    if (value.isEmpty) {
      _error(
        StratumThemeErrorCode.emptyFontFiles,
        path,
        'expected at least one font file',
      );
    }
    final files = <String>[];
    for (final entry in value) {
      if (entry is String &&
          !entry.startsWith('/') &&
          !entry.split('/').contains('..') &&
          _fontFile.hasMatch(entry)) {
        files.add(entry);
      } else {
        _invalidFontFile(path, entry);
      }
    }
    return files;
  }

  void _invalidFontFile(String path, Object? value) => _error(
    StratumThemeErrorCode.invalidFontFile,
    path,
    'expected a path inside the theme folder ending in .ttf or .otf, got '
    '${ThemeReader.show(value)}',
  );

  /// The id and the folder of the file that set [path].
  ({String id, String folder}) _sourceOf(String path) {
    final index = _reader.origins[path]?.source ?? 0;
    return index < _sources.length
        ? _sources[index]
        : (id: 'theme', folder: '');
  }

  /// [file] below [folder], with one `/` between them.
  static String _join(String folder, String file) {
    final base = folder.endsWith('/')
        ? folder.substring(0, folder.length - 1)
        : folder;
    return base.isEmpty ? file : '$base/$file';
  }

  /// `rawFamily` as-is for an app font; the bare Google Fonts name, with
  /// [StratumFontSource.google], for the exact prefix `Google/`. Returns
  /// null and reports an error when the name is empty after the prefix or
  /// `GoogleFontsLookup.exists` does not know it; also reports an error
  /// when [package] is set together with a Google family.
  ({String family, StratumFontSource source})? _googleFamily(
    String rawFamily,
    String? package,
    String fontPath,
  ) {
    if (!rawFamily.startsWith(_googlePrefix)) {
      return (family: rawFamily, source: StratumFontSource.app);
    }
    if (package != null) {
      _error(
        StratumThemeErrorCode.googleFontPackage,
        '$fontPath.package',
        'package is not allowed with a Google font',
      );
    }
    final name = rawFamily.substring(_googlePrefix.length);
    if (name.isEmpty) {
      _error(
        StratumThemeErrorCode.emptyGoogleFont,
        '$fontPath.family',
        'expected a font name after "Google/"',
      );
      return null;
    }
    if (!GoogleFontsLookup.exists(name)) {
      _error(
        StratumThemeErrorCode.unknownGoogleFont,
        '$fontPath.family',
        'unknown Google Fonts family "$name"',
      );
      return null;
    }
    return (family: name, source: StratumFontSource.google);
  }

  Map<String, StratumFamilySet> _families(
    Map<String, Object?>? node,
    String path,
    Set<String> fontKeys,
  ) {
    if (node == null) return const {};
    final families = <String, StratumFamilySet>{};
    for (final MapEntry(:key, :value) in node.entries) {
      final tagPath = '$path.$key';
      final tag = _tag(key, tagPath);
      final entry = _reader.map(value, tagPath);
      if (tag == null || entry == null) continue;
      if (families.containsKey(tag)) {
        _error(
          StratumThemeErrorCode.duplicateTag,
          tagPath,
          'duplicate tag "$tag"',
        );
        continue;
      }
      final types = <FontType, StratumFontRef>{};
      String? mono;
      for (final MapEntry(key: name, value: ref) in entry.entries) {
        final refPath = '$tagPath.$name';
        if (name == 'mono') {
          mono = _fontKey(ref, refPath, fontKeys);
          continue;
        }
        final type = FontType.values.asNameMap()[name];
        if (type == null) {
          _unknownKey(refPath, name);
          continue;
        }
        final fontRef = _fontRef(ref, refPath, fontKeys);
        if (fontRef != null) types[type] = fontRef;
      }
      families[tag] = StratumFamilySet(types: frozenMap(types), mono: mono);
    }
    return frozenMap(families);
  }

  String? _tag(String key, String path) {
    if (key == 'default') return key;
    final match = _tagPattern.firstMatch(key);
    if (match == null) {
      _error(
        StratumThemeErrorCode.invalidTag,
        path,
        'expected "default", a language such as "th", or a language and '
        'country such as "th_TH"',
      );
      return null;
    }
    final country = match[2];
    return country == null ? match[1] : '${match[1]}_$country';
  }

  StratumFontRef? _fontRef(Object? value, String path, Set<String> keys) {
    if (value is! Map<String, Object?>) {
      final font = _fontKey(value, path, keys);
      return font == null ? null : StratumFontRef(font: font);
    }
    _checkKeys(value, path, const {'font', 'mono'});
    final font = _fontKey(value['font'], '$path.font', keys);
    final mono = value['mono'] == null
        ? null
        : _fontKey(value['mono'], '$path.mono', keys);
    return font == null ? null : StratumFontRef(font: font, mono: mono);
  }

  String? _fontKey(Object? value, String path, Set<String> keys) {
    final key = _reader.string(value, path);
    if (key == null) return null;
    if (keys.isEmpty || keys.contains(key)) return key;
    _error(
      StratumThemeErrorCode.unknownFontKey,
      path,
      'unknown font key "$key"',
    );
    return null;
  }

  Map<WindowSize, StratumDimension>? _scale(Object? value, String path) {
    final node = _reader.map(value, path, required: false);
    if (node == null) return null;
    final scale = <WindowSize, StratumDimension>{};
    for (final MapEntry(:key, :value) in node.entries) {
      final sizePath = '$path.$key';
      final windowSize = WindowSize.values.asNameMap()[key];
      if (windowSize == null) {
        _reader.report(
          StratumThemeErrorCode.unknownKey,
          sizePath,
          'unknown window size "$key"',
          atKey: true,
        );
        continue;
      }
      final dimension = _reader.dimension(value, sizePath, required: true);
      if (dimension != null) scale[windowSize] = dimension;
    }
    return frozenMap(scale);
  }

  Map<FontType, StratumTypeStyle> _types(
    Map<String, Object?>? node,
    String path,
  ) {
    if (node == null) return const {};
    final types = <FontType, StratumTypeStyle>{};
    final seen = <FontType>{};
    for (final MapEntry(:key, :value) in node.entries) {
      final typePath = '$path.$key';
      final type = FontType.values.asNameMap()[key];
      if (type == null) {
        _unknownKey(typePath, key);
        continue;
      }
      if (type == FontType.table) {
        _error(
          StratumThemeErrorCode.tableBlock,
          typePath,
          "table takes body's metrics; remove this block",
        );
        continue;
      }
      seen.add(type);
      final typeNode = _reader.map(value, typePath);
      if (typeNode == null) continue;
      final style = _typeStyle(typeNode, typePath);
      if (style != null) types[type] = style;
    }
    for (final type in FontType.values) {
      if (type == FontType.table || seen.contains(type)) continue;
      _error(StratumThemeErrorCode.required, '$path.${type.name}', 'required');
    }
    return frozenMap(types);
  }

  StratumTypeStyle? _typeStyle(Map<String, Object?> node, String path) {
    _checkKeys(node, path, const {'weight', 'sizes', 'scaleByWindowSize'});
    final weight = _weight(node['weight'], '$path.weight');
    if (weight == null && node['weight'] == null) {
      _error(StratumThemeErrorCode.required, '$path.weight', 'required');
    }
    final scale = _scale(node['scaleByWindowSize'], '$path.scaleByWindowSize');
    final sizes = _sizes(node['sizes'], '$path.sizes');
    if (sizes.isEmpty) {
      _error(
        StratumThemeErrorCode.emptySizes,
        '$path.sizes',
        'expected at least one size',
      );
    }
    if (weight == null || sizes.isEmpty) return null;
    return StratumTypeStyle(
      weight: weight,
      scaleByWindowSize: scale,
      sizes: frozenMap({
        for (final size in FontSize.values) size: ?sizes[size],
      }),
    );
  }

  Map<FontSize, StratumSizeMetrics> _sizes(Object? value, String path) {
    final node = _reader.map(value, path, required: false);
    if (node == null) return const {};
    final sizes = <FontSize, StratumSizeMetrics>{};
    for (final MapEntry(:key, :value) in node.entries) {
      final sizePath = '$path.$key';
      final size = FontSize.values.asNameMap()[key];
      if (size == null) {
        _unknownKey(sizePath, key);
        continue;
      }
      final metrics = _reader.map(value, sizePath);
      if (metrics == null) continue;
      _checkKeys(metrics, sizePath, const {'spaceHeight', 'letterSpacing'});
      final spaceHeight = _reader.dimension(
        metrics['spaceHeight'],
        '$sizePath.spaceHeight',
        required: true,
      );
      final letterSpacing = _reader.dimension(
        metrics['letterSpacing'],
        '$sizePath.letterSpacing',
      );
      if (spaceHeight == null) continue;
      sizes[size] = StratumSizeMetrics(
        spaceHeight: spaceHeight,
        letterSpacing: letterSpacing ?? const StratumDimension.fixed(0),
      );
    }
    return frozenMap(sizes);
  }

  FontWeight? _weight(Object? value, String path) {
    if (value == null) return null;
    if (value is int && value >= 100 && value <= 900 && value % 100 == 0) {
      return FontWeight.values[value ~/ 100 - 1];
    }
    _error(
      StratumThemeErrorCode.invalidWeight,
      path,
      'expected 100 to 900 in steps of 100, got ${ThemeReader.show(value)}',
    );
    return null;
  }

  /// Reports each type the `default` family set does not name directly.
  ///
  /// Reads the names from the tree, so a bad font reference, which has its
  /// own error, still counts as naming the type.
  void _checkDefaultFamily(Map<String, Object?> families, String path) {
    if (!families.containsKey('default')) {
      _error(StratumThemeErrorCode.required, path, 'required');
      return;
    }
    final defaults = families['default'];
    if (defaults is! Map<String, Object?>) return;
    for (final type in FontType.values) {
      if (defaults.containsKey(type.name)) continue;
      _error(
        StratumThemeErrorCode.missingDefaultFont,
        '$path.${type.name}',
        'no font for type "${type.name}"',
      );
    }
  }

  /// Reports `unknown_key` at each key of [node] outside [known].
  void _checkKeys(Map<String, Object?> node, String path, Set<String> known) {
    for (final key in node.keys) {
      if (!known.contains(key)) _unknownKey('$path.$key', key);
    }
  }

  void _unknownKey(String path, String key) => _reader.report(
    StratumThemeErrorCode.unknownKey,
    path,
    'unknown key "$key"',
    atKey: true,
  );

  void _error(StratumThemeErrorCode code, String path, String message) =>
      _reader.report(code, path, message);
}
