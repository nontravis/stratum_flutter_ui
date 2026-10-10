@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stratum_ui/src/themes/remote/remote_zip_writer.dart';

import '../../bin/stratum_theme.dart';

const _schema = r'$schema: stratum-theme/v1.0.0';
const _svg = '<svg xmlns="http://www.w3.org/2000/svg" width="4" height="4"/>';

/// Whether this process runs as root, which ignores a folder's own write
/// permission bit (fix-2 n1).
bool get _isRoot =>
    Process.runSync('id', ['-u']).stdout.toString().trim() == '0';

/// The app project of one test: a fresh temporary folder.
late Directory _app;

/// One run's exit status, standard output, and standard error lines.
typedef _Result = ({int code, String out, List<String> err});

Future<_Result> _run(List<String> args) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await runStratumTheme(
    args,
    out: out,
    err: err,
    workingDirectory: _app.path,
    packageRoot: Directory.current.path,
  );
  return (
    code: code,
    out: out.toString(),
    err: const LineSplitter().convert(err.toString()),
  );
}

/// Writes [files], path to text, under [folder] of the app project, and
/// returns the folder's path; an empty [files] makes an empty folder.
String _folder(String folder, Map<String, String> files) {
  final root = p.join(_app.path, folder);
  Directory(root).createSync(recursive: true);
  for (final MapEntry(:key, :value) in files.entries) {
    File(p.join(root, key))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(value);
  }
  return root;
}

/// A theme folder whose theme file names `images/logo.svg`, which it holds.
Map<String, String> _theme([String body = '']) => {
  'theme.yaml': '$_schema\nassets:\n  loading: images/logo.svg\n$body',
  'images/logo.svg': _svg,
};

/// Writes the app project's `pubspec.yaml` with [assets] as its
/// `flutter: assets:` items.
void _pubspec(List<String> assets) {
  File(p.join(_app.path, 'pubspec.yaml')).writeAsStringSync(
    'name: app\nflutter:\n  assets:\n'
    '${[for (final asset in assets) '    - $asset\n'].join()}',
  );
}

/// [files], path to text, as a zip at [name] in the app project.
String _zip(String name, Map<String, String> files) {
  final path = p.join(_app.path, name);
  File(path).writeAsBytesSync(
    writeRemoteZip({
      for (final MapEntry(:key, :value) in files.entries)
        key: utf8.encode(value),
    }),
  );
  return path;
}

String _sha(List<int> bytes) => 'sha256:${crypto.sha256.convert(bytes)}';

final _printable = RegExp(r'^[\x20-\x7e]*$');

