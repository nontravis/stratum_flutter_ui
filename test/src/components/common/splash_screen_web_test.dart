@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/splash_screen.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:web/web.dart' as web;

import '../../themes/remote/remote_fakes.dart';

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
}
