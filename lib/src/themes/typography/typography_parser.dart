import 'package:stratum_ui/src/themes/config/format_error.dart';
import 'package:stratum_ui/src/themes/config/plain_by_window_size.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';
import 'package:stratum_ui/src/themes/constant/font_size.dart';
import 'package:stratum_ui/src/themes/constant/font_type.dart';
import 'package:stratum_ui/src/themes/font_data.dart';
import 'package:stratum_ui/src/themes/typography/dimension.dart';
import 'package:stratum_ui/src/themes/typography/text_size.dart';
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
    final typography = PlainTypography(
      fonts: fonts,
      families: families,
      scaleByWindowSize: scale == null || scale.isEmpty
          ? const PlainByWindowSize.all(StratumDimension.fixed(0))
          : PlainByWindowSize(scale),
      types: types,
    );
    _DrawSizeCheck(_reader, node, typography).run();
    return typography;
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

/// FO-02 typography s03 invariant 14: at text scale 1, every text the app
/// can draw under a parsed typography has a font size and a line box above
/// 0 px.
///
/// Tries every `FontSize`, with no window size and at each window size, in
/// every font a tag can give the type, through `textSizeOf`, the size math
/// `TypographyResolver` draws with. Reports one `expected_dimension` per
/// path to blame, its message named by the first text that fails there: by
/// size, then window size, then `FontType` order, then the order the tags
/// list the fonts (US-07 FR-02 E17 to E19).
final class _DrawSizeCheck {
  new(this._reader, this._node, this._typography);

  static const _path = 'typography';
  static const _zero = StratumDimension.fixed(0);

  final ThemeReader _reader;

  /// The `typography` subtree, for the value a message shows.
  final Map<String, Object?> _node;

  /// The values that parsed: a value another rule refuses is not here, so
  /// it draws no second error at its path (E19).
  final PlainTypography _typography;

  /// The message of each path to blame, in the order its first text fails.
  final _messages = <String, String>{};

  void run() {
    final fontKeys = {
      for (final type in FontType.values) type: _fontKeys(type),
    };
    final declaredSizes = {
      for (final type in FontType.values) type: _declaredSizes(type),
    };
    final ownDeclaredWindows = {
      for (final type in FontType.values) type: _declaredWindowsOf(type),
    };
    final themeDeclaredWindows = _declaredWindows(['scaleByWindowSize']);
    for (final size in FontSize.values) {
      for (final window in <String?>[null, ...windowSizeNames]) {
        for (final type in FontType.values) {
          final metricsType = type == FontType.table ? FontType.body : type;
          _check(
            size,
            window,
            type,
            fontKeys[type]!,
            declaredSizes[metricsType]!,
            ownDeclaredWindows[metricsType]!,
            themeDeclaredWindows,
          );
        }
      }
    }
    for (final MapEntry(key: path, value: message) in _messages.entries) {
      _reader.report(StratumThemeErrorCode.expectedDimension, path, message);
    }
  }

  void _check(
    FontSize size,
    String? window,
    FontType type,
    Set<String> fontKeys,
    Set<FontSize> declaredSizes,
    Set<String> ownDeclaredWindows,
    Set<String> themeDeclaredWindows,
  ) {
    final metricsType = type == FontType.table ? FontType.body : type;
    final style = _typography.types[metricsType];
    if (style == null) return;
    final nearest = nearestFontSize(
      declaredSizes.isEmpty ? style.sizes.keys : declaredSizes,
      size.value,
    );
    if (nearest == null) return;
    final metrics = style.sizes[nearest];
    // The nearest size the type declares may have failed to parse (E19):
    // no other declared size answers for it, so this size draws no
    // line-box error here. The font-size checks below do not read
    // spaceHeight, so they still run over every value that parsed.
    final spaceHeight = metrics?.spaceHeight ?? _zero;
    if (metrics != null && window == null) {
      final lineBox = _sizeOf(size, null, style, _zero, spaceHeight).lineBox;
      if (!isDrawableSize(lineBox)) {
        _blame(
          ['types', metricsType.name, 'sizes', nearest.name, 'spaceHeight'],
          'a spaceHeight that keeps ${size.name} above 0 px',
          '(line box ${_px(lineBox)} px)',
        );
      }
    }
    // A window whose scale entry would come from a declared-but-refused
    // value, own or theme-wide, draws no window-scale error here: the
    // value a passing theme would have used is unknown, so the check must
    // not fall through further and blame a different, unrelated entry
    // (E19).
    final shadowed =
        window != null &&
        _scaleSourceRefused(
          window,
          style,
          ownDeclaredWindows,
          themeDeclaredWindows,
        );
    for (final key in fontKeys) {
      final adjustSize = _typography.fonts[key]?.adjustSize;
      if (adjustSize == null) continue;
      final unscaled = _sizeOf(size, null, style, adjustSize, spaceHeight);
      if (!isDrawableSize(unscaled.fontSize)) {
        if (window == null) {
          _blame(
            ['fonts', key, 'adjustSize'],
            'an adjustSize that keeps ${size.name} above 0 px',
            '(${size.name} draws at ${_px(unscaled.fontSize)} px)',
          );
        }
        continue;
      }
      if (window == null || shadowed) continue;
      final sizes = _sizeOf(size, window, style, adjustSize, spaceHeight);
      final entry = sizes.windowScale;
      if (entry == null || isDrawableSize(sizes.fontSize)) continue;
      _blame(
        entry.own
            ? ['types', metricsType.name, 'scaleByWindowSize', entry.name]
            : ['scaleByWindowSize', entry.name],
        'a scaleByWindowSize that keeps ${size.name} above 0 px',
        '(${size.name} draws at ${_px(sizes.fontSize)} px)',
      );
    }
  }

