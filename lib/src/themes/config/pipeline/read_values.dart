import 'package:stratum_ui/src/themes/config/animation_config.dart';
import 'package:stratum_ui/src/themes/config/focus_names.dart';
import 'package:stratum_ui/src/themes/config/format_error.dart';
import 'package:stratum_ui/src/themes/config/pipeline/check_keys.dart';
import 'package:stratum_ui/src/themes/config/pipeline/resolve_aliases.dart';
import 'package:stratum_ui/src/themes/config/plain_by_window_size.dart';
import 'package:stratum_ui/src/themes/config/plain_theme_config.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';
import 'package:stratum_ui/src/themes/config/shadow_layer.dart';
import 'package:stratum_ui/src/themes/config/system_names.dart';
import 'package:stratum_ui/src/themes/config/theme_asset.dart';
import 'package:stratum_ui/src/themes/config/theme_source.dart';
import 'package:stratum_ui/src/themes/config/transition_names.dart';
import 'package:stratum_ui/src/themes/typography/dimension.dart';
import 'package:stratum_ui/src/themes/typography/typography_parser.dart';

/// Stage 5 (spec section 7): reads the resolved tree into a
/// [PlainThemeConfig]. Every problem goes to [errors]; the result holds
/// the values that read, so the caller throws when [errors] is not empty.
PlainThemeConfig readThemeValues(
  ResolvedTheme theme,
  ThemeSchema schema,
  List<StratumThemeSource> sources,
  ThemeErrors errors, {
  required bool Function(String name) googleFontExists,
}) => _Read(theme, schema, sources, errors, googleFontExists).run();

final class _Read {
  new(
    this._theme,
    this._schema,
    this._sources,
    ThemeErrors errors,
    this._googleFontExists,
  ) : _reader = ThemeReader(errors, _theme.origins),
      _quiet = ThemeReader(
        ThemeErrors([for (final source in _sources) source.id]),
        _theme.origins,
      );

  final ResolvedTheme _theme;
  final ThemeSchema _schema;
  final List<StratumThemeSource> _sources;
  final bool Function(String name) _googleFontExists;

  /// Reports to the parse's errors.
  final ThemeReader _reader;

  /// Reports nowhere: for a value whose error belongs to another path
  /// (spec section 7.4).
  final ThemeReader _quiet;

  /// The paths a fully transparent focus color was reported at, so an
  /// overlay that inherits it reports once.
  final _reportedClear = <String>{};

  PlainThemeConfig run() {
    final tree = _theme.tree;
    return PlainThemeConfig(
      name: _reader.string(tree['name'], 'name') ?? '',
      assets: _assets(tree['assets']),
      space: _tokens(tree['space'], 'space'),
      radius: _tokens(tree['radius'], 'radius'),
      layouts: _tokens(tree['layouts'], 'layouts'),
      palette: _palette(tree['palette']),
      color: PlainColorSets(
        light: _colorSet('light'),
        dark: _colorSet('dark'),
        highContrastLight: _colorSet('highContrastLight'),
        highContrastDark: _colorSet('highContrastDark'),
      ),
      typography: _typography(tree['typography']),
      animation: _animation(tree['animation']),
      opacity: frozenMap(_opacity(tree['opacity'])),
      border: frozenMap(_effectNumbers(tree['border'], 'border')),
      shadow: frozenMap(_shadow(tree['shadow'])),
      blur: frozenMap(_effectNumbers(tree['blur'], 'blur')),
      system: _system(tree['system']),
      focus: _focus(tree['focus']),
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
      'layouts' => _isTokenDimension(value, percent: true),
      'border' || 'blur' => _isEffectNumber(value),
      _ => _isTokenDimension(value, percent: false),
    };
  }

