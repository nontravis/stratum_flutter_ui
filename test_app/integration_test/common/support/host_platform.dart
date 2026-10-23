/// `hostOSName`, the real host OS a device file reads instead of
/// `defaultTargetPlatform` (`host_platform_io.dart`'s doc explains why).
library;

/// `dart:io` does not compile for web, so the real read lives in
/// `host_platform_io.dart`, swapped for `host_platform_web.dart`'s stub
/// there.
export 'host_platform_web.dart' if (dart.library.io) 'host_platform_io.dart';
