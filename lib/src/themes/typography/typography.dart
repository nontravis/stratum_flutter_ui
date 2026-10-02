import 'package:stratum_ui/src/src.dart';

/// The fonts one type uses under one locale tag.
@immutable
class StratumFontRef {
  const new({required this.font, this.mono});

  /// Key into [StratumTypography.fonts].
  final String font;

  /// Key into [StratumTypography.fonts] that `.mono` swaps to, or null.
  final String? mono;

  @override
  bool operator ==(Object other) =>
      other is StratumFontRef && other.font == font && other.mono == mono;

  @override
  int get hashCode => Object.hash(font, mono);

  @override
  String toString() => 'StratumFontRef(font: $font, mono: $mono)';
}

/// The fonts of one `typography.families` entry, that is one locale tag.
@immutable
class StratumFamilySet {
  const new({required this.types, this.mono});

  /// The fonts of each type this tag names.
  final Map<FontType, StratumFontRef> types;

  /// Key of the theme-wide mono font of this tag, for `.mono` on a type
  /// without a mono font of its own, or null.
  final String? mono;

  @override
  bool operator ==(Object other) =>
      other is StratumFamilySet &&
      mapEquals(other.types, types) &&
      other.mono == mono;

  @override
  int get hashCode => Object.hash(_mapHash(types), mono);

  @override
  String toString() => 'StratumFamilySet(types: $types, mono: $mono)';
}

/// The line spacing and tracking of one type at one size.
@immutable
class StratumSizeMetrics {
  const new({
    required this.spaceHeight,
    this.letterSpacing = const StratumDimension.fixed(0),
  });

  /// Added to the size to give the line box; a percent resolves against
  /// the scaled size.
  final StratumDimension spaceHeight;

  /// The tracking; a percent resolves against the scaled size.
  final StratumDimension letterSpacing;

  @override
  bool operator ==(Object other) =>
      other is StratumSizeMetrics &&
      other.spaceHeight == spaceHeight &&
      other.letterSpacing == letterSpacing;

  @override
  int get hashCode => Object.hash(spaceHeight, letterSpacing);

  @override
  String toString() =>
      'StratumSizeMetrics(spaceHeight: $spaceHeight, '
      'letterSpacing: $letterSpacing)';
}

/// One entry of `typography.types`, with `extends` already merged in.
@immutable
class StratumTypeStyle {
  const new({
    required this.weight,
    required this.sizes,
    this.tabular = false,
    this.extendsType,
    this.scaleByWindowSize,
  });

  /// The weight when the text style sets none.
  final FontWeight weight;

  /// Whether the type draws tabular figures.
  final bool tabular;

  /// The type this one extends; the family lookup walks it.
  final FontType? extendsType;

  /// The window scale of this type, or null for the theme-wide one.
  final Map<WindowSize, StratumDimension>? scaleByWindowSize;

  /// The metrics of each size this type defines, smallest first.
  final Map<FontSize, StratumSizeMetrics> sizes;

  @override
  bool operator ==(Object other) =>
      other is StratumTypeStyle &&
      other.weight == weight &&
      other.tabular == tabular &&
      other.extendsType == extendsType &&
      mapEquals(other.scaleByWindowSize, scaleByWindowSize) &&
      mapEquals(other.sizes, sizes);

  @override
  int get hashCode => Object.hash(
    weight,
    tabular,
    extendsType,
    scaleByWindowSize == null ? null : _mapHash(scaleByWindowSize!),
    _mapHash(sizes),
  );

  @override
  String toString() =>
      'StratumTypeStyle(weight: $weight, tabular: $tabular, '
      'extendsType: $extendsType, scaleByWindowSize: $scaleByWindowSize, '
      'sizes: $sizes)';
}

/// The typography of a theme: the `typography:` subtree of `theme.yaml`.
@immutable
class StratumTypography {
  const new({
    required this.fonts,
    required this.families,
    required this.types,
    this.scaleByWindowSize = const {},
  });

