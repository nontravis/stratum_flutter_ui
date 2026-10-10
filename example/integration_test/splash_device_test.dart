// Holds the engine's first frame under a splash screen on a device or a
// browser until the start theme is active (FO-03 US-12 FR-02, Scenario 2).
// Runs in roadmap phase stratum-device-round, never in a feature session:
//
//   flutter test integration_test/splash_device_test.dart -d <device>
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/splash_device_test.dart \
//     -d web-server --browser-name=chrome
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/stratum_ui.dart';

/// The app's asset bundle with the package default theme file held until
/// [release] completes, so the splash's preload stays open.
class _HeldBundle extends CachingAssetBundle {
  _HeldBundle(this.release);

  final Future<void> release;

  @override
  Future<ByteData> load(String key) => rootBundle.load(key);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == 'packages/stratum_ui/assets/themes/default/theme.yaml') {
      await release;
    }
    return rootBundle.loadString(key, cache: cache);
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('us12/fr02, us12/s2: no frame reaches the engine until the '
      'start theme is active; then the splash shows', (tester) async {
    final release = Completer<void>();
    // Held so `postload` cannot finish before the loading-app assertion
    // below runs: the live binding flushes every microtask ahead of its
    // own warm-up frame (`dart:ui` `Timer.run`, unlike the widget-test
    // binding, which draws it synchronously inside `allowFirstFrame`), so
    // an unheld `postload` would race past `StratumSplashLoadingApp`
    // before this test ever reads `states`.
    final postload = Completer<void>();
    final states = <String>[];
    binding.resetFirstFrameSent();
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _HeldBundle(release.future),
        child: StratumSplashScreen<void>(
          postload: (context, controller) => postload.future,
          builder: (context, state) {
            states.add(state.runtimeType.toString());
            return const ColoredBox(color: Color(0xFF2050C0));
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(binding.sendFramesToEngine, isFalse);
    expect(states, isEmpty);

    release.complete();
    await tester.pumpAndSettle();

    expect(binding.sendFramesToEngine, isTrue);
    expect(states.first, startsWith('StratumSplashLoadingApp'));

    postload.complete();
    await tester.pumpAndSettle();
  });
}
