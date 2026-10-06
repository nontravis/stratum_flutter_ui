import 'package:stratum_ui/src/themes/config/format_error.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';
import 'package:yaml/yaml.dart';

/// One file's plain tree after stage 2, and the origin of each of its
/// paths. `$schema` is not part of it: stage 1 read it, and it never merges.
final class ThemeTree {
  new(this.tree, this.origins);

  /// The file's values, keys in string form, refused nodes removed.
  final Map<String, Object?> tree;

  /// The origin of every path [tree] holds; the root is `''`.
  final Map<String, ThemeOrigin> origins;
}

/// The result of stage 2: the schema the package default defines, and each
/// file's tree, the package default first.
typedef CheckedThemes = ({ThemeSchema schema, List<ThemeTree> files});

/// The shape of the package default (spec section 5.3): which keys a layer
/// may write, which paths hold one token, and which maps are open.
final class ThemeSchema {
  new(this.base);

  /// The token groups an alias may name (spec section 7.3).
  static const tokenGroups = {'space', 'radius', 'layouts', 'palette', 'color'};

  /// Each color set, and the set whose keys it takes.
  static const colorSets = {
    'light': 'light',
    'dark': 'dark',
    'highContrastLight': 'light',
    'highContrastDark': 'dark',
  };

  static const _absent = Object();

  /// The plain tree of the package default.
  final Map<String, Object?> base;

  /// Whether a layer may write any key below [path]: `extensions`,
  /// `typography`, `palette.app`, and the `app` map of each color set.
  bool isOpen(List<String> path) => switch (path) {
    ['extensions'] || ['typography'] || ['palette', 'app'] => true,
    ['color', final colorSet, 'app'] => colorSets.containsKey(colorSet),
    _ => false,
  };

  /// Whether [path] holds one value, which a layer replaces whole: a token
  /// of `space`, `radius`, or `layouts` (a window-size map included), a
  /// palette shade, an app color, or any other path where the package
  /// default holds no map.
  bool isLeaf(List<String> path) => switch (path) {
    ['space' || 'radius' || 'layouts', _] => true,
    ['palette', 'app', _, _] => true,
    ['palette', final ramp, _] => ramp != 'app',
    ['color', final colorSet, 'app', _] => colorSets.containsKey(colorSet),
    _ => _baseHoldsLeaf(path),
  };

  /// The map of the package default that lists the keys a layer may write
  /// at [path]; a high-contrast set reads its base set. Null when the
  /// package default holds no map there.
  Map<String, Object?>? keysAt(List<String> path) {
    final node = _baseAt(path);
    return node is Map<String, Object?> ? node : null;
  }

  bool _baseHoldsLeaf(List<String> path) {
    final node = _baseAt(path);
    return !identical(node, _absent) && node is! Map<String, Object?>;
  }

  Object? _baseAt(List<String> path) {
    Object? node = base;
    for (final (index, key) in path.indexed) {
      final name = index == 1 && path.first == 'color'
          ? colorSets[key] ?? key
          : key;
      if (node is! Map<String, Object?> || !node.containsKey(name)) {
        return _absent;
      }
      node = node[name];
    }
    return node;
  }
}

/// Stage 2 (spec section 7): turns each root into a plain tree and checks
/// the keys of each layer against the package default, `roots.first`.
///
/// A refused node is reported to [errors] and left out of its tree, so the
/// lower layers' value stays in its place.
CheckedThemes checkThemeKeys(List<YamlMap> roots, ThemeErrors errors) {
  final baseOrigins = <String, ThemeOrigin>{};
  final plain =
      plainOf(roots.first, path: '', source: 0, origins: baseOrigins)!
          as Map<String, Object?>;
  final baseTree = {
    for (final MapEntry(:key, :value) in plain.entries)
      if (key != r'$schema') key: value,
  };
  baseOrigins.remove(r'$schema');
  final schema = ThemeSchema(baseTree);
  return (
    schema: schema,
    files: [
      ThemeTree(baseTree, baseOrigins),
      for (var index = 1; index < roots.length; index++)
        _LayerCheck(schema, errors, index).run(roots[index]),
    ],
  );
}

final class _LayerCheck {
  new(this._schema, this._errors, this._source);

  static const _refused = Object();

  final ThemeSchema _schema;
  final ThemeErrors _errors;
  final int _source;
  final _origins = <String, ThemeOrigin>{};

  ThemeTree run(YamlMap root) {
    _origins[''] = (source: _source, key: null, value: positionOf(root));
    return ThemeTree(_closedMap(root, const []), _origins);
  }

  /// The keys of [node] that the package default holds at [path]; reports
  /// every other key.
  Map<String, Object?> _closedMap(YamlMap node, List<String> path) {
    final allowed = _schema.keysAt(path) ?? const <String, Object?>{};
    final result = <String, Object?>{};
    for (final MapEntry(key: Object? keyNode, value: child)
        in node.nodes.entries) {
      final key = keyNode! as YamlNode;
      final name = '${key.value}';
      if (path.isEmpty && name == r'$schema') continue;
      final childPath = [...path, name];
      if (!allowed.containsKey(name)) {
        _errors.add(
          StratumThemeErrorCode.unknownKey,
          childPath.join('.'),
          'unknown key ${ThemeReader.show(name)}',
          source: _source,
          at: positionOf(key),
        );
        continue;
      }
      final value = _check(child, childPath, key);
      if (!identical(value, _refused)) result[name] = value;
    }
    return result;
  }

  /// The plain value of [node] at [path], or [_refused] when [path] needs a
  /// map and [node] is none.
  Object? _check(YamlNode node, List<String> path, YamlNode key) {
    final dotted = path.join('.');
    final open = _schema.isOpen(path);
    if (!open && _schema.isLeaf(path)) {
      return plainOf(
        node,
        path: dotted,
        source: _source,
        origins: _origins,
        key: positionOf(key),
      );
    }
    if (node is! YamlMap) {
      final Object? value = node.value;
      _errors.add(
        value == null
            ? StratumThemeErrorCode.required
            : StratumThemeErrorCode.expectedMap,
        dotted,
        value == null
            ? 'required'
            : 'expected a map, got ${ThemeReader.show(value)}',
        source: _source,
        at: positionOf(node),
      );
      return _refused;
    }
    if (open) {
      return plainOf(
        node,
        path: dotted,
        source: _source,
        origins: _origins,
        key: positionOf(key),
      );
    }
    _origins[dotted] = (
      source: _source,
      key: positionOf(key),
      value: positionOf(node),
    );
    return _closedMap(node, path);
  }
}
