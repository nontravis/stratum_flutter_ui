import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';

import 'os_major_version.dart';

/// How often [probe] polls for the capture script's ack file (device-test
/// probe contract item 1b).
const _pollInterval = Duration(milliseconds: 100);

/// How long [probe] waits for the ack before failing (item 1b).
const _ackTimeout = Duration(seconds: 60);

/// Whether this run's target has a capture script watching it at all
/// (device-test probe contract item 1b): a real Android or iOS device or
/// simulator does; desktop, web, and `-d flutter-tester` do not.
///
/// `-d flutter-tester` reports Android to [defaultTargetPlatform] with no
/// window manager or capture script behind it, caught the same way
/// `page_layout_m2_device_test.dart`'s `_canShowSoftKeyboard` catches it:
/// only that fake Android run also reports a real, Apple, OS version.
bool get _hasProbeCapture {
  if (kIsWeb) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return realOSMajorVersion == null;
    case TargetPlatform.iOS:
      return true;
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      return false;
  }
}

/// The ack directory a device-test host script writes into (`probe_ack/`
/// under the app's own support dir): shared by [probe] and
/// `host_action.dart`'s `hostAction`/`attend` (host-action contract, device
/// side, item 1).
Future<Directory> probeAckDir() async {
  final supportDir = await getApplicationSupportDirectory();
  return Directory('${supportDir.path}/probe_ack');
}

/// Marks probe [name] (device-test probe contract item 1) and, on a target
/// the capture script watches, holds until that script acks the capture
/// (item 1b) instead of on a fixed timer.
///
/// Clears any ack `probe_ack/<name>` left by an earlier launch before
/// printing `PROBE:<name>`, so only an ack written after this marker can end
/// the wait. Fails with `probe ack timeout: <name>` after 60 s with no ack.
/// Returns at once on a target with no capture script.
Future<void> probe(String name) async {
  if (!_hasProbeCapture) {
    debugPrint('PROBE:$name');
    return;
  }

  await awaitProbeAck(
    ackDir: await probeAckDir(),
    name: name,
    pollInterval: _pollInterval,
    timeout: _ackTimeout,
    onReady: () => debugPrint('PROBE:$name'),
  );
}

/// Clears a stale ack for [name] under [ackDir], calls [onReady] (where
/// [probe] prints its marker), then polls for a fresh `<name>` file every
/// [pollInterval] until one appears or [timeout] elapses, deleting it once
/// found.
///
/// Exposed so a plain `flutter test` can drive the wait with a temp
/// directory. Fails with `probe ack timeout: <name>` on timeout.
@visibleForTesting
Future<void> awaitProbeAck({
  required Directory ackDir,
  required String name,
  required Duration pollInterval,
  required Duration timeout,
  required void Function() onReady,
}) async {
  final ackFile = File('${ackDir.path}/$name');
  if (ackFile.existsSync()) {
    ackFile.deleteSync();
  }

  onReady();

  final deadline = DateTime.now().add(timeout);
  while (!ackFile.existsSync()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('probe ack timeout: $name');
    }
    await Future<void>.delayed(pollInterval);
  }
  await ackFile.delete();
}
