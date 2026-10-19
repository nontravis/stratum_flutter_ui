import 'package:stratum_ui/src/themes/config/escape_text.dart';
import 'package:stratum_ui/src/themes/config/format_error.dart';
import 'package:stratum_ui/src/themes/config/pipeline/check_keys.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';

/// The tree after stage 3: every layer merged over the package default, and
/// the four color sets and the four `system` and `focus` sets full.
final class MergedTheme {
  new({required this.tree, required this.origins, required this.inherited});

  /// The merged values; `$schema` is not part of it.
  final Map<String, Object?> tree;

  /// For each path, the origin of the last layer that wrote it; an
  /// inherited high-contrast leaf keeps the origin of its base-set leaf.
  final Map<String, ThemeOrigin> origins;

  /// The paths of the high-contrast leaves copied from their base set,
  /// which report no error of their own (spec section 7.4).
  final Set<String> inherited;
}

/// Stage 3 (spec section 7.1): merges the files of [checked] in order,
/// checks the app colors, and derives the high-contrast sets of `color`
/// (section 7.2) and of the four `system` and `focus` sets (config s03
/// invariants 16, 19). Every problem goes to [errors].
MergedTheme mergeThemes(CheckedThemes checked, ThemeErrors errors) =>
    _Merge(checked.schema, errors).run(checked.files);

final class _Merge {
  new(this._schema, this._errors);

  static const List<({String overlay, String base})> _pairs = [
    (overlay: 'highContrastLight', base: 'light'),
    (overlay: 'highContrastDark', base: 'dark'),
  ];

  final ThemeSchema _schema;
  final ThemeErrors _errors;
  final _origins = <String, ThemeOrigin>{};
  final _inherited = <String>{};

  MergedTheme run(List<ThemeTree> files) {
    final tree = <String, Object?>{};
    for (final file in files) {
      _mergeInto(tree, file.tree, const [], file.origins);
    }
    if (tree['color'] case final Map<String, Object?> color) {
      _pairAppColors(color);
      for (final pair in _pairs) {
        _checkOverlayApp(color, pair.overlay, pair.base);
      }
      for (final pair in _pairs) {
        _derive(color, 'color', pair.overlay, pair.base);
      }
    }
    if (tree['system'] case final Map<String, Object?> system) {
      for (final pair in _pairs) {
        _derive(system, 'system', pair.overlay, pair.base);
      }
    }
    if (tree['focus'] case final Map<String, Object?> focus) {
      for (final pair in _pairs) {
        _derive(focus, 'focus', pair.overlay, pair.base);
      }
    }
    return MergedTheme(tree: tree, origins: _origins, inherited: _inherited);
  }

  /// Merges [layer] into [target], which sits at [path]: a map merges with
  /// the map at the same path key by key, unless the package default holds
  /// a leaf there; any other value replaces the value at the same path.
  void _mergeInto(
    Map<String, Object?> target,
    Map<String, Object?> layer,
    List<String> path,
    Map<String, ThemeOrigin> from,
  ) {
    for (final MapEntry(:key, :value) in layer.entries) {
      final childPath = [...path, key];
      final dotted = childPath.join('.');
      final current = target[key];
      if (current is Map<String, Object?> &&
          value is Map<String, Object?> &&
          !_schema.isLeaf(childPath)) {
        if (from[dotted] case final origin?) _origins[dotted] = origin;
        _inherited.remove(dotted);
        _mergeInto(current, value, childPath, from);
        continue;
      }
      target[key] = copyTree(value);
      _replaceOrigins(dotted, from);
    }
  }

  /// Gives [path] and every path below it the origins [from] holds.
  void _replaceOrigins(String path, Map<String, ThemeOrigin> from) {
    bool under(String other) => other == path || other.startsWith('$path.');
    _dropOrigins(path);
    _inherited.removeWhere(under);
    for (final MapEntry(:key, :value) in from.entries) {
      if (under(key)) _origins[key] = value;
    }
  }

  void _dropOrigins(String path) => _origins.removeWhere(
    (other, _) => other == path || other.startsWith('$path.'),
  );

