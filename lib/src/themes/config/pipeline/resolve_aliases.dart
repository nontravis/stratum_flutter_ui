import 'package:stratum_ui/src/themes/config/escape_text.dart';
import 'package:stratum_ui/src/themes/config/format_error.dart';
import 'package:stratum_ui/src/themes/config/pipeline/check_keys.dart';
import 'package:stratum_ui/src/themes/config/pipeline/merge.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';
import 'package:stratum_ui/src/themes/config/transparent.dart';

/// The tree after stage 4: every alias holder holds its target's value.
final class ResolvedTheme {
  new({
    required this.tree,
    required this.origins,
    required this.inherited,
    required this.aliases,
    required this.chains,
    required this.failed,
  });

  /// The merged tree with each resolved alias replaced by its target's
  /// value; a failed alias keeps its text.
  final Map<String, Object?> tree;

  /// [MergedTheme.origins], unchanged.
  final Map<String, ThemeOrigin> origins;

  /// [MergedTheme.inherited], unchanged.
  final Set<String> inherited;

  /// Each alias holder's alias text, by the holder's path.
  final Map<String, String> aliases;

  /// For each resolved holder, the paths its alias passed through: its own
  /// target first, the final target last.
  final Map<String, List<String>> chains;

  /// The holders whose alias failed in stage 4; stage 5 skips them.
  final Set<String> failed;
}

/// Stage 4 (spec section 7.3): resolves every alias in the token groups of
/// [merged] and in the `system` and `focus` groups, which no alias may name
/// (config s03 INV-16, INV-19), then each shadow layer's color alias
/// (config s03 INV-13). Every problem goes to [errors].
ResolvedTheme resolveThemeAliases(
  MergedTheme merged,
  ThemeSchema schema,
  ThemeErrors errors,
) => _Resolve(merged, schema, ThemeReader(errors, merged.origins)).run();

enum _Target { token, builtin, missing, group, outside }

final class _Resolve {
  new(this._merged, this._schema, this._reader);

  final MergedTheme _merged;
  final ThemeSchema _schema;
  final ThemeReader _reader;

  /// Each holder's path as segments, by its dotted path, in tree order.
  final _holders = <String, List<String>>{};
  final _aliases = <String, String>{};

  /// Each holder's chain once known; null for a holder whose alias failed.
  final _done = <String, List<String>?>{};

  /// The holders being followed, outermost first.
  final _visiting = <String>[];

  /// The groups whose aliases name a token of their own group only (config
  /// s03 INV-4).
  static const _ownGroupOnly = {'border', 'blur'};

  ResolvedTheme run() {
    for (final group in ThemeSchema.tokenGroups) {
      _collect(_merged.tree[group], [group]);
    }
    _collect(_merged.tree['system'], const ['system']);
    _collect(_merged.tree['focus'], const ['focus']);
    _holders.keys.forEach(_resolve);
    final chains = <String, List<String>>{};
    final failed = <String>{};
    final deepestFirst = _holders.keys.toList()
      ..sort((a, b) => _holders[b]!.length.compareTo(_holders[a]!.length));
    for (final path in deepestFirst) {
      final chain = _done[path];
      if (chain == null) {
        failed.add(path);
        continue;
      }
      chains[path] = chain;
      _setAt(_holders[path]!, _valueOf(chain.last));
    }
    _layerColors(chains, failed);
    return ResolvedTheme(
      tree: _merged.tree,
      origins: _merged.origins,
      inherited: _merged.inherited,
      aliases: _aliases,
      chains: chains,
      failed: failed,
    );
  }

  void _collect(Object? node, List<String> path) {
    if (node is Map<String, Object?>) {
      for (final MapEntry(:key, :value) in node.entries) {
        _collect(value, [...path, key]);
      }
    } else if (node is String && isAlias(node) && !_isAppRamp(path)) {
      final dotted = path.join('.');
      _holders[dotted] = path;
      _aliases[dotted] = node;
    }
  }

  /// Whether [path] is a `palette.app` ramp (a group, never an alias
  /// source or target, spec G1): stage 5 reports it directly.
  static bool _isAppRamp(List<String> path) =>
      path.length == 3 && path[0] == 'palette' && path[1] == 'app';

