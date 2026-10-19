import 'dart:io';

/// The real host OS this process runs on (`android`, `ios`, `macos`,
/// `linux`, `windows`, or `fuchsia`), from `dart:io`'s
/// `Platform.operatingSystem`.
///
/// Never `defaultTargetPlatform`: every `flutter test` process, debug or
/// release target, sets the `FLUTTER_TEST` environment variable, which
/// Flutter's own `defaultTargetPlatform` forces to `TargetPlatform.android`
/// regardless of the real host OS.
String get hostOSName => Platform.operatingSystem;