  /// Parses the `typography:` node of `theme.yaml`.
  ///
  /// Collects every problem with its yaml path and throws one
  /// [StratumThemeFormatException] that lists them all. An unknown key
  /// prints one debug warning and is skipped.
  factory fromYaml(YamlMap node) => _TypographyParser().parse(node);

  /// Each font by its key.
  final Map<String, StratumFontData> fonts;

  /// Each family set by its locale tag (`default`, `th`, `th_TH`), in yaml
  /// order.
  final Map<String, StratumFamilySet> families;

  /// The size each window size adds; a missing window size adds 0.
  final Map<WindowSize, StratumDimension> scaleByWindowSize;

  /// The style of every type.
  final Map<FontType, StratumTypeStyle> types;

  @override
  bool operator ==(Object other) =>
      other is StratumTypography &&
      mapEquals(other.fonts, fonts) &&
      mapEquals(other.families, families) &&
      mapEquals(other.scaleByWindowSize, scaleByWindowSize) &&
      mapEquals(other.types, types);

  @override
  int get hashCode => Object.hash(
    _mapHash(fonts),
    _mapHash(families),
    _mapHash(scaleByWindowSize),
    _mapHash(types),
  );
}

/// One problem in `theme.yaml`, at [path].
@immutable
class StratumThemeFormatError {
  const new(this.path, this.message);

  /// The yaml path, for example `typography.types.body.sizes.s16`.
  final String path;

  /// What is wrong at [path].
  final String message;

  @override
  bool operator ==(Object other) =>
      other is StratumThemeFormatError &&
      other.path == path &&
      other.message == message;

  @override
  int get hashCode => Object.hash(path, message);

  @override
  String toString() => '$path: $message';
}

/// Thrown when `theme.yaml` has one or more problems; [errors] lists them
/// all.
class StratumThemeFormatException implements Exception {
  const new(this.errors);

  /// Every problem found, in the order the parser met them.
  final List<StratumThemeFormatError> errors;

  @override
  String toString() => [
    'StratumThemeFormatException: ${errors.length} problem(s) in theme.yaml',
    for (final error in errors) '  $error',
  ].join('\n');
}

int _mapHash(Map<Object?, Object?> map) => Object.hashAllUnordered(
  map.entries.map((entry) => Object.hash(entry.key, entry.value)),
);

/// One `typography.types` entry before `extends` is merged.
class _RawType {
  const new({
    required this.node,
    required this.sizes,
    this.weight,
    this.tabular,
    this.extendsType,
    this.scale,
  });

  final YamlMap node;
  final FontWeight? weight;
  final bool? tabular;
  final FontType? extendsType;
  final Map<WindowSize, StratumDimension>? scale;
  final Map<FontSize, StratumSizeMetrics> sizes;
}

class _TypographyParser {
  final _errors = <StratumThemeFormatError>[];
  final _extends = <FontType, FontType>{};

  /// Types whose `extends` names an unknown type.
  final _brokenExtends = <FontType>{};

  /// Types whose `extends` chain runs into a cycle.
  final _cycles = <FontType>{};

  static final _tagPattern = RegExp(r'^([a-z]{2,3})(?:[-_]([A-Z]{2}))?$');

  StratumTypography parse(YamlMap node) {
    const path = 'typography';
    _warnUnknown(node, path, const {
      'fonts',
      'families',
      'scaleByWindowSize',
      'types',
    });
    final fontsNode = _map(node['fonts'], '$path.fonts');
    final fontKeys = {...?fontsNode?.keys.map((key) => '$key')};
    final fonts = _fonts(fontsNode, '$path.fonts');
    final familiesNode = _map(node['families'], '$path.families');
    final families = _families(familiesNode, '$path.families', fontKeys);
    final scale = _scale(node['scaleByWindowSize'], '$path.scaleByWindowSize');
    final types = _types(_map(node['types'], '$path.types'), '$path.types');
    if (familiesNode != null) {
      _checkDefaultFamily(familiesNode, '$path.families.default');
    }
    if (_errors.isNotEmpty) {
      throw StratumThemeFormatException(List.unmodifiable(_errors));
    }
    return StratumTypography(
      fonts: fonts,
      families: families,
      scaleByWindowSize: scale ?? const {},
      types: types,
    );
  }