  /// The chain of the holder at [path], or null when its alias fails.
  List<String>? _resolve(String path) {
    if (_done.containsKey(path)) return _done[path];
    final start = _visiting.indexOf(path);
    if (start >= 0) {
      _reportCycle(_visiting.sublist(start));
      return null;
    }
    _visiting.add(path);
    final chain = _follow(path, _aliases[path]!);
    _visiting.removeLast();
    return _done[path] = chain;
  }

  List<String>? _follow(String path, String alias) {
    final target = alias.substring(1, alias.length - 1).split('.');
    final group = path.substring(0, path.indexOf('.'));
    if (_ownGroupOnly.contains(group) &&
        target.first != group &&
        (ThemeSchema.tokenGroups.contains(target.first) ||
            target.first == 'transparent')) {
      _report(
        path,
        StratumThemeErrorCode.aliasNotToken,
        'names a ${target.first} token, not a $group token',
      );
      return null;
    }
    switch (_classify(target)) {
      case _Target.builtin:
        return [target.join('.')];
      case _Target.token:
        final dotted = target.join('.');
        if (!_aliases.containsKey(dotted)) return [dotted];
        final rest = _resolve(dotted);
        return rest == null ? null : [dotted, ...rest];
      case _Target.missing:
        _report(path, StratumThemeErrorCode.unknownAlias, 'names no token');
        return null;
      case _Target.group:
        _report(
          path,
          StratumThemeErrorCode.aliasNotToken,
          'names a group, not a token',
        );
        return null;
      case _Target.outside:
        _report(
          path,
          StratumThemeErrorCode.aliasNotToken,
          'is outside the token groups',
        );
        return null;
    }
  }

  _Target _classify(List<String> path) {
    if (path.first == 'transparent') {
      if (path.length == 3 &&
          (transparentColors[path[1]]?.containsKey(path[2]) ?? false)) {
        return _Target.builtin;
      }
      final isGroup = switch (path.length) {
        1 => true,
        2 => transparentColors.containsKey(path[1]),
        _ => false,
      };
      return isGroup ? _Target.group : _Target.missing;
    }
    if (!ThemeSchema.tokenGroups.contains(path.first)) return _Target.outside;
    Object? node = _merged.tree;
    var insideToken = false;
    for (final (index, key) in path.indexed) {
      if (node is! Map<String, Object?> || !node.containsKey(key)) {
        return _Target.missing;
      }
      node = node[key];
      if (index < path.length - 1 &&
          _schema.isLeaf(path.sublist(0, index + 1))) {
        insideToken = true;
      }
    }
    if (insideToken || !_schema.isLeaf(path)) return _Target.group;
    return _Target.token;
  }

  /// Stage 4 for the `color` of each shadow layer (FO-01 US-03 FR-01 E05,
  /// E06; config s03 INV-13). A layer is no alias target, so this
  /// runs once the token groups have resolved: a palette or transparent
  /// alias takes its final target's value and records its chain; a
  /// `"{color.<group>.<name>}"` reference stays as written once every
  /// color set holds a token at that path; any other alias fails.
  void _layerColors(Map<String, List<String>> chains, Set<String> failed) {
    final shadow = _merged.tree['shadow'];
    if (shadow is! Map<String, Object?>) return;
    for (final MapEntry(key: level, value: layers) in shadow.entries) {
      if (layers is! List<Object?>) continue;
      for (final (index, layer) in layers.indexed) {
        if (layer is! Map<String, Object?>) continue;
        final alias = layer['color'];
        if (alias is! String || !isAlias(alias)) continue;
        final path = 'shadow.$level.$index.color';
        _aliases[path] = alias;
        final chain = _layerChain(
          path,
          alias.substring(1, alias.length - 1).split('.'),
        );
        if (chain == null) {
          failed.add(path);
        } else if (chain.isNotEmpty) {
          chains[path] = chain;
          layer['color'] = _valueOf(chain.last);
        }
      }
    }
  }

