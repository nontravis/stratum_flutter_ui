import 'dart:io';

/// The leading integer of `Platform.operatingSystemVersion`'s `Version NN`
/// prefix, which both iOS and macOS report; null for a string with no
/// such prefix, as Android, Windows, and Linux report.
int? get realOSMajorVersion {
  final match = RegExp(r'^Version (\d+)')
      .firstMatch(Platform.operatingSystemVersion);
  return match == null ? null : int.parse(match.group(1)!);
}