  Map<String, StratumFontData> _fonts(YamlMap? node, String path) {
    if (node == null) return const {};
    if (node.isEmpty) _error(path, 'expected at least one font');
    final fonts = <String, StratumFontData>{};
    for (final MapEntry(:key, :value) in node.entries) {
      final fontPath = '$path.$key';
      final font = _map(value, fontPath);
      if (font == null) continue;
      _warnUnknown(font, fontPath, const {'family', 'package', 'adjustSize'});
      final family = _string(font['family'], '$fontPath.family');
      final package = _string(
        font['package'],
        '$fontPath.package',
        required: false,
      );
      final adjustSize = _dimension(font['adjustSize'], '$fontPath.adjustSize');
      if (family == null) continue;
      fonts['$key'] = StratumFontData(
        family: family,
        package: package,
        adjustSize: adjustSize ?? const StratumDimension.fixed(0),
      );
    }
    return fonts;
  }

  Map<String, StratumFamilySet> _families(
    YamlMap? node,
    String path,
    Set<String> fontKeys,
  ) {
    if (node == null) return const {};
    final families = <String, StratumFamilySet>{};
    for (final MapEntry(:key, :value) in node.entries) {
      final tagPath = '$path.$key';
      final tag = _tag('$key', tagPath);
      final entry = _map(value, tagPath);
      if (tag == null || entry == null) continue;
      final types = <FontType, StratumFontRef>{};
      String? mono;
      for (final MapEntry(key: name, value: ref) in entry.entries) {
        final refPath = '$tagPath.$name';
        if (name == 'mono') {
          mono = _fontKey(ref, refPath, fontKeys);
          continue;
        }
        final type = FontType.values.asNameMap()['$name'];
        if (type == null) {
          _warn(refPath);
          continue;
        }
        final fontRef = _fontRef(ref, refPath, fontKeys);
        if (fontRef != null) types[type] = fontRef;
      }
      families[tag] = StratumFamilySet(types: types, mono: mono);
    }
    return families;
  }

