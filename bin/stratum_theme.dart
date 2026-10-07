// Packs a theme folder into a zip and checks a theme zip by the app's own
// install check (FO-04 US-02). Run it from the app project, so its checks
// are the stratum_ui version the app resolves (FR-02 E07):
//
//   dart run stratum_ui:stratum_theme pack <folder> [options]
//   dart run stratum_ui:stratum_theme check <file.zip> [options]
//
// It reaches no Flutter library, so `dart run` compiles it in the Dart VM
// (FO-04 s03 invariant 13); of the CLI, only this file reads and writes
// files.
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:stratum_ui/src/themes/config/pipeline/parse_values.dart';
import 'package:stratum_ui/src/themes/config/theme_source.dart';
import 'package:stratum_ui/src/themes/remote/generated/google_font_names.g.dart';
import 'package:stratum_ui/src/themes/remote/remote_cli_report.dart';
import 'package:stratum_ui/src/themes/remote/remote_id.dart';
import 'package:stratum_ui/src/themes/remote/remote_install_check.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';
import 'package:stratum_ui/src/themes/remote/remote_zip_writer.dart';

/// The run passed.
const exitPass = 0;

/// A check failed, or `pack` met a symbolic link or another entry that is
/// neither a file nor a folder.
const exitFailed = 1;

/// A usage error: nothing is checked or written.
const exitUsage = 64;

/// A named folder, zip file, `--app-default` file, or `--out` folder that
/// cannot be read, or a zip that cannot be written: no file is left
/// written (plan D-l).
const exitNoInput = 66;

/// The usage text a usage error prints on the standard error.
const stratumThemeUsage = '''
usage: dart run stratum_ui:stratum_theme <command> <file> [options]
  pack <folder>      [--id <id>] [--out <folder>] [--app-default <path>]
                     [--max-bytes <n>] [--max-entries <n>]
  check <file.zip>   [--id <id>] [--app-default <path>]
                     [--max-bytes <n>] [--max-entries <n>]''';

Future<void> main(List<String> args) async {
  exitCode = await runStratumTheme(
    args,
    out: stdout,
    err: stderr,
    workingDirectory: Directory.current.path,
    packageRoot: await stratumPackageRoot(),
  );
}

/// The root folder of the stratum_ui package this script runs from, whose
/// `assets/themes/default/theme.yaml` is the package default; null when the
/// package cannot be resolved.
Future<String?> stratumPackageRoot() async {
  final library = await Isolate.resolvePackageUri(
    Uri.parse('package:stratum_ui/stratum_ui.dart'),
  );
  return library == null ? null : p.dirname(p.dirname(library.toFilePath()));
}

/// Runs one `pack` or `check` command of [args] from [workingDirectory],
/// the app project, and returns its exit status (FO-04 US-02 FR-01 to
/// FR-03): the defaults line, the problems, and the warnings go to [err],
/// and the `sha256:<hex>` of a passing run is the only line of [out].
Future<int> runStratumTheme(
  List<String> args, {
  required StringSink out,
  required StringSink err,
  required String workingDirectory,
  required String? packageRoot,
}) async {
  final _Command command;
  try {
    command = _Command.parse(args);
  } on _UsageError catch (error) {
    err
      ..writeln('usage error: ${error.message}')
      ..writeln(stratumThemeUsage);
    return exitUsage;
  }
  final run = _Run(
    command,
    err: err,
    workingDirectory: workingDirectory,
    packageRoot: packageRoot,
  );
  try {
    final checksum = command.pack ? await run.pack() : await run.check();
    if (checksum == null) return exitFailed;
    out.writeln(checksum);
    return exitPass;
  } on _NoInput catch (error) {
    err.writeln(error.message);
    return exitNoInput;
  }
}

/// One command line, read by hand: no `args` dependency (design S1).
final class _Command {
  const new({
    required this.pack,
    required this.target,
    required this.maxBytes,
    required this.maxEntries,
    this.id,
    this.appDefault,
    this.outFolder,
  });

