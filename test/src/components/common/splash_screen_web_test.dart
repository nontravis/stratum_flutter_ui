@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:web/web.dart' as web;

import '../../themes/remote/remote_fakes.dart';
import '../../themes/remote/remote_test_zip.dart' show remoteSchemaLine;

void main() {
  testWidgets('us12/fr02/e02, us12/s3: the splash sends the page one '
      'stratum-splash-shown event, when it ends the hold', (tester) async {
    var events = 0;
    final listener = ((web.Event event) {
      events += 1;
    }).toJS;
    web.window.addEventListener('stratum-splash-shown', listener);
    addTearDown(
      () => web.window.removeEventListener('stratum-splash-shown', listener),
    );
    final work = Completer<String>();
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: RemoteFakeBundle(),
        child: StratumSplashScreen<String>(
          postload: (context, controller) => work.future,
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(events, 1);

    work.complete('ready');
    await tester.pumpAndSettle();
    expect(events, 1);
  });

  testWidgets(
    'us12/fr02/e02, us12/fr02/e03: a broken start theme still sends one '
    'event, and a retry sends no second one',
    (tester) async {
      var events = 0;
      final listener = ((web.Event event) {
        events += 1;
      }).toJS;
      web.window.addEventListener('stratum-splash-shown', listener);
      addTearDown(
        () => web.window.removeEventListener('stratum-splash-shown', listener),
      );
      final states = <StratumSplashState<String>>[];
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: RemoteFakeBundle(
            themes: {'brand': '$remoteSchemaLine\nspcae:\n  md: 12'},
          ),
          child: StratumSplashScreen<String>(
            initialThemeId: 'brand',
            postload: (context, controller) async => 'never',
            builder: (context, state) {
              states.add(state);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(states.last, isA<StratumSplashFailed<String>>());
      expect(events, 1);

      (states.last as StratumSplashFailed<String>).retry();
      await tester.pumpAndSettle();
      expect(events, 1);
    },
  );
}
