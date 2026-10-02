import 'dart:ui' show Color;

import 'package:stratum_ui/src/themes/config/by_window_size.dart';
import 'package:stratum_ui/src/themes/config/format_error.dart';
import 'package:stratum_ui/src/themes/config/pipeline/check_keys.dart';
import 'package:stratum_ui/src/themes/config/pipeline/resolve_aliases.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';
import 'package:stratum_ui/src/themes/config/theme_asset.dart';
import 'package:stratum_ui/src/themes/config/theme_config.dart';
import 'package:stratum_ui/src/themes/config/theme_source.dart';
import 'package:stratum_ui/src/themes/constant/window_size.dart';
import 'package:stratum_ui/src/themes/typography/dimension.dart';
import 'package:stratum_ui/src/themes/typography/typography.dart';

/// Stage 5 (spec section 7): reads the resolved tree into a
/// [StratumThemeConfig]. Every problem goes to [errors]; the result holds
/// the values that read, so the caller throws when [errors] is not empty.
StratumThemeConfig readThemeValues(
  ResolvedTheme theme,
  ThemeSchema schema,
  List<StratumThemeSource> sources,
  ThemeErrors errors,
) => _Read(theme, schema, sources, errors).run();

final class _Read {
  new(this._theme, this._schema, this._sources, ThemeErrors errors)
    : _reader = ThemeReader(errors, _theme.origins),
      _quiet = ThemeReader(
        ThemeErrors([for (final source in _sources) source.id]),
        _theme.origins,
      );

  final ResolvedTheme _theme;
  final ThemeSchema _schema;
  final List<StratumThemeSource> _sources;

  /// Reports to the parse's errors.
  final ThemeReader _reader;

  /// Reports nowhere: for a value whose error belongs to another path
  /// (spec section 7.4).
  final ThemeReader _quiet;

  StratumThemeConfig run() {
    final tree = _theme.tree;
    return StratumThemeConfig(
      name: _reader.string(tree['name'], 'name') ?? '',
      assets: _assets(tree['assets']),
      space: _tokens(tree['space'], 'space'),
      radius: _tokens(tree['radius'], 'radius'),
      layouts: _tokens(tree['layouts'], 'layouts'),
      palette: _palette(tree['palette']),
      color: StratumColorSets(
        light: _colorSet('light'),
        dark: _colorSet('dark'),
        highContrastLight: _colorSet('highContrastLight'),
        highContrastDark: _colorSet('highContrastDark'),
      ),
      typography: _typography(tree['typography']),
      extensions: _extensions(tree['extensions']),
    );
  }

  /// The reader for the value [value] at [path]: [_quiet] when the value's
  /// error belongs elsewhere. That holds for an inherited high-contrast
  /// leaf, and for an alias holder when any path its alias passed through
  /// rejects the value: the error then appears once, at that path.
  ThemeReader _readerFor(String path, Object? value) {
    if (_theme.inherited.contains(path)) return _quiet;
    final chain = _theme.chains[path];
    if (chain == null) return _reader;
    return chain.any((target) => !_fits(target, value)) ? _quiet : _reader;
  }

  /// Whether [value] passes the kind check of the token at [target].
  static bool _fits(String target, Object? value) {
    final path = target.split('.');
    return switch (path.first) {
      'transparent' => true,
      'palette' || 'color' => ThemeReader.parseColor(value) != null,
      _ => _isTokenDimension(value),
    };
  }

  /// Whether [value] reads as a `space`, `radius`, or `layouts` token: one
  /// dimension, or a non-empty map of window sizes to dimensions.
  static bool _isTokenDimension(Object? value) {
    if (value is! Map<String, Object?>) {
      return ThemeReader.parseDimension(value) != null;
    }
    final sizes = WindowSize.values.asNameMap();
    return value.isNotEmpty &&
        value.entries.every(
          (entry) =>
              sizes.containsKey(entry.key) &&
              ThemeReader.parseDimension(entry.value) != null,
        );
  }

  String _folderOf(String path) {
    final folder = _sources[_theme.origins[path]?.source ?? 0].folder;
    return folder.endsWith('/')
        ? folder.substring(0, folder.length - 1)
        : folder;
  }

  Map<String, StratumThemeAsset> _assets(Object? value) {
    final slots = _reader.map(value, 'assets', required: false);
    return Map.unmodifiable({
      for (final MapEntry(key: slot, value: relative)
          in (slots ?? const <String, Object?>{}).entries)
        slot: ?_asset('assets.$slot', relative),
    });
  }

  StratumThemeAsset? _asset(String path, Object? value) {
    if (value == null || value == '') return null;
    final relative = _reader.string(value, path);
    if (relative == null) return null;
    if (relative.startsWith('/') || relative.split('/').contains('..')) {
      _reader.report(
        StratumThemeErrorCode.invalidAsset,
        path,
        'expected a path inside the theme folder, got "$relative"',
      );
      return null;
    }
    final file = relative.split('/').last;
    final dot = file.lastIndexOf('.');
    final kind = dot < 0
        ? null
        : StratumAssetKind.fromExtension(file.substring(dot + 1));
    if (kind == null) {
      _reader.report(
        StratumThemeErrorCode.invalidAsset,
        path,
        'expected one of png, jpg, jpeg, webp, svg, gif, json, lottie, '
        'got "$relative"',
      );
      return null;
    }
    return StratumThemeAsset(kind: kind, path: '${_folderOf(path)}/$relative');
  }

