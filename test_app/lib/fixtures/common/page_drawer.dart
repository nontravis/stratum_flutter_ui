import 'dart:async';

import 'package:stratum_ui/stratum_ui.dart';

/// How long `Open drawer in 5 s` waits before it opens the drawer, so a screen
/// reader is already on when the drawer appears.
const pageDrawerFixtureOpenDelay = Duration(seconds: 5);

/// Drawer fixture for the open drawer and its scrim that a `PageLayout` shows
/// (FO-06 US-19 FR-05).
///
/// A page whose `left` is a drawer on every window size: text `Drawer link A`
/// (id `page_drawer.link_a`) and text `Drawer link B`. The body holds text
/// `Page body`, button `Open drawer`, which opens the drawer at once, and
/// button `Open drawer in 5 s`, which opens it after
/// [pageDrawerFixtureOpenDelay]. The buttons carry no id: a semantics
/// identifier would split a button's label and role from its tap onto two
/// nodes, so a test finds each by its label. The drawer carries no label of
/// its own: it reads `Navigation menu` and its scrim `Dismiss`.
class PageDrawerFixture extends StatefulWidget {
  const PageDrawerFixture({super.key});

  @override
  State<PageDrawerFixture> createState() => _PageDrawerFixtureState();
}

class _PageDrawerFixtureState extends State<PageDrawerFixture> {
  // MARK: - Properties

  final _controller = PageLayoutController();

  Timer? _openTimer;

  // MARK: - Lifecycle

  @override
  void dispose() {
    _openTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // MARK: - Build

  @override
  Widget build(BuildContext context) {
    return PageLayout(
      controller: _controller,
      // The largest window size, so the left pane is a drawer on every window,
      // the tablet one included.
      drawerCut: WindowSize.bigDesktop,
      left: ColumnLayout(
        mainAxisAlignment: MainAxisAlignment.center,
        gap: 8,
        children: [
          Semantics(
            identifier: 'page_drawer.link_a',
            child: const Text('Drawer link A'),
          ),
          const Text('Drawer link B'),
        ],
      ),
      body: ColumnLayout(
        mainAxisAlignment: MainAxisAlignment.center,
        gap: 8,
        children: [
          const Text('Page body'),
          FilledButton(
            onPressed: _controller.openLeft,
            child: const Text('Open drawer'),
          ),
          FilledButton(
            onPressed: _openLater,
            child: const Text('Open drawer in 5 s'),
          ),
        ],
      ),
    );
  }

  // MARK: - Private Methods

  void _openLater() {
    _openTimer?.cancel();
    _openTimer = Timer(pageDrawerFixtureOpenDelay, _controller.openLeft);
  }
}
