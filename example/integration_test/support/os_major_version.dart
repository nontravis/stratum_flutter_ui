/// The real OS major version this process reports, never faked by a test
/// binding override; null on a platform with no such version (web,
/// Android, Windows, Linux) or whose version string holds no parseable
/// number.
library;

/// `dart:io` does not compile for web, so the real read lives in
/// `os_major_version_io.dart`, swapped for `os_major_version_web.dart`'s
/// null stub there.
export 'os_major_version_web.dart'
    if (dart.library.io) 'os_major_version_io.dart';
