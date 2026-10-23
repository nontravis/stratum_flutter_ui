import 'package:stratum_ui/stratum_ui.dart';

/// The app-wide style of the fixture (`system_style_device_test.dart:29`):
/// the switcher label `Stratum`, every look field left to the theme.
const systemStyleFixtureAppWide = SystemStyle(appSwitcherLabel: 'Stratum');

/// The video page's style (`system_style_device_test.dart:31-35`):
/// `immersiveSticky` bars, `portraitUp` only, the switcher label `Video`.
const systemStyleFixtureVideo = SystemStyle(
  barMode: SystemBarMode.immersiveSticky,
  orientations: [DeviceOrientation.portraitUp],
  appSwitcherLabel: 'Video',
);

/// The status bar color the dark-status-bar page paints under the bar
/// (`system_style_device_test.dart:152`).
const systemStyleFixtureDarkBarColor = Color(0xFF101828);

/// The header color of the dark-header page
/// (`system_style_device_test.dart:117`).
const systemStyleFixtureDarkHeaderColor = Color(0xFF101828);

const _openDarkHeader = 'Open dark header';
const _openWhitePage = 'Open white page';
const _openDarkStatusBar = 'Open dark status bar';
const _openVideo = 'Open video';

/// The system-style fixture: the pages and styles of
/// `system_style_device_test.dart:28-95`, hosted for the M3-T19 Appium
/// legs.
///
/// Buttons `Open dark header`, `Open white page`, `Open dark status bar`, and
/// `Open video` each push their page onto the navigator. They carry no id: a
/// semantics identifier would split a button's label and role from its tap
/// onto two nodes, so a test finds each by its label. The menu page holds [systemStyleFixtureAppWide] in a scope,
/// so back from a page restores the app-wide bars, rotation, and label
/// with no restore code.
class SystemStyleFixture extends StatelessWidget {
  const SystemStyleFixture({super.key});

  @override
  Widget build(BuildContext context) {
    return SystemStyleScope(
      style: systemStyleFixtureAppWide,
      child: ColumnLayout(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final label in const [
            _openDarkHeader,
            _openWhitePage,
            _openDarkStatusBar,
            _openVideo,
          ])
            FilledButton(
              onPressed: () => _open(context, label),
              child: Text(label),
            ),
        ],
      ),
    );
  }

  void _open(BuildContext context, String label) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (context) => _page(label)));
  }

  static Widget _page(String label) => switch (label) {
    _openDarkHeader => _headerPage(),
    _openWhitePage => const _WhitePage(),
    _openDarkStatusBar => _statusBarPage(),
    _ => const _VideoPage(),
  };
}

/// A page with a [color] header under the status bar, declared to the bar
/// resolver through `SystemBarFill`
/// (`system_style_device_test.dart:58-69`).
Widget _headerPage() => ColumnLayout(
  children: [
    SystemBarFill(
      color: systemStyleFixtureDarkHeaderColor,
      child: ColoredBox(
        color: systemStyleFixtureDarkHeaderColor,
        child: const SizedBox(width: double.infinity, height: 120),
      ),
    ),
    const Expanded(child: _PageBody('Dark header')),
  ],
);

/// A page that paints the theme's own light-mode page background under
/// the status bar with no fill declared to Stratum
/// (`system_style_device_test.dart:85-92`), so the by-eye and automated
/// checks see the same color the system style resolver picked icons
/// against.
class _WhitePage extends StatelessWidget {
  const _WhitePage();

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: ColoredBox(
          key: const Key('system_style.white_page_fill'),
          color: StratumTheme.of(context).data.color.background.defaults.normal,
        ),
      ),
      const _PageBody('White page'),
    ],
  );
}

/// A page whose scope paints [systemStyleFixtureDarkBarColor] under the
/// status bar, set per page through `SystemStyleScope`
/// (`system_style_device_test.dart:142-152`).
Widget _statusBarPage() => SystemStyleScope(
  style: const SystemStyle(statusBarColor: systemStyleFixtureDarkBarColor),
  child: const _PageBody('Dark status bar'),
);

/// The video page: [systemStyleFixtureVideo] over the whole page
/// (`system_style_device_test.dart:175-179`).
class _VideoPage extends StatelessWidget {
  const _VideoPage();

  @override
  Widget build(BuildContext context) => SystemStyleScope(
    style: systemStyleFixtureVideo,
    child: const _PageBody('Video'),
  );
}

/// A page body: a label naming the page, centered.
class _PageBody extends StatelessWidget {
  const _PageBody(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => ColumnLayout(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [Text(label)],
  );
}
