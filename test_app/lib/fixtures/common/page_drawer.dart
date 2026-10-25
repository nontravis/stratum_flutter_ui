import 'package:stratum_ui/stratum_ui.dart';

/// Drawer fixture for the open drawer and its scrim that a `PageLayout` shows
/// (FO-06 US-19 FR-05).
///
/// A page whose `left` is a drawer on every window size: text `Drawer link A`
/// (id `page_drawer.link_a`) and text `Drawer link B`. The body holds text
/// `Page body`, button `Open drawer`, which opens the drawer at once, and
/// button `Open drawer when VoiceOver is on`, which a tap arms. Once armed,
/// the first screen reader focus in the app is the reader's start-up focus;
/// the drawer opens on the next focus move, which a test makes after it has
/// heard the reader's first read, so the drawer never opens while the reader
/// is still starting. The buttons carry no id: a semantics identifier would
/// split a button's label and role from its tap onto two nodes, so a test
/// finds each by its label. The drawer carries no label of its own: it reads
/// `Navigation menu` and its scrim `Dismiss`.
class PageDrawerFixture extends StatefulWidget {
  const PageDrawerFixture({super.key});

  @override
  State<PageDrawerFixture> createState() => _PageDrawerFixtureState();
}

class _PageDrawerFixtureState extends State<PageDrawerFixture> {
  // MARK: - Properties

  final _controller = PageLayoutController();

  /// Whether a tap armed `Open drawer when VoiceOver is on`.
  bool _armed = false;

  /// Screen reader focus changes seen since the arming tap.
  int _focusMoves = 0;

  // MARK: - Lifecycle

  @override
  void initState() {
    super.initState();
    ServicesBinding.instance.accessibilityFocus.addListener(_onReaderFocus);
  }

  @override
  void dispose() {
    ServicesBinding.instance.accessibilityFocus.removeListener(_onReaderFocus);
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
            onPressed: () => _armed = true,
            child: const Text('Open drawer when VoiceOver is on'),
          ),
        ],
      ),
    );
  }

  // MARK: - Private Methods

  /// Opens the drawer on the second focus change after arming: the first is
  /// the screen reader's start-up focus, the second a move the test makes.
  void _onReaderFocus() {
    if (!_armed) return;
    _focusMoves += 1;
    if (_focusMoves == 2) _controller.openLeft();
  }
}
