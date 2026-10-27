import 'package:stratum_ui/stratum_ui.dart';

/// Drawer fixture for a `PageLayout` whose box is smaller than the screen
/// (FO-06 US-19 FR-04).
///
/// Registered with `edgeToEdge: false`, so the host `SafeArea` stays above
/// the page and narrows its box by the system-bar insets. The box node reads
/// id `page_drawer_in_safe_area.box`. The page's `left` is a drawer on every
/// window size: text `Drawer link A` (id `page_drawer_in_safe_area.link_a`).
/// The body holds text `Page body` and button `Open drawer`, which opens the
/// drawer at once. The button carries no id: a semantics identifier would
/// split its label and role from its tap onto two nodes.
class PageDrawerInSafeAreaFixture extends StatefulWidget {
  const PageDrawerInSafeAreaFixture({super.key});

  @override
  State<PageDrawerInSafeAreaFixture> createState() =>
      _PageDrawerInSafeAreaFixtureState();
}

class _PageDrawerInSafeAreaFixtureState
    extends State<PageDrawerInSafeAreaFixture> {
  // MARK: - Properties

  final _controller = PageLayoutController();

  // MARK: - Lifecycle

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // MARK: - Build

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      identifier: 'page_drawer_in_safe_area.box',
      child: PageLayout(
        controller: _controller,
        // The largest window size, so the left pane is a drawer on every
        // window, the tablet one included.
        drawerCut: WindowSize.bigDesktop,
        left: Semantics(
          identifier: 'page_drawer_in_safe_area.link_a',
          child: const Text('Drawer link A'),
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
          ],
        ),
      ),
    );
  }
}