  /// Reports each name in only one of `color.light.app` and
  /// `color.dark.app` as `required` at the set that lacks it, at the
  /// position of the entry that exists (spec G3, G11).
  void _pairAppColors(Map<String, Object?> color) {
    final light = _appNames(color, 'light');
    final dark = _appNames(color, 'dark');
    for (final name in light.difference(dark)) {
      _unpaired(name, have: 'light', lack: 'dark');
    }
    for (final name in dark.difference(light)) {
      _unpaired(name, have: 'dark', lack: 'light');
    }
  }

  void _unpaired(String name, {required String have, required String lack}) {
    final origin = _origins['color.$have.app.$name'];
    _errors.add(
      StratumThemeErrorCode.required,
      'color.$lack.app.$name',
      'required; color.$have.app.${escapeZipText(name)} has no $lack value',
      source: origin?.source ?? 0,
      at: origin?.key,
    );
  }

  /// Reports and removes each name of the [overlay] set's `app` map that
  /// the merged [base] set's `app` map lacks.
  void _checkOverlayApp(
    Map<String, Object?> color,
    String overlay,
    String base,
  ) {
    final overlaySet = color[overlay];
    if (overlaySet is! Map<String, Object?>) return;
    final app = overlaySet['app'];
    if (app is! Map<String, Object?>) return;
    final known = _appNames(color, base);
    for (final name in app.keys.toList()) {
      if (known.contains(name)) continue;
      final path = 'color.$overlay.app.$name';
      final origin = _origins[path];
      _errors.add(
        StratumThemeErrorCode.unknownKey,
        path,
        'no color ${ThemeReader.show(name)} in color.$base.app',
        source: origin?.source ?? 0,
        at: origin?.key,
      );
      app.remove(name);
      _dropOrigins(path);
    }
  }

  /// Makes the [overlay] set of [sets], the group [group], full (spec
  /// section 7.2; config s03 invariant 16): a copy of the merged [base] set
  /// whose `{color.<base>.` aliases point into the [overlay] color set,
  /// with the merged overlay applied on top.
  void _derive(
    Map<String, Object?> sets,
    String group,
    String overlay,
    String base,
  ) {
    final baseSet = sets[base];
    if (baseSet is! Map<String, Object?>) return;
    final overlayPath = '$group.$overlay';
    final overlayOrigins = {
      for (final MapEntry(:key, :value) in _origins.entries)
        if (key == overlayPath || key.startsWith('$overlayPath.')) key: value,
    };
    _dropOrigins(overlayPath);
    final basePrefix = '$group.$base.';
    for (final MapEntry(:key, :value) in {..._origins}.entries) {
      if (!key.startsWith(basePrefix)) continue;
      final copied = '$overlayPath.${key.substring(basePrefix.length)}';
      _origins[copied] = value;
      _inherited.add(copied);
    }
    if (overlayOrigins[overlayPath] case final origin?) {
      _origins[overlayPath] = origin;
    }
    final copy = _retarget(baseSet, base, overlay)! as Map<String, Object?>;
    if (sets[overlay] case final Map<String, Object?> overlaySet) {
      _mergeInto(copy, overlaySet, [group, overlay], overlayOrigins);
    }
    sets[overlay] = copy;
  }

  static Object? _retarget(Object? value, String base, String overlay) =>
      switch (value) {
        final Map<String, Object?> map => <String, Object?>{
          for (final MapEntry(:key, value: child) in map.entries)
            key: _retarget(child, base, overlay),
        },
        final String alias
            when isAlias(alias) && alias.startsWith('{color.$base.') =>
          '{color.$overlay.${alias.substring('{color.$base.'.length)}',
        _ => copyTree(value),
      };

  static Set<String> _appNames(Map<String, Object?> color, String setName) {
    final colorSet = color[setName];
    final app = colorSet is Map<String, Object?> ? colorSet['app'] : null;
    return app is Map<String, Object?> ? app.keys.toSet() : <String>{};
  }
}
