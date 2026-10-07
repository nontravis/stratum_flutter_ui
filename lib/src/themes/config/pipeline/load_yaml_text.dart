import 'package:stratum_ui/src/themes/config/escape_text.dart';
import 'package:yaml/yaml.dart';

/// Loads [text] as one yaml document, in the one place that turns every
/// failure package:yaml throws on hostile text into [YamlTextFailure]
/// instead of an unhandled exception (FR-03 E09, s05 exit 66).
///
/// Does not catch [StackOverflowError]: deep flow nesting is untested here
/// and queued for the owner separately.
YamlNode loadYamlText(String text) {
  try {
    return loadYamlNode(text);
  } on FormatException catch (error) {
    // `FormatException` also covers `YamlException`, whose `span` locates
    // the error when package:yaml found one.
    final start = error is YamlException ? error.span?.start : null;
    throw YamlTextFailure(
      escapeZipText(error.message),
      at: start == null
          ? null
          : (line: start.line + 1, column: start.column + 1),
    );
  }
  // package:yaml's leaky ArgumentError below is untrusted-input text, not a
  // programming bug; see the WORKAROUND on the next line.
  // ignore: avoid_catching_errors
  on ArgumentError {
    // WORKAROUND: package:yaml throws ArgumentError, not YamlException, for
    // a malformed %-escape in a tag; remove once package:yaml reports it as
    // YamlException.
    throw const YamlTextFailure('invalid percent escape in a tag');
  }
}

/// A yaml document [loadYamlText] could not parse: [message] is escaped
/// once (plan D-g); [at] is the 1-based line and column package:yaml
/// located the error at, or null when it found none.
final class YamlTextFailure implements Exception {
  const new(this.message, {this.at});

  final String message;
  final ({int line, int column})? at;
}
