import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/config/escape_text.dart';
import 'package:stratum_ui/src/themes/config/theme_model.dart';

part 'generated/format_error.freezed.dart';

/// The kind of a `theme.yaml` problem; [key] is its catalog name.
enum StratumThemeErrorCode {
  // Stage 1
  yamlSyntax,
  unsupportedSchema,
  // FO-01
  required,
  expectedMap,
  expectedString,
  expectedDimension,
  expectedColor,
  unknownKey,
  unknownAlias,
  aliasCycle,
  aliasNotToken,
  invalidAsset,
  expectedDuration,
  expectedCurve,
  expectedTransition,
  // FO-02 typography (docs/specs/stratum_ui/themes/typography/s05_errors.md)
  emptyFonts,
  unknownFontKey,
  invalidTag,
  duplicateTag,
  invalidWeight,
  emptySizes,
  tableBlock,
  missingDefaultFont,
  unknownGoogleFont,
  emptyGoogleFont,
  googleFontPackage,
  invalidFontFile,
  emptyFontFiles,
  googleFontFiles,
  fontFilesPackage;

  static final _capital = RegExp('[A-Z]');

  /// The catalog key: the code's name in snake_case, for example
  /// `unsupported_schema`.
  String get key =>
      name.replaceAllMapped(_capital, (match) => '_${match[0]!.toLowerCase()}');
}

/// One problem in a `theme.yaml` file.
@immutable
@themeModel
class StratumThemeFormatError with _$StratumThemeFormatError {
  const new({
    required this.code,
    required this.source,
    required this.path,
    required this.message,
    this.line,
    this.column,
  });

  /// What kind of problem this is.
  final StratumThemeErrorCode code;

  /// The id of the file that set the value.
  final String source;

  /// The dotted yaml path, for example `color.light.brand.normal`; the
  /// empty string is the root.
  final String path;

  /// What is wrong at [path].
  final String message;

  /// 1-based, as editors show; null when the yaml has no position for it.
  final int? line;

  /// 1-based; null exactly when [line] is null.
  final int? column;

  /// `<path>: <message>`, the path escaped by FO-04's rule (FO-01 S-06).
  @override
  String toString() => '${escapeZipText(path)}: $message';
}

/// Thrown when one or more `theme.yaml` files have problems; [errors] lists
/// them all.
@immutable
class StratumThemeFormatException implements Exception {
  const new(this.errors);

  /// Every problem: the package default's first, then each layer's in
  /// order; inside one file by line, then column, with the problems that
  /// have no position last.
  final List<StratumThemeFormatError> errors;

  @override
  bool operator ==(Object other) =>
      other is StratumThemeFormatException &&
      const DeepCollectionEquality().equals(other.errors, errors);

  @override
  int get hashCode => Object.hashAll(errors);

  /// A header line, then one line per error:
  /// `  <source>:<line>:<column> <path>: <message> [<key>]`. The position
  /// drops when the error has none, and the root path shows as `(root)`.
  @override
  String toString() => [
    'StratumThemeFormatException: ${errors.length} problem(s) in theme.yaml',
    for (final error in errors) '  ${_describe(error)}',
  ].join('\n');

  static String _describe(StratumThemeFormatError error) {
    final position = error.line == null ? '' : ':${error.line}:${error.column}';
    final path = error.path.isEmpty ? '(root)' : escapeZipText(error.path);
    return '${error.source}$position $path: ${error.message} '
        '[${error.code.key}]';
  }
}