  /// The chain of the layer color alias at [path] naming [target]: empty
  /// for a color set reference, which each set resolves on its own; null
  /// when the alias fails. A palette target whose own alias failed fails
  /// here too, silently: the target reports it.
  List<String>? _layerChain(String path, List<String> target) {
    final group = target.first;
    if (group == 'color') {
      return _inEverySet(path, target.sublist(1)) ? const [] : null;
    }
    if (group != 'palette' && group != 'transparent') {
      _report(
        path,
        StratumThemeErrorCode.aliasNotToken,
        ThemeSchema.tokenGroups.contains(group)
            ? 'names a $group token, not a color'
            : 'is outside the token groups',
      );
      return null;
    }
    final kind = _classify(target);
    if (kind == _Target.missing) {
      _report(path, StratumThemeErrorCode.unknownAlias, 'names no token');
      return null;
    }
    if (kind == _Target.group) {
      _report(
        path,
        StratumThemeErrorCode.aliasNotToken,
        'names a group, not a token',
      );
      return null;
    }
    final dotted = target.join('.');
    if (kind == _Target.builtin || !_aliases.containsKey(dotted)) {
      return [dotted];
    }
    final rest = _done[dotted];
    return rest == null ? null : [dotted, ...rest];
  }

  /// Whether every color set of the merged tree holds a token at [rest], a
  /// path inside a set; reports `unknown_alias` at [path] when a set lacks
  /// it and `alias_not_token` when it names a group.
  bool _inEverySet(String path, List<String> rest) {
    final color = _merged.tree['color'];
    for (final colorSet in ThemeSchema.colorSets.keys) {
      var node = color is Map<String, Object?> ? color[colorSet] : null;
      for (final key in rest) {
        if (node is! Map<String, Object?> || !node.containsKey(key)) {
          _report(path, StratumThemeErrorCode.unknownAlias, 'names no token');
          return false;
        }
        node = node[key];
      }
      if (rest.isEmpty || !_schema.isLeaf(['color', colorSet, ...rest])) {
        _report(
          path,
          StratumThemeErrorCode.aliasNotToken,
          'names a group, not a token',
        );
        return false;
      }
    }
    return true;
  }

  /// Reports one cycle once, at the member that sorts first by the error
  /// order among the members that are not inherited (spec G12). When every
  /// member is an inherited leaf, the cycle has no light or dark mirror of
  /// its own to carry the report: it goes instead to the outermost
  /// non-inherited holder still on [_visiting], the explicit value that led
  /// into the cycle. A cycle reached with no such holder on the stack (a
  /// mirror cycle the retarget copied whole, disconnected from the base
  /// set's own traversal) stays silent: its base-set twin reports it.
  void _reportCycle(List<String> members) {
    final reporters = [
      for (final member in members)
        if (!_merged.inherited.contains(member)) member,
    ]..sort(_byPosition);
    final String path;
    final List<String> cycle;
    if (reporters.isEmpty) {
      String? outer;
      for (final holder in _visiting) {
        if (!_merged.inherited.contains(holder)) {
          outer = holder;
          break;
        }
      }
      if (outer == null) return;
      path = outer;
      cycle = [...members, members.first];
    } else {
      final first = reporters.first;
      final start = members.indexOf(first);
      path = first;
      cycle = [...members.sublist(start), ...members.sublist(0, start), first];
    }
    _reader.report(
      StratumThemeErrorCode.aliasCycle,
      path,
      'alias cycle: ${escapeZipText(cycle.join(' -> '))}',
    );
  }

  int _byPosition(String a, String b) {
    final (x, y) = (_rank(a), _rank(b));
    if (x.source != y.source) return x.source.compareTo(y.source);
    if (x.line != y.line) return x.line.compareTo(y.line);
    return x.column.compareTo(y.column);
  }

  /// Where [path] sorts in the error order; a path without a position
  /// sorts after the positioned paths of its file.
  ({int source, int line, int column}) _rank(String path) {
    final origin = _merged.origins[path];
    final at = origin?.value;
    return (
      source: origin?.source ?? 0,
      line: at?.line ?? 1 << 30,
      column: at?.column ?? 0,
    );
  }

  void _report(String path, StratumThemeErrorCode code, String what) {
    if (_merged.inherited.contains(path)) return;
    _reader.report(code, path, '${ThemeReader.show(_aliases[path])} $what');
  }

  Object? _valueOf(String target) {
    final path = target.split('.');
    if (path.first == 'transparent') {
      return transparentColors[path[1]]![path[2]];
    }
    Object? node = _merged.tree;
    for (final key in path) {
      node = (node! as Map<String, Object?>)[key];
    }
    return copyTree(node);
  }

  void _setAt(List<String> path, Object? value) {
    var node = _merged.tree;
    for (final key in path.take(path.length - 1)) {
      node = node[key]! as Map<String, Object?>;
    }
    node[path.last] = value;
  }
}