  /// Whether [value] reads as a `space`, `radius`, or `layouts` token: one
  /// dimension within the length bound (config s03 INV-15), or a
  /// non-empty map of window sizes to such dimensions; a percent only when
  /// [percent] is set (spec section 8.3).
  static bool _isTokenDimension(Object? value, {required bool percent}) {
    bool fits(Object? entry) => switch (ThemeReader.parseLength(entry)) {
      null => false,
      PercentDimension() => percent,
      FixedDimension() => true,
    };
    if (value is! Map<String, Object?>) return fits(value);
    return value.isNotEmpty &&
        value.entries.every(
          (entry) => windowSizeNames.contains(entry.key) && fits(entry.value),
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
    return frozenMap({
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
        'expected a path inside the theme folder, got '
        '${ThemeReader.show(relative)}',
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
        'got ${ThemeReader.show(relative)}',
      );
      return null;
    }
    return StratumThemeAsset(kind: kind, path: '${_folderOf(path)}/$relative');
  }

  /// `PlainThemeConfig` holds this once, un-wrapped by `frozenMap`:
  /// `convertThemeConfig` rebuilds it into a `StratumByWindowSize` map for
  /// the freezed model, so this copy carries no identity contract of its
  /// own.
  Map<String, PlainByWindowSize> _tokens(Object? value, String group) {
    final tokens = value is Map<String, Object?>
        ? value
        : const <String, Object?>{};
    return Map.unmodifiable({
      for (final MapEntry(key: name, value: token) in tokens.entries)
        if (!_theme.failed.contains('$group.$name'))
          name: ?_byWindowSize(
            '$group.$name',
            token,
            percent: group == 'layouts',
          ),
    });
  }

  PlainByWindowSize? _byWindowSize(
    String path,
    Object? value, {
    required bool percent,
  }) {
    final reader = _readerFor(path, value);
    if (value is! Map<String, Object?>) {
      final dimension = _dimension(reader, value, path, percent: percent);
      return dimension == null ? null : PlainByWindowSize.all(dimension);
    }
    if (value.isEmpty) {
      reader.report(StratumThemeErrorCode.required, path, 'required');
      return null;
    }
    final entries = <String, StratumDimension>{};
    for (final MapEntry(key: name, value: entry) in value.entries) {
      final entryPath = '$path.$name';
      if (!windowSizeNames.contains(name)) {
        reader.report(
          StratumThemeErrorCode.unknownKey,
          entryPath,
          'unknown window size ${ThemeReader.show(name)}',
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
      final dimension = _dimension(
        entryReader,
        entry,
        entryPath,
        percent: percent,
      );
      if (dimension != null) entries[name] = dimension;
    }
    return entries.isEmpty
        ? null
        : PlainByWindowSize(Map.unmodifiable(entries));
  }

  /// [reader]'s required dimension of [value] at [path]. Without [percent]
  /// (`space` and `radius`), a percent is reported as `expected_dimension`
  /// and dropped (spec section 8.3); `ThemeReader.dimension` holds every
  /// value to the length bound (config s03 INV-15).
  StratumDimension? _dimension(
    ThemeReader reader,
    Object? value,
    String path, {
    required bool percent,
  }) => reader.dimension(value, path, percent: percent, required: true);

  /// Like [_tokens], held un-wrapped by `frozenMap` here: `convertThemeConfig`
  /// rebuilds this into `Color` values for the freezed model.
  Map<String, int> _palette(Object? value) {
    final ramps = value is Map<String, Object?>
        ? value
        : const <String, Object?>{};
    final palette = <String, int>{};
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

  void _shades(List<String> ramp, Object? value, Map<String, int> out) {
    final shades = _reader.map(value, ramp.join('.'));
    if (shades == null) return;
    for (final MapEntry(key: shade, value: color) in shades.entries) {
      _color([...ramp, shade], color, out, skip: 1);
    }
  }

  /// The colors of the set [name], walked along the package default's
  /// shape of that set, then its `app` names. `convertThemeConfig` rebuilds
  /// this into `Color` values for the freezed model, so, like [_tokens] and
  /// [_palette], this copy holds no identity contract of its own.
  Map<String, int> _colorSet(String name) {
    final colors = <String, int>{};
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
    Map<String, int> out,
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
    Map<String, int> out, {
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

  static final _percent = RegExp(r'^(\d+(?:\.\d+)?)%$');

  /// The `animation` group (spec sections 8.1 and 8.2). Its levels are the
  /// package default's, read from the schema; its values are never
  /// alias-resolved.
  StratumAnimationConfig _animation(Object? value) {
    final node = _reader.map(value, 'animation');
    final duration = node == null
        ? null
        : _reader.map(node['duration'], 'animation.duration');
    final curve = node == null
        ? null
        : _reader.map(node['curve'], 'animation.curve');
    final transition = node == null
        ? null
        : _reader.map(node['transition'], 'animation.transition');
    final levels = [
      for (final key
          in _schema.keysAt(const ['animation', 'duration'])?.keys ??
              const <String>[])
        if (key != 'default') key,
    ];
    return StratumAnimationConfig(
      durations: frozenMap(_durations(duration, levels)),
      defaultLevel: _defaultLevel(duration, levels),
      reverseRatio: node == null ? 0 : _reverseRatio(node['reverseDuration']),
      curves: frozenMap(_curves(curve)),
      transitions: frozenMap(_transitions(transition)),
    );
  }

  Map<String, Duration> _durations(
    Map<String, Object?>? node,
    List<String> levels,
  ) {
    final durations = <String, Duration>{};
    if (node == null) return durations;
    for (final level in levels) {
      final value = node[level];
      if (value is num && value.isFinite && value >= 0) {
        durations[level] = Duration(microseconds: (value * 1000).round());
        continue;
      }
      _reader.report(
        StratumThemeErrorCode.expectedDuration,
        'animation.duration.$level',
        'expected a number of milliseconds of 0 or more, got '
            '${ThemeReader.show(value)}',
      );
    }
    return durations;
  }

  /// `duration.default` when it names a level; a level whose own value
  /// failed reports nothing more here (schema v1's no-repeat rule).
  String _defaultLevel(Map<String, Object?>? node, List<String> levels) {
    final value = node?['default'];
    if (value is String && levels.contains(value)) return value;
    if (node != null) {
      _reader.report(
        StratumThemeErrorCode.expectedDuration,
        'animation.duration.default',
        'expected one of ${levels.join(', ')}, got ${ThemeReader.show(value)}',
      );
    }
    return levels.isEmpty ? '' : levels.first;
  }

  double _reverseRatio(Object? value) {
    final match = value is String ? _percent.firstMatch(value) : null;
    if (match != null) return double.parse(match[1]!) / 100;
    _reader.report(
      StratumThemeErrorCode.expectedDuration,
      'animation.reverseDuration',
      'expected "N%" of 0% or more, got ${ThemeReader.show(value)}',
    );
    return 0;
  }

  Map<String, StratumCurve> _curves(Map<String, Object?>? node) {
    final curves = <String, StratumCurve>{};
    for (final MapEntry(:key, :value)
        in (node ?? const <String, Object?>{}).entries) {
      final curve = value is String ? StratumCurve.tryParse(value) : null;
      if (curve != null) {
        curves[key] = curve;
        continue;
      }
      final shown = ThemeReader.show(value);
      _reader.report(
        StratumThemeErrorCode.expectedCurve,
        'animation.curve.$key',
        value is String && StratumCubicCurve.pattern.hasMatch(value)
            ? 'expected cubic x values a and c within 0 and 1, got $shown'
            : 'expected a Curves name or "cubic(a, b, c, d)", got $shown',
      );
    }
    return curves;
  }

  /// `animation.transition` (FO-01 US-01 FR-01 E11): each window size the
  /// merged tree holds, the package default's five, naming one of
  /// [transitionTypeNames].
  Map<String, String> _transitions(Map<String, Object?>? node) {
    final transitions = <String, String>{};
    for (final MapEntry(:key, :value)
        in (node ?? const <String, Object?>{}).entries) {
      if (value is String && transitionTypeNames.contains(value)) {
        transitions[key] = value;
        continue;
      }
      _reader.report(
        StratumThemeErrorCode.expectedTransition,
        'animation.transition.$key',
        'expected one of the 19 page transition types, such as platform or '
            'fade, got ${ThemeReader.show(value)}',
      );
    }
    return transitions;
  }

  /// The `opacity` group (FO-01 US-01 FR-01 E12; config s03 INV-11):
  /// each key the merged tree holds, the package default's
  /// `disabled` and `scrim`, as a number from 0 to 1, the range Flutter's
  /// `Opacity` asserts.
  Map<String, double> _opacity(Object? value) {
    final opacity = <String, double>{};
    final node = _reader.map(value, 'opacity');
    for (final MapEntry(:key, value: entry)
        in (node ?? const <String, Object?>{}).entries) {
      final path = 'opacity.$key';
      if (entry is num && entry >= 0 && entry <= 1) {
        opacity[key] = entry.toDouble();
        continue;
      }
      if (entry == null) {
        _reader.report(StratumThemeErrorCode.required, path, 'required');
        continue;
      }
      _reader.report(
        StratumThemeErrorCode.expectedOpacity,
        path,
        'expected a number from 0 to 1, got ${ThemeReader.show(entry)}',
      );
    }
    return opacity;
  }

  static const _layerKeys = {'x', 'y', 'blur', 'spread', 'color'};

  /// The most layers one `shadow` level holds (FO-01 US-01 FR-01 E14;
  /// config s03 INV-13). Each layer is one more blurred draw for
  /// every box that paints the level, so the cap bounds the paint cost a
  /// theme file the app did not write can ask for.
  static const _maxShadowLayers = 8;

  /// The `border` or `blur` group [group] (FO-01 US-01 FR-01 E05, E13;
  /// config s03 INV-12, INV-14, and INV-15): each key the merged tree holds,
  /// a number from 0 to the length bound; an alias resolved in stage 4
  /// reads its target's value, and one that failed there reports nothing
  /// here.
  Map<String, double> _effectNumbers(Object? value, String group) {
    final numbers = <String, double>{};
    final node = _reader.map(value, group);
    for (final MapEntry(:key, value: entry)
        in (node ?? const <String, Object?>{}).entries) {
      final path = '$group.$key';
      if (_theme.failed.contains(path)) continue;
      final number = _atLeastZero(_readerFor(path, entry), path, entry);
      if (number != null) numbers[key] = number;
    }
    return numbers;
  }

  /// The `shadow` group (FO-01 US-01 FR-01 E05, E13 to E15; config s03
  /// INV-13): each level the merged tree holds, its layers in file
  /// order; `[]` is no shadow. A level of more than [_maxShadowLayers]
  /// reports `expected_shadow` once and stage 5 reads none of its layers;
  /// stage 4 still checks each layer's own color alias, so a bad alias in
  /// an over-cap level reports there regardless.
  Map<String, List<StratumShadowLayer>> _shadow(Object? value) {
    final shadow = <String, List<StratumShadowLayer>>{};
    final node = _reader.map(value, 'shadow');
    for (final MapEntry(key: level, value: entry)
        in (node ?? const <String, Object?>{}).entries) {
      final path = 'shadow.$level';
      if (entry == null) {
        _reader.report(StratumThemeErrorCode.required, path, 'required');
        continue;
      }
      if (entry is! List<Object?>) {
        _reader.report(
          StratumThemeErrorCode.expectedShadow,
          path,
          'expected a list of shadow layers, got ${ThemeReader.show(entry)}',
        );
        continue;
      }
      if (entry.length > _maxShadowLayers) {
        _reader.report(
          StratumThemeErrorCode.expectedShadow,
          path,
          'expected at most $_maxShadowLayers shadow layers, got '
          '${entry.length}',
        );
        continue;
      }
      shadow[level] = List<StratumShadowLayer>.unmodifiable([
        for (final (index, item) in entry.indexed)
          ?_shadowLayer('$path.$index', item),
      ]);
    }
    return shadow;
  }

  /// The layer at [path]: a map of exactly [_layerKeys], else
  /// `expected_shadow` and no check of its values; null when any part
  /// fails.
  StratumShadowLayer? _shadowLayer(String path, Object? value) {
    if (value is! Map<String, Object?>) {
      _reader.report(
        StratumThemeErrorCode.expectedShadow,
        path,
        'expected a map of x, y, blur, spread, and color, got '
        '${ThemeReader.show(value)}',
      );
      return null;
    }
    if (value.length != _layerKeys.length ||
        !value.keys.every(_layerKeys.contains)) {
      final keys = value.keys.map(ThemeReader.show).join(', ');
      _reader.report(
        StratumThemeErrorCode.expectedShadow,
        path,
        'expected the keys x, y, blur, spread, and color, got '
        '${keys.isEmpty ? 'none' : keys}',
      );
      return null;
    }
    final x = _signedLength('$path.x', value['x']);
    final y = _signedLength('$path.y', value['y']);
    final blur = _atLeastZero(_reader, '$path.blur', value['blur']);
    final spread = _signedLength('$path.spread', value['spread']);
    final color = _layerColor('$path.color', value['color']);
    if (x == null ||
        y == null ||
        blur == null ||
        spread == null ||
        color == null) {
      return null;
    }
    return StratumShadowLayer(
      x: x,
      y: y,
      blur: blur,
      spread: spread,
      color: color,
    );
  }

  /// A layer's `x`, `y`, or `spread` at [path]: a theme length (config s03
  /// INV-15), which may be negative; `required` for an empty value,
  /// else `expected_dimension`.
  double? _signedLength(String path, Object? value) {
    if (value is num && ThemeReader.isLength(value)) return value.toDouble();
    if (value == null) {
      _reader.report(StratumThemeErrorCode.required, path, 'required');
      return null;
    }
    const max = ThemeReader.maxLength;
    _reader.report(
      StratumThemeErrorCode.expectedDimension,
      path,
      'expected a number from -$max to $max, got ${ThemeReader.show(value)}',
    );
    return null;
  }

  /// [value] at [path] as a number from 0 to the length bound, reported
  /// through [reader]: `required` for an empty value, else
  /// `expected_dimension`.
  static double? _atLeastZero(ThemeReader reader, String path, Object? value) {
    if (value is num && _isEffectNumber(value)) return value.toDouble();
    if (value == null) {
      reader.report(StratumThemeErrorCode.required, path, 'required');
      return null;
    }
    reader.report(
      StratumThemeErrorCode.expectedDimension,
      path,
      'expected a number from 0 to ${ThemeReader.maxLength}, got '
      '${ThemeReader.show(value)}',
    );
    return null;
  }

  /// Whether [value] is a `border` width or a blur radius: a theme length
  /// (config s03 INV-15) of 0 or more.
  static bool _isEffectNumber(Object? value) =>
      value is num && ThemeReader.isLength(value) && value >= 0;

  /// The color of the layer at [path] (FO-01 US-01 FR-01 E15; US-03 FR-01
  /// E05, E06): `"{color.<group>.<name>}"`, which stage 4 checked in every
  /// color set, stays a reference to that path inside the set; any other
  /// value reads as a color, a palette or transparent alias holding its
  /// stage-4 target's value. A path whose alias failed in stage 4 reports
  /// nothing more.
  StratumLayerColor? _layerColor(String path, Object? value) {
    if (_theme.failed.contains(path)) return null;
    const prefix = '{color.';
    if (value is String && isAlias(value) && value.startsWith(prefix)) {
      return StratumSetLayerColor(
        value.substring(prefix.length, value.length - 1),
      );
    }
    final argb = _readerFor(
      path,
      value,
    ).color(value, path, alias: _theme.aliases[path]);
    return argb == null ? null : StratumFixedLayerColor(argb);
  }

  /// The `system` group (FO-01 US-01 FR-01 E17 to E19; config s03
  /// INV-16): each of the four sets, which stage 3 made full.
  Map<String, Map<String, Object>> _system(Object? value) {
    final node = _reader.map(value, 'system');
    if (node == null) return const {};
    return frozenMap({
      for (final name in ThemeSchema.colorSets.keys)
        name: _systemSet(node[name], name),
    });
  }

  /// The `system` set [name]: each key of its base set in the package
  /// default, read by its kind. `statusBarIcons` and `navigationBarIcons`
  /// name one of [systemBarIconNames], `statusBarContrast` and
  /// `navigationBarContrast` are booleans, and every other key is a color
  /// or an alias that stage 4 resolved to one.
  Map<String, Object> _systemSet(Object? value, String name) {
    final values = <String, Object>{};
    final node = value is Map<String, Object?>
        ? value
        : const <String, Object?>{};
    for (final key in (_schema.keysAt(['system', name]) ?? const {}).keys) {
      final path = 'system.$name.$key';
      if (_theme.failed.contains(path)) continue;
      final entry = node[key];
      final reader = _readerFor(path, entry);
      final read = switch (key) {
        'statusBarIcons' ||
        'navigationBarIcons' => _barIcons(reader, path, entry),
        'statusBarContrast' ||
        'navigationBarContrast' => _flag(reader, path, entry),
        _ => reader.color(entry, path, alias: _theme.aliases[path]),
      };
      if (read != null) values[key] = read;
    }
    return frozenMap(values);
  }

  /// [value] as one of [systemBarIconNames] (FO-01 US-01 FR-01 E18).
  static String? _barIcons(ThemeReader reader, String path, Object? value) {
    if (value is String && systemBarIconNames.contains(value)) return value;
    if (value == null) {
      reader.report(StratumThemeErrorCode.required, path, 'required');
      return null;
    }
    reader.report(
      StratumThemeErrorCode.expectedBarIcons,
      path,
      'expected one of ${systemBarIconNames.join(', ')}, got '
      '${ThemeReader.show(value)}',
    );
    return null;
  }

  /// [value] as a yaml boolean (FO-01 US-01 FR-01 E19).
  static bool? _flag(ThemeReader reader, String path, Object? value) {
    if (value is bool) return value;
    if (value == null) {
      reader.report(StratumThemeErrorCode.required, path, 'required');
      return null;
    }
    reader.report(
      StratumThemeErrorCode.expectedBoolean,
      path,
      'expected true or false, got ${ThemeReader.show(value)}',
    );
    return null;
  }

  /// The `focus` group (FO-01 US-01 FR-01 E20; config s03 INV-19):
  /// each of the four sets, which stage 3 made full.
  Map<String, Map<String, Object>> _focus(Object? value) {
    final node = _reader.map(value, 'focus');
    if (node == null) return const {};
    return frozenMap({
      for (final name in ThemeSchema.colorSets.keys)
        name: _focusSet(node[name], name),
    });
  }

  /// The `focus` set [name], each key of [focusKeys] read by its kind: a
  /// color with an alpha above 0, a width above 0 up to the length bound,
  /// and a gap from 0 to it (config s03 INV-15), since a fully
  /// transparent color or a width of 0 hides the ring.
  Map<String, Object> _focusSet(Object? value, String name) {
    final values = <String, Object>{};
    for (final key in focusKeys) {
      final path = 'focus.$name.$key';
      if (_theme.failed.contains(path)) continue;
      final entry = _at(value, key.split('.'));
      final reader = _readerFor(path, entry);
      final read = switch (key) {
        'outside.color' || 'inside.color' => _focusColor(reader, path, entry),
        'outside.gap' => _atLeastZero(reader, path, entry),
        _ => _aboveZero(reader, path, entry),
      };
      if (read != null) values[key] = read;
    }
    return frozenMap(values);
  }

  /// The value at [segments] below [node]; null when a step is no map.
  static Object? _at(Object? node, List<String> segments) {
    var current = node;
    for (final segment in segments) {
      if (current is! Map<String, Object?>) return null;
      current = current[segment];
    }
    return current;
  }

  /// [value] at [path] as a focus color: a color, or an alias that stage 4
  /// resolved to one, whose alpha is above 0 (FO-01 US-01 FR-01 E20). An
  /// inherited high-contrast leaf reports nothing at its own path (spec
  /// section 7.4), so a fully transparent color it inherits reports at the
  /// color token its retargeted alias names (config s03 INV-19).
  int? _focusColor(ThemeReader reader, String path, Object? value) {
    final alias = _theme.aliases[path];
    final argb = reader.color(value, path, alias: alias);
    if (argb == null || (argb >> 24) & 0xFF != 0) return argb;
    if (_theme.inherited.contains(path)) {
      // A copied literal alias (one `_retarget` left unchanged) names the
      // same token the base set's own leaf does, which already reported at
      // the base set (INV-18); only a retargeted alias, which names a
      // token inside the overlay set's own color set, can fail here. A
      // retargeted token the overlay set itself never set is inherited too,
      // so it holds the base set's own value, whose leaf already reported
      // (INV-18): skip it rather than report it a second time.
      final overlay = path.split('.')[1];
      final token = _theme.chains[path]?.first;
      if (token != null &&
          token.startsWith('color.$overlay.') &&
          !_theme.inherited.contains(token) &&
          _reportedClear.add(token)) {
        _reader.report(
          StratumThemeErrorCode.expectedColor,
          token,
          'expected a color with an alpha above 0, since $path names it and '
          'a fully transparent color hides the focus ring, got '
          '${ThemeReader.show(value)}',
        );
      }
      return null;
    }
    final from = alias == null ? '' : ' (from ${ThemeReader.show(alias)})';
    if (_reportedClear.add(path)) {
      reader.report(
        StratumThemeErrorCode.expectedColor,
        path,
        'expected a color with an alpha above 0, since a fully transparent '
        'color hides the focus ring, got ${ThemeReader.show(value)}$from',
      );
    }
    return null;
  }

  /// [value] at [path] as a focus width: a number above 0 up to the length
  /// bound (FO-01 US-01 FR-01 E20), since a width of 0 hides the ring;
  /// `required` for an empty value, else `expected_dimension`.
  static double? _aboveZero(ThemeReader reader, String path, Object? value) {
    if (value is num && ThemeReader.isLength(value) && value > 0) {
      return value.toDouble();
    }
    if (value == null) {
      reader.report(StratumThemeErrorCode.required, path, 'required');
      return null;
    }
    reader.report(
      StratumThemeErrorCode.expectedDimension,
      path,
      'expected a number above 0 up to ${ThemeReader.maxLength}, since a '
      'width of 0 hides the focus ring, got ${ThemeReader.show(value)}',
    );
    return null;
  }

  PlainTypography _typography(Object? value) {
    final node = _reader.map(value, 'typography');
    return node == null
        ? const PlainTypography(fonts: {}, families: {}, types: {})
        : readTypography(
            node,
            _reader,
            sources: [
              for (final source in _sources)
                (id: source.id, folder: source.folder),
            ],
            googleFontExists: _googleFontExists,
          );
  }

  Map<String, Object?> _extensions(Object? value) =>
      value is Map<String, Object?>
      ? _frozen(value)! as Map<String, Object?>
      : const {};

  static Object? _frozen(Object? value) => switch (value) {
    final Map<String, Object?> map => frozenMap<String, Object?>({
      for (final MapEntry(:key, value: child) in map.entries)
        key: _frozen(child),
    }),
    final List<Object?> list => List<Object?>.unmodifiable(list.map(_frozen)),
    _ => value,
  };
}