  Map<String, StratumByWindowSize<StratumDimension>> _tokens(
    Object? value,
    String group,
  ) {
    final tokens = value is Map<String, Object?>
        ? value
        : const <String, Object?>{};
    return Map.unmodifiable({
      for (final MapEntry(key: name, value: token) in tokens.entries)
        if (!_theme.failed.contains('$group.$name'))
          name: ?_byWindowSize('$group.$name', token),
    });
  }

  StratumByWindowSize<StratumDimension>? _byWindowSize(
    String path,
    Object? value,
  ) {
    final reader = _readerFor(path, value);
    if (value is! Map<String, Object?>) {
      final dimension = reader.dimension(value, path, required: true);
      return dimension == null ? null : StratumByWindowSize.all(dimension);
    }
    if (value.isEmpty) {
      reader.report(StratumThemeErrorCode.required, path, 'required');
      return null;
    }
    final sizes = WindowSize.values.asNameMap();
    final entries = <WindowSize, StratumDimension>{};
    for (final MapEntry(key: name, value: entry) in value.entries) {
      final entryPath = '$path.$name';
      final size = sizes[name];
      if (size == null) {
        reader.report(
          StratumThemeErrorCode.unknownKey,
          entryPath,
          'unknown window size "$name"',
          atKey: true,
        );
        continue;
      }
      if (_theme.failed.contains(entryPath)) continue;
      // A map at an entry is always wrong (spec section 7.3), whatever
      // state the chain's target copy is in: `_fits` cannot judge it.
      final entryReader = identical(reader, _quiet)
          ? _quiet
          : entry is Map<String, Object?>
          ? _reader
          : _readerFor(entryPath, entry);
      final dimension = entryReader.dimension(entry, entryPath, required: true);
      if (dimension != null) entries[size] = dimension;
    }
    return entries.isEmpty ? null : StratumByWindowSize(entries);
  }

  Map<String, Color> _palette(Object? value) {
    final ramps = value is Map<String, Object?>
        ? value
        : const <String, Object?>{};
    final palette = <String, Color>{};
    for (final MapEntry(key: ramp, value: shades) in ramps.entries) {
      if (ramp != 'app') {
        _shades(['palette', ramp], shades, palette);
        continue;
      }
      final appRamps = shades is Map<String, Object?>
          ? shades
          : const <String, Object?>{};
      for (final MapEntry(key: name, value: appShades) in appRamps.entries) {
        _shades(['palette', 'app', name], appShades, palette);
      }
    }
    return Map.unmodifiable(palette);
  }

  void _shades(List<String> ramp, Object? value, Map<String, Color> out) {
    final shades = _reader.map(value, ramp.join('.'));
    if (shades == null) return;
    for (final MapEntry(key: shade, value: color) in shades.entries) {
      _color([...ramp, shade], color, out, skip: 1);
    }
  }

  /// The colors of the set [name], walked along the package default's
  /// shape of that set, then its `app` names.
  Map<String, Color> _colorSet(String name) {
    final colors = <String, Color>{};
    final color = _theme.tree['color'];
    final values = color is Map<String, Object?> ? color[name] : null;
    _walkSet(_schema.keysAt(['color', name]) ?? const {}, values, [
      'color',
      name,
    ], colors);
    return Map.unmodifiable(colors);
  }

  void _walkSet(
    Map<String, Object?> shape,
    Object? values,
    List<String> path,
    Map<String, Color> out,
  ) {
    final node = values is Map<String, Object?>
        ? values
        : const <String, Object?>{};
    for (final MapEntry(:key, value: shapeValue) in shape.entries) {
      final childPath = [...path, key];
      if (_schema.isOpen(childPath)) {
        final app = node[key];
        if (app is! Map<String, Object?>) continue;
        for (final MapEntry(key: name, :value) in app.entries) {
          _color([...childPath, name], value, out, skip: 2);
        }
      } else if (_schema.isLeaf(childPath)) {
        _color(childPath, node[key], out, skip: 2);
      } else if (shapeValue is Map<String, Object?>) {
        _walkSet(shapeValue, node[key], childPath, out);
      }
    }
  }

  /// Reads the color at [path] into [out], keyed by [path] without its
  /// first [skip] segments.
  void _color(
    List<String> path,
    Object? value,
    Map<String, Color> out, {
    required int skip,
  }) {
    final dotted = path.join('.');
    if (_theme.failed.contains(dotted)) return;
    final color = _readerFor(
      dotted,
      value,
    ).color(value, dotted, alias: _theme.aliases[dotted]);
    if (color != null) out[path.skip(skip).join('.')] = color;
  }

  StratumTypography _typography(Object? value) {
    final node = _reader.map(value, 'typography');
    return node == null
        ? const StratumTypography(fonts: {}, families: {}, types: {})
        : readTypography(node, _reader);
  }

  Map<String, Object?> _extensions(Object? value) =>
      value is Map<String, Object?>
      ? _frozen(value)! as Map<String, Object?>
      : const {};

  static Object? _frozen(Object? value) => switch (value) {
    final Map<String, Object?> map => Map<String, Object?>.unmodifiable({
      for (final MapEntry(:key, value: child) in map.entries)
        key: _frozen(child),
    }),
    final List<Object?> list => List<Object?>.unmodifiable(list.map(_frozen)),
    _ => value,
  };
}
