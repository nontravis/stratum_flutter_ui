import 'dart:ui' show Color;

import 'package:stratum_ui/src/themes/config/format_error.dart';
import 'package:stratum_ui/src/themes/typography/dimension.dart';
import 'package:yaml/yaml.dart';

/// A 1-based line and column in one theme file.
typedef ThemePosition = ({int line, int column});

/// Where the value at one path came from: the index of its file among the
/// sources of the parse, and where its key and its value start. The root
/// has no key.
typedef ThemeOrigin = ({int source, ThemePosition? key, ThemePosition? value});

/// The position where [node] starts.
ThemePosition positionOf(YamlNode node) =>
    (line: node.span.start.line + 1, column: node.span.start.column + 1);

/// [key] below [path]; a [path] of `''` is the root.
String childPath(String path, String key) => path.isEmpty ? key : '$path.$key';

/// Whether [value] is an alias: a whole string `{<path>}` (spec section
/// 7.3).
bool isAlias(Object? value) => value is String && _alias.hasMatch(value);

final _alias = RegExp(r'^\{[^{}]+\}$');

/// Converts [node] to plain Dart values: a `Map<String, Object?>` with
/// every key in its string form, a `List<Object?>`, or the scalar's value.
/// Records the origin of [path] and of every path below it in [origins].
Object? plainOf(
  YamlNode node, {
  required String path,
  required int source,
  required Map<String, ThemeOrigin> origins,
  ThemePosition? key,
}) {
  origins[path] = (source: source, key: key, value: positionOf(node));
  if (node is YamlMap) {
    final map = <String, Object?>{};
    for (final MapEntry(key: Object? keyNode, value: child)
        in node.nodes.entries) {
      final keyYaml = keyNode! as YamlNode;
      final name = '${keyYaml.value}';
      map[name] = plainOf(
        child,
        path: childPath(path, name),
        source: source,
        origins: origins,
        key: positionOf(keyYaml),
      );
    }
    return map;
  }
  if (node is YamlList) {
    return <Object?>[
      for (final (index, child) in node.nodes.indexed)
        plainOf(
          child,
          path: childPath(path, '$index'),
          source: source,
          origins: origins,
        ),
    ];
  }
  return node.value;
}

/// A deep copy of a plain [value]: maps and lists are copied, scalars
/// shared.
Object? copyTree(Object? value) => switch (value) {
  final Map<String, Object?> map => <String, Object?>{
    for (final MapEntry(:key, value: child) in map.entries)
      key: copyTree(child),
  },
  final List<Object?> list => <Object?>[
    for (final item in list) copyTree(item),
  ],
  _ => value,
};

typedef _Entry = ({int source, int order, StratumThemeFormatError error});

/// The errors of one parse, sorted in the order of spec section 7.4.
final class ThemeErrors {
  new(this.sources);

  /// The id of each file, in parse order: the base first, then each layer.
  final List<String> sources;

  final _entries = <_Entry>[];

  /// Whether no error was added.
  bool get isEmpty => _entries.isEmpty;

  /// Adds one error of the file at index [source], at position [at].
  void add(
    StratumThemeErrorCode code,
    String path,
    String message, {
    required int source,
    ThemePosition? at,
  }) => _entries.add((
    source: source,
    order: _entries.length,
    error: StratumThemeFormatError(
      code: code,
      source: sources[source],
      path: path,
      message: message,
      line: at?.line,
      column: at?.column,
    ),
  ));

  /// Every error: by file, then by line and column, the errors without a
  /// position after the positioned ones of their file; ties keep the order
  /// they were added in.
  List<StratumThemeFormatError> get sorted {
    final entries = [..._entries]..sort(_compare);
    return List.unmodifiable([for (final entry in entries) entry.error]);
  }

  /// Throws one [StratumThemeFormatException] with [sorted] when any error
  /// was added.
  void throwIfAny() {
    if (_entries.isNotEmpty) throw StratumThemeFormatException(sorted);
  }

  static int _compare(_Entry a, _Entry b) {
    if (a.source != b.source) return a.source.compareTo(b.source);
    final (aLine, bLine) = (a.error.line, b.error.line);
    if (aLine == null || bLine == null) {
      if (aLine != bLine) return aLine == null ? 1 : -1;
      return a.order.compareTo(b.order);
    }
    if (aLine != bLine) return aLine.compareTo(bLine);
    final byColumn = a.error.column!.compareTo(b.error.column!);
    return byColumn != 0 ? byColumn : a.order.compareTo(b.order);
  }
}

