import 'package:stratum_ui/src/themes/config/format_error.dart';
import 'package:stratum_ui/src/themes/config/plain_by_window_size.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';
import 'package:stratum_ui/src/themes/constant/font_size.dart';
import 'package:stratum_ui/src/themes/constant/font_type.dart';
import 'package:stratum_ui/src/themes/font_data.dart';
import 'package:stratum_ui/src/themes/typography/dimension.dart';
import 'package:stratum_ui/src/themes/typography/typography_models.dart';

/// One entry of `typography.types` as stage 5 reads it: the plain twin of
/// `StratumTypeStyle`, its weight a number (FO-01 s01 Theme config data).
/// Internal: not exported.
final class PlainTypeStyle {
  const new({
    required this.weight,
    required this.sizes,
    this.scaleByWindowSize,
  });

  /// 100 to 900 in steps of 100.
  final int weight;

  /// The metrics of each size this type defines, smallest first.
  final Map<FontSize, StratumSizeMetrics> sizes;

  /// The window scale of this type by window size name, or null.
  final Map<String, StratumDimension>? scaleByWindowSize;
}

/// The `typography:` subtree as stage 5 reads it: the plain twin of
/// `StratumTypography`. Internal: not exported.
final class PlainTypography {
  const new({
    required this.fonts,
    required this.families,
    required this.types,
    this.scaleByWindowSize = const PlainByWindowSize.all(
      StratumDimension.fixed(0),
    ),
  });

  /// Each font by its key.
  final Map<String, StratumFontData> fonts;

  /// Each family set by its locale tag, in yaml order.
  final Map<String, StratumFamilySet> families;

  /// The style of every type except `table`.
  final Map<FontType, PlainTypeStyle> types;

  /// The size each window size adds.
  final PlainByWindowSize scaleByWindowSize;
}

/// Reads the `typography` subtree [node], which sits at the path
/// `typography`, and reports every problem through [reader].
///
/// [sources] lists the id and the folder of each file of the parse, in the
/// order of the source indexes [reader]'s origins hold; a font's `files`
/// take the id and the folder of the file that set them. An empty [sources]
/// reads as one file with the id `theme` and no folder.
///
/// [googleFontExists] answers whether a Google Fonts family exists: the
/// app passes `GoogleFontsLookup.exists`, the CLI a generated list (plan
/// D-j).
///
/// Internal: not exported; `StratumTypography.fromYaml` runs it, then
/// `convertTypography`, and stage 5 runs it on the merged layers.
PlainTypography readTypography(
  Map<String, Object?> node,
  ThemeReader reader, {
  List<({String id, String folder})> sources = const [],
  required bool Function(String name) googleFontExists,
}) => _TypographyParser(reader, sources, googleFontExists).parse(node);

class _TypographyParser {
  new(this._reader, this._sources, this._googleFontExists);

  static const _path = 'typography';
  static const _googlePrefix = 'Google/';
  static final _tagPattern = RegExp(r'^([a-z]{2,3})(?:[-_]([A-Z]{2}))?$');
  static final _fontFile = RegExp(r'\.(ttf|otf)$', caseSensitive: false);

  final ThemeReader _reader;
  final List<({String id, String folder})> _sources;
  final bool Function(String name) _googleFontExists;

  PlainTypography parse(Map<String, Object?> node) {
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
    return PlainTypography(
      fonts: fonts,
      families: families,
      scaleByWindowSize: scale == null || scale.isEmpty
          ? const PlainByWindowSize.all(StratumDimension.fixed(0))
          : PlainByWindowSize(scale),
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
        percent: true,
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
  /// [_googleFontExists] does not know it; also reports an error
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
    if (!_googleFontExists(name)) {
      _error(
        StratumThemeErrorCode.unknownGoogleFont,
        '$fontPath.family',
        'unknown Google Fonts family ${ThemeReader.show(name)}',
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
          'duplicate tag ${ThemeReader.show(tag)}',
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
      'unknown font key ${ThemeReader.show(key)}',
    );
    return null;
  }

  Map<String, StratumDimension>? _scale(Object? value, String path) {
    final node = _reader.map(value, path, required: false);
    if (node == null) return null;
    final scale = <String, StratumDimension>{};
    for (final MapEntry(:key, :value) in node.entries) {
      final sizePath = '$path.$key';
      if (!windowSizeNames.contains(key)) {
        _reader.report(
          StratumThemeErrorCode.unknownKey,
          sizePath,
          'unknown window size ${ThemeReader.show(key)}',
          atKey: true,
        );
        continue;
      }
      final dimension = _reader.dimension(
        value,
        sizePath,
        percent: true,
        required: true,
      );
      if (dimension != null) scale[key] = dimension;
    }
    return Map.unmodifiable(scale);
  }

  Map<FontType, PlainTypeStyle> _types(
    Map<String, Object?>? node,
    String path,
  ) {
    if (node == null) return const {};
    final types = <FontType, PlainTypeStyle>{};
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
    return Map.unmodifiable(types);
  }

  PlainTypeStyle? _typeStyle(Map<String, Object?> node, String path) {
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
    return PlainTypeStyle(
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
        percent: true,
        required: true,
      );
      final letterSpacing = _reader.dimension(
        metrics['letterSpacing'],
        '$sizePath.letterSpacing',
        percent: true,
      );
      if (spaceHeight == null) continue;
      sizes[size] = StratumSizeMetrics(
        spaceHeight: spaceHeight,
        letterSpacing: letterSpacing ?? const StratumDimension.fixed(0),
      );
    }
    return sizes;
  }

  int? _weight(Object? value, String path) {
    if (value == null) return null;
    if (value is int && value >= 100 && value <= 900 && value % 100 == 0) {
      return value;
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
    'unknown key ${ThemeReader.show(key)}',
    atKey: true,
  );

  void _error(StratumThemeErrorCode code, String path, String message) =>
      _reader.report(code, path, message);
}