  /// Reads [args]; throws [_UsageError] for a missing or unknown command or
  /// option, an option given twice or with no value, a cap that is not a
  /// whole number above 0, or a missing or extra file argument (FR-03 E01).
  factory parse(List<String> args) {
    if (args.isEmpty) throw const _UsageError('no command');
    final name = args.first;
    if (name != 'pack' && name != 'check') {
      throw _UsageError('unknown command "${escapeZipText(name)}"');
    }
    final pack = name == 'pack';
    final known = {
      '--id',
      '--app-default',
      '--max-bytes',
      '--max-entries',
      if (pack) '--out',
    };
    final options = <String, String>{};
    final files = <String>[];
    for (var i = 1; i < args.length; i++) {
      final arg = args[i];
      if (!arg.startsWith('-') || arg == '-') {
        files.add(arg);
        continue;
      }
      final equals = arg.indexOf('=');
      final option = equals < 0 ? arg : arg.substring(0, equals);
      if (!known.contains(option)) {
        throw _UsageError(
          'unknown option "${escapeZipText(option)}" for $name',
        );
      }
      if (options.containsKey(option)) {
        throw _UsageError('$option given twice');
      }
      if (equals >= 0) {
        options[option] = arg.substring(equals + 1);
      } else if (i + 1 < args.length) {
        options[option] = args[++i];
      } else {
        throw _UsageError('$option needs a value');
      }
    }
    final what = pack ? 'folder' : 'zip file';
    if (files.isEmpty) throw _UsageError('no $what');
    if (files.length > 1) throw _UsageError('one $what per run');
    return _Command(
      pack: pack,
      target: files.single,
      id: options['--id'],
      appDefault: options['--app-default'],
      outFolder: options['--out'],
      maxBytes: _cap(
        options['--max-bytes'],
        '--max-bytes',
        StratumRemoteTheme.defaultMaxBytes,
      ),
      maxEntries: _cap(
        options['--max-entries'],
        '--max-entries',
        StratumRemoteTheme.defaultMaxEntries,
      ),
    );
  }

  static int _cap(String? text, String option, int fallback) {
    if (text == null) return fallback;
    final value = int.tryParse(text);
    if (value == null || value <= 0) {
      throw _UsageError('$option needs a whole number above 0');
    }
    return value;
  }

  /// `pack` when true, `check` when false.
  final bool pack;

  /// The folder to pack or the zip file to check, as given.
  final String target;
  final String? id;
  final String? appDefault;
  final String? outFolder;
  final int maxBytes;
  final int maxEntries;
}

/// The default theme files a check reads the zip over.
typedef _Defaults = ({
  String packagePath,
  StratumThemeSource package,
  String? appPath,
  StratumThemeSource? app,
});

/// One run of a parsed command.
final class _Run {
  new(
    this._command, {
    required StringSink err,
    required String workingDirectory,
    required String? packageRoot,
  }) : _err = err,
       _cwd = workingDirectory,
       _packageRoot = packageRoot;

  final _Command _command;
  final StringSink _err;
  final String _cwd;
  final String? _packageRoot;

  /// FR-01: reads the folder and the defaults, takes the id, collects the
  /// files, builds the zip, checks the built bytes, and writes
  /// `<out>/<id>.zip` only once the check passes. Returns the checksum, or
  /// null after a failure it printed; throws [_NoInput] for an input it
  /// cannot read.
  Future<String?> pack() async {
    final folder = _resolve(_command.target);
    if (!FileSystemEntity.isDirectorySync(folder)) {
      throw _NoInput(
        'cannot read the folder ${_shown(_command.target)}: no such folder',
      );
    }
    final defaults = _readDefaults();
    final outName = _command.outFolder ?? '.';
    final outFolder = _resolve(outName);
    if (!FileSystemEntity.isDirectorySync(outFolder)) {
      throw _NoInput('cannot write to ${_shown(outName)}: no such folder');
    }
    final id = _command.id ?? p.basename(folder);
    try {
      checkRemoteThemeId(id);
    } on RemoteThemeFailure catch (failure) {
      _err.writeln('${failure.code.key}: ${failure.message}');
      return null;
    }
    final Map<String, List<int>> files;
    try {
      files = _collect(folder);
    } on _Unsafe catch (unsafe) {
      _err.writeln(
        '${StratumRemoteThemeErrorCode.unsafeEntryPath.key}: '
        '${unsafe.message}',
      );
      return null;
    }
    final bytes = writeRemoteZip(files);
    final checksum = _checksumOf(bytes);
    if (!await _check(id, bytes, checksum, defaults)) return null;
    _write(p.join(outFolder, '$id.zip'), bytes);
    return checksum;
  }

  /// FR-02: reads the zip file and the defaults and checks the zip; returns
  /// its checksum, or null after a failure it printed.
  Future<String?> check() async {
    final file = _resolve(_command.target);
    final Uint8List bytes;
    try {
      bytes = File(file).readAsBytesSync();
    } on FileSystemException catch (error) {
      throw _NoInput(
        'cannot read ${_shown(_command.target)}: ${error.message}',
      );
    }
    final defaults = _readDefaults();
    final id = _command.id ?? p.basenameWithoutExtension(file);
    final checksum = _checksumOf(bytes);
    return await _check(id, bytes, checksum, defaults) ? checksum : null;
  }

  /// The package default, and the app default: `--app-default`, else the
  /// app project's `assets/themes/default/theme.yaml` when it holds one
  /// (FR-02 E01 to E03), with the ids and folders the controller gives
  /// them.
  _Defaults _readDefaults() {
    final root = _packageRoot;
    if (root == null) {
      throw const _NoInput('cannot find the stratum_ui package');
    }
    final packagePath = p.join(
      root,
      'assets',
      'themes',
      'default',
      'theme.yaml',
    );
    final named = _command.appDefault;
    final appPath = named == null
        ? p.join(_cwd, 'assets', 'themes', 'default', 'theme.yaml')
        : _resolve(named);
    final readApp = named != null || FileSystemEntity.isFileSync(appPath);
    return (
      packagePath: packagePath,
      package: StratumThemeSource(
        id: 'stratum-default',
        folder: 'packages/stratum_ui/assets/themes/default',
        yaml: _readText(packagePath, packagePath),
      ),
      appPath: readApp ? appPath : null,
      app: readApp
          ? StratumThemeSource(
              id: 'default',
              folder: 'assets/themes/default',
              yaml: _readText(appPath, named ?? appPath),
            )
          : null,
    );
  }

