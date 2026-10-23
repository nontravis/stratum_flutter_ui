/// Reaches the real `window.localStorage` on a web device test
/// (`local_storage_web.dart`'s own doc explains why), stubbed out
/// everywhere else so this file still compiles for native targets.
library;

/// `dart:js_interop` does not compile outside web, so the real read/write
/// lives in `local_storage_web.dart`, swapped for `local_storage_io.dart`'s
/// stub there.
export 'local_storage_web.dart' if (dart.library.io) 'local_storage_io.dart';
