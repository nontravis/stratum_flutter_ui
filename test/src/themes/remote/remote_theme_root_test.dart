import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_root.dart';

Matcher _missing(String cause) => throwsA(
  isA<RemoteThemeFailure>()
      .having(
        (f) => f.code,
        'code',
        StratumRemoteThemeErrorCode.missingThemeFile,
      )
      .having((f) => f.message, 'message', contains(cause)),
);

void main() {
  test('us01/s1: theme.yaml at the zip root is the root', () {
    expect(findThemeRoot(['theme.yaml', 'fonts/a.ttf']), '');
  });

  test('us01/s10, us01/fr02/e05: one top folder holding theme.yaml is the '
      'root, beside __MACOSX/ and .DS_Store', () {
    expect(
      findThemeRoot([
        'brand/',
        'brand/theme.yaml',
        'brand/fonts/a.ttf',
        '__MACOSX/brand/._theme.yaml',
        '.DS_Store',
        'brand/.DS_Store',
      ]),
      'brand/',
    );
  });

  test('us01/fr02/e03: no theme.yaml names the cause', () {
    expect(() => findThemeRoot(['fonts/a.ttf']), _missing('no theme.yaml'));
  });

  test('us01/fr02/e03: theme.yaml two folders deep names the cause', () {
    expect(
      () => findThemeRoot(['a/b/theme.yaml']),
      _missing('two or more folders deep: a/b/theme.yaml'),
    );
  });

  test('us01/fr02/e03: two top folders names the cause', () {
    expect(
      () => findThemeRoot(['a/theme.yaml', 'b/theme.yaml', 'x.txt']),
      _missing('two or more top folders: a, b'),
    );
  });

  test('us01/fr02/e05: a loose top file beside one top folder is ignored', () {
    expect(findThemeRoot(['README.md', 'brand/theme.yaml']), 'brand/');
  });

  test('M6: folder names and a deep path reach the message escaped', () {
    expect(
      () => findThemeRoot(['a\u001b/theme.yaml', 'b\n/theme.yaml']),
      throwsA(
        isA<RemoteThemeFailure>().having(
          (f) => f.message,
          'message',
          allOf(
            contains(r'a\u001b, b\u000a'),
            isNot(contains('\u001b')),
            isNot(contains('\n')),
          ),
        ),
      ),
    );
    expect(
      () => findThemeRoot(['a/\u202E/theme.yaml']),
      _missing(r'two or more folders deep: a/\u202e/theme.yaml'),
    );
  });

  test('M6: a long folder list is one text cut at 200 characters', () {
    expect(
      () => findThemeRoot([for (var i = 0; i < 100; i++) 'folder$i/x']),
      throwsA(
        isA<RemoteThemeFailure>().having(
          (f) => f.message,
          'message',
          allOf(endsWith('...'), isNot(contains('folder99'))),
        ),
      ),
    );
  });

  test('ignored entries: __MACOSX/ and .DS_Store only', () {
    expect(isIgnoredEntry('__MACOSX/x'), isTrue);
    expect(isIgnoredEntry('a/.DS_Store'), isTrue);
    expect(isIgnoredEntry('a/DS_Store'), isFalse);
    expect(isIgnoredEntry('theme.yaml'), isFalse);
  });
}
