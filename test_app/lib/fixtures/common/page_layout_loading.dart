import 'dart:async';

import 'package:stratum_ui/stratum_ui.dart';

/// How long the fixture's page stays idle before `loading` turns true, in
/// every cycle.
const pageLayoutLoadingFixtureIdle = Duration(seconds: 3);

/// How long the fixture's page stays busy before `loading` turns false again,
/// in every cycle.
const pageLayoutLoadingFixtureBusy = Duration(seconds: 4);

/// Fixture for the loading layer a busy `PageLayout` shows (FO-06 US-18
/// FR-06).
///
/// A page whose body is text `Page body`. From mount until dispose its
/// `loading` cycles: false for [pageLayoutLoadingFixtureIdle], then true for
/// [pageLayoutLoadingFixtureBusy], and again. The cycle lets a screen reader
/// turned on after launch catch a later turn to loading.
class PageLayoutLoadingFixture extends StatefulWidget {
  const PageLayoutLoadingFixture({super.key});

  @override
  State<PageLayoutLoadingFixture> createState() =>
      _PageLayoutLoadingFixtureState();
}

class _PageLayoutLoadingFixtureState extends State<PageLayoutLoadingFixture> {
  // MARK: - Properties

  bool _loading = false;

  Timer? _timer;

  // MARK: - Lifecycle

  @override
  void initState() {
    super.initState();
    _scheduleNextTurn();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // MARK: - Build

  @override
  Widget build(BuildContext context) {
    return PageLayout(loading: _loading, body: const Text('Page body'));
  }

  // MARK: - Private Methods

  void _scheduleNextTurn() {
    final stretch = _loading
        ? pageLayoutLoadingFixtureBusy
        : pageLayoutLoadingFixtureIdle;
    _timer = Timer(stretch, _turn);
  }

  void _turn() {
    setState(() => _loading = !_loading);
    _scheduleNextTurn();
  }
}