  String? _tag(String key, String path) {
    if (key == 'default') return key;
    final match = _tagPattern.firstMatch(key);
    if (match == null) {
      _error(
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
    if (value is! YamlMap) {
      final font = _fontKey(value, path, keys);
      return font == null ? null : StratumFontRef(font: font);
    }
    _warnUnknown(value, path, const {'font', 'mono'});
    final font = _fontKey(value['font'], '$path.font', keys);
    final mono = value['mono'] == null
        ? null
        : _fontKey(value['mono'], '$path.mono', keys);
    return font == null ? null : StratumFontRef(font: font, mono: mono);
  }

  String? _fontKey(Object? value, String path, Set<String> keys) {
    final key = _string(value, path);
    if (key == null) return null;
    if (keys.isEmpty || keys.contains(key)) return key;
    _error(path, 'unknown font key "$key"');
    return null;
  }

  Map<WindowSize, StratumDimension>? _scale(Object? value, String path) {
    final node = _map(value, path, required: false);
    if (node == null) return null;
    final scale = <WindowSize, StratumDimension>{};
    for (final MapEntry(:key, :value) in node.entries) {
      final sizePath = '$path.$key';
      final windowSize = WindowSize.values.asNameMap()['$key'];
      if (windowSize == null) {
        _warn(sizePath);
        continue;
      }
      final dimension = _dimension(value, sizePath, required: true);
      if (dimension != null) scale[windowSize] = dimension;
    }
    return scale;
  }

  Map<FontType, StratumTypeStyle> _types(YamlMap? node, String path) {
    if (node == null) return const {};
    final raw = <FontType, _RawType>{};
    for (final MapEntry(:key, :value) in node.entries) {
      final typePath = '$path.$key';
      final type = FontType.values.asNameMap()['$key'];
      if (type == null) {
        _warn(typePath);
        continue;
      }
      final typeNode = _map(value, typePath);
      if (typeNode != null) raw[type] = _rawType(type, typeNode, typePath);
    }
    final types = <FontType, StratumTypeStyle>{};
    for (final type in FontType.values) {
      final typePath = '$path.${type.name}';
      if (!raw.containsKey(type)) {
        _error(typePath, 'required');
        continue;
      }
      final chain = _chain(type, raw, typePath);
      if (chain == null) continue;
      final style = _merge(chain.map((link) => raw[link]!).toList(), typePath);
      if (style != null) types[type] = style;
    }
    return types;
  }

  _RawType _rawType(FontType type, YamlMap node, String path) {
    _warnUnknown(node, path, const {
      'weight',
      'sizes',
      'scaleByWindowSize',
      'extends',
      'tabular',
    });
    final extendsType = _extendsType(node['extends'], '$path.extends');
    if (extendsType != null) _extends[type] = extendsType;
    if (extendsType == null && node['extends'] != null) {
      _brokenExtends.add(type);
    }
    return _RawType(
      node: node,
      weight: _weight(node['weight'], '$path.weight'),
      tabular: _bool(node['tabular'], '$path.tabular'),
      extendsType: extendsType,
      scale: _scale(node['scaleByWindowSize'], '$path.scaleByWindowSize'),
      sizes: _sizes(node['sizes'], '$path.sizes'),
    );
  }

  /// [type] and its `extends` ancestors, nearest first; null when the chain
  /// has a cycle or reaches a type that is undefined or extends an unknown
  /// type.
  List<FontType>? _chain(
    FontType type,
    Map<FontType, _RawType> raw,
    String path,
  ) {
    if (_brokenExtends.contains(type)) return null;
    final chain = [type];
    for (var parent = raw[type]!.extendsType; parent != null;) {
      if (chain.contains(parent)) {
        final names = [...chain, parent].map((link) => link.name);
        _error('$path.extends', 'cycle ${names.join(' -> ')}');
        _cycles.add(type);
        return null;
      }
      final parentRaw = raw[parent];
      if (parentRaw == null || _brokenExtends.contains(parent)) return null;
      chain.add(parent);
      parent = parentRaw.extendsType;
    }
    return chain;
  }

  /// Merges a chain, nearest first, so a child keeps its own values.
  StratumTypeStyle? _merge(List<_RawType> chain, String path) {
    FontWeight? weight;
    bool? tabular;
    Map<WindowSize, StratumDimension>? scale;
    final sizes = <FontSize, StratumSizeMetrics>{};
    for (final link in chain.reversed) {
      weight = link.weight ?? weight;
      tabular = link.tabular ?? tabular;
      scale = link.scale ?? scale;
      sizes.addAll(link.sizes);
    }
    if (weight == null && chain.every((link) => link.node['weight'] == null)) {
      _error('$path.weight', 'required');
    }
    if (sizes.isEmpty) _error('$path.sizes', 'expected at least one size');
    if (weight == null || sizes.isEmpty) return null;
    return StratumTypeStyle(
      weight: weight,
      tabular: tabular ?? false,
      extendsType: chain.first.extendsType,
      scaleByWindowSize: scale,
      sizes: {for (final size in FontSize.values) size: ?sizes[size]},
    );
  }

  Map<FontSize, StratumSizeMetrics> _sizes(Object? value, String path) {
    final node = _map(value, path, required: false);
    if (node == null) return const {};
    final sizes = <FontSize, StratumSizeMetrics>{};
    for (final MapEntry(:key, :value) in node.entries) {
      final sizePath = '$path.$key';
      final size = FontSize.values.asNameMap()['$key'];
      if (size == null) {
        _warn(sizePath);
        continue;
      }
      final metrics = _map(value, sizePath);
      if (metrics == null) continue;
      _warnUnknown(metrics, sizePath, const {'spaceHeight', 'letterSpacing'});
      final spaceHeight = _dimension(
        metrics['spaceHeight'],
        '$sizePath.spaceHeight',
        required: true,
      );
      final letterSpacing = _dimension(
        metrics['letterSpacing'],
        '$sizePath.letterSpacing',
      );
      if (spaceHeight == null) continue;
      sizes[size] = StratumSizeMetrics(
        spaceHeight: spaceHeight,
        letterSpacing: letterSpacing ?? const StratumDimension.fixed(0),
      );
    }
    return sizes;
  }

  FontType? _extendsType(Object? value, String path) {
    final name = _string(value, path, required: false);
    if (name == null) return null;
    final type = FontType.values.asNameMap()[name];
    if (type == null) _error(path, 'unknown type "$name"');
    return type;
  }

  FontWeight? _weight(Object? value, String path) {
    if (value == null) return null;
    if (value is int && value >= 100 && value <= 900 && value % 100 == 0) {
      return FontWeight.values[value ~/ 100 - 1];
    }
    _error(path, 'expected 100 to 900 in steps of 100, got ${_show(value)}');
    return null;
  }

  /// Reports each type that the `default` family set names neither
  /// directly nor through the type's `extends` chain.
  ///
  /// Reads the names from yaml, so a bad font reference, which has its own
  /// error, still counts as naming the type.
  void _checkDefaultFamily(YamlMap families, String path) {
    final defaults = families['default'];
    if (defaults == null) {
      _error(path, 'required');
      return;
    }
    if (defaults is! YamlMap) return;
    final named = defaults.keys.map((key) => '$key').toSet();
    for (final type in FontType.values) {
      final lineage = _lineage(type).toList();
      if (lineage.any(_brokenExtends.contains)) continue;
      if (lineage.any(_cycles.contains)) continue;
      if (lineage.any((link) => named.contains(link.name))) continue;
      _error('$path.${type.name}', 'no font for type "${type.name}"');
    }
  }

  /// [type], then each type it extends, until the chain ends or repeats.
  Iterable<FontType> _lineage(FontType type) sync* {
    final seen = <FontType>{};
    for (FontType? link = type; link != null && seen.add(link);) {
      yield link;
      link = _extends[link];
    }
  }

  YamlMap? _map(Object? value, String path, {bool required = true}) {
    if (value is YamlMap) return value;
    if (value == null) {
      if (required) _error(path, 'required');
      return null;
    }
    _error(path, 'expected a map, got ${_show(value)}');
    return null;
  }

  String? _string(Object? value, String path, {bool required = true}) {
    if (value is String) return value;
    if (value == null) {
      if (required) _error(path, 'required');
      return null;
    }
    _error(path, 'expected a string, got ${_show(value)}');
    return null;
  }

  bool? _bool(Object? value, String path) {
    if (value == null || value is bool) return value as bool?;
    _error(path, 'expected true or false, got ${_show(value)}');
    return null;
  }

  StratumDimension? _dimension(
    Object? value,
    String path, {
    bool required = false,
  }) {
    if (value == null) {
      if (required) _error(path, 'required');
      return null;
    }
    try {
      return StratumDimension.parse(value);
    } on FormatException catch (error) {
      _error(path, error.message);
      return null;
    }
  }

  void _warnUnknown(YamlMap node, String path, Set<String> known) {
    for (final key in node.keys) {
      if (!known.contains('$key')) _warn('$path.$key');
    }
  }

  void _warn(String path) {
    if (kDebugMode) debugPrint('Stratum theme: skipped unknown key $path');
  }

  void _error(String path, String message) =>
      _errors.add(StratumThemeFormatError(path, message));

  static String _show(Object? value) => value is String ? '"$value"' : '$value';
}
