import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'probe.dart';

/// How often [hostAction] polls for the host's ack or fail file
/// (host-action contract, device side, item 1).
const _actionPollInterval = Duration(milliseconds: 100);

/// How long [hostAction] waits for the host to answer before failing
/// (contract item 1).
const _actionTimeout = Duration(seconds: 60);

/// How long [attend] waits for a human to confirm before failing (contract
/// item 2).
const _attendTimeout = Duration(seconds: 300);

/// Whether an attended test actually runs (contract items 2, 7): set by
/// `--dart-define=DT_ATTENDED=true`, which `--attended` (round and run)
/// adds to the launch argv; without it nothing changes.
///
/// Public so a caller can gate a whole attended `testWidgets` on it through
/// `skip:` at registration time, rather than inside the test body: a
/// mid-body `markTestSkipped` (what [attend] still falls back to) turns an
/// otherwise-passing automated test's result into "skipped" too, since a
/// skip set anywhere in a test overrides its own earlier assertions.
const attended = bool.fromEnvironment('DT_ATTENDED');

/// Asks the host to run [verb] (with [args]) through [id], waiting bounded
/// 60 s for a success ack or a named failure (host-action contract, device
/// side, item 1).
///
/// Clears any stale `probe_ack/<id>` or `probe_ack/<id>.fail` left by an
/// earlier launch before printing `ACTION:<id> <verb> <args...>`, so only a
/// file written after this marker can end the wait.
///
/// Fails with `host action failed: <id>` on `<id>.fail`, or
/// `host action timeout: <id>` after 60 s with neither file.
Future<void> hostAction(
  String id,
  String verb, [
  List<String> args = const [],
]) async {
  final ackDir = await probeAckDir();
  final ackFile = File('${ackDir.path}/$id');
  final failFile = File('${ackDir.path}/$id.fail');
  if (ackFile.existsSync()) ackFile.deleteSync();
  if (failFile.existsSync()) failFile.deleteSync();

  debugPrint('ACTION:$id ${[verb, ...args].join(' ')}');

  final deadline = DateTime.now().add(_actionTimeout);
  while (!ackFile.existsSync() && !failFile.existsSync()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('host action timeout: $id');
    }
    await Future<void>.delayed(_actionPollInterval);
  }
  if (failFile.existsSync()) {
    await failFile.delete();
    fail('host action failed: $id');
  }
  await ackFile.delete();
}

/// Asks a human to follow [instruction] on [id], waiting bounded 300 s for a
/// confirmation (host-action contract, device side, item 2).
///
/// Skips the calling test with a named reason and returns `false` unless
/// launched with `--attended`; a caller returns right after a `false`, the
/// same way `markTestSkipped` callers elsewhere in this directory do.
/// Reuses `probe.dart`'s ack-dir wait (`awaitProbeAck`) to print
/// `ATTEND:<id> <instruction>` and wait for the ack `device-test.sh ack`
/// writes.
Future<bool> attend(String id, String instruction) async {
  if (!attended) {
    markTestSkipped('attended test; rerun with --attended: $id');
    return false;
  }
  await awaitProbeAck(
    ackDir: await probeAckDir(),
    name: id,
    pollInterval: _actionPollInterval,
    timeout: _attendTimeout,
    onReady: () => debugPrint('ATTEND:$id $instruction'),
  );
  return true;
}