  /// Whether the window scale entry `windowScaleSource` picks for [window],
  /// over the keys each raw map declares, parsed or refused ([ownDeclared]
  /// for [style]'s own map, [themeDeclared] for the theme-wide one), failed
  /// to parse: declared there, but missing from the parsed map (E19).
  bool _scaleSourceRefused(
    String window,
    PlainTypeStyle style,
    Set<String> ownDeclared,
    Set<String> themeDeclared,
  ) {
    final source = windowScaleSource(
      window,
      ownSets: ownDeclared.contains,
      themeSets: themeDeclared.contains,
    );
    if (source == null) return false;
    final parsed = source.own
        ? style.scaleByWindowSize
        : _typography.scaleByWindowSize.sizes;
    return !(parsed?.containsKey(source.name) ?? false);
  }

  TextSize _sizeOf(
    FontSize size,
    String? window,
    PlainTypeStyle style,
    StratumDimension adjustSize,
    StratumDimension spaceHeight,
  ) => textSizeOf(
    base: size.value,
    window: window,
    ownScale: style.scaleByWindowSize,
    themeScale: _typography.scaleByWindowSize.sizes,
    adjustSize: adjustSize,
    spaceHeight: spaceHeight,
  );

  /// Every font key a tag gives [type], in the order the tags list them:
  /// each tag's font for the type, then, for every type but `code`, which
  /// draws no mono font, the type's mono and the tag's theme-wide mono
  /// (s03 step 2).
  Set<String> _fontKeys(FontType type) => {
    for (final family in _typography.families.values) ...[
      ?family.types[type]?.font,
      if (type != FontType.code) ...[?family.types[type]?.mono, ?family.mono],
    ],
  };

  /// The `FontSize` keys the raw node declares for [type]'s `sizes`,
  /// parsed or refused, so `_check` finds the nearest by every size the
  /// author wrote, not only the ones that parsed (E19).
  Set<FontSize> _declaredSizes(FontType type) {
    final node = _valueAt(['types', type.name, 'sizes']);
    if (node is! Map<String, Object?>) return const {};
    final names = FontSize.values.asNameMap();
    return {for (final key in node.keys) ?names[key]};
  }

  /// The window-size names [type]'s own `scaleByWindowSize` declares,
  /// parsed or refused (E19, mirroring [_declaredSizes]); every window
  /// size name when the value itself is not a map (`expected_map`), since
  /// no entry it would have held is known to have parsed.
  Set<String> _declaredWindowsOf(FontType type) {
    final keys = ['types', type.name, 'scaleByWindowSize'];
    final value = _valueAt(keys);
    return value != null && value is! Map<String, Object?>
        ? windowSizeNames.toSet()
        : _declaredWindows(keys);
  }

  /// The window-size names the raw node declares at [keys], parsed or
  /// refused.
  Set<String> _declaredWindows(List<String> keys) {
    final node = _valueAt(keys);
    if (node is! Map<String, Object?>) return const {};
    return {
      for (final key in node.keys)
        if (windowSizeNames.contains(key)) key,
    };
  }

  /// Records the message of the path [keys] names below `typography`,
  /// unless an earlier text already named it.
  void _blame(List<String> keys, String expected, String drawn) =>
      _messages.putIfAbsent(
        [_path, ...keys].join('.'),
        () =>
            'expected $expected, got ${ThemeReader.show(_valueAt(keys))} '
            '$drawn',
      );

  Object? _valueAt(List<String> keys) {
    Object? value = _node;
    for (final key in keys) {
      value = value is Map<String, Object?> ? value[key] : null;
    }
    return value;
  }

  /// [px] rounded to two decimals, with no trailing zero: -2.0 shows `-2`.
  static String _px(double px) {
    final rounded = double.parse(px.toStringAsFixed(2));
    return rounded == rounded.truncateToDouble()
        ? '${rounded.toInt()}'
        : '$rounded';
  }
}
