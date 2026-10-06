import 'package:stratum_ui/src/themes/config/escape_text.dart';
import 'package:stratum_ui/src/themes/config/format_error.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';
import 'package:stratum_ui/src/themes/config/schema_version.dart';
import 'package:stratum_ui/src/themes/config/theme_source.dart';
import 'package:yaml/yaml.dart';

/// Stage 1 (spec section 7): loads every one of [sources] and checks its
/// `$schema`.
///
/// Returns the root map of each file, in order. Every problem goes to
/// [errors]; the list is complete only when [errors] stayed empty, and the
/// caller stops when it did not.
List<YamlMap> loadThemes(List<StratumThemeSource> sources, ThemeErrors errors) {
  final roots = <YamlMap>[];
  for (final (index, source) in sources.indexed) {
    final root = _load(source.yaml, index, errors);
    if (root != null && _checkSchema(root, index, errors)) roots.add(root);
  }
  return roots;
}

YamlMap? _load(String yaml, int source, ThemeErrors errors) {
  final YamlNode root;
  try {
    root = loadYamlNode(yaml);
  } on YamlException catch (error) {
    final start = error.span?.start;
    errors.add(
      StratumThemeErrorCode.yamlSyntax,
      '',
      escapeZipText(error.message),
      source: source,
      at: start == null
          ? null
          : (line: start.line + 1, column: start.column + 1),
    );
    return null;
  }
  // package:yaml's leaky ArgumentError below is untrusted-input text, not a
  // programming bug; see the WORKAROUND on the next line.
  // ignore: avoid_catching_errors
  on ArgumentError {
    // WORKAROUND: package:yaml throws ArgumentError, not YamlException, for a
    // malformed %-escape in a tag; remove once package:yaml reports it as
    // YamlException.
    errors.add(
      StratumThemeErrorCode.yamlSyntax,
      '',
      'invalid percent escape in a tag',
      source: source,
    );
    return null;
  }
  if (root is YamlMap) return root;
  final Object? value = root.value;
  errors.add(
    StratumThemeErrorCode.expectedMap,
    '',
    'expected a map, got ${ThemeReader.show(value)}',
    source: source,
    at: value == null ? null : positionOf(root),
  );
  return null;
}

/// Whether the `$schema` of [root] names a version this package reads;
/// reports why when it does not.
bool _checkSchema(YamlMap root, int source, ThemeErrors errors) {
  const path = r'$schema';
  final node = root.nodes[path];
  final Object? value = node?.value;
  final at = node == null ? null : positionOf(node);
  void fail(StratumThemeErrorCode code, String message) =>
      errors.add(code, path, message, source: source, at: at);

  if (value == null) {
    fail(StratumThemeErrorCode.required, 'required');
    return false;
  }
  if (value is! String) {
    fail(
      StratumThemeErrorCode.expectedString,
      'expected a string, got ${ThemeReader.show(value)}',
    );
    return false;
  }
  final version = StratumSchemaVersion.tryParse(value);
  if (version == null) {
    fail(
      StratumThemeErrorCode.unsupportedSchema,
      'expected "stratum-theme/v<major>.<minor>.<patch>", got '
      '${ThemeReader.show(value)}',
    );
    return false;
  }
  if (!version.isSupported) {
    const current = StratumSchemaVersion.current;
    fail(
      StratumThemeErrorCode.unsupportedSchema,
      'theme needs stratum-theme v${version.major}.${version.minor}; '
      'this app reads up to v${current.major}.${current.minor}',
    );
    return false;
  }
  return true;
}
