// Packs a theme folder into a zip and checks a theme zip by the app's own
// install check (FO-04 US-02). Run it from the app project, so its checks
// are the stratum_ui version the app resolves:
//
//   dart run stratum_ui:stratum_theme pack <folder> [options]
//   dart run stratum_ui:stratum_theme check <file.zip> [options]
//
// It reaches no Flutter library, so `dart run` compiles it in the Dart VM
// (FO-04 s03 invariant 13).
import 'dart:io';

/// The exit status of a usage error (FO-04 US-02 FR-03).
const exitUsage = 64;

/// The usage text a usage error prints on the standard error.
const stratumThemeUsage = '''
usage: dart run stratum_ui:stratum_theme <command> <file> [options]
  pack <folder>      [--id <id>] [--out <folder>] [--app-default <path>]
                     [--max-bytes <n>] [--max-entries <n>]
  check <file.zip>   [--id <id>] [--app-default <path>]
                     [--max-bytes <n>] [--max-entries <n>]''';

/// Every argument list is a usage error until the `pack` and `check`
/// commands land.
void main(List<String> args) {
  stderr
    ..writeln('usage error: no command is built yet')
    ..writeln(stratumThemeUsage);
  exitCode = exitUsage;
}