/// Reads typed values out of a plain tree and reports each problem at its
/// path, with the source and the position that [origins] holds for it.
final class ThemeReader {
  new(this.errors, this.origins);

  static final _hex = RegExp(r'^#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$');

  /// Where every error goes.
  final ThemeErrors errors;

  /// The origin of every path the tree holds.
  final Map<String, ThemeOrigin> origins;

  /// Reports [message] at [path]: at the position of the path's key when
  /// [atKey] is set, else at its value's. A path with no origin of its own
  /// takes the source of its nearest ancestor that has one, and no
  /// position.
  void report(
    StratumThemeErrorCode code,
    String path,
    String message, {
    bool atKey = false,
  }) {
    final origin = origins[path];
    if (origin == null) {
      errors.add(code, path, message, source: _ancestorSource(path));
      return;
    }
    errors.add(
      code,
      path,
      message,
      source: origin.source,
      at: atKey ? origin.key : origin.value,
    );
  }

  /// [value] as a map; reports `required` for null when [required] is set,
  /// and `expected_map` for any other value.
  Map<String, Object?>? map(
    Object? value,
    String path, {
    bool required = true,
  }) {
    if (value is Map<String, Object?>) return value;
    if (value == null) {
      if (required) report(StratumThemeErrorCode.required, path, 'required');
      return null;
    }
    report(
      StratumThemeErrorCode.expectedMap,
      path,
      'expected a map, got ${show(value)}',
    );
    return null;
  }

  /// [value] as a string; reports `required` for null when [required] is
  /// set, and `expected_string` for any other value.
  String? string(Object? value, String path, {bool required = true}) {
    if (value is String) return value;
    if (value == null) {
      if (required) report(StratumThemeErrorCode.required, path, 'required');
      return null;
    }
    report(
      StratumThemeErrorCode.expectedString,
      path,
      'expected a string, got ${show(value)}',
    );
    return null;
  }

  /// [value] read by [StratumDimension.parse]; reports `required` for null
  /// when [required] is set, and `expected_dimension` for anything else
  /// that does not parse.
  StratumDimension? dimension(
    Object? value,
    String path, {
    bool required = false,
  }) {
    if (value == null) {
      if (required) report(StratumThemeErrorCode.required, path, 'required');
      return null;
    }
    try {
      return StratumDimension.parse(value);
    } on FormatException catch (error) {
      report(StratumThemeErrorCode.expectedDimension, path, error.message);
      return null;
    }
  }

  /// [value] read by [parseColor]; reports `required` for null and
  /// `expected_color` for anything else that does not parse, naming
  /// [alias] when the value came through one.
  Color? color(Object? value, String path, {String? alias}) {
    if (value == null) {
      report(StratumThemeErrorCode.required, path, 'required');
      return null;
    }
    final color = parseColor(value);
    if (color == null) {
      final from = alias == null ? '' : ' (from "$alias")';
      report(
        StratumThemeErrorCode.expectedColor,
        path,
        'expected "#RRGGBB" or "#RRGGBBAA", got ${show(value)}$from',
      );
    }
    return color;
  }

  /// A quoted `"#RRGGBB"` or `"#RRGGBBAA"` in either case, alpha last;
  /// null for anything else.
  static Color? parseColor(Object? value) {
    if (value is! String) return null;
    final match = _hex.firstMatch(value);
    if (match == null) return null;
    final rgb = int.parse(match[1]!, radix: 16);
    final alpha = match[2] == null ? 0xFF : int.parse(match[2]!, radix: 16);
    return Color(alpha << 24 | rgb);
  }

  /// [value] read by [StratumDimension.parse], or null when it does not
  /// parse.
  static StratumDimension? parseDimension(Object? value) {
    try {
      return StratumDimension.parse(value);
    } on FormatException {
      return null;
    }
  }

  /// [value] as an error message shows it: a string in double quotes.
  static String show(Object? value) => value is String ? '"$value"' : '$value';

  int _ancestorSource(String path) {
    var current = path;
    while (current.isNotEmpty) {
      final dot = current.lastIndexOf('.');
      current = dot < 0 ? '' : current.substring(0, dot);
      if (origins[current] case final origin?) return origin.source;
    }
    return 0;
  }
}
