import 'dart:async';

import 'package:stratum_ui/stratum_ui.dart';

/// How long one splash generation lives before the fixture bumps its key and
/// the splash starts again, in every cycle.
const splashScreenFixtureCycle = Duration(seconds: 7);

/// How long the fixture's `postload` holds the app-loading frame before the
/// done frame appears, in every cycle.
const splashScreenFixtureHold = Duration(seconds: 4);

/// Fixture for the loading frames a `StratumSplashScreen` announces to screen
/// readers (FO-03 US-12 FR-08).
///
/// One `StratumSplashScreen<void>` at a time, keyed by a generation the
/// fixture bumps every [splashScreenFixtureCycle], so the splash starts again
/// and a screen reader turned on after launch still meets a loading frame.
/// `postload` waits [splashScreenFixtureHold]; the builder draws a spinner for
/// both loading states, text `Start failed` at `StratumSplashFailed`, and text
/// `Started` (id `splash_screen.done`) at `StratumSplashDone`. No
/// `loadingLabel` is passed, so a loading frame reads the built-in `Loading`.
class SplashScreenFixture extends StatefulWidget {
  const SplashScreenFixture({super.key});

  @override
  State<SplashScreenFixture> createState() => _SplashScreenFixtureState();
}

class _SplashScreenFixtureState extends State<SplashScreenFixture> {
  // MARK: - Properties

  int _generation = 0;

  Timer? _timer;

  // MARK: - Lifecycle

  @override
  void initState() {
    super.initState();
    _scheduleNextGeneration();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // MARK: - Build

  @override
  Widget build(BuildContext context) {
    return StratumSplashScreen<void>(
      key: ValueKey(_generation),
      // No wait for Google fonts: a fixture must not depend on the network.
      googleFontsTimeout: Duration.zero,
      postload: (context, controller) async {
        await Future<void>.delayed(splashScreenFixtureHold);
      },
      builder: (context, state) {
        if (state is StratumSplashLoadingTheme<void> ||
            state is StratumSplashLoadingApp<void>) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is StratumSplashFailed<void>) {
          return const Center(child: Text('Start failed'));
        }
        return Center(
          child: Semantics(
            identifier: 'splash_screen.done',
            child: const Text('Started'),
          ),
        );
      },
    );
  }

  // MARK: - Private Methods

  void _scheduleNextGeneration() {
    _timer = Timer(splashScreenFixtureCycle, _bumpGeneration);
  }

  void _bumpGeneration() {
    setState(() => _generation++);
    _scheduleNextGeneration();
  }
}
