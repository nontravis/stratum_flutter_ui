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
/// [merged]. Every problem goes to [errors].
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

  ResolvedTheme run() {
    for (final group in ThemeSchema.tokenGroups) {
      _collect(_merged.tree[group], [group]);
    }
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
    } else if (node is String && isAlias(node)) {
      final dotted = path.join('.');
      _holders[dotted] = path;
      _aliases[dotted] = node;
    }
  }

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

  /// Reports one cycle once, at the member that sorts first by the error
  /// order among the members that are not inherited (spec G12).
  void _reportCycle(List<String> members) {
    final reporters = [
      for (final member in members)
        if (!_merged.inherited.contains(member)) member,
    ]..sort(_byPosition);
    if (reporters.isEmpty) return;
    final first = reporters.first;
    final start = members.indexOf(first);
    final cycle = [
      ...members.sublist(start),
      ...members.sublist(0, start),
      first,
    ];
    _reader.report(
      StratumThemeErrorCode.aliasCycle,
      first,
      'alias cycle: ${cycle.join(' -> ')}',
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
    _reader.report(code, path, '"${_aliases[path]}" $what');
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