void main() {
  setUp(() => _app = Directory.systemTemp.createTempSync('stratum_theme_'));
  tearDown(() => _app.deleteSync(recursive: true));

  group('us02/fr01: pack', () {
    test('us02/s1, us02/fr01, r9: pack writes <id>.zip in the working '
        'folder and prints its checksum alone', () async {
      _folder('brand', _theme());

      final run = await _run(['pack', 'brand']);
      final zip = File(p.join(_app.path, 'brand.zip')).readAsBytesSync();

      expect(run.code, exitPass);
      expect(run.out, '${_sha(zip)}\n');
      expect(run.err.first, startsWith('defaults: '));
      expect(run.err.first, isNot(contains('(app)')));
    });

    test('us02/s2, us02/fr01/e05: the same folder packs to the same bytes, '
        'whatever the file times or creation order', () async {
      _folder('brand', _theme());
      await _run(['pack', 'brand', '--out', _folder('one', {})]);
      File(p.join(_app.path, 'brand', 'images', 'logo.svg'))
          .setLastModifiedSync(DateTime(2001));
      final theme = File(p.join(_app.path, 'brand', 'theme.yaml'));
      final text = theme.readAsStringSync();
      theme
        ..deleteSync()
        ..writeAsStringSync(text);

      final second = await _run(['pack', 'brand', '--out', _folder('two', {})]);

      expect(second.code, exitPass);
      expect(
        File(p.join(_app.path, 'two', 'brand.zip')).readAsBytesSync(),
        File(p.join(_app.path, 'one', 'brand.zip')).readAsBytesSync(),
      );
    });

    test(
      'us02/s4, us02/fr01/e02: hidden names and __MACOSX stay out',
      () async {
        _folder('brand', {
          ..._theme(),
          '.DS_Store': 'x',
          '.git/config': 'x',
          '__MACOSX/._logo.svg': 'x',
          'images/.hidden.png': 'x',
        });

        final run = await _run(['pack', 'brand']);

        expect(run.code, exitPass);
        expect(
          File(p.join(_app.path, 'brand.zip')).readAsBytesSync(),
          writeRemoteZip({
            for (final MapEntry(:key, :value) in _theme().entries)
              key: utf8.encode(value),
          }),
        );
      },
    );

    test('us02/s5, us02/fr01/e04, us02/fr03/e04, us02/fr03/e05: a file the '
        'theme does not name ships and is a warning, and stdout holds the '
        'checksum alone', () async {
      _folder('brand', {..._theme(), 'anim/data.json': '{}'});

      final run = await _run(['pack', 'brand']);

      expect(run.code, exitPass);
      expect(
        run.out,
        '${_sha(File(p.join(_app.path, 'brand.zip')).readAsBytesSync())}\n',
      );
      expect(
        run.err,
        contains(
          'warning: "anim/data.json" is in the zip, but the theme file does '
          'not name it',
        ),
      );
    });

    test('us02/s8, us02/fr01/e06, us02/fr03/e03: theme problems fail the '
        'pack, one line each, and nothing is written', () async {
      _folder('brand', _theme('space:\n  a: 1\nradius:\n  b: 2'));

      final run = await _run(['pack', 'brand']);

      expect(run.code, exitFailed);
      expect(run.out, isEmpty);
      expect(
        run.err.where((line) => line.startsWith('theme_format: brand@1:')),
        hasLength(2),
      );
      expect(File(p.join(_app.path, 'brand.zip')).existsSync(), isFalse);
    });

    test('us02/s10, us02/fr01/e01, us02/fr03/e14: a folder named default fails '
        'as invalid_id before the check, and nothing is written', () async {
      _folder('default', _theme());

      final run = await _run(['pack', 'default']);

      expect(run.code, exitFailed);
      expect(run.out, isEmpty);
      expect(run.err.single, startsWith('invalid_id: '));
      expect(File(p.join(_app.path, 'default.zip')).existsSync(), isFalse);
    });

    test('us02/fr01/e01: a folder name with a character outside the id rule '
        'fails as invalid_id, and nothing is written', () async {
      _folder('Brand', _theme());

      final run = await _run(['pack', 'Brand']);

      expect(run.code, exitFailed);
      expect(run.out, isEmpty);
      expect(run.err.single, startsWith('invalid_id: '));
      expect(File(p.join(_app.path, 'Brand.zip')).existsSync(), isFalse);
    });

    test('us02/s11, us02/fr01/e03, us02/fr03, r10: a symbolic link fails as '
        'unsafe_entry_path naming it, with exit 1', () async {
      final root = _folder('brand', _theme());
      Link(p.join(root, 'images', 'link.svg'))
          .createSync(p.join(root, 'images', 'logo.svg'));

      final run = await _run(['pack', 'brand']);

      const tail =
          'is a symbolic link, which the app install refuses as a zip entry';
      expect(run.code, exitFailed);
      expect(run.out, isEmpty);
      expect(run.err, ['unsafe_entry_path: "images/link.svg" $tail']);
      expect(File(p.join(_app.path, 'brand.zip')).existsSync(), isFalse);
    });

    test('review focus 2: a hidden link and a link inside __MACOSX are left '
        'out', () async {
      final root = _folder('brand', _theme());
      Link(p.join(root, '.link')).createSync(p.join(root, 'theme.yaml'));
      Directory(p.join(root, '__MACOSX')).createSync();
      Link(p.join(root, '__MACOSX', 'l'))
          .createSync(p.join(root, 'theme.yaml'));

      expect((await _run(['pack', 'brand'])).code, exitPass);
    });

    test(
      'us02/fr01/e03, review focus 3, d-d: a FIFO is refused unread',
      () async {
        final root = _folder('brand', _theme());
        Process.runSync('mkfifo', [p.join(root, 'images', 'pipe')]);

        final run = await _run(['pack', 'brand']);

        expect(run.code, exitFailed);
        expect(
          run.err.single,
          startsWith(
            'unsafe_entry_path: "images/pipe" is neither a file nor a folder',
          ),
        );
      },
      skip: Platform.isWindows ? 'no FIFO on Windows' : false,
    );

    test('review focus 4, d-l: a failing pack leaves an earlier zip whole; '
        'a passing pack replaces it', () async {
      _folder('brand', _theme());
      await _run(['pack', 'brand']);
      final zip = File(p.join(_app.path, 'brand.zip'));
      final first = zip.readAsBytesSync();

      _folder('brand', _theme('space:\n  a: 1'));
      expect((await _run(['pack', 'brand'])).code, exitFailed);
      expect(zip.readAsBytesSync(), first);

      _folder('brand', _theme('name: Brand'));
      expect((await _run(['pack', 'brand'])).code, exitPass);
      expect(zip.readAsBytesSync(), isNot(first));
      expect(
        _app.listSync().map((entity) => p.basename(entity.path)),
        isNot(contains(startsWith('.stratum_theme_'))),
      );
    });

    test('us02/fr03/e11, d-l: a write that fails after the check exits 66, '
        'leaves no partial file, and prints no checksum', () async {
      _folder('brand', _theme());
      Directory(p.join(_app.path, 'brand.zip')).createSync();

      final run = await _run(['pack', 'brand']);

      expect(run.code, exitNoInput);
      expect(run.out, isEmpty);
      expect(run.err.last, startsWith('cannot write '));
      expect(
        FileSystemEntity.isDirectorySync(p.join(_app.path, 'brand.zip')),
        isTrue,
      );
      expect(
        _app.listSync().map((entity) => p.basename(entity.path)),
        isNot(contains(startsWith('.stratum_theme_'))),
      );
    });

    test('us02/fr01/e07, us02/fr02/e06: --max-entries below the entry count '
        'fails as archive_too_large', () async {
      _folder('brand', _theme());

      final run = await _run(['pack', 'brand', '--max-entries', '1']);

      expect(run.code, exitFailed);
      expect(run.err.last, startsWith('archive_too_large: '));
    });

    test('r9, us02/fr03/e10, d-l: --out names the folder, and an --out '
        'that is not a folder exits 66 before any check', () async {
      _folder('brand', _theme());
      _folder('out', {});

      expect((await _run(['pack', 'brand', '--out', 'out'])).code, exitPass);
      expect(File(p.join(_app.path, 'out', 'brand.zip')).existsSync(), isTrue);
      final missing = await _run(['pack', 'brand', '--out', 'nowhere']);
      expect(missing.code, exitNoInput);
      expect(missing.err.single, startsWith('cannot write to "nowhere"'));
    });

    for (final (label, files) in [
      ('an empty folder', <String, String>{}),
      ('a folder holding only hidden names', {'.DS_Store': 'x'}),
    ]) {
      test('fix-1 edge critical: pack of $label fails as invalid_archive, '
          'with no stack trace', () async {
        _folder('brand', files);

        final run = await _run(['pack', 'brand']);

        expect(run.code, exitFailed);
        expect(run.out, isEmpty);
        expect(run.err, contains('invalid_archive: the zip is empty'));
        expect(File(p.join(_app.path, 'brand.zip')).existsSync(), isFalse);
      });
    }

    test(
      'us02/fr01/e10, us02/fr03/e14, r14, fix-1 sec f2: a POSIX file name '
      'holding a backslash fails as '
      'unsafe_entry_path from the writer, not left as a stack trace',
      () async {
        final root = _folder('brand', _theme());
        File(p.join(root, 'images', r'a\b.svg')).writeAsStringSync(_svg);

        final run = await _run(['pack', 'brand']);

        expect(run.code, exitFailed);
        expect(run.out, isEmpty);
        expect(
          run.err.single,
          r'unsafe_entry_path: entry "images/a\u005cb.svg" is no canonical '
          'relative path',
        );
      },
      skip: Platform.isWindows
          ? 'no backslash in a POSIX file name on Windows'
          : false,
    );

    test('edge i1, us02/fr01/e10, rz2 (c-2): a POSIX file name holding a '
        'control character fails as unsafe_entry_path with the '
        'printable-ASCII message, not left as a stack trace', () async {
      final root = _folder('brand', _theme());
      File(p.join(root, 'images', 'a\u0001b.svg')).writeAsStringSync(_svg);

      final run = await _run(['pack', 'brand']);

      expect(run.code, exitFailed);
      expect(run.out, isEmpty);
      expect(
        run.err.single,
        r'unsafe_entry_path: entry "images/a\u0001b.svg" holds a '
        'character outside printable ASCII, U+0020 to U+007E',
      );
    });

    test(
      'us02/fr01/e09, r14, fix-1 edge important: --out the same folder being '
      'packed excludes its own last zip, so repeated packs give the same '
      'bytes',
      () async {
        _folder('brand', _theme());

        final first = await _run(['pack', 'brand', '--out', 'brand']);
        final second = await _run(['pack', 'brand', '--out', 'brand']);

        expect(first.code, exitPass);
        expect(second.code, exitPass);
        expect(second.out, first.out);
        expect(
          File(p.join(_app.path, 'brand', 'brand.zip')).readAsBytesSync(),
          writeRemoteZip({
            for (final MapEntry(:key, :value) in _theme().entries)
              key: utf8.encode(value),
          }),
        );
      },
    );

    test('fix-1 sec f1: a planted link at the old predictable temp name is '
        'never opened, so the victim it points to is unchanged', () async {
      _folder('brand', _theme());
      final out = _folder('out', {});
      final victim = File(p.join(out, 'victim.txt'))
        ..writeAsStringSync('precious');
      Link(p.join(out, 'brand.zip.$pid.tmp')).createSync(victim.path);

      final run = await _run(['pack', 'brand', '--out', 'out']);

      expect(run.code, exitPass);
      expect(victim.readAsStringSync(), 'precious');
      expect(
        Directory(out)
            .listSync()
            .map((entity) => p.basename(entity.path))
            .where((name) => name.startsWith('.stratum_theme_')),
        isEmpty,
      );
    });

    test(
      'fix-2 n1: an unwritable --out exits 66, not an unhandled exception',
      () async {
        _folder('brand', _theme());
        final out = _folder('ro', {});
        Process.runSync('chmod', ['0555', out]);
        addTearDown(() => Process.runSync('chmod', ['0755', out]));

        final run = await _run(['pack', 'brand', '--out', 'ro']);

        expect(run.code, exitNoInput);
        expect(run.out, isEmpty);
        expect(run.err.last, startsWith('cannot write '));
        expect(
          Directory(out)
              .listSync()
              .map((entity) => p.basename(entity.path))
              .where((name) => name.startsWith('.stratum_theme_')),
          isEmpty,
        );
      },
      skip: Platform.isWindows || _isRoot
          ? 'needs a non-root POSIX --out owner'
          : false,
    );

    test('coverage: a folder path holding a space and a non-ASCII letter '
        'packs normally', () async {
      _folder('bra nd é', _theme());

      final run = await _run(['pack', 'bra nd é', '--id', 'brand']);

      expect(run.code, exitPass);
      expect(File(p.join(_app.path, 'brand.zip')).existsSync(), isTrue);
    });

    for (final (label, file) in [
      ('a file name', 'images/é.png'),
      ('a folder name', 'imagés/logo.png'),
    ]) {
      test('us02/fr01/e10, us02/fr03/e14, rz2: $label outside printable '
          'ASCII fails the pack with one unsafe_entry_path line, no '
          'defaults line, and no zip', () async {
        _folder('brand', {..._theme(), file: _svg});

        final run = await _run(['pack', 'brand']);

        expect(run.code, exitFailed);
        expect(run.out, isEmpty);
        expect(run.err, hasLength(1));
        expect(run.err.single, startsWith('unsafe_entry_path: entry "'));
        expect(run.err.single, contains('outside printable ASCII'));
        expect(File(p.join(_app.path, 'brand.zip')).existsSync(), isFalse);
      });
    }

    for (final (label, file, why) in [
      (
        'a file name ending in a dot',
        'images/logo.svg.',
        'ending in a dot or a space',
      ),
      (
        'a file name ending in a space',
        'images/logo.svg ',
        'ending in a dot or a space',
      ),
      (
        'a file name holding a colon',
        'images/a:b.svg',
        'which no Windows name holds',
      ),
      (
        'a file name holding "?"',
        'images/a?b.svg',
        'which no Windows name holds',
      ),
      ('a reserved device name', 'images/CON.svg', 'names the device CON'),
      (
        'a folder named after a reserved device',
        'aux/logo.svg',
        'names the device AUX',
      ),
      (
        'a file name matching a console device with trailing spaces',
        'images/CON .svg',
        'names the device CON',
      ),
      (
        'a file name holding a short-name marker',
        'images/icon~2.svg',
        'holding "~" before a digit',
      ),
    ]) {
      test(
        'us02/fr01/e10, us02/fr03/e14, rzf3, rzf9: $label fails the pack '
        'with one unsafe_entry_path line, no defaults line, and no zip',
        () async {
          _folder('brand', {..._theme(), file: _svg});

          final run = await _run(['pack', 'brand']);

          expect(run.code, exitFailed);
          expect(run.out, isEmpty);
          expect(run.err, hasLength(1));
          expect(run.err.single, startsWith('unsafe_entry_path: entry "'));
          expect(run.err.single, contains(why));
          expect(File(p.join(_app.path, 'brand.zip')).existsSync(), isFalse);
        },
        skip: Platform.isWindows ? 'no such file name on Windows' : false,
      );
    }

    test('us02/fr01/e10, us02/fr03/e14, rz2: a folder holding an emoji '
        'name and a DEL (0x7F) name fails the pack with one '
        'unsafe_entry_path line naming the first offending path, before '
        'any write', () async {
      const emoji = 'images/😀.png';
      const del = 'images/a\u007Fb.png';
      try {
        _folder('brand', {..._theme(), emoji: _svg, del: _svg});
      } on FileSystemException {
        // This file system refuses to create a file name holding an
        // emoji or a DEL byte; nothing to pin here.
        markTestSkipped('no emoji or DEL file name on this file system');
        return;
      }

      final run = await _run(['pack', 'brand']);

      expect(run.code, exitFailed);
      expect(run.out, isEmpty);
      expect(run.err, hasLength(1));
      expect(run.err.single, startsWith('unsafe_entry_path: entry "'));
      expect(run.err.single, contains('outside printable ASCII'));
      expect(
        run.err.single,
        anyOf(
          contains(r'images/\ud83d\ude00.png'),
          contains(r'images/a\u007fb.png'),
        ),
      );
      expect(File(p.join(_app.path, 'brand.zip')).existsSync(), isFalse);
    });

    test('coverage: on-disk case twins warn, through the real walk, not only '
        'the writer', () async {
      final root = _folder('brand', _theme());
      File(p.join(root, 'A.svg')).writeAsStringSync(_svg);
      File(p.join(root, 'a.svg')).writeAsStringSync(_svg);
      final twins = Directory(root)
          .listSync()
          .where((entity) => p.basename(entity.path).toLowerCase() == 'a.svg');
      if (twins.length < 2) return;

      final run = await _run(['pack', 'brand']);

      expect(run.code, exitPass);
      expect(
        run.err,
        contains('warning: "A.svg" and "a.svg" differ only in letter case'),
      );
    });
  });

  group('us02/fr02: check', () {
    test('us02/s3, us02/fr02/e05: check passes a zip the app installs and '
        'prints its checksum alone', () async {
      _folder('brand', _theme());
      await _run(['pack', 'brand']);

      final run = await _run(['check', 'brand.zip']);

      expect(run.code, exitPass);
      expect(
        run.out,
        '${_sha(File(p.join(_app.path, 'brand.zip')).readAsBytesSync())}\n',
      );
    });

    test('us02/s9, us02/fr02/e04, us02/fr03/e08: a zip that lacks a named '
        'file fails as missing_entry and prints no checksum', () async {
      _zip('brand.zip', {'theme.yaml': _theme()['theme.yaml']!});

      final run = await _run(['check', 'brand.zip']);

      expect(run.code, exitFailed);
      expect(run.out, isEmpty);
      expect(
        run.err.last,
        'missing_entry: the theme file names '
        '"images/logo.svg", which the zip lacks',
      );
    });

    test("us02/s7, us02/fr02/e01, r13: the app project's listed default "
        'theme is read too, and the defaults line names both', () async {
      _folder('assets/themes/default', {
        'theme.yaml': '$_schema\nspace:\n  nope: 4',
      });
      _pubspec(['assets/themes/default/']);
      _zip('brand.zip', _theme());

      final run = await _run(['check', 'brand.zip']);

      expect(run.code, exitFailed);
      expect(run.err.first, contains('(app)'));
      expect(run.err, contains(startsWith('theme_format: default:')));
    });

    test('us02/fr02/e03: --app-default names a file in place of the '
        "project's", () async {
      _folder('assets/themes/default', {
        'theme.yaml': '$_schema\nspace:\n  nope: 4',
      });
      final good = _folder('elsewhere', {'theme.yaml': _schema});
      _zip('brand.zip', _theme());

      final run = await _run([
        'check',
        'brand.zip',
        '--app-default',
        p.join(good, 'theme.yaml'),
      ]);

      expect(run.code, exitPass);
      expect(run.err.first, contains(p.join(good, 'theme.yaml')));
    });

    test('us02/fr02/e02: a project with no default theme is read over the '
        'package default only', () async {
      _zip('brand.zip', _theme());

      final run = await _run(['check', 'brand.zip']);

      expect(run.code, exitPass);
      expect(run.err.first, endsWith('(package)'));
    });

    test('us02/fr02/e01, r13: a file item of flutter: assets: lists the app '
        'default too', () async {
      _folder('assets/themes/default', {
        'theme.yaml': '$_schema\nspace:\n  nope: 4',
      });
      _pubspec(['assets/themes/default/theme.yaml']);
      _zip('brand.zip', _theme());

      final run = await _run(['check', 'brand.zip']);

      expect(run.code, exitFailed);
      expect(run.err.first, contains('(app)'));
      expect(run.err, isNot(contains(appDefaultUnlistedWarning)));
    });

    for (final (label, assets) in [
      ('a parent folder item', ['assets/themes/']),
      ('no item', <String>[]),
    ]) {
      test('us02/s13, us02/fr02/e10, us02/fr03/e12, r13: an app default '
          'under $label is not read, and a warning follows the defaults '
          'line', () async {
        _folder('assets/themes/default', {
          'theme.yaml': '$_schema\nspace:\n  nope: 4',
        });
        _pubspec(assets);
        _zip('brand.zip', _theme());

        final run = await _run(['check', 'brand.zip']);

        expect(run.code, exitPass);
        expect(run.err.first, endsWith('(package)'));
        expect(run.err[1], appDefaultUnlistedWarning);
      });
    }

    test('us02/fr02/e10, us02/fr03/e12, r13: a project with no pubspec.yaml '
        'lists nothing, and the warning prints on a failing check '
        'too', () async {
      _folder('assets/themes/default', {'theme.yaml': _schema});
      _zip('brand.zip', {'theme.yaml': _theme()['theme.yaml']!});

      final run = await _run(['check', 'brand.zip']);

      expect(run.code, exitFailed);
      expect(run.err.first, endsWith('(package)'));
      expect(run.err[1], appDefaultUnlistedWarning);
      expect(run.err.last, startsWith('missing_entry: '));
    });

    for (final (label, makePubspec) in [
      (
        'not yaml',
        () =>
            File(p.join(_app.path, 'pubspec.yaml'))
                .writeAsStringSync('flutter: [\n'),
      ),
      (
        'a folder',
        () => Directory(p.join(_app.path, 'pubspec.yaml')).createSync(),
      ),
    ]) {
      test('us02/fr03/e09, r13: a pubspec.yaml that is $label exits 66 when '
          'the project holds its own default theme', () async {
        _folder('assets/themes/default', {'theme.yaml': _schema});
        makePubspec();
        _zip('brand.zip', _theme());

        final run = await _run(['check', 'brand.zip']);

        expect(run.code, exitNoInput);
        expect(run.out, isEmpty);
        expect(run.err.last, startsWith('cannot read "pubspec.yaml"'));
      });
    }

    test('us02/fr03/e09, fix-a minor3: a pubspec.yaml holding a yaml syntax '
        'error names the line and column', () async {
      _folder('assets/themes/default', {'theme.yaml': _schema});
      File(p.join(_app.path, 'pubspec.yaml')).writeAsStringSync('a: 1\nb: [\n');
      _zip('brand.zip', _theme());

      final run = await _run(['check', 'brand.zip']);

      expect(run.code, exitNoInput);
      expect(run.out, isEmpty);
      expect(
        run.err.last,
        'cannot read "pubspec.yaml":3:1: Expected node content.',
      );
    });

    for (final (label, body) in [
      ('a malformed percent escape in a tag', 'x: !<%ZZ> y'),
      ('a percent escape that decodes to invalid utf-8', 'x: !<%FF> y'),
    ]) {
      test('sec f1, us02/fr03/e09: a pubspec.yaml holding $label exits 66, '
          'not an unhandled exception', () async {
        _folder('assets/themes/default', {'theme.yaml': _schema});
        File(p.join(_app.path, 'pubspec.yaml')).writeAsStringSync(body);
        _zip('brand.zip', _theme());

        final run = await _run(['check', 'brand.zip']);

        expect(run.code, exitNoInput);
        expect(run.out, isEmpty);
        expect(run.err.last, startsWith('cannot read "pubspec.yaml"'));
        expect(run.err, isNot(contains(contains('Unhandled exception'))));
      });
    }

    test('sec f1, us02/fr03/e09: a pubspec.yaml whose tag forges a control '
        'sequence exits 66 with printable-only stderr', () async {
      _folder('assets/themes/default', {'theme.yaml': _schema});
      File(p.join(_app.path, 'pubspec.yaml'))
          .writeAsStringSync('x: !!foo%1B%5D0%3Bpwned%07 y');
      _zip('brand.zip', _theme());

      final run = await _run(['check', 'brand.zip']);

      expect(run.code, exitNoInput);
      expect(run.out, isEmpty);
      expect(run.err.last, startsWith('cannot read "pubspec.yaml"'));
      for (final line in run.err) {
        expect(line, matches(_printable));
      }
    });

    group('r16 (t25), rz1: hostile pubspec.yaml files', () {
      setUp(() {
        _folder('assets/themes/default', {'theme.yaml': _schema});
        _zip('brand.zip', _theme());
      });

      String pubspecPath() => p.join(_app.path, 'pubspec.yaml');

      test('us02/fr03/e09: flow nesting 100,000 deep exits 66 at line 1, '
          'column 65', () async {
        File(pubspecPath()).writeAsStringSync('[' * 100000);

        final run = await _run(['check', 'brand.zip']);

        expect(run.code, exitNoInput);
        expect(run.out, isEmpty);
        expect(
          run.err.last,
          'cannot read "pubspec.yaml":1:65: nesting deeper than 64',
        );
      });

      test('us02/fr03/e09: a mapping key built from aliases 40 deep exits 66 '
          'at its first anchor', () async {
        File(pubspecPath()).writeAsStringSync(
          [
            'a0: &a0 [x, x]',
            for (var d = 1; d <= 40; d++) 'a$d: &a$d [*a${d - 1}, *a${d - 1}]',
            '? *a40',
            ': v',
          ].join('\n'),
        );

        final run = await _run(['check', 'brand.zip']);

        expect(run.code, exitNoInput);
        expect(
          run.err.last,
          'cannot read "pubspec.yaml":1:5: no anchor, alias, or tag; refer '
          'to a token with "{path}" instead',
        );
      });

      test('us02/fr03/e09: a 200 MB pubspec.yaml exits 66 after reading at '
          'most 1,048,577 bytes', () async {
        File(pubspecPath()).openSync(mode: FileMode.write)
          ..truncateSync(200 * 1024 * 1024)
          ..closeSync();

        final run = await _run(['check', 'brand.zip']);

        expect(run.code, exitNoInput);
        expect(
          run.err.last,
          'cannot read "pubspec.yaml": text longer than 1 MiB',
        );
      });

      String padded(int bytes) {
        const head =
            'name: app\nflutter:\n  assets:\n    - assets/themes/default/\n';
        return '$head#${'x' * (bytes - head.length - 2)}\n';
      }

      test('us02/fr03/e09, g1: bytes past 1 MiB that are not valid utf-8 '
          'still exit 66 by length, never decoded', () async {
        File(pubspecPath()).writeAsBytesSync([
          ...utf8.encode(padded(1048576)),
          ...List.filled(16, 0xFF),
        ]);

        final run = await _run(['check', 'brand.zip']);

        expect(run.code, exitNoInput);
        expect(
          run.err.last,
          'cannot read "pubspec.yaml": text longer than 1 MiB',
        );
      });

      test('us02/fr03/e09, g1: a pubspec.yaml of exactly 1,048,576 bytes is '
          'read, and one more byte exits 66', () async {
        File(pubspecPath()).writeAsStringSync(padded(1048576));
        final read = await _run(['check', 'brand.zip']);

        expect(read.code, exitPass);
        expect(read.err.first, contains('(app)'));

        File(pubspecPath()).writeAsStringSync(padded(1048577));
        final refused = await _run(['check', 'brand.zip']);

        expect(refused.code, exitNoInput);
        expect(
          refused.err.last,
          'cannot read "pubspec.yaml": text longer than 1 MiB',
        );
      });

      test('us02/fr03/e09: a pubspec.yaml under 1 MiB holding byte 0xe9 '
          'exits 66, not an unhandled exception', () async {
        File(pubspecPath()).writeAsBytesSync([
          ...utf8.encode('name: app\n# caf'),
          0xe9,
          ...utf8.encode('\n'),
        ]);

        final run = await _run(['check', 'brand.zip']);

        expect(run.code, exitNoInput);
        expect(run.out, isEmpty);
        expect(run.err.last, startsWith('cannot read "pubspec.yaml"'));
        expect(run.err, isNot(contains(contains('Unhandled exception'))));
        for (final line in run.err) {
          expect(line, matches(_printable));
        }
      });
    });

    test('sec f3, us02/fr03/e09: a pubspec.yaml that is a dangling symbolic '
        'link exits 66 when the project holds its own default theme', () async {
      _folder('assets/themes/default', {'theme.yaml': _schema});
      Link(p.join(_app.path, 'pubspec.yaml'))
          .createSync(p.join(_app.path, 'nowhere.yaml'));
      _zip('brand.zip', _theme());

      final run = await _run(['check', 'brand.zip']);

      expect(run.code, exitNoInput);
      expect(run.out, isEmpty);
      expect(run.err.last, startsWith('cannot read "pubspec.yaml"'));
    });

    test('r13: a project with no default theme never reads its '
        'pubspec.yaml', () async {
      File(p.join(_app.path, 'pubspec.yaml')).writeAsStringSync('flutter: [\n');
      _zip('brand.zip', _theme());

      final run = await _run(['check', 'brand.zip']);

      expect(run.code, exitPass);
      expect(run.err, isNot(contains(appDefaultUnlistedWarning)));
    });

    test('us02/s6, us02/fr02/e08, us02/fr03/e06: twin names pass with one '
        'warning per pair', () async {
      _zip('brand.zip', {..._theme(), 'images/Logo.svg': _svg});

      final run = await _run(['check', 'brand.zip']);

      expect(run.code, exitPass);
      expect(
        run.err,
        contains(
          'warning: "images/Logo.svg" and "images/logo.svg" differ only in '
          'letter case',
        ),
      );
    });

    test('us02/s14, us02/fr03/e13, r15: check warns on every entry the '
        'install never reads, and passes', () async {
      _zip('brand.zip', {
        for (final MapEntry(:key, :value) in _theme().entries)
          'brand/$key': value,
        'README.html': 'x',
        '__MACOSX/brand/._theme.yaml': 'x',
        'brand/.DS_Store': 'x',
      });

      final run = await _run(['check', 'brand.zip']);

      const unread = 'is in the zip, but the app install never reads it';
      expect(run.code, exitPass);
      expect(
        run.err,
        containsAllInOrder([
          'warning: "README.html" $unread',
          'warning: "__MACOSX/brand/._theme.yaml" $unread',
          'warning: "brand/.DS_Store" $unread',
        ]),
      );
    });

    test('us02/fr03/e02, fo01 us02/fr01/e05: a problem holding theme text '
        'prints escaped, with no raw control or non-ASCII byte', () async {
      _zip('brand.zip', {
        ..._theme(),
        'theme.yaml': '$_schema\nspace:\n  "md\\aไทย": 4',
      });

      final run = await _run(['check', 'brand.zip']);

      expect(run.code, exitFailed);
      expect(
        run.err,
        contains(
          contains(
            r'space.md\u0007\u0e44\u0e17\u0e22: unknown key '
            r'"md\u0007\u0e44\u0e17\u0e22" [unknown_key]',
          ),
        ),
      );
      for (final line in run.err.skip(1)) {
        expect(line, matches(_printable));
      }
    });

    test(
      'f1 (deferred minor 2), r9/fr03/e02: a theme.yaml holding an unknown '
      'directive, control character included, prints only the checksum',
      () async {
        final prints = <String>[];

        final run = await runZoned(
          () {
            _zip('brand.zip', {
              ..._theme(),
              'theme.yaml':
                  '%X \x1b]0;pwned\x07\n---\n${_theme()['theme.yaml']!}',
            });
            return _run(['check', 'brand.zip']);
          },
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) => prints.add(line),
          ),
        );

        expect(prints, isEmpty);
        expect(run.code, exitPass);
        expect(run.out, startsWith('sha256:'));
      },
    );

    test(
      'us02/fr03/e09, r14, fix-1 sec f4 (type half): check of a folder, not a '
      'file, exits '
      '66 before any read',
      () async {
        final folder = _folder('brand', {});

        final run = await _run(['check', folder]);

        expect(run.code, exitNoInput);
        expect(run.out, isEmpty);
      },
    );

    test(
      'us02/fr03/e09, r14, fix-1 sec f4 (type half): check of a FIFO exits 66 '
      'without blocking',
      () async {
        final fifo = p.join(_app.path, 'pipe');
        expect(Process.runSync('mkfifo', [fifo]).exitCode, 0);
        expect(FileSystemEntity.typeSync(fifo), FileSystemEntityType.pipe);

        final run = await _run(['check', fifo]);

        expect(run.code, exitNoInput);
        expect(run.out, isEmpty);
      },
      skip: Platform.isWindows ? 'no FIFO on Windows' : false,
    );

    test('us02/fr03/e09, r14, fix-5 sec f4 (type half, --app-default): a FIFO '
        '--app-default exits '
        '66 without blocking', () async {
      _zip('brand.zip', _theme());
      final fifo = p.join(_app.path, 'pipe');
      expect(Process.runSync('mkfifo', [fifo]).exitCode, 0);
      expect(FileSystemEntity.typeSync(fifo), FileSystemEntityType.pipe);

      final run = await _run(['check', 'brand.zip', '--app-default', fifo]);

      expect(run.code, exitNoInput);
      expect(run.out, isEmpty);
    }, skip: Platform.isWindows ? 'no FIFO on Windows' : false);
  });

  group('us02/fr03: usage errors and unreadable inputs', () {
    for (final (args, message) in [
      (<String>[], 'no command'),
      (['zip'], 'unknown command "zip"'),
      (['check'], 'no zip file'),
      (['check', 'a.zip', 'b.zip'], 'one zip file per run'),
      (['check', 'a.zip', '--out', 'x'], 'unknown option "--out" for check'),
      (['pack', 'brand', '--id'], '--id needs a value'),
      (['pack', 'brand', '--id', 'a', '--id', 'b'], '--id given twice'),
      (
        ['pack', 'brand', '--max-bytes', 'lots'],
        '--max-bytes needs a whole number above 0',
      ),
    ]) {
      test('us02/s12, us02/fr03/e01: "$message" exits 64, checks nothing, '
          'and writes nothing', () async {
        _folder('brand', _theme());

        final run = await _run(args);

        expect(run.code, exitUsage);
        expect(run.out, isEmpty);
        expect(run.err.first, 'usage error: $message');
        expect(_app.listSync().map((entity) => p.basename(entity.path)), [
          'brand',
        ]);
      });
    }

    test(
      'us02/fr03/e09: a missing folder, zip, or --app-default exits 66',
      () async {
        _zip('brand.zip', _theme());

        for (final args in [
          ['pack', 'nope'],
          ['check', 'nope.zip'],
          ['check', 'brand.zip', '--app-default', 'nope.yaml'],
        ]) {
          final run = await _run(args);

          expect(run.code, exitNoInput, reason: '$args');
          expect(run.out, isEmpty, reason: '$args');
        }
      },
    );

    test('us02/fr03/e09, r14: a stratum_ui package that cannot be found, or '
        'whose default theme cannot be read, exits 66', () async {
      _zip('brand.zip', _theme());
      final empty = _folder('nopackage', {});

      for (final root in [null, empty]) {
        final err = StringBuffer();
        final code = await runStratumTheme(
          ['check', 'brand.zip'],
          out: StringBuffer(),
          err: err,
          workingDirectory: _app.path,
          packageRoot: root,
        );

        expect(code, exitNoInput, reason: '$root');
        expect(err.toString(), startsWith('cannot '), reason: '$root');
      }
    });
  });
}
