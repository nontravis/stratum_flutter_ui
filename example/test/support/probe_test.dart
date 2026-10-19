import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/probe.dart';

void main() {
  late Directory ackDir;

  setUp(() {
    ackDir = Directory.systemTemp.createTempSync('probe_ack_test');
  });

  tearDown(() {
    if (ackDir.existsSync()) {
      ackDir.deleteSync(recursive: true);
    }
  });

  test('a stale ack present before the call does not end the wait before the '
      "marker's own fresh ack lands", () async {
    final ackFile = File('${ackDir.path}/dark_header')
      ..createSync(recursive: true);
    final stopwatch = Stopwatch()..start();
    var markerFired = false;

    await awaitProbeAck(
      ackDir: ackDir,
      name: 'dark_header',
      pollInterval: const Duration(milliseconds: 1),
      timeout: const Duration(milliseconds: 500),
      onReady: () {
        markerFired = true;
        unawaited(
          Future<void>.delayed(const Duration(milliseconds: 40), () {
            ackFile.writeAsStringSync('');
          }),
        );
      },
    );

    expect(markerFired, isTrue);
    expect(
      stopwatch.elapsed,
      greaterThanOrEqualTo(const Duration(milliseconds: 35)),
    );
    expect(ackFile.existsSync(), isFalse);
  });

  test(
    'a fresh ack written after the marker ends the wait and is deleted',
    (() async {
      final ackFile = File('${ackDir.path}/white_page');

      await awaitProbeAck(
        ackDir: ackDir,
        name: 'white_page',
        pollInterval: const Duration(milliseconds: 1),
        timeout: const Duration(milliseconds: 500),
        onReady: () => ackFile.writeAsStringSync(''),
      );

      expect(ackFile.existsSync(), isFalse);
    }),
  );

  test('no ack fails with the exact probe ack timeout text', () async {
    await expectLater(
      () => awaitProbeAck(
        ackDir: ackDir,
        name: 'video_back',
        pollInterval: const Duration(milliseconds: 1),
        timeout: const Duration(milliseconds: 50),
        onReady: () {},
      ),
      throwsA(
        isA<TestFailure>().having(
          (failure) => failure.message,
          'message',
          'probe ack timeout: video_back',
        ),
      ),
    );
  });
}