  /// Prints the defaults line, runs the app's install check on [bytes] as
  /// theme [id] with [checksum] and the caps, the stages inline with the
  /// generated Google family list (plan D-j), and prints the warnings or
  /// the problems; true when the check passed.
  Future<bool> _check(
    String id,
    Uint8List bytes,
    String checksum,
    _Defaults defaults,
  ) async {
    _err.writeln(
      cliDefaultsLine(
        packageDefault: defaults.packagePath,
        appDefault: defaults.appPath,
      ),
    );
    try {
      final result = await checkRemoteInstall(
        StratumRemoteTheme(
          id: id,
          bytes: bytes,
          checksum: checksum,
          maxBytes: _command.maxBytes,
          maxEntries: _command.maxEntries,
        ),
        packageDefault: defaults.package,
        appDefault: defaults.app,
        parseValues: (base, layers) async => parseThemeValues(
          base: base,
          layers: layers,
          googleFontExists: googleFontNames.contains,
        ),
        nextGeneration: () => 1,
      );
      cliWarnings(result).forEach(_err.writeln);
      return true;
    } on StratumRemoteThemeException catch (error) {
      cliProblemLines(error).forEach(_err.writeln);
      return false;
    }
  }

  String _resolve(String path) =>
      p.normalize(p.isAbsolute(path) ? path : p.join(_cwd, path));

  String _readText(String path, String shown) {
    try {
      return File(path).readAsStringSync();
    } on FileSystemException catch (error) {
      throw _NoInput('cannot read ${_shown(shown)}: ${error.message}');
    }
  }

  /// Writes [bytes] to [path] through a temporary file in the same folder,
  /// so a failed write leaves no partial zip and an earlier zip stays whole
  /// until the new one replaces it (plan D-l).
  void _write(String path, Uint8List bytes) {
    final temporary = File('$path.$pid.tmp');
    try {
      temporary
        ..writeAsBytesSync(bytes, flush: true)
        ..renameSync(path);
    } on FileSystemException catch (error) {
      if (temporary.existsSync()) temporary.deleteSync();
      throw _NoInput('cannot write ${_shown(path)}: ${error.message}');
    }
  }

  /// Every file under [root] by its path below it, `/` between segments,
  /// leaving out each name that starts with `.` and each `__MACOSX` folder
  /// with everything under them (FR-01 E02); throws [_Unsafe] naming the
  /// first symbolic link or other entry that is neither a file nor a
  /// folder (FR-01 E03, plan D-d), never reading it, and [_NoInput] for a
  /// folder or file it cannot read.
  static Map<String, List<int>> _collect(String root) {
    final files = <String, List<int>>{};
    void walk(String folder, String prefix) {
      for (final child in Directory(folder).listSync(followLinks: false)) {
        final name = p.basename(child.path);
        final type = FileSystemEntity.typeSync(child.path, followLinks: false);
        final isFolder = type == FileSystemEntityType.directory;
        if (name.startsWith('.') || (isFolder && name == '__MACOSX')) continue;
        final relative = prefix.isEmpty ? name : '$prefix/$name';
        if (isFolder) {
          walk(child.path, relative);
        } else if (type == FileSystemEntityType.file) {
          files[relative] = File(child.path).readAsBytesSync();
        } else {
          final kind = type == FileSystemEntityType.link
              ? 'a symbolic link'
              : 'neither a file nor a folder';
          throw _Unsafe(
            '"${escapeZipText(relative)}" is $kind, which the app install '
            'refuses as a zip entry',
          );
        }
      }
    }

    try {
      walk(root, '');
    } on FileSystemException catch (error) {
      throw _NoInput(
        'cannot read ${_shown(error.path ?? root)}: ${error.message}',
      );
    }
    return files;
  }

  /// [path] as a message shows it, escaped by the shared rule (plan D-g).
  static String _shown(String path) => '"${escapeZipText(path)}"';

  static String _checksumOf(List<int> bytes) =>
      'sha256:${crypto.sha256.convert(bytes)}';
}

/// A usage error (exit 64).
final class _UsageError implements Exception {
  const new(this.message);
  final String message;
}

/// An input that cannot be read or an output that cannot be written (exit
/// 66).
final class _NoInput implements Exception {
  const new(this.message);
  final String message;
}

/// A packed folder entry the app install would refuse (exit 1).
final class _Unsafe implements Exception {
  const new(this.message);
  final String message;
}
